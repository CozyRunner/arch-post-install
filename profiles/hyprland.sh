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

    # Config-driven step: refuse to run on a mis-parsed config rather
    # than silently operating on an empty one.
    require_yaml_parser || return 1
    local config="${CONFIG_DIR}/hyprland.yaml"

    log_step "Setting up Hyprland environment"

    # Install Hyprland-specific packages
    install_packages_from_config "${config}"

    # Enable Hyprland-specific services
    enable_services_from_config "${config}"

    # Deploy dotfiles listed in hyprland.yaml
    deploy_dotfiles_from_config "${config}"

    # Build hypridle and hyprlock from source if system binaries are missing
    local hypr_scripts="${DOTFILES_DIR}/hypr/scripts"
    if ! command -v hypridle &>/dev/null && [[ -x "${hypr_scripts}/build_hypridle.sh" ]]; then
        log_info "hypridle package not found. Building from source..."
        bash "${hypr_scripts}/build_hypridle.sh"
        log_success "hypridle built successfully"
    fi
    if ! command -v hyprlock &>/dev/null && [[ -x "${hypr_scripts}/build_hyprlock.sh" ]]; then
        log_info "hyprlock package not found. Building from source..."
        bash "${hypr_scripts}/build_hyprlock.sh"
        log_success "hyprlock built successfully"
    fi

    # ── Hyprland-specific post-setup ──────────────────────────────────────────

    # Set GTK dark mode defaults
    log_info "Applying GTK dark mode settings"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
    log_success "GTK theming applied"

    # Create XDG user directories
    xdg-user-dirs-update 2>/dev/null
    log_success "XDG user directories created"

    # Setup KWallet
    setup_kwallet

    log_success "Hyprland setup complete"
    log_info "Log out and select Hyprland from your display manager to start."
}
