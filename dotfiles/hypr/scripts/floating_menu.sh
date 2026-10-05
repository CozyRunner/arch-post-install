#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║             Hyprland Control Center Menu                     ║
# ║        Appearance · Controls · System · Config · Power       ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ------------------------------------------------------------------------------
# Environment & Path Resolution (with repo fallback for portability)
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPTS_DIR:-$HOME/.config/hypr/scripts}"
[[ ! -d "$SCRIPTS_DIR" ]] && SCRIPTS_DIR="$SCRIPT_DIR"

HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
[[ ! -d "$HYPR_DIR" ]] && HYPR_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"

ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/floating-menu.rasi}"
if [[ ! -f "$ROFI_THEME" ]]; then
    REPO_ROFI_THEME="$(cd "$SCRIPT_DIR/../../rofi" 2>/dev/null && pwd)/floating-menu.rasi"
    [[ -f "$REPO_ROFI_THEME" ]] && ROFI_THEME="$REPO_ROFI_THEME"
fi

TERM_APP="${TERMINAL:-kitty}"
EDITOR_APP="${EDITOR:-nvim}"
USER_NAME="${USER:-$(whoami)}"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
# Launch terminal application with proper flags and detached execution
launch_term() {
    local title="$1"
    local class="$2"
    shift 2

    local term_bin
    term_bin="$(command -v "$TERM_APP" 2>/dev/null || command -v kitty 2>/dev/null || command -v alacritty 2>/dev/null || echo "kitty")"

    if [[ "$term_bin" == *"alacritty"* ]]; then
        "$term_bin" --title "$title" --class "$class" -e "$@" & disown
    elif [[ "$term_bin" == *"foot"* ]]; then
        "$term_bin" --title "$title" --app-id "$class" "$@" & disown
    elif [[ "$term_bin" == *"ghostty"* ]]; then
        "$term_bin" --title="$title" --class="$class" -e "$@" & disown
    else
        "$term_bin" --title "$title" --class "$class" "$@" & disown
    fi
}

# Run rofi dmenu safely without crashing on Escape or dismiss
rofi_menu() {
    local prompt="$1"
    local message="$2"
    local options="$3"

    local choice=""
    choice=$(echo -e "$options" | rofi -dmenu -i \
        -p "$prompt" \
        -mesg "  $message" \
        -theme "$ROFI_THEME") || true

    echo "$choice"
}

