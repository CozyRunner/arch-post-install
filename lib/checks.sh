#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Library: checks.sh
# Description: Check registry, assertion helpers, result accumulator, and
#              JSON serialization engine.
# ──────────────────────────────────────────────────────────────────────────────

# Source dependencies if not already loaded
if [[ -z "${LIB_DIR:-}" ]]; then
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi
if ! declare -f print_check_result &>/dev/null; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/output.sh"
fi

# ── Check Accumulator State ───────────────────────────────────────────────────

# shellcheck disable=SC2034
COUNT_PASS=0
# shellcheck disable=SC2034
COUNT_WARN=0
# shellcheck disable=SC2034
COUNT_FAIL=0
# shellcheck disable=SC2034
COUNT_SKIP=0
# shellcheck disable=SC2034
COUNT_INFO=0

# Array of check records formatted as TSV or internal delimited string
# Format: CATEGORY|NAME|STATUS|MESSAGE|DETAILS|FIX_CMD|EXPECTED|CURRENT
# shellcheck disable=SC2034
CHECKS_RESULTS=()

reset_checks() {
    # shellcheck disable=SC2034
    COUNT_PASS=0
    # shellcheck disable=SC2034
    COUNT_WARN=0
    # shellcheck disable=SC2034
    COUNT_FAIL=0
    # shellcheck disable=SC2034
    COUNT_SKIP=0
    # shellcheck disable=SC2034
    COUNT_INFO=0
    # shellcheck disable=SC2034
    CHECKS_RESULTS=()
}

# ── Check Registration ────────────────────────────────────────────────────────

register_check() {
    local category="$1"
    local name="$2"
    local status="$3"
    local message="$4"
    local details="${5:-}"
    local fix_cmd="${6:-}"
    local expected="${7:-}"
    local current="${8:-}"

    case "${status}" in
        PASS) COUNT_PASS=$((COUNT_PASS + 1)) ;;
        WARN) COUNT_WARN=$((COUNT_WARN + 1)) ;;
        FAIL) COUNT_FAIL=$((COUNT_FAIL + 1)) ;;
        SKIP) COUNT_SKIP=$((COUNT_SKIP + 1)) ;;
        INFO) COUNT_INFO=$((COUNT_INFO + 1)) ;;
    esac

    # Store in check results array
    # We replace pipe characters in fields to prevent splitting errors
    local clean_msg="${message//|/ - }"
    local clean_details="${details//|/ - }"
    local clean_fix="${fix_cmd//|/ && }"
    local clean_exp="${expected//|/ - }"
    local clean_cur="${current//|/ - }"

    CHECKS_RESULTS+=("${category}|${name}|${status}|${clean_msg}|${clean_details}|${clean_fix}|${clean_exp}|${clean_cur}")

    # Output to terminal if not in json-only or doctor-silent mode
    if [[ "${JSON_OUTPUT:-false}" != true && "${DOCTOR_MODE:-false}" != true ]]; then
        print_check_result "${status}" "${name}" "${message}" "${details}"
    fi
}

pass() {
    local category="$1"
    local name="$2"
    local message="$3"
    local details="${4:-}"
    register_check "${category}" "${name}" "PASS" "${message}" "${details}" "" "" ""
}

warn() {
    local category="$1"
    local name="$2"
    local message="$3"
    local details="${4:-}"
    local fix_cmd="${5:-}"
    local expected="${6:-}"
    local current="${7:-}"
    register_check "${category}" "${name}" "WARN" "${message}" "${details}" "${fix_cmd}" "${expected}" "${current}"
}

fail() {
    local category="$1"
    local name="$2"
    local message="$3"
    local details="${4:-}"
    local fix_cmd="${5:-}"
    local expected="${6:-}"
    local current="${7:-}"
    register_check "${category}" "${name}" "FAIL" "${message}" "${details}" "${fix_cmd}" "${expected}" "${current}"
}

skip() {
    local category="$1"
    local name="$2"
    local message="$3"
    local details="${4:-}"
    register_check "${category}" "${name}" "SKIP" "${message}" "${details}" "" "" ""
}

info() {
    local category="$1"
    local name="$2"
    local message="$3"
    local details="${4:-}"
    register_check "${category}" "${name}" "INFO" "${message}" "${details}" "" "" ""
}

# ── High-Level Assertions ─────────────────────────────────────────────────────

assert_package_installed() {
    local pkg="$1"
    local category="${2:-packages}"
    local name="pkg:${pkg}"

    if package_installed "${pkg}"; then
        local ver
        ver="$(pacman -Q "${pkg}" 2>/dev/null | awk '{print $2}')"
        pass "${category}" "${name}" "Installed (${ver})"
        return 0
    else
        fail "${category}" "${name}" "Package '${pkg}' is not installed" \
             "Declared in repository package list but missing from pacman DB" \
             "sudo pacman -S --needed ${pkg}" \
             "installed" "missing"
        return 1
    fi
}

assert_aur_package_installed() {
    local pkg="$1"
    local category="${2:-packages}"
    local name="aur:${pkg}"

    if aur_package_installed "${pkg}"; then
        local ver
        ver="$(yay -Q "${pkg}" 2>/dev/null | awk '{print $2}' || pacman -Qm "${pkg}" 2>/dev/null | awk '{print $2}')"
        pass "${category}" "${name}" "Installed (${ver})"
        return 0
    else
        warn "${category}" "${name}" "AUR package '${pkg}' is not installed" \
             "Declared in repository AUR list but not present" \
             "yay -S --needed ${pkg}" \
             "installed" "missing"
        return 1
    fi
}

