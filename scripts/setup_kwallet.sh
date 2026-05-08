#!/usr/bin/env bash

# Configure PAM for KWallet auto-unlock
log_step "Configuring PAM for KWallet"

PAM_LOGIN="/etc/pam.d/login"
PAM_SDDM="/etc/pam.d/sddm"
PAM_LIGHTDM="/etc/pam.d/lightdm"
PAM_GDM="/etc/pam.d/gdm-password"

# Function to add kwallet to a pam file
configure_pam_kwallet() {
    local pam_file="$1"
    
    if [[ ! -f "$pam_file" ]]; then
        return 0
    fi

    # Check if already configured
    if grep -q "pam_kwallet.so" "$pam_file"; then
        log_debug "KWallet PAM already configured in $pam_file"
        return 0
    fi

    # Add auth line
    if grep -q "^auth.*include.*system-local-login" "$pam_file"; then
        sudo sed -i '/^auth.*include.*system-local-login/a auth       optional     pam_kwallet.so' "$pam_file"
    elif grep -q "^auth.*include.*system-login" "$pam_file"; then
        sudo sed -i '/^auth.*include.*system-login/a auth       optional     pam_kwallet.so' "$pam_file"
    fi

    # Add session line
    if grep -q "^session.*include.*system-local-login" "$pam_file"; then
        sudo sed -i '/^session.*include.*system-local-login/a session    optional     pam_kwallet.so auto_start' "$pam_file"
    elif grep -q "^session.*include.*system-login" "$pam_file"; then
        sudo sed -i '/^session.*include.*system-login/a session    optional     pam_kwallet.so auto_start' "$pam_file"
    fi

    log_success "KWallet PAM configured in $pam_file"
}

configure_pam_kwallet "$PAM_LOGIN"
configure_pam_kwallet "$PAM_SDDM"
configure_pam_kwallet "$PAM_LIGHTDM"
configure_pam_kwallet "$PAM_GDM"