# ------------------------------------------------------------------------------
# 1. Appearance & Theming Sub-Menu
# ------------------------------------------------------------------------------
menu_appearance() {
    local current_scheme
    current_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")
    local theme_label
    if [[ "$current_scheme" == "'prefer-dark'" ]]; then
        theme_label="󰖙  Toggle Theme  →  Light"
    else
        theme_label="󰖔  Toggle Theme  →  Dark"
    fi

    local options="󰌍  Back to Main Menu
$theme_label
󰸉  Select Theme Scheme
󰋩  Change Wallpaper
󰏘  GTK Settings (nwg-look)"

    local choice
    choice=$(rofi_menu "🎨 Appearance" "Control Center › Appearance" "$options")
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Back to Main Menu"*)
            main_menu
            ;;
        *"Toggle Theme"*)
            bash "$SCRIPTS_DIR/toggle_theme.sh"
            ;;
        *"Select Theme Scheme"*)
            bash "$SCRIPTS_DIR/theme_picker.sh"
            ;;
        *"Change Wallpaper"*)
            bash "$SCRIPTS_DIR/wallpaper_picker.sh"
            ;;
        *"GTK Settings"*)
            if command -v nwg-look &>/dev/null; then
                nwg-look & disown
            else
                notify-send "GTK Settings" "nwg-look is not installed" -i dialog-warning
            fi
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 2. Quick Controls & Devices Sub-Menu
# ------------------------------------------------------------------------------
menu_controls() {
    local options="󰌍  Back to Main Menu
󰂚  Notification Center
󰖩  Network Manager (Impala)
󰂯  Bluetooth Devices (Bluetui)
󰓃  Audio Mixer (WireMix)
󱘖  Clipboard History"

    local choice
    choice=$(rofi_menu "📡 Controls" "Control Center › Quick Controls" "$options")
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Back to Main Menu"*)
            main_menu
            ;;
        *"Notification Center"*)
            bash "$SCRIPTS_DIR/notification_center.sh" toggle
            ;;
        *"Network Manager"*)
            if command -v impala &>/dev/null; then
                launch_term "Network Settings (Impala)" "large-floating-term" impala
            elif command -v nmtui &>/dev/null; then
                launch_term "Network Settings (nmtui)" "large-floating-term" nmtui
            else
                notify-send "Network Manager" "Neither impala nor nmtui found" -i dialog-warning
            fi
            ;;
        *"Bluetooth Devices"*)
            if command -v bluetui &>/dev/null; then
                launch_term "Bluetooth Settings (Bluetui)" "large-floating-term" bluetui
            elif command -v bluetoothctl &>/dev/null; then
                launch_term "Bluetooth Settings" "large-floating-term" bluetoothctl
            else
                notify-send "Bluetooth" "Neither bluetui nor bluetoothctl found" -i dialog-warning
            fi
            ;;
        *"Audio Mixer"*)
            if command -v wiremix &>/dev/null; then
                launch_term "Audio Mixer (WireMix)" "large-floating-term" wiremix
            elif command -v pulsemixer &>/dev/null; then
                launch_term "Audio Mixer (pulsemixer)" "large-floating-term" pulsemixer
            elif command -v pavucontrol &>/dev/null; then
                pavucontrol & disown
            else
                notify-send "Audio Mixer" "No audio mixer utility found" -i dialog-warning
            fi
            ;;
        *"Clipboard History"*)
            bash "$SCRIPTS_DIR/clipboard.sh"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 3. System & Maintenance Sub-Menu
# ------------------------------------------------------------------------------
menu_system() {
    local options="󰌍  Back to Main Menu
󰚐  Check Updates
󰣇  Update Arch Linux
󰚙  Update AUR Packages
󰚰  Update Device Firmware
󰋊  Disk Analyzer (ncdu)
󰍹  About This PC"

    local choice
    choice=$(rofi_menu "📦 System" "Control Center › System & Maintenance" "$options")
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Back to Main Menu"*)
            main_menu
            ;;
        *"Check Update"*)
            launch_term "Check Update" "floating-term" bash "$SCRIPTS_DIR/check_updates.sh"
            ;;
        *"Update Arch"*)
            launch_term "System Update" "floating-term" bash "$SCRIPTS_DIR/update_arch.sh"
            ;;
        *"Update AUR"*)
            launch_term "AUR Update" "floating-term" bash "$SCRIPTS_DIR/aur_update.sh"
            ;;
        *"Update Device Firmware"*)
            launch_term "Firmware Update" "floating-term" bash "$SCRIPTS_DIR/firmware_update.sh"
            ;;
        *"Disk Analyzer"*|*"Disk Analyser"*|*"ncdu"*)
            if command -v ncdu &>/dev/null; then
                launch_term "Disk Analyzer (ncdu)" "large-floating-term" ncdu --exclude-kernfs /
            elif command -v dust &>/dev/null; then
                launch_term "Disk Analyzer (dust)" "large-floating-term" bash -c "dust /; read -r -p 'Press Enter to close...'"
            else
                notify-send "Disk Analyzer" "Neither ncdu nor dust installed" -i dialog-warning
            fi
            ;;
        *"About This PC"*)
            launch_term "About This PC" "medium-floating-term" bash "$SCRIPTS_DIR/about_pc.sh"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 4. Configuration & Dotfiles Sub-Menu
