#!/usr/bin/env bash

# Module: flatpak.sh
# Description: Installs Flatpak and manages Flatpak applications.

is_flatpak_installed() {
    flatpak info "$1" &>/dev/null 2>&1
}

install_flatpaks_from_config() {
    local config="$1"

    if [[ ! -f "${config}" ]]; then
        log_error "Config file not found: ${config}"
        return 1
    fi

    # Ensure Flatpak is installed
    if ! command -v flatpak &>/dev/null; then
        log_info "Installing Flatpak..."
        sudo pacman -S --needed --noconfirm flatpak 2>&1 | tee -a "${LOG_FILE}"
    fi

    # Add Flathub if not already present
    if ! flatpak remotes | grep -q flathub; then
        log_info "Adding Flathub remote..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "${LOG_FILE}"
        log_success "Flathub remote added"
    fi

    # Parse and install Flatpak packages
    local -a flatpak_pkgs=()
    while IFS= read -r pkg; do
        [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && flatpak_pkgs+=("${pkg}")
    done < <(yaml_list "${config}" "packages.flatpak")

    if [[ ${#flatpak_pkgs[@]} -eq 0 ]]; then
        log_warn "No Flatpak packages found in ${config}"
        return 0
    fi

    log_step "Installing ${#flatpak_pkgs[@]} Flatpak packages"

    local -a to_install=()
    for pkg in "${flatpak_pkgs[@]}"; do
        if is_flatpak_installed "${pkg}"; then
            log_debug "Already installed: ${pkg}"
        else
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Flatpaks to install: ${to_install[*]}"
        if flatpak install -y flathub "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
            log_success "Flatpak packages installed"
        else
            log_warn "Some Flatpak packages may have failed"
        fi
    else
        log_success "All Flatpak packages already installed"
    fi
}

setup_flatpak() {
    log_step "Setting up Flatpak"
    install_flatpaks_from_config "${CONFIG_DIR}/base.yaml"
    install_flatpaks_from_config "${CONFIG_DIR}/hyprland.yaml"
}
