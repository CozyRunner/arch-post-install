#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Library: common.sh
# Description: Core helper functions, system detection, YAML parsing integration,
#              and environment inspection for validation & health checks.
# ──────────────────────────────────────────────────────────────────────────────

# Resolve root directory of the repository
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${LIB_DIR}/.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"
# shellcheck disable=SC2034
SCRIPTS_DIR="${ROOT_DIR}/scripts"
# shellcheck disable=SC2034
DOTFILES_DIR="${ROOT_DIR}/dotfiles"

# Load checks.conf if available
CHECKS_CONF="${CONFIG_DIR}/checks.conf"
if [[ -f "${CHECKS_CONF}" ]]; then
    # shellcheck disable=SC1090
    source "${CHECKS_CONF}"
fi

# Fallback default configuration values if not set
# shellcheck disable=SC2034
DISK_WARN_PERCENT="${DISK_WARN_PERCENT:-80}"
# shellcheck disable=SC2034
DISK_FAIL_PERCENT="${DISK_FAIL_PERCENT:-95}"
# shellcheck disable=SC2034
INODE_WARN_PERCENT="${INODE_WARN_PERCENT:-85}"
# shellcheck disable=SC2034
INODE_FAIL_PERCENT="${INODE_FAIL_PERCENT:-95}"
# shellcheck disable=SC2034
JOURNAL_WARN_MB="${JOURNAL_WARN_MB:-500}"
# shellcheck disable=SC2034
JOURNAL_FAIL_MB="${JOURNAL_FAIL_MB:-2048}"
# shellcheck disable=SC2034
PING_HOST="${PING_HOST:-archlinux.org}"
# shellcheck disable=SC2034
PING_TIMEOUT="${PING_TIMEOUT:-3}"
# shellcheck disable=SC2034
HTTP_URL="${HTTP_URL:-https://archlinux.org}"
# shellcheck disable=SC2034
HTTP_TIMEOUT="${HTTP_TIMEOUT:-5}"
# shellcheck disable=SC2034
MEM_WARN_PERCENT="${MEM_WARN_PERCENT:-85}"
# shellcheck disable=SC2034
MEM_FAIL_PERCENT="${MEM_FAIL_PERCENT:-95}"
# shellcheck disable=SC2034
SWAP_WARN_PERCENT="${SWAP_WARN_PERCENT:-80}"
# shellcheck disable=SC2034
SWAP_FAIL_PERCENT="${SWAP_FAIL_PERCENT:-95}"
# shellcheck disable=SC2034
DEFAULT_PROFILE="${DEFAULT_PROFILE:-hyprland}"
# shellcheck disable=SC2034
CMD_TIMEOUT="${CMD_TIMEOUT:-5}"

# ── Command & Package Probing ──────────────────────────────────────────────────

command_exists() {
    local cmd="$1"
    command -v "${cmd}" &>/dev/null
}

package_installed() {
    local pkg="$1"
    if command_exists pacman; then
        pacman -Q "${pkg}" &>/dev/null
    else
        return 1
    fi
}

aur_package_installed() {
    local pkg="$1"
    if command_exists yay; then
        yay -Q "${pkg}" &>/dev/null
    elif command_exists pacman; then
        pacman -Qm "${pkg}" &>/dev/null
    else
        return 1
    fi
}

# ── Service Probing ────────────────────────────────────────────────────────────

service_exists() {
    local svc="$1"
    if ! command_exists systemctl; then
        return 1
    fi
    systemctl cat "${svc}" &>/dev/null || \
    systemctl cat "${svc}.service" &>/dev/null || \
    systemctl cat "${svc}.timer" &>/dev/null || \
    systemctl cat "${svc}.socket" &>/dev/null
}

service_enabled() {
    local svc="$1"
    if ! command_exists systemctl; then
        return 1
    fi
    local state
    state="$(systemctl is-enabled "${svc}" 2>/dev/null || true)"
    [[ "${state}" =~ ^(enabled|enabled-runtime|alias|indirect|static)$ ]]
}

service_active() {
    local svc="$1"
    if ! command_exists systemctl; then
        return 1
    fi
    systemctl is-active --quiet "${svc}" 2>/dev/null
}

user_service_exists() {
    local svc="$1"
    if ! command_exists systemctl; then
        return 1
    fi
    systemctl --user cat "${svc}" &>/dev/null || \
    systemctl --user cat "${svc}.service" &>/dev/null || \
    systemctl --user cat "${svc}.timer" &>/dev/null || \
    systemctl --user cat "${svc}.socket" &>/dev/null
}

user_service_enabled() {
    local svc="$1"
    if ! command_exists systemctl; then
        return 1
    fi
    local state
    state="$(systemctl --user is-enabled "${svc}" 2>/dev/null || true)"
    [[ "${state}" =~ ^(enabled|enabled-runtime|alias|indirect|static)$ ]]
}

user_service_active() {
    local svc="$1"
    if ! command_exists systemctl; then
        return 1
    fi
    systemctl --user is-active --quiet "${svc}" 2>/dev/null
}

# ── File & Mount Probing ───────────────────────────────────────────────────────

file_exists() {
    local path="$1"
    [[ -f "${path}" ]]
}