# ------------------------------------------------------------------------------
menu_config() {
    local options="󰌍  Back to Main Menu
󰌌  Input & Touchpad
󰌓  Core Keybindings
󱕰  Utility Bindings
󰒓  Look & Feel / Animations
󰖲  Window Rules & Layout
󰐥  Autostart Daemons
󰍹  Monitor Settings
󰒲  Hypridle Settings
󰂎  Power Management (Hyprlock)
󰂚  Notification Settings"

    local choice
    choice=$(rofi_menu " Config" "Control Center › Configurations" "$options")
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Back to Main Menu"*)
            main_menu
            ;;
        *"Input & Touchpad"*)
            launch_term "Input Settings" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/config/input.lua"
            ;;
        *"Core Keybindings"*)
            launch_term "Core Keybindings" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/config/keybinds/core.lua"
            ;;
        *"Utility Bindings"*)
            launch_term "Utility Bindings" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/config/keybinds/utilities.lua"
            ;;
        *"Look & Feel"*)
            launch_term "Look & Feel Settings" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/config/looknfeel.lua"
            ;;
        *"Window Rules"*)
            launch_term "Window Rules" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/config/rules.lua"
            ;;
        *"Autostart Daemons"*)
            launch_term "Autostart Settings" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/config/autostart.lua"
            ;;
        *"Monitor Settings"*)
            launch_term "Monitor Settings" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/config/monitors.lua"
            ;;
        *"Hypridle Settings"*)
            launch_term "Hypridle Settings" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/hypridle.conf"
            ;;
        *"Power Management"*)
            launch_term "Power Management" "large-floating-term" "$EDITOR_APP" "$HYPR_DIR/hyprlock.conf"
            ;;
        *"Notification Settings"*)
            if [[ -f "$HOME/.config/swaync/config.json" ]]; then
                launch_term "Notification Settings" "large-floating-term" "$EDITOR_APP" "$HOME/.config/swaync/config.json"
            elif [[ -f "$HOME/.config/dunst/dunstrc" ]]; then
                launch_term "Notification Settings" "large-floating-term" "$EDITOR_APP" "$HOME/.config/dunst/dunstrc"
            else
                launch_term "Notification Settings" "large-floating-term" "$EDITOR_APP" "$HOME/.config/swaync/config.json"
            fi
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 5. Power & Session Sub-Menu
# ------------------------------------------------------------------------------
menu_power() {
    local options="󰌍  Back to Main Menu
󰌾  Lock Session
󰤄  Suspend System
󰑐  Reboot System
  Power Off
󰍃  Logout ($USER_NAME)"

    local choice
    choice=$(rofi_menu "⏻ Power" "Control Center › Power & Session" "$options")
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Back to Main Menu"*)
            main_menu
            ;;
        *"Lock"*)
            hyprlock || swaylock
            ;;
        *"Suspend"*)
            systemctl suspend
            ;;
        *"Reboot"*)
            systemctl reboot
            ;;
        *"Power Off"*)
            systemctl poweroff
            ;;
        *"Logout"*)
            hyprctl dispatch exit
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Root Control Center Menu
# ------------------------------------------------------------------------------
main_menu() {
    local root_options="🎨  Appearance & Theming
📡  Quick Controls & Devices
📦  System & Maintenance
  Configuration & Dotfiles
⏻  Power & Session"

    local selection
    selection=$(rofi_menu "⚡ Quick Settings" "Hyprland Control Center" "$root_options")
    [[ -z "$selection" ]] && exit 0

    case "$selection" in
        *"Appearance"*)
            menu_appearance
            ;;
        *"Quick Controls"*)
            menu_controls
            ;;
        *"System & Maintenance"*)
            menu_system
            ;;
        *"Configuration & Dotfiles"*)
            menu_config
            ;;
        *"Power & Session"*)
            menu_power
            ;;
    esac
}

# Allow direct entry into sub-menus via CLI argument (e.g. ./floating_menu.sh config)
ACTION="${1:-main}"
case "$ACTION" in
    appearance) menu_appearance ;;
    controls)   menu_controls ;;
    system)     menu_system ;;
    config)     menu_config ;;
    power)      menu_power ;;
    *)          main_menu ;;
esac
