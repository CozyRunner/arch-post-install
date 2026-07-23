#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: services.sh
# Description: Manages Systemd units (services and timers).
#              Automatically detects unit types and enables/starts them.
# ──────────────────────────────────────────────────────────────────────────────

# /**
#  * enable_services_from_config()
#  * Reads a YAML config and enables/starts systemd units.
#  * @param {string} config - Path to the YAML config file.
#  */
enable_services_from_config() {
    local config="$1"

    if [[ ! -f "${config}" ]]; then
        log_error "Config file not found: ${config}"
        return 1
    fi

    local -a services=()
    while IFS= read -r svc; do
        [[ -n "${svc}" ]] && services+=("${svc}")
    done < <(yaml_list "${config}" "services")

    if [[ ${#services[@]} -eq 0 ]]; then
        log_warn "No services found in ${config}"
        return 0
    fi

    log_step "Enabling ${#services[@]} services"

    for svc in "${services[@]}"; do
    # Probe unit existence: systemctl cat exits non-zero if unit is not found,
    # unlike list-unit-files which exits 0 even for missing units.
    if systemctl cat "${svc}" &>/dev/null; then
            sudo systemctl enable --now "${svc}" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Enabled: ${svc}"
        elif systemctl cat "${svc}.service" &>/dev/null; then
            sudo systemctl enable --now "${svc}.service" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Enabled: ${svc}"
        elif systemctl cat "${svc}.timer" &>/dev/null; then
            sudo systemctl enable --now "${svc}.timer" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Enabled timer: ${svc}"
        elif systemctl --user cat "${svc}" &>/dev/null; then
            systemctl --user enable --now "${svc}" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Enabled (user): ${svc}"
        elif systemctl --user cat "${svc}.service" &>/dev/null; then
            systemctl --user enable --now "${svc}.service" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Enabled (user): ${svc}"
        else
            log_warn "Unit not found: ${svc} (skipped)"
        fi
    done
}

# /**
#  * enable_base_services()
#  * Convenience function to enable core system services.
#  */
enable_base_services() {
    log_step "Enabling base services"
    enable_services_from_config "${CONFIG_DIR}/base.yaml"
}
