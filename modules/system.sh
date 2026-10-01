#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: system.sh
# Description: Handles system-wide configuration tasks like fonts, shell setup,
#              ZRAM, pacman tuning, firewall, and hardware optimizations.
# ──────────────────────────────────────────────────────────────────────────────

# /**
#  * setup_system_fonts()
#  * Installs and configures system-wide fonts.
#  */
setup_system_fonts() {
    log_step "Installing system fonts"
    if [[ -f "${SCRIPT_DIR}/scripts/fonts.sh" ]]; then
        bash "${SCRIPT_DIR}/scripts/fonts.sh" 2>&1 | tee -a "${LOG_FILE}"
        log_success "System fonts installed"
    else
        log_warn "fonts.sh script not found"
    fi
}

# /**
#  * setup_system_shell()
#  * Installs and configures the default system shell (Fish).
#  */
setup_system_shell() {
    log_step "Setting up system shell (Fish)"
    if [[ -f "${SCRIPT_DIR}/scripts/setup_fish.sh" ]]; then
        bash "${SCRIPT_DIR}/scripts/setup_fish.sh" 2>&1 | tee -a "${LOG_FILE}"
        log_success "System shell configured"
    else
        log_warn "setup_fish.sh script not found"
    fi
}

# /**
#  * apply_system_updates()
#  * Wrapper for core system update logic.
#  */
apply_system_updates() {
    setup_core
}

# /**
#  * setup_kwallet()
#  * Installs and configures PAM for KWallet.
#  */
setup_kwallet() {
    log_step "Setting up KWallet"
    if [[ -f "${SCRIPT_DIR}/scripts/setup_kwallet.sh" ]]; then
        bash "${SCRIPT_DIR}/scripts/setup_kwallet.sh" 2>&1 | tee -a "${LOG_FILE}"
        log_success "KWallet setup complete"
    else
        log_warn "setup_kwallet.sh script not found"
    fi
}

# /**
#  * tune_pacman()
#  * Configures pacman for speed (ParallelDownloads) and readability (Color, ILoveCandy).
#  */
tune_pacman() {
    log_step "Optimizing Pacman configuration"
    local pacman_conf="/etc/pacman.conf"

    if [[ ! -f "${pacman_conf}" ]]; then
        log_warn "Pacman config not found: ${pacman_conf}"
        return 0
    fi

    # Only claim what was actually applied. Each `sed` below matches the
    # STOCK commented form, so a user who had already uncommented and set a
    # value kept their value while the old code still printed
    # "optimized (... ParallelDownloads=5)". Check the desired state first and
    # skip what is already satisfied.
    local applied=()

    if grep -qE "^[[:space:]]*Color[[:space:]]*$" "${pacman_conf}"; then
        applied+=("Color")
    else
        sudo sed -i 's/^#Color/Color/' "${pacman_conf}"
        applied+=("Color")
    fi

    if grep -qE "^[[:space:]]*VerbosePkgLists[[:space:]]*$" "${pacman_conf}"; then
        applied+=("VerbosePkgLists")
    else
        sudo sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' "${pacman_conf}"
        applied+=("VerbosePkgLists")
    fi

    if grep -qE "^[[:space:]]*ParallelDownloads[[:space:]]*=[[:space:]]*5[[:space:]]*$" "${pacman_conf}"; then
        applied+=("ParallelDownloads=5")
    else
        # Matches both the commented stock form and an existing non-5 value.
        if grep -qE "^[[:space:]]*ParallelDownloads[[:space:]]*=" "${pacman_conf}"; then
            sudo sed -i -E 's/^[[:space:]]*ParallelDownloads[[:space:]]*=.*/ParallelDownloads = 5/' "${pacman_conf}"
        else
            sudo sed -i 's/^#ParallelDownloads = .*/ParallelDownloads = 5/' "${pacman_conf}"
        fi
        applied+=("ParallelDownloads=5")
    fi

    if grep -q "^ILoveCandy" "${pacman_conf}"; then
        applied+=("ILoveCandy")
    else
        sudo sed -i '/^Color/a ILoveCandy' "${pacman_conf}"
        applied+=("ILoveCandy")
    fi

    log_success "Pacman settings verified/applied: ${applied[*]}"
}

# /**
#  * setup_zram()
#  * Configures fast in-memory compressed swap via zram-generator.
#  */
setup_zram() {
    log_step "Configuring ZRAM Swap"

    if ! pacman -Q zram-generator &>/dev/null; then
        log_info "Installing zram-generator..."
        sudo pacman -S --needed --noconfirm zram-generator 2>&1 | tee -a "${LOG_FILE}"
    fi

    local zram_conf="/etc/systemd/zram-generator.conf"
    local zram_body='[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd'

    # Only rewrite the config when it differs. An unconditional write followed
    # by a restart made every re-run discard live swapped data: the swap device
    # is torn down and re-created, so anything the kernel had paged out to it
    # is lost. Check both the config and the unit's active state first.
    #
    # Compare the file content to the desired body directly. `grep -qF` with a
    # multi-line pattern is line-oriented: it matches if ANY line matches, so
    # it cannot detect a changed compression-algorithm and would report the
    # config as already correct for ever after the first run.
    local needs_restart=0
    local current_body=""
    if [[ -f "${zram_conf}" ]]; then
        current_body="$(cat "${zram_conf}")"
    fi
    if [[ "${current_body}" != "${zram_body}" ]]; then
        log_info "Writing ZRAM generator configuration to ${zram_conf}"
        printf '%s\n' "${zram_body}" | sudo tee "${zram_conf}" > /dev/null
        run_logged sudo systemctl daemon-reload
        needs_restart=1
    fi

    if systemctl is-active --quiet systemd-zram-setup@zram0.service; then
        if [[ ${needs_restart} -eq 1 ]]; then
            log_info "ZRAM config changed; restarting swap device"
            run_logged sudo systemctl restart systemd-zram-setup@zram0.service
        else
            log_success "ZRAM already active with the desired configuration"
            return 0
        fi
    else
        run_logged sudo systemctl start systemd-zram-setup@zram0.service
    fi
    log_success "ZRAM swap configured (zstd, min(RAM/2, 8GB))"
}

