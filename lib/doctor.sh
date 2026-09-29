#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Library: doctor.sh
# Description: Diagnostic intelligence engine. Translates failures and warnings
#              into actionable root-cause analysis and automated/interactive remediation.
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
# doctor consumes CHECKS_RESULTS and its field delimiter. This dependency was
# previously implicit: it only worked because bin/arch-postinstall happens to
# source checks.sh first, so sourcing this file alone left CHECK_FIELD_SEP unset.
if ! declare -f register_check &>/dev/null; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/checks.sh"
fi

run_doctor_analysis() {
    local issues_found=0

    # Count issues
    for record in "${CHECKS_RESULTS[@]}"; do
        IFS="${CHECK_FIELD_SEP}" read -r cat name status msg details fix exp cur <<< "${record}"
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

    local num=0

    for record in "${CHECKS_RESULTS[@]}"; do
        IFS="${CHECK_FIELD_SEP}" read -r cat name status msg details fix exp cur <<< "${record}"
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
    echo -e "${C_YELLOW}${C_BOLD}Note:${C_RESET} Doctor runs in read-only mode by default."
    echo -e "Execute remediation automatically with: ${C_BOLD}./bin/arch-postinstall doctor --fix${C_RESET}"
    echo ""
}

run_doctor_fix() {
    local -a fixable_records=()

    for record in "${CHECKS_RESULTS[@]}"; do
        IFS="${CHECK_FIELD_SEP}" read -r cat name status msg details fix exp cur <<< "${record}"
        if [[ ("${status}" == "FAIL" || "${status}" == "WARN") && -n "${fix}" ]]; then
            fixable_records+=("${record}")
        fi
    done

    print_banner "Arch Post-Installation Doctor" "Interactive Remediation Engine (--fix)"

    if [[ ${#fixable_records[@]} -eq 0 ]]; then
        echo -e "${C_GREEN}${C_BOLD}✔ No automated remediations required!${C_RESET}"
        echo ""
        return 0
    fi

    echo -e "${C_BOLD}Found ${C_CYAN}${#fixable_records[@]}${C_RESET}${C_BOLD} remediation(s) to execute:${C_RESET}\n"

    local applied=0
    local skipped=0
    local failed=0

    for record in "${fixable_records[@]}"; do
        IFS="${CHECK_FIELD_SEP}" read -r cat name status msg details fix exp cur <<< "${record}"

        echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"
        echo -e "  ${C_BOLD}Issue:${C_RESET}       ${msg}"
        echo -e "  ${C_BOLD}Category:${C_RESET}    ${cat}"
        echo -e "  ${C_BOLD}Command:${C_RESET}     ${C_GREEN}${C_BOLD}${fix}${C_RESET}"
        echo ""

        local execute=false
        if [[ "${AUTO_YES:-false}" == true ]]; then
            execute=true
        else
            read -rp "  Execute this fix? [y/N/q]: " yn
            case "${yn}" in
                [Yy]*) execute=true ;;
                [Qq]*)
                    echo -e "\n${C_YELLOW}Aborted remediation process.${C_RESET}\n"
                    break
                    ;;
                *)
                    echo -e "  ${C_GRAY}Skipped.${C_RESET}"
                    skipped=$((skipped + 1))
                    ;;
            esac
        fi

        if ${execute}; then
            # The fix string is executed with `eval` under `sudo`. It is built
            # by interpolating config-derived and system-derived values, so it
            # MUST be validated before execution: a group name such as
            #   'wheel`id >/tmp/pwned`'
            # becomes arbitrary root code execution without this check.
            if ! fix_cmd_is_safe "${fix}"; then
                echo -e "  ${C_RED}✖ Refused: command failed the safety check.${C_RESET}"
                echo -e "    ${C_GRAY}${fix}${C_RESET}"
                echo -e "    ${C_GRAY}Only plain allowlisted commands may be remediated.${C_RESET}"
                failed=$((failed + 1))
                echo ""
                continue
            fi
            echo -e "  ${C_BLUE}Running:${C_RESET} ${fix}"
            local fix_rc=0
            eval "${fix}" || fix_rc=$?
            if [[ ${fix_rc} -eq 0 ]]; then
                echo -e "  ${C_GREEN}✔ Fix applied successfully.${C_RESET}"
                applied=$((applied + 1))
            else
                echo -e "  ${C_RED}✖ Fix failed with exit code ${fix_rc}.${C_RESET}"
                failed=$((failed + 1))
            fi
        fi
        echo ""
    done

    echo -e "${C_GRAY}────────────────────────────────────────────────────────────${C_RESET}"
    echo -e "${C_BOLD}Remediation Summary:${C_RESET}"
    echo -e "  ${C_GREEN}Applied:${C_RESET} ${applied}"
    echo -e "  ${C_YELLOW}Skipped:${C_RESET} ${skipped}"
    echo -e "  ${C_RED}Failed:${C_RESET}  ${failed}"
    echo ""

    # Propagate the result. Previously this function ended on a bare `echo`,
    # so it always returned 0 — `doctor --fix` and `make fix` reported success
    # even when every remediation failed, breaking the documented exit-code
    # contract used for automation.
    if [[ ${failed} -gt 0 ]]; then
        return 1
    fi
    return 0
}
