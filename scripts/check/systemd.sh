#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: systemd.sh
# Description: Validates systemd daemon status, enabled and active services
#              declared in configs, and failed units.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_systemd() {
    print_category_header "Systemd Services Configuration"

    if ! command_exists systemctl; then
        fail "systemd" "systemctl_available" "systemctl binary not found"
        return 1
    fi

    # 1. Base services from config/base.yaml
    local -a base_services=()
    while IFS= read -r svc; do
        [[ -n "${svc}" && ! "${svc}" =~ ^# ]] && base_services+=("${svc}")
    done < <(yaml_list_get "${CONFIG_DIR}/base.yaml" "services")

    for svc in "${base_services[@]}"; do
        if ! service_exists "${svc}"; then
            warn "systemd" "svc_${svc}" "Unit '${svc}' not installed" \
                 "Service declared in config/base.yaml is not present" \
                 "Check packages providing ${svc}"
            continue
        fi

        if service_enabled "${svc}"; then
            pass "systemd" "svc_${svc}_enabled" "Base service '${svc}' is enabled"
        else
            fail "systemd" "svc_${svc}_enabled" "Base service '${svc}' is disabled" \
                 "Service is declared in config/base.yaml but not enabled in systemd" \
                 "sudo systemctl enable --now ${svc}" \
                 "enabled" "disabled"
        fi
    done

    # 2. Profile services
    local profile_yaml="${CONFIG_DIR}/${PROFILE:-${DEFAULT_PROFILE}}.yaml"
    if [[ -f "${profile_yaml}" ]]; then
        local -a profile_services=()
        while IFS= read -r svc; do
            [[ -n "${svc}" && ! "${svc}" =~ ^# ]] && profile_services+=("${svc}")
        done < <(yaml_list_get "${profile_yaml}" "services")

        for svc in "${profile_services[@]}"; do
            # Skip if already tested in base
            local already_tested=false
            for b in "${base_services[@]}"; do
                [[ "${b}" == "${svc}" ]] && already_tested=true && break
            done
            ${already_tested} && continue

            # Check if this is a user service (e.g. pipewire, wireplumber)
            if user_service_exists "${svc}" && ! service_exists "${svc}"; then
                if user_service_enabled "${svc}" || user_service_active "${svc}"; then
                    pass "systemd" "user_svc_${svc}" "User service '${svc}' is enabled/active"
                else
                    warn "systemd" "user_svc_${svc}" "User service '${svc}' is not enabled" \
                         "systemctl --user enable --now ${svc}" \
                         "systemctl --user enable --now ${svc}" \
                         "enabled" "disabled"
                fi
            elif service_exists "${svc}"; then
                if service_enabled "${svc}"; then
                    pass "systemd" "svc_${svc}_enabled" "Profile service '${svc}' is enabled"
                else
                    warn "systemd" "svc_${svc}_enabled" "Profile service '${svc}' is not enabled" \
                         "sudo systemctl enable --now ${svc}" \
                         "sudo systemctl enable --now ${svc}" \
                         "enabled" "disabled"
                fi
            else
                skip "systemd" "svc_${svc}" "Service '${svc}' not found on system"
            fi
        done
    fi
}

health_systemd() {
    print_category_header "Systemd Runtime Health"

    if ! command_exists systemctl; then
        return 0
    fi

    # 1. System state
    local sys_state
    sys_state="$(systemctl is-system-running 2>/dev/null || true)"
    case "${sys_state}" in
        running)
            pass "systemd" "system_state" "Systemd state is 'running'"
            ;;
        degraded)
            warn "systemd" "system_state" "Systemd state is 'degraded' (one or more units failed)" \
                 "Inspect failed units with: systemctl --failed" \
                 "systemctl reset-failed" \
                 "running" "degraded"
            ;;
        initializing|starting|stopping)
            info "systemd" "system_state" "Systemd state is '${sys_state}'"
            ;;
        *)
            if is_virtual_machine; then
                info "systemd" "system_state" "Systemd state: ${sys_state:-unknown} (container/VM)"
            else
                warn "systemd" "system_state" "Systemd state: ${sys_state:-unknown}"
            fi
            ;;
    esac

    # 2. Failed System Units
    local -a failed_units=()
    while IFS= read -r unit; do
        [[ -n "${unit}" ]] && failed_units+=("${unit}")
    done < <(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' || true)

    if [[ ${#failed_units[@]} -eq 0 ]]; then
        pass "systemd" "failed_units" "No failed systemd system units"
    else
        fail "systemd" "failed_units" "${#failed_units[@]} failed system unit(s): ${failed_units[*]}" \
             "Inspect logs with: journalctl -u <unit_name> -e" \
             "sudo systemctl restart ${failed_units[0]}" \
             "0 failed units" "${#failed_units[@]} failed (${failed_units[*]})"
    fi

    # 3. Failed User Units (if available)
    if systemctl --user list-units &>/dev/null; then
        local -a failed_user_units=()
        while IFS= read -r unit; do
            [[ -n "${unit}" ]] && failed_user_units+=("${unit}")
        done < <(systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}' || true)

        if [[ ${#failed_user_units[@]} -eq 0 ]]; then
            pass "systemd" "failed_user_units" "No failed user units"
        else
            warn "systemd" "failed_user_units" "${#failed_user_units[@]} failed user unit(s): ${failed_user_units[*]}" \
                 "Inspect with: systemctl --user status ${failed_user_units[0]}"
        fi
    fi
}
