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

    # Config-driven step: refuse to run on a mis-parsed config rather
    # than silently operating on an empty one.
    require_yaml_parser || return 1
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

    local -a failed=()
    for svc in "${services[@]}"; do
        # Probe unit existence: systemctl cat exits non-zero if unit is not found,
        # unlike list-unit-files which exits 0 even for missing units.
        #
        # A failing `enable` must NOT abort the run. Under `set -e` a failing
        # pipeline in an if-BODY is fatal, which previously left ZRAM, UFW,
        # snapper, fonts, fish, flatpak and every dotfile unconfigured — all
        # reported as one generic trap message. run_logged keeps the real exit
        # status without that hazard, and one bad unit (docker routinely fails)
        # no longer takes the rest of the install with it.
        if systemctl cat "${svc}" &>/dev/null; then
            if run_logged sudo systemctl enable --now "${svc}"; then
                log_success "Enabled: ${svc}"
            else
                log_warn "Failed to enable: ${svc} (continuing)"
                failed+=("${svc}")
            fi
        elif systemctl cat "${svc}.service" &>/dev/null; then
            if run_logged sudo systemctl enable --now "${svc}.service"; then
                log_success "Enabled: ${svc}"
            else
                log_warn "Failed to enable: ${svc} (continuing)"
                failed+=("${svc}")
            fi
        elif systemctl cat "${svc}.timer" &>/dev/null; then
            if run_logged sudo systemctl enable --now "${svc}.timer"; then
                log_success "Enabled timer: ${svc}"
            else
                log_warn "Failed to enable timer: ${svc} (continuing)"
                failed+=("${svc}")
            fi
        elif systemctl --user cat "${svc}" &>/dev/null; then
            if run_logged systemctl --user enable --now "${svc}"; then
                log_success "Enabled (user): ${svc}"
            else
                log_warn "Failed to enable (user): ${svc} (continuing)"
                failed+=("${svc}")
            fi
        elif systemctl --user cat "${svc}.service" &>/dev/null; then
            if run_logged systemctl --user enable --now "${svc}.service"; then
                log_success "Enabled (user): ${svc}"
            else
                log_warn "Failed to enable (user): ${svc} (continuing)"
                failed+=("${svc}")
            fi
        else
            log_warn "Unit not found: ${svc} (skipped)"
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_warn "${#failed[@]} unit(s) failed to enable: ${failed[*]}"
        log_warn "Re-run 'systemctl enable --now <unit>' once the cause is fixed."
    fi
}

# /**
#  * enable_base_services()
#  * Convenience function to enable core system services.
#  */
enable_base_services() {
    log_step "Enabling base services"
    enable_services_from_config "${CONFIG_DIR}/base.yaml"
}
