#!/usr/bin/env bash

# ─────────────────────────────────────────────
# core.sh — Shared utilities and helpers
# ─────────────────────────────────────────────

# Resolve the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"
LOG_DIR="${SCRIPT_DIR}/logs"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Log file for current run
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

# Verbose mode (set via -v flag)
VERBOSE=false
DRY_RUN=false

# Cleanup handler
cleanup_on_exit() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Script failed. Log saved to: ${LOG_FILE}"
    fi
}
trap cleanup_on_exit EXIT

# ── Colors ────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Logging ───────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${NC}    $*" | tee -a "${LOG_FILE}"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $*" | tee -a "${LOG_FILE}"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*" | tee -a "${LOG_FILE}"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*" | tee -a "${LOG_FILE}"; }
log_step()    { echo -e "\n${CYAN}${BOLD}▸ $*${NC}\n" | tee -a "${LOG_FILE}"; }
log_debug()   { [[ "${VERBOSE}" == true ]] && echo -e "${GRAY}[DEBUG]${NC}  $*" | tee -a "${LOG_FILE}"; }

# ── Network check ─────────────────────────────
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

# ── Checks ────────────────────────────────────
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

require_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is designed for Arch Linux only."
        exit 1
    fi
}

require_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "Required command '${cmd}' not found."
        return 1
    fi
}

# ── YAML Parsing ──────────────────────────────
# Uses yq to read YAML config files.
# Falls back to a basic grep parser if yq is unavailable.

yaml_list() {
    # Usage: yaml_list <file> <key>
    # Returns a newline-separated list of values under a YAML array key.
    local file="$1" key="$2"

    if command -v yq &>/dev/null; then
        yq -r ".${key}[]? // empty" "${file}" 2>/dev/null
    else
        # Fallback: basic parser for simple YAML arrays
        _yaml_list_fallback "${file}" "${key}"
    fi
}

yaml_value() {
    # Usage: yaml_value <file> <key>
    # Returns a single scalar value.
    local file="$1" key="$2"

    if command -v yq &>/dev/null; then
        yq -r ".${key} // empty" "${file}" 2>/dev/null
    else
        _yaml_value_fallback "${file}" "${key}"
    fi
}

_yaml_list_fallback() {
    # Simple line-by-line YAML list parser (handles nested `key:\n  - val` format)
    local file="$1" key="$2"
    local in_block=false
    local depth=0
    local target_depth="${key//[^:]}"  # Count colons for depth
    target_depth="${#target_depth}"
    local key_segments=(${key//./ })
    local current_segment=0
    local match_key="${key_segments[-1]}"

    while IFS= read -r line; do
        # Strip leading whitespace for easier parsing
        local stripped="${line#"${line%%[![:space:]]*}"}"

        # Track current depth based on leading spaces
        local line_depth=0
        if [[ "${stripped}" =~ ^([[:space:]]*) ]]; then
            line_depth=$((${#BASH_REMATCH[1]} / 2))
        fi

        # Skip empty lines and comments
        [[ -z "${stripped}" || "${stripped}" =~ ^# ]] && continue

        # Parse key-value
        if [[ "${stripped}" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
            local current_key="${BASH_REMATCH[1]}"
            local current_val="${BASH_REMATCH[2]}"

            # Handle parent keys for nested structures
            if [[ "${line_depth}" -eq $((target_depth - 1)) && "${current_key}" == "${match_key}" ]]; then
                in_block=true
                continue
            fi

            # If we're inside our target block and hit a sibling key at same depth, stop
            if ${in_block} && [[ "${line_depth}" -le $((target_depth - 1)) && -n "${current_val}" ]]; then
                break
            fi
        fi

        if ${in_block}; then
            if [[ "${stripped}" =~ ^-[[:space:]]+(.*) ]]; then
                echo "${BASH_REMATCH[1]}"
            elif [[ "${stripped}" =~ ^-[[:space:]]*$ ]]; then
                continue
            else
                break
            fi
        fi
    done < "${file}"
}

_yaml_value_fallback() {
    local file="$1" key="$2"
    local match_key="${key##*.}"

    grep -E "^[[:space:]]*${match_key}:" "${file}" 2>/dev/null \
        | head -1 \
        | sed 's/.*:[[:space:]]*//'
}

# ── System Update ─────────────────────────────
setup_core() {
    log_step "Updating system"
    check_internet || { log_error "Cannot proceed without internet"; exit 1; }
    sudo pacman -Syu --noconfirm 2>&1 | tee -a "${LOG_FILE}"
    log_success "System updated"
}

# ── Ensure yay is available ───────────────────
ensure_yay() {
    if ! command -v yay &>/dev/null; then
        log_info "yay not found, installing..."
        bash "${SCRIPT_DIR}/scripts/install_yay.sh" 2>&1 | tee -a "${LOG_FILE}"
    else
        log_success "yay is already installed"
    fi
}