assert_service_enabled() {
    local svc="$1"
    local category="${2:-systemd}"
    local name="svc_enabled:${svc}"

    if ! service_exists "${svc}"; then
        warn "${category}" "${name}" "Unit '${svc}' not found on system" \
             "Service unit does not exist in systemd paths" \
             "Verify package providing '${svc}' is installed" \
             "exists and enabled" "not found"
        return 1
    fi

    if service_enabled "${svc}"; then
        pass "${category}" "${name}" "Unit is enabled"
        return 0
    else
        fail "${category}" "${name}" "Service '${svc}' is not enabled" \
             "Service is declared in config but disabled in systemd" \
             "sudo systemctl enable --now ${svc}" \
             "enabled" "disabled"
        return 1
    fi
}

assert_service_active() {
    local svc="$1"
    local category="${2:-systemd}"
    local name="svc_active:${svc}"

    if ! service_exists "${svc}"; then
        skip "${category}" "${name}" "Unit '${svc}' not found"
        return 0
    fi

    if service_active "${svc}"; then
        pass "${category}" "${name}" "Service is active (running)"
        return 0
    else
        local state
        state="$(systemctl is-active "${svc}" 2>/dev/null || echo "inactive")"
        warn "${category}" "${name}" "Service '${svc}' is ${state}" \
             "Service is inactive or failed" \
             "sudo systemctl restart ${svc}" \
             "active" "${state}"
        return 1
    fi
}

assert_user_group() {
    local user="$1"
    local grp="$2"
    local category="${3:-security}"
    local name="group:${grp}"

    if ! getent group "${grp}" &>/dev/null; then
        skip "${category}" "${name}" "System group '${grp}' does not exist"
        return 0
    fi

    if id -nG "${user}" 2>/dev/null | grep -qw "${grp}"; then
        pass "${category}" "${name}" "User '${user}' is in '${grp}'"
        return 0
    else
        fail "${category}" "${name}" "User '${user}' is NOT in group '${grp}'" \
             "Config specifies group '${grp}' for user '${user}'" \
             "sudo usermod -aG ${grp} ${user}" \
             "member" "not member"
        return 1
    fi
}

assert_mount() {
    local mountpoint="$1"
    local category="${2:-filesystem}"
    local name="mount:${mountpoint}"

    if mount_exists "${mountpoint}"; then
        local fs_info
        fs_info="$(findmnt -n -o FSTYPE,SOURCE "${mountpoint}" 2>/dev/null || true)"
        pass "${category}" "${name}" "Mounted (${fs_info})"
        return 0
    else
        fail "${category}" "${name}" "Mountpoint '${mountpoint}' is NOT mounted" \
             "Expected filesystem mount not found in /proc/mounts" \
             "sudo mount ${mountpoint}" \
             "mounted" "unmounted"
        return 1
    fi
}

# ── JSON Serialization ─────────────────────────────────────────────────────────

render_json() {
    local overall="pass"
    if [[ "${COUNT_FAIL}" -gt 0 ]]; then
        overall="fail"
    elif [[ "${COUNT_WARN}" -gt 0 ]]; then
        overall="warn"
    fi

    printf '{\n'
    printf '  "status": "%s",\n' "${overall}"
    printf '  "summary": {\n'
    printf '    "pass": %d,\n' "${COUNT_PASS}"
    printf '    "warn": %d,\n' "${COUNT_WARN}"
    printf '    "fail": %d,\n' "${COUNT_FAIL}"
    printf '    "skip": %d,\n' "${COUNT_SKIP}"
    printf '    "info": %d\n' "${COUNT_INFO}"
    printf '  },\n'
    printf '  "checks": [\n'

    local total=${#CHECKS_RESULTS[@]}
    local i=0

    for record in "${CHECKS_RESULTS[@]}"; do
        i=$((i + 1))
        IFS='|' read -r cat name status msg details fix exp cur <<< "${record}"

        local esc_cat esc_name esc_stat esc_msg esc_det esc_fix esc_exp esc_cur
        esc_cat="$(json_escape "${cat}")"
        esc_name="$(json_escape "${name}")"
        esc_stat="$(json_escape "${status}")"
        esc_msg="$(json_escape "${msg}")"
        esc_det="$(json_escape "${details}")"
        esc_fix="$(json_escape "${fix}")"
        esc_exp="$(json_escape "${exp}")"
        esc_cur="$(json_escape "${cur}")"

        printf '    {\n'
        printf '      "category": "%s",\n' "${esc_cat}"
        printf '      "name": "%s",\n' "${esc_name}"
        printf '      "status": "%s",\n' "${esc_stat}"
        printf '      "message": "%s"' "${esc_msg}"

        if [[ -n "${esc_det}" ]]; then
            printf ',\n      "details": "%s"' "${esc_det}"
        fi
        if [[ -n "${esc_fix}" ]]; then
            printf ',\n      "suggested_fix": "%s"' "${esc_fix}"
        fi
        if [[ -n "${esc_exp}" ]]; then
            printf ',\n      "expected": "%s"' "${esc_exp}"
        fi
        if [[ -n "${esc_cur}" ]]; then
            printf ',\n      "current": "%s"' "${esc_cur}"
        fi
        printf '\n    }'

        if [[ ${i} -lt ${total} ]]; then
            printf ',\n'
        else
            printf '\n'
        fi
    done

    printf '  ]\n'
    printf '}\n'
}

# ── Exit Code Calculation ──────────────────────────────────────────────────────

get_exit_code() {
    if [[ "${COUNT_FAIL}" -gt 0 ]]; then
        return 2
    elif [[ "${COUNT_WARN}" -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}
