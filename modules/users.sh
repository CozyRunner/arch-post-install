#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: users.sh
# Description: Configures user account settings and system locales.
#              Handles shell, groups, timezone, and locale generation.
# ──────────────────────────────────────────────────────────────────────────────

# /**
#  * setup_users()
#  * Configures the current user and system-wide settings from config/base.yaml.
#  */
setup_users() {

    # Config-driven step: refuse to run on a mis-parsed config rather
    # than silently operating on an empty one.
    require_yaml_parser || return 1
    local config="${CONFIG_DIR}/base.yaml"

    log_step "Configuring user account"

    # ── Set default shell ─────────────────────────────────────────────────────
    local shell
    shell="$(yaml_value "${config}" "user.shell")"
    if [[ -n "${shell}" && -x "${shell}" ]]; then
        if [[ "$(getent passwd "${USER}" | cut -d: -f7)" != "${shell}" ]]; then
            log_info "Changing shell to ${shell}"
            chsh -s "${shell}" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Shell set to ${shell}"
        else
            log_success "Shell already set to ${shell}"
        fi
    fi

    # ── Add user to groups ────────────────────────────────────────────────────
    local -a groups=()
    while IFS= read -r grp; do
        [[ -n "${grp}" ]] && groups+=("${grp}")
    done < <(yaml_list "${config}" "user.groups")

    for grp in "${groups[@]}"; do
        if getent group "${grp}" &>/dev/null; then
            if ! id -nG "${USER}" | grep -qw "${grp}"; then
                sudo usermod -aG "${grp}" "${USER}" 2>&1 | tee -a "${LOG_FILE}"
                log_success "Added ${USER} to group: ${grp}"
            else
                log_success "Already in group: ${grp}"
            fi
        else
            log_warn "Group does not exist: ${grp} (skipped)"
        fi
    done

    # ── Set hostname ─────────────────────────────────────────────────────────
    local hostname
    hostname="$(yaml_value "${config}" "system.hostname")"
    if [[ -n "${hostname}" ]]; then
        if [[ "$(cat /etc/hostname 2>/dev/null)" != "${hostname}" ]]; then
            log_info "Setting hostname to ${hostname}"
            echo "${hostname}" | sudo tee /etc/hostname >/dev/null
            sudo hostnamectl set-hostname "${hostname}" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Hostname: ${hostname}"
        else
            log_success "Hostname already set to ${hostname}"
        fi
    fi

    # ── Set locale & timezone ─────────────────────────────────────────────────
    local timezone locale keymap
    timezone="$(yaml_value "${config}" "system.timezone")"
    locale="$(yaml_value "${config}" "system.locale")"
    keymap="$(yaml_value "${config}" "system.keymap")"

    if [[ -n "${timezone}" ]]; then
        log_info "Setting timezone to ${timezone}"
        sudo timedatectl set-timezone "${timezone}" 2>&1 | tee -a "${LOG_FILE}"
        log_success "Timezone: ${timezone}"
    fi

    if [[ -n "${locale}" ]]; then
        log_info "Setting locale to ${locale}"
        sudo sed -i "s/^#\(${locale}.*\)/\1/" /etc/locale.gen 2>/dev/null
        run_logged sudo locale-gen
        # Preserve every existing key. `echo LANG=… | sudo tee` truncated
        # /etc/locale.conf, destroying any LC_* the user had already set (LC_TIME,
        # LC_COLLATE, …). Only the managed LANG key is written.
        set_etc_key "LANG" "${locale}" /etc/locale.conf
        log_success "Locale: ${locale}"
    fi

    if [[ -n "${keymap}" ]]; then
        log_info "Setting keymap to ${keymap}"
        # Same for /etc/vconsole.conf: FONT and other keys must survive.
        set_etc_key "KEYMAP" "${keymap}" /etc/vconsole.conf
        log_success "Keymap: ${keymap}"
    fi
}
