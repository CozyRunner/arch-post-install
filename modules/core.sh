#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: core.sh
# Description: Shared utilities, logging engine, and YAML parsing fallbacks.
#              This is the heart of the post-install framework.
# ──────────────────────────────────────────────────────────────────────────────

# Resolve the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034
CONFIG_DIR="${SCRIPT_DIR}/config"
# shellcheck disable=SC2034
DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"
LOG_DIR="${SCRIPT_DIR}/logs"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Log file for current run
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

# Global flags
# shellcheck disable=SC2034
VERBOSE=false
# shellcheck disable=SC2034
DRY_RUN=false

# /**
#  * cleanup_on_exit()
#  * Handles script termination and logs errors if the exit code is non-zero.
#  */
cleanup_on_exit() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Script failed. Log saved to: ${LOG_FILE}"
    fi
}
trap cleanup_on_exit EXIT

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Logging ───────────────────────────────────────────────────────────────────
# Standardized logging functions that print to stdout and append to the log file.

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*" | tee -a "${LOG_FILE}"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $*" | tee -a "${LOG_FILE}"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*" | tee -a "${LOG_FILE}"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*" | tee -a "${LOG_FILE}"; }
log_step()    { echo -e "\n${CYAN}${BOLD}▸ $*${NC}\n" | tee -a "${LOG_FILE}"; }
log_debug()   { [[ "${VERBOSE}" == true ]] && echo -e "${GRAY}[DEBUG]${NC}  $*" | tee -a "${LOG_FILE}" || true; }

# /**
#  * run_logged()
#  * Runs a command, appends its combined output to the log, prints it, and
#  * returns the COMMAND's exit status.
#  *
#  * Prefer this over `if some_cmd | tee -a "$LOG_FILE"; then`:
#  * without `set -o pipefail` a pipeline's status is tee's status, so a failed
#  * command reads as success. The Makefile targets source core.sh directly and
#  * do NOT set pipefail, so that pattern silently inverts these decisions.
#  */
run_logged() {
    local output rc=0
    output="$("$@" 2>&1)" || rc=$?
    [[ -n "${output}" ]] && printf '%s\n' "${output}" | tee -a "${LOG_FILE}"
    return "${rc}"
}

# ── Network check ─────────────────────────────────────────────────────────────
# /**
#  * check_internet()
#  * Verifies that the system has an active internet connection.
#  * Returns 0 if connected, 1 otherwise.
#  */
check_internet() {
    log_step "Checking internet connectivity..."
    if curl -s --max-time 5 https://archlinux.org > /dev/null 2>&1; then
        log_success "Internet connection verified"
        return 0
    elif ping -c 1 -W 3 archlinux.org > /dev/null 2>&1; then
        log_success "Internet connection verified (via ping)"
        return 0
    else
        log_error "No internet connection. Please check your network."
        return 1
    fi
}

# ── Checks ────────────────────────────────────────────────────────────────────
# /**
#  * require_root()
#  * Ensures the script is NOT run as root, but that the user has sudo privileges.
#  */
require_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root. Use a normal user with sudo."
        exit 1
    fi

    # Verify sudo access
    if ! sudo -v 2>/dev/null; then
        log_error "sudo access required but not available. Add user to wheel group."
        exit 1
    fi
}

# /**
#  * require_arch()
#  * Ensures the script is running on Arch Linux.
#  */
require_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is designed for Arch Linux only."
        exit 1
    fi
}

# /**
#  * require_command()
#  * Verifies that a specific command is available in the PATH.
#  * @param {string} cmd - The command to check.
#  */
require_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "Required command '${cmd}' not found."
        return 1
    fi
}

# ── YAML Parsing ──────────────────────────────────────────────────────────────
# `yq` is a HARD dependency. The previous grep-based fallback computed nesting
# depth with `${key//[^:]}`, which is always 0 for dot-separated keys
# (packages.pacman, user.groups, ...). It therefore returned EMPTY for every
# nested list while exiting 0, which on a system without yq meant zero packages
# installed and zero groups assigned — with no error. See lib/common.sh for the
# validator-side equivalent.
#
# yq is installed by setup_core() during the "full"/"base" flows, before the
# first config read. require_yaml_parser() guards the paths that skip it.
YAML_PARSER="yq"

# /**
#  * require_yaml_parser()
#  * Verifies the YAML parser is available. Returns non-zero with an actionable
#  * message if it is not, so callers fail fast instead of acting on an empty
#  * config that looks valid.
#  */
require_yaml_parser() {
    if ! command -v "${YAML_PARSER}" &>/dev/null; then
        log_error "Required dependency '${YAML_PARSER}' not found in PATH."
        log_error "Configuration is read from YAML; refusing to continue with a mis-parsed config."
        log_error "Install it with: sudo pacman -S --needed ${YAML_PARSER}"
        return 1
    fi
    return 0
}

# /**
#  * yaml_list()
#  * Extracts a list (array) from a YAML file.
#  * @param {string} file - Path to the YAML file.
#  * @param {string} key - The YAML key (e.g., "packages.pacman").
#  * @returns {string} - Newline-separated list of values.
#  */
yaml_list() {
    local file="$1" key="$2"

    if [[ ! -f "${file}" ]]; then
        log_error "Config file not found: ${file}"
        return 1
    fi
    require_yaml_parser || return 1
    yq -r ".${key}[]? // empty" "${file}" 2>/dev/null
}

# /**
#  * yaml_value()
#  * Extracts a single scalar value from a YAML file.
#  * @param {string} file - Path to the YAML file.
#  * @param {string} key - The YAML key.
#  * @returns {string} - The value of the key.
#  */
yaml_value() {
    local file="$1" key="$2"

    if [[ ! -f "${file}" ]]; then
        log_error "Config file not found: ${file}"
        return 1
    fi
    require_yaml_parser || return 1
    yq -r ".${key} // empty" "${file}" 2>/dev/null
}

# ── System Update ─────────────────────────────────────────────────────────────
# /**
#  * setup_core()
#  * Performs initial system update and installs essential tools (yq).
#  */
setup_core() {
    log_step "Updating system"
    check_internet || { log_error "Cannot proceed without internet"; exit 1; }
    
    # Update pacman databases and system
    sudo pacman -Syu --noconfirm 2>&1 | tee -a "${LOG_FILE}"
    
    # Ensure yq is installed (used for YAML parsing)
    if ! command -v yq &>/dev/null; then
        log_info "yq not found, installing..."
        sudo pacman -S --needed --noconfirm yq 2>&1 | tee -a "${LOG_FILE}"
    fi

    log_success "System updated and core tools verified"
}

# /**
#  * ensure_yay()
#  * Installs the yay AUR helper if it's not already available.
#  */
ensure_yay() {
    if ! command -v yay &>/dev/null; then
        log_info "yay not found, installing..."
        bash "${SCRIPT_DIR}/scripts/install_yay.sh" 2>&1 | tee -a "${LOG_FILE}"
    else
        log_success "yay is already installed"
    fi
}
