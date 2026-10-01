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

# Array of check records. Format (US-delimited, see CHECK_FIELD_SEP):
#   CATEGORY <US> NAME <US> STATUS <US> MESSAGE <US> DETAILS <US> FIX_CMD <US> EXPECTED <US> CURRENT
# shellcheck disable=SC2034
CHECKS_RESULTS=()

# Field delimiter for CHECKS_RESULTS records: ASCII Unit Separator (0x1F).
# Chosen because it is a control character that cannot appear in YAML-derived
# values, unlike '|' which is both legal data and a shell pipeline operator.
# Read records with: IFS="${CHECK_FIELD_SEP}" read -r a b c d e f g h <<< "$rec"
CHECK_FIELD_SEP=$'\x1f'

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

# ── Fix-command safety ────────────────────────────────────────────────────────
# Fix commands are stored as strings and executed with `eval` under `sudo`. The
# strings are built by interpolating values that ultimately come from YAML
# config and from system state, so a config-supplied value containing shell
# metacharacters becomes arbitrary code execution as root:
#
#   groups: [ 'wheel`id >/tmp/pwned`' ]
#   → fix string "usermod -aG wheel`id >/tmp/pwned`"  → eval runs `id >/tmp/pwned`
#
# `fix_cmd_is_safe` rejects the constructs that enable this. It is an
# allowlist, not a blocklist: anything not positively recognised is refused.

# Commands permitted to start a segment of a remediation command.
FIX_CMD_ALLOWED_CMDS="sudo pacman yay paru pikaur systemctl journalctl ufw
    timedatectl hostnamectl locale-gen locale-conf localectl tee chmod chown
    rm cp mv mkdir ln install sed awk grep cat find head tail wc sort uniq
    usermod gpasswd groupadd useradd chpasswd passwd visudo mkinitcpio
    paccache efibootmgr grub-mkconfig dracupgrub blkid lsblk findmnt ip
    rfkill bluetoothctl modprobe sysctl hwclock nmcli resolvectl fstrim
    systemctl-sysusers bootctl update-grub echo printf xargs
    ./install.sh"

# /**
#  * fix_cmd_is_safe()
#  * Returns 0 if a remediation command is safe to `eval`, non-zero otherwise.
#  *
#  * Rejects: backticks, `;`, `<`/`>` redirection, newlines, and ALL `$`
#  * expansion — including `$(...)`. A config value that reaches the fix string
#  * therefore cannot introduce a substitution of any kind. Quote balance is
#  * enforced so a stray quote cannot swallow the remainder of the command.
#  */
fix_cmd_is_safe() {
    local cmd="$1"

    # Empty is not a runnable command.
    [[ -z "${cmd//[[:space:]]/}" ]] && return 1

    # Hard denials — these are the injection primitives.
    # Built with ANSI-C quoting: a literal backtick inside [[ =~ ]] would
    # otherwise be parsed as the start of a command substitution.
    local danger=$'[\x60;<>$]'
    [[ "${cmd}" =~ ${danger} ]] && return 1
    [[ "${cmd}" == *$'\n'* || "${cmd}" == *$'\r'* ]] && return 1
    # `&` is only ever valid as the `&&` operator here.
    [[ "${cmd}" == *'&'* && "${cmd}" != *'&&'* ]] && return 1

    # Quotes must be balanced, else a trailing quote can swallow the rest.
    local single="${cmd//[^\']/}" double="${cmd//[^\"]/}"
    (( ${#single} % 2 == 0 )) || return 1
    (( ${#double} % 2 == 0 )) || return 1

    # Every command segment must start with an allowlisted command.
    local segment
    while IFS= read -r segment; do
        segment="${segment#"${segment%%[![:space:]]*}"}"
        [[ -z "${segment}" ]] && continue
        local first="${segment%%[[:space:]]*}"
        _fix_cmd_allowed "${first}" || return 1
    done < <(sed -e 's/&&/\n/g' -e 's/||/\n/g' -e 's/|/\n/g' <<< "${cmd}")

    return 0
}

# /**
#  * _fix_cmd_allowed()
#  * Returns 0 if a word is in the remediation command allowlist.
#  */
_fix_cmd_allowed() {
    local word="$1" allowed
    for allowed in ${FIX_CMD_ALLOWED_CMDS}; do
        [[ "${word}" == "${allowed}" ]] && return 0
    done
    return 1
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

    # Store in check results array.
    #
    # Records are US-delimited ($'\x1f', ASCII unit separator), NOT '|'.
    # A pipe is a legal character in every one of these fields — most of all in
    # fix_cmd, where "a | tee file" is a normal shell pipeline. The old code
    # rewrote those pipes to '&&', so the fix printed to stdout instead of
    # writing the file, and then reported success.
    #
    # US cannot appear in YAML-derived values, so no rewriting is needed and
    # fix_cmd is stored verbatim. Any stray US is still stripped defensively,
    # from EVERY field — the old code sanitised only 5 of 8, so a '|' in
    # category or name silently shifted every later field (which could move a
    # message into the fix slot, i.e. straight into `eval`).
    local clean_cat="${category//$'\x1f'/}"
    local clean_name="${name//$'\x1f'/}"
    local clean_status="${status//$'\x1f'/}"
    local clean_msg="${message//$'\x1f'/}"
    local clean_details="${details//$'\x1f'/}"
    local clean_fix="${fix_cmd//$'\x1f'/}"
    local clean_exp="${expected//$'\x1f'/}"
    local clean_cur="${current//$'\x1f'/}"

    CHECKS_RESULTS+=("${clean_cat}${CHECK_FIELD_SEP}${clean_name}${CHECK_FIELD_SEP}${clean_status}${CHECK_FIELD_SEP}${clean_msg}${CHECK_FIELD_SEP}${clean_details}${CHECK_FIELD_SEP}${clean_fix}${CHECK_FIELD_SEP}${clean_exp}${CHECK_FIELD_SEP}${clean_cur}")

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
        local ver=""
        # The fallback must be keyed on the PIPELINE, not appended to it with
        # `||`: `cmd | awk || other` binds `||` to the whole pipeline, and awk
        # exits 0 even on empty input, so `pacman -Qm` never ran. AUR packages
        # therefore reported "Installed ()" whenever yay was absent.
        ver="$(yay -Q "${pkg}" 2>/dev/null | awk '{print $2}')"
        if [[ -z "${ver}" ]]; then
            ver="$(pacman -Qm "${pkg}" 2>/dev/null | awk '{print $2}')"
        fi
        pass "${category}" "${name}" "Installed (${ver:-unknown version})"
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
        IFS="${CHECK_FIELD_SEP}" read -r cat name status msg details fix exp cur <<< "${record}"

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