dir_exists() {
    local path="$1"
    [[ -d "${path}" ]]
}

symlink_exists() {
    local path="$1"
    [[ -L "${path}" ]]
}

mount_exists() {
    local mountpoint="$1"
    if command_exists findmnt; then
        findmnt --mountpoint "${mountpoint}" &>/dev/null
    else
        mount | grep -q " on ${mountpoint} "
    fi
}

# ── System Introspection ───────────────────────────────────────────────────────

is_arch_linux() {
    [[ -f /etc/arch-release ]]
}

is_uefi() {
    [[ -d /sys/firmware/efi ]]
}

is_root() {
    [[ ${EUID:-$(id -u)} -eq 0 ]]
}

has_sudo() {
    if is_root; then
        return 0
    fi
    if command_exists sudo; then
        sudo -n true 2>/dev/null || sudo -v -n 2>/dev/null
    else
        return 1
    fi
}

get_chassis_type() {
    if command_exists hostnamectl; then
        local chassis
        chassis="$(hostnamectl status 2>/dev/null | grep -i "Chassis:" | awk '{print $2}')"
        if [[ -n "${chassis}" ]]; then
            echo "${chassis}"
            return 0
        fi
    fi
    if [[ -d /sys/class/dmi/id ]]; then
        local type_num
        type_num="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "")"
        case "${type_num}" in
            8|9|10|11|12|14|30|31|32) echo "laptop" ;;
            3|4|5|6|7|15|16|24) echo "desktop" ;;
            17|23) echo "server" ;;
            *) echo "unknown" ;;
        esac
        return 0
    fi
    if [[ -d /sys/class/power_supply ]]; then
        if ls /sys/class/power_supply/BAT* &>/dev/null; then
            echo "laptop"
            return 0
        fi
    fi
    echo "desktop"
}

is_laptop() {
    local chassis
    chassis="$(get_chassis_type)"
    [[ "${chassis}" =~ (laptop|notebook|convertible|tablet|handheld) ]]
}

is_virtual_machine() {
    if command_exists systemd-detect-virt; then
        systemd-detect-virt --quiet 2>/dev/null
    else
        grep -qiE "(hypervisor|vmware|qemu|kvm|virtualbox|xen|bhyve)" /proc/cpuinfo 2>/dev/null
    fi
}

# ── YAML Parsing Wrappers ──────────────────────────────────────────────────────

yaml_list_get() {
    local file="$1" key="$2"
    if [[ ! -f "${file}" ]]; then
        return 0
    fi
    if command_exists yq; then
        yq -r ".${key}[]? // empty" "${file}" 2>/dev/null
    else
        _yaml_list_fallback "${file}" "${key}"
    fi
}

yaml_value_get() {
    local file="$1" key="$2"
    if [[ ! -f "${file}" ]]; then
        return 0
    fi
    if command_exists yq; then
        yq -r ".${key} // empty" "${file}" 2>/dev/null
    else
        _yaml_value_fallback "${file}" "${key}"
    fi
}

_yaml_list_fallback() {
    local file="$1" key="$2"
    local in_block=false
    local target_depth="${key//[^:]}"
    target_depth="${#target_depth}"
    # shellcheck disable=SC2206
    local key_segments=(${key//./ })
    local match_key="${key_segments[-1]}"

    while IFS= read -r line; do
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local line_depth=0
        if [[ "${line}" =~ ^([[:space:]]*) ]]; then
            line_depth=$((${#BASH_REMATCH[1]} / 2))
        fi

        [[ -z "${stripped}" || "${stripped}" =~ ^# ]] && continue

        if [[ "${stripped}" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
            local current_key="${BASH_REMATCH[1]}"
            local current_val="${BASH_REMATCH[2]}"

            if [[ "${line_depth}" -eq $((target_depth)) && "${current_key}" == "${match_key}" ]]; then
                in_block=true
                continue
            fi

            if ${in_block} && [[ "${line_depth}" -le $((target_depth)) && -n "${current_val}" ]]; then
                break
            fi
        fi

        if ${in_block}; then
            if [[ "${stripped}" =~ ^-[[:space:]]+(.*) ]]; then
                echo "${BASH_REMATCH[1]}"
            elif [[ "${stripped}" =~ ^-[[:space:]]*$ ]]; then
                continue
            else
                if [[ "${line_depth}" -le $((target_depth)) ]]; then
                   in_block=false
                fi
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

# ── JSON String Escaping ───────────────────────────────────────────────────────

json_escape() {
    local str="$1"
    # Use python or jq if available, otherwise pure bash/sed
    if command_exists jq; then
        printf '%s' "${str}" | jq -s -R -r '@json' | sed 's/^"//;s/"$//'
    elif command_exists python3; then
        python3 -c 'import json, sys; print(json.dumps(sys.argv[1])[1:-1])' "${str}"
    else
        # Fallback sed escaping for quotes, backslashes, tabs, newlines
        printf '%s' "${str}" | sed \
            -e 's/\\/\\\\/g' \
            -e 's/"/\\"/g' \
            -e 's/\t/\\t/g' \
            -e ':a;N;$!ba;s/\n/\\n/g'
    fi
}
