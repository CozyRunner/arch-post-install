#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: packages.sh
# Description: Handles software installation via pacman and yay.
#              Automatically detects already installed packages to skip them.
# ──────────────────────────────────────────────────────────────────────────────

# /**
#  * is_installed()
#  * Checks if a specific package is installed on the system.
#  * @param {string} pkg - Package name.
#  */
is_installed() {
    pacman -Q "$1" &>/dev/null
}

# /**
#  * install_packages_from_config()
#  * Parses a YAML configuration file and installs listed pacman and AUR packages.
#  * @param {string} config - Path to the YAML config file.
#  */
install_packages_from_config() {
    local config="$1"

    if [[ ! -f "${config}" ]]; then
        log_error "Config file not found: ${config}"
        return 1
    fi

    # ── Pacman packages ───────────────────────────────────────────────────────
    local -a pacman_pkgs=()
    while IFS= read -r pkg; do
        [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && pacman_pkgs+=("${pkg}")
    done < <(yaml_list "${config}" "packages.pacman")

    if [[ ${#pacman_pkgs[@]} -gt 0 ]]; then
        log_step "Installing ${#pacman_pkgs[@]} pacman packages"

        local -a to_install=()
        for pkg in "${pacman_pkgs[@]}"; do
            if is_installed "${pkg}"; then
                log_debug "Already installed: ${pkg}"
            else
                to_install+=("${pkg}")
            fi
        done

        if [[ ${#to_install[@]} -gt 0 ]]; then
            log_info "Packages to install: ${to_install[*]}"
            if sudo pacman -S --needed --noconfirm "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
                log_success "Pacman packages installed"
                
                # Enable corepack if nodejs was installed
                if is_installed "nodejs" && command -v corepack &>/dev/null; then
                    log_info "Enabling corepack..."
                    sudo corepack enable 2>/dev/null || log_warn "Could not enable corepack"
                    log_success "Corepack enabled"
                fi
            else
                log_error "Some pacman packages failed to install"
            fi
        else
            log_success "All pacman packages already installed"
        fi
    else
        log_warn "No pacman packages found in ${config}"
    fi

    # ── AUR packages ──────────────────────────────────────────────────────────
    local -a aur_pkgs=()
    while IFS= read -r pkg; do
        [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && aur_pkgs+=("${pkg}")
    done < <(yaml_list "${config}" "packages.aur")

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        ensure_yay
        log_step "Installing ${#aur_pkgs[@]} AUR packages"

        local -a to_install=()
        for pkg in "${aur_pkgs[@]}"; do
            if yay -Q "${pkg}" &>/dev/null; then
                log_debug "Already installed: ${pkg}"
            else
                to_install+=("${pkg}")
            fi
        done

        if [[ ${#to_install[@]} -gt 0 ]]; then
            log_info "Packages to install: ${to_install[*]}"
            if yay -S --needed --noconfirm "${to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
                log_success "AUR packages installed"
            else
                log_warn "Some AUR packages may have failed"
            fi
        else
            log_success "All AUR packages already installed"
        fi
    fi
}

# /**
#  * install_base_packages()
#  * Convenience function to install core system packages.
#  */
install_base_packages() {
    log_step "Installing base packages"
    install_packages_from_config "${CONFIG_DIR}/base.yaml"
}
