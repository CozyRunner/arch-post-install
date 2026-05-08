#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: system.sh
# Description: Handles system-wide configuration tasks like fonts, shell setup,
#              and other common utilities.
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
