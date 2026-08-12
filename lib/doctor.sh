#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Library: doctor.sh
# Description: Diagnostic intelligence engine. Translates failures and warnings
#              into actionable root-cause analysis and copy-paste fixes.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC2034
# Source dependencies if not already loaded
if [[ -z "${LIB_DIR:-}" ]]; then
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi
if ! declare -f print_category_header &>/dev/null; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/output.sh"
fi

run_doctor_analysis() {
    local issues_found=0

    # Count issues
    for record in "${CHECKS_RESULTS[@]}"; do
        IFS='|' read -r cat name status msg details fix exp cur <<< "${record}"
        if [[ "${status}" == "FAIL" || "${status}" == "WARN" ]]; then
            issues_found=$((issues_found + 1))
        fi
    done

    if [[ "${JSON_OUTPUT:-false}" == true ]]; then
        render_json
        return 0
    fi

    print_banner "Arch Post-Installation Doctor" "Automated Diagnosis & Suggested Remediation"

    if [[ ${issues_found} -eq 0 ]]; then
        echo -e "${C_GREEN}${C_BOLD}✔ System is completely healthy!${C_RESET}"
        echo -e "  No configuration mismatches or runtime failures detected."
        echo ""
        return 0
    fi

    echo -e "${C_BOLD}Found ${C_RED}${issues_found}${C_RESET}${C_BOLD} issue(s) requiring attention:${C_RESET}\n"

    local current_cat=""
    local num=0

    for record in "${CHECKS_RESULTS[@]}"; do
        IFS='|' read -r cat name status msg details fix exp cur <<< "${record}"
        if [[ "${status}" != "FAIL" && "${status}" != "WARN" ]]; then
            continue
        fi

        num=$((num + 1))

        local status_badge
        if [[ "${status}" == "FAIL" ]]; then
            status_badge="${C_RED}${C_BOLD}[FAIL]${C_RESET}"
        else
            status_badge="${C_YELLOW}${C_BOLD}[WARN]${C_RESET}"
        fi

        echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"
        printf "%-2d. %b ${C_BOLD}%s${C_RESET} (${C_CYAN}%s${C_RESET})\n" "${num}" "${status_badge}" "${msg}" "${cat}"
        echo ""

        if [[ -n "${exp}" || -n "${cur}" ]]; then
            echo -e "    ${C_BOLD}State Comparison:${C_RESET}"
            [[ -n "${exp}" ]] && echo -e "      ${C_BLUE}Expected:${C_RESET} ${exp}"
            [[ -n "${cur}" ]] && echo -e "      ${C_RED}Current:${C_RESET}  ${cur}"
            echo ""
        fi

        if [[ -n "${details}" ]]; then
            echo -e "    ${C_BOLD}Diagnostics:${C_RESET}"
            echo -e "      ${details}"
            echo ""
        fi

        if [[ -n "${fix}" ]]; then
            echo -e "    ${C_BOLD}Suggested Remediation:${C_RESET}"
            echo -e "      ${C_GREEN}${C_BOLD}${fix}${C_RESET}"
            echo ""
        fi
    done

    echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"
    echo ""
    echo -e "${C_YELLOW}${C_BOLD}Note:${C_RESET} Doctor runs in read-only mode and does not modify the system."
    echo -e "Review and execute the suggested remediation commands above as needed."
    echo ""
}
