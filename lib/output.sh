#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Library: output.sh
# Description: Terminal formatting, color support detection, standardized
#              symbols, category headers, and human-readable scorecards.
# ──────────────────────────────────────────────────────────────────────────────

# Global display options
USE_COLOR=true
QUIET_MODE=false
VERBOSE_MODE=false

init_output() {
    # Respect NO_COLOR standard (https://no-color.org/)
    if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
        USE_COLOR=false
    fi

    # Disable color if stdout is not a TTY
    if [[ ! -t 1 ]]; then
        USE_COLOR=false
    fi

    if [[ "${USE_COLOR}" == true ]]; then
        # shellcheck disable=SC2034
        C_RESET='\033[0m'
        # shellcheck disable=SC2034
        C_BOLD='\033[1m'
        # shellcheck disable=SC2034
        C_DIM='\033[2m'
        # shellcheck disable=SC2034
        C_RED='\033[0;31m'
        # shellcheck disable=SC2034
        C_GREEN='\033[0;32m'
        # shellcheck disable=SC2034
        C_YELLOW='\033[1;33m'
        # shellcheck disable=SC2034
        C_BLUE='\033[0;34m'
        # shellcheck disable=SC2034
        C_MAGENTA='\033[0;35m'
        # shellcheck disable=SC2034
        C_CYAN='\033[0;36m'
        # shellcheck disable=SC2034
        C_GRAY='\033[0;90m'

        # Symbols
        SYM_PASS="${C_GREEN}✓${C_RESET}"
        SYM_WARN="${C_YELLOW}⚠${C_RESET}"
        SYM_FAIL="${C_RED}✗${C_RESET}"
        SYM_SKIP="${C_GRAY}○${C_RESET}"
        SYM_INFO="${C_CYAN}ℹ${C_RESET}"
    else
        # shellcheck disable=SC2034
        C_RESET=''
        # shellcheck disable=SC2034
        C_BOLD=''
        # shellcheck disable=SC2034
        C_DIM=''
        # shellcheck disable=SC2034
        C_RED=''
        # shellcheck disable=SC2034
        C_GREEN=''
        # shellcheck disable=SC2034
        C_YELLOW=''
        # shellcheck disable=SC2034
        C_BLUE=''
        # shellcheck disable=SC2034
        C_MAGENTA=''
        # shellcheck disable=SC2034
        C_CYAN=''
        # shellcheck disable=SC2034
        C_GRAY=''

        SYM_PASS="[PASS]"
        SYM_WARN="[WARN]"
        SYM_FAIL="[FAIL]"
        SYM_SKIP="[SKIP]"
        SYM_INFO="[INFO]"
    fi
}

# Initialize colors on load
init_output

print_banner() {
    local title="$1"
    local subtitle="${2:-}"

    if [[ "${QUIET_MODE}" == true || "${JSON_OUTPUT:-false}" == true ]]; then
        return 0
    fi

    echo ""
    echo -e "${C_CYAN}${C_BOLD}  ╔══════════════════════════════════════════════════════════╗${C_RESET}"
    printf "${C_CYAN}${C_BOLD}  ║ %-56s ║${C_RESET}\n" "${title}"
    if [[ -n "${subtitle}" ]]; then
        printf "${C_GRAY}  ║ %-56s ║${C_RESET}\n" "${subtitle}"
    fi
    echo -e "${C_CYAN}${C_BOLD}  ╚══════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
}

print_category_header() {
    local category_title="$1"
    if [[ "${QUIET_MODE}" == true || "${JSON_OUTPUT:-false}" == true ]]; then
        return 0
    fi
    echo -e "\n${C_BOLD}${C_CYAN}▸ ${category_title}${C_RESET}"
}

print_check_result() {
    local status="$1"
    local name="$2"
    local message="$3"
    local details="${4:-}"

    if [[ "${QUIET_MODE}" == true && "${status}" != "FAIL" && "${status}" != "WARN" ]]; then
        return 0
    fi

    local sym
    case "${status}" in
        PASS) sym="${SYM_PASS}" ;;
        WARN) sym="${SYM_WARN}" ;;
        FAIL) sym="${SYM_FAIL}" ;;
        SKIP) sym="${SYM_SKIP}" ;;
        INFO) sym="${SYM_INFO}" ;;
        *)    sym="[${status}]" ;;
    esac

    printf "  %b  %-30s %s\n" "${sym}" "${name}" "${message}"

    if [[ -n "${details}" && ( "${VERBOSE_MODE}" == true || "${status}" == "FAIL" || "${status}" == "WARN" ) ]]; then
        while IFS= read -r line; do
            [[ -n "${line}" ]] && printf "      ${C_GRAY}%s${C_RESET}\n" "${line}"
        done <<< "${details}"
    fi
}

print_summary() {
    local pass_cnt="$1"
    local warn_cnt="$2"
    local fail_cnt="$3"
    local skip_cnt="$4"
    local info_cnt="${5:-0}"

    if [[ "${QUIET_MODE}" == true && "${fail_cnt}" -eq 0 && "${warn_cnt}" -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"
    printf "  ${C_BOLD}Results Summary:${C_RESET}\n"
    printf "    ${C_GREEN}PASS:${C_RESET} %-4d" "${pass_cnt}"
    printf "    ${C_YELLOW}WARN:${C_RESET} %-4d" "${warn_cnt}"
    printf "    ${C_RED}FAIL:${C_RESET} %-4d" "${fail_cnt}"
    printf "    ${C_GRAY}SKIP:${C_RESET} %-4d" "${skip_cnt}"
    if [[ "${info_cnt}" -gt 0 ]]; then
        printf "    ${C_CYAN}INFO:${C_RESET} %-4d" "${info_cnt}"
    fi
    echo ""

    local overall_status="PASS"
    local status_color="${C_GREEN}"

    if [[ "${fail_cnt}" -gt 0 ]]; then
        overall_status="FAIL"
        status_color="${C_RED}"
    elif [[ "${warn_cnt}" -gt 0 ]]; then
        overall_status="PASS WITH WARNINGS"
        status_color="${C_YELLOW}"
    fi

    echo -e "  ${C_BOLD}Overall Status:${C_RESET} ${status_color}${C_BOLD}${overall_status}${C_RESET}"
    echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"
    echo ""
}
