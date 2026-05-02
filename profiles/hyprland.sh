#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: hyprland.sh
# Description: Orchestrates the Hyprland desktop environment setup.
#              Integrates packages, services, and dotfiles specifically for
#              the Hyprland workflow.
# ──────────────────────────────────────────────────────────────────────────────

# /**
#  * setup_hyprland()
#  * Orchestrates the full Hyprland environment installation.
#  * Calls packages, services, and dotfiles modules using config/hyprland.yaml.
#  */
setup_hyprland() {
    local config="${CONFIG_DIR}/hyprland.yaml"

    log_step "Setting up Hyprland environment"

    # Install Hyprland-specific packages
    install_packages_from_config "${config}"

    # Enable Hyprland-specific services
    enable_services_from_config "${config}"

    # Deploy dotfiles listed in hyprland.yaml
    deploy_dotfiles_from_config "${config}"

    # ── Hyprland-specific post-setup ──────────────────────────────────────────

    # Ensure scripts in hypr dotfiles are executable
    if [[ -d "${DOTFILES_DIR}/hypr/scripts" ]]; then
        chmod +x "${DOTFILES_DIR}/hypr/scripts/"*.sh 2>/dev/null
        log_success "Hyprland scripts marked executable"
    fi

    # Ensure waybar scripts are executable
    if [[ -d "${DOTFILES_DIR}/waybar/scripts" ]]; then
        chmod +x "${DOTFILES_DIR}/waybar/scripts/"*.sh 2>/dev/null
        log_success "Waybar scripts marked executable"
    fi

    # Set GTK dark mode defaults
    log_info "Applying GTK dark mode settings"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
    log_success "GTK theming applied"

    # Create XDG user directories
    xdg-user-dirs-update 2>/dev/null
    log_success "XDG user directories created"

    log_success "Hyprland setup complete"
    log_info "Log out and select Hyprland from your display manager to start."
}