# /**
#  * setup_firewall()
#  * Configures and enables UFW firewall with secure defaults.
#  */
setup_firewall() {
    local config="${1:-${CONFIG_DIR}/base.yaml}"
    log_step "Configuring UFW Firewall"

    if ! pacman -Q ufw &>/dev/null; then
        log_info "Installing ufw..."
        sudo pacman -S --needed --noconfirm ufw 2>&1 | tee -a "${LOG_FILE}"
    fi

    # ── Preserve SSH access BEFORE applying the deny policy ───────────────────
    # `config/base.yaml` enables sshd. Applying `default deny incoming` with no
    # allow rule severs the current session and locks the user out on the next
    # boot, so any SSH-based service must be allowed first. This ordering is
    # load-bearing, not cosmetic.
    local -a ssh_services=()
    if [[ -f "${config}" ]] && require_yaml_parser &>/dev/null; then
        local svc
        while IFS= read -r svc; do
            [[ -n "${svc}" ]] && ssh_services+=("${svc}")
        done < <(yaml_list "${config}" "services" 2>/dev/null)
    fi

    local -a opened=()
    for svc in "${ssh_services[@]}"; do
        case "${svc}" in
            sshd|openssh|ssh|dropbear)
                if ufw_has_rule_ssh; then
                    log_info "SSH already allowed by an existing UFW rule"
                else
                    # run_logged, not `cmd | tee`: the decision must not depend
                    # on pipefail, which the Makefile targets do not set.
                    if run_logged sudo ufw allow OpenSSH; then
                        opened+=("OpenSSH")
                    elif run_logged sudo ufw allow 22/tcp; then
                        # Some systems have no OpenSSH profile registered.
                        opened+=("22/tcp")
                    else
                        log_error "Could not add an SSH allow rule to UFW."
                        log_error "Refusing to enable the firewall: 'deny incoming' would cut SSH access."
                        return 1
                    fi
                fi
                ;;
        esac
    done

    if [[ ${#opened[@]} -gt 0 ]]; then
        log_success "Preserved SSH access: allow ${opened[*]}"
    fi

    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        log_warn "This session is over SSH — 'deny incoming' will apply to new connections."
        log_warn "Keep this session open until you have confirmed you can reconnect."
    fi

    run_logged sudo ufw default deny incoming
    run_logged sudo ufw default allow outgoing

    # Re-verify SSH is still reachable under the new policy before enabling.
    if [[ ${#ssh_services[@]} -gt 0 ]] && ! ufw_has_rule_ssh; then
        log_error "No SSH allow rule present after applying defaults. Aborting before enabling UFW."
        return 1
    fi

    run_logged sudo ufw --force enable
    run_logged sudo systemctl enable --now ufw
    log_success "UFW firewall active with default deny incoming posture"
}

# /**
#  * ufw_has_rule_ssh()
#  * Reports whether UFW currently permits inbound SSH, by profile or by port.
#  * Safe to call when UFW is not yet enabled.
#  */
ufw_has_rule_ssh() {
    local rules
    rules="$(sudo ufw status 2>/dev/null || true)"
    grep -qiE '(^|[[:space:]])(OpenSSH|22/tcp)([[:space:]]|$)' <<< "${rules}"
}

# /**
#  * tune_bluetooth()
#  * Configures Bluetooth daemon to auto-power controllers on startup.
#  */
tune_bluetooth() {
    local bt_conf="/etc/bluetooth/main.conf"
    if [[ ! -f "${bt_conf}" ]]; then
        log_warn "${bt_conf} not found (skipping Bluetooth AutoEnable)"
        return 0
    fi

    log_step "Configuring Bluetooth AutoEnable"

    # Already uncommented and true? Nothing to do.
    if grep -qE "^[[:space:]]*AutoEnable[[:space:]]*=[[:space:]]*true" "${bt_conf}"; then
        log_success "Bluetooth AutoEnable already set to true"
        return 0
    fi

    # Uncomment the stock commented-out line (the common case).
    if grep -q "^[[:space:]]*#AutoEnable" "${bt_conf}"; then
        sudo sed -i 's/^[[:space:]]*#AutoEnable[[:space:]]*=.*/AutoEnable = true/' "${bt_conf}"
        log_success "Bluetooth AutoEnable set to true"
        return 0
    fi

    # An explicit `AutoEnable = false` (or a value we do not recognise) exists.
    # Edit it in place rather than appending, which is what created a SECOND
    # `[Policy]` section on every re-run.
    if grep -qE "^[[:space:]]*AutoEnable[[:space:]]*=" "${bt_conf}"; then
        sudo sed -i -E 's/^[[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable = true/' "${bt_conf}"
        log_success "Bluetooth AutoEnable updated to true"
        return 0
    fi

    # No AutoEnable key at all: add one under the existing [Policy] section if
    # there is one, otherwise create the section exactly once.
    if grep -qE "^[[:space:]]*\[Policy\]" "${bt_conf}"; then
        sudo sed -i -E '0,/^[[:space:]]*\[Policy\]/s//[Policy]\nAutoEnable = true/' "${bt_conf}"
    else
        printf '\n[Policy]\nAutoEnable = true\n' | sudo tee -a "${bt_conf}" > /dev/null
    fi
    log_success "Bluetooth AutoEnable configured"
}
