#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: desktop.sh
# Description: Validates graphical desktop environment, Hyprland configuration,
#              portals, and desktop ecosystem components.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_desktop() {
    print_category_header "Desktop Environment & Hyprland Configuration"

    local profile_name="${PROFILE:-${DEFAULT_PROFILE}}"
    local profile_yaml="${CONFIG_DIR}/${profile_name}.yaml"

    if [[ ! -f "${profile_yaml}" ]]; then
        skip "desktop" "desktop_profile" "No desktop profile configured (${profile_name}.yaml not found)"
        return 0
    fi

    # 1. Compositor binary
    if package_installed "hyprland" || command_exists Hyprland || command_exists hyprland; then
        pass "desktop" "compositor" "Hyprland compositor is installed"
    else
        warn "desktop" "compositor" "Hyprland compositor is not installed" \
             "Install Hyprland: sudo pacman -S hyprland" \
             "sudo pacman -S hyprland"
    fi

    # 2. Hyprland configuration file
    local hypr_cfg="${HOME}/.config/hypr/hyprland.lua"
    local hypr_cfg_legacy="${HOME}/.config/hypr/hyprland.conf"

    if [[ -f "${hypr_cfg}" ]]; then
        pass "desktop" "hyprland_config" "Hyprland Lua config present (~/.config/hypr/hyprland.lua)"
    elif [[ -f "${hypr_cfg_legacy}" ]]; then
        pass "desktop" "hyprland_config" "Hyprland conf present (~/.config/hypr/hyprland.conf)"
    else
        warn "desktop" "hyprland_config" "No Hyprland configuration found in ~/.config/hypr/" \
             "Deploy dotfiles: ./install.sh dotfiles" \
             "./install.sh dotfiles"
    fi

    # 3. Essential desktop ecosystem tools
    local -a de_tools=("waybar" "rofi" "kitty" "dunst" "xdg-desktop-portal-hyprland")
    for tool in "${de_tools[@]}"; do
        if package_installed "${tool}" || command_exists "${tool}"; then
            pass "desktop" "tool_${tool}" "Desktop component '${tool}' is installed"
        else
            warn "desktop" "tool_${tool}" "Desktop component '${tool}' is missing" \
                 "sudo pacman -S --needed ${tool}"
        fi
    done

    # 4. Dotfiles symlinks
    local -a dotfiles_list=()
    while IFS= read -r df; do
        [[ -n "${df}" && ! "${df}" =~ ^# ]] && dotfiles_list+=("${df}")
    done < <(yaml_list_get "${profile_yaml}" "dotfiles")

    for df in "${dotfiles_list[@]}"; do
        local target="${HOME}/.config/${df}"
        if [[ -L "${target}" || -d "${target}" ]]; then
            pass "desktop" "dotfile_${df}" "Config directory ~/.config/${df} exists"
        else
            warn "desktop" "dotfile_${df}" "Config ~/.config/${df} not deployed" \
                 "Deploy dotfiles: ./install.sh dotfiles"
        fi
    done
}

health_desktop() {
    print_category_header "Desktop Session Runtime Health"

    # 1. Active graphical session
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        pass "desktop" "session_type" "Active Wayland session: ${WAYLAND_DISPLAY}"
    elif [[ -n "${DISPLAY:-}" ]]; then
        pass "desktop" "session_type" "Active X11 session: ${DISPLAY}"
    else
        info "desktop" "session_type" "No active graphical session detected (running in TTY/SSH or non-interactive mode)"
    fi

    # 2. XDG Desktop Portal health
    if systemctl --user is-active --quiet xdg-desktop-portal 2>/dev/null; then
        pass "desktop" "portal_service" "XDG desktop portal user service is active"
    elif [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
        warn "desktop" "portal_service" "XDG desktop portal user service is inactive"
    fi
}
