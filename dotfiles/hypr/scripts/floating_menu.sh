#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║             Hyprland Control Center Menu                     ║
# ║        Appearance · Controls · System · Config · Power       ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPTS_DIR="$HOME/.config/hypr/scripts"
HYPR_DIR="$HOME/.config/hypr"
ROFI_THEME="$HOME/.config/rofi/floating-menu.rasi"
TERM_APP="${TERMINAL:-kitty}"
USER_NAME="$(whoami)"

# Helper to run rofi dmenu
rofi_menu() {
  local prompt="$1"
  local message="$2"
  local options="$3"
  echo -e "$options" | rofi -dmenu -i \
    -p "$prompt" \
    -mesg "  $message" \
    -theme "$ROFI_THEME"
}

# ------------------------------------------------------------------------------
# 1. Appearance & Theming Sub-Menu
# ------------------------------------------------------------------------------
menu_appearance() {
  local current_scheme
  current_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")
  local theme_label
  if [ "$current_scheme" == "'prefer-dark'" ]; then
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
      nwg-look &
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

  case "$choice" in
    *"Back to Main Menu"*)
      main_menu
      ;;
    *"Notification Center"*)
      bash "$SCRIPTS_DIR/notification_center.sh" toggle
      ;;
    *"Network Manager"*)
      $TERM_APP --title "Network Settings (Impala)" --class large-floating-term impala
      ;;
    *"Bluetooth Devices"*)
      $TERM_APP --title "Bluetooth Settings (Bluetui)" --class large-floating-term bluetui
      ;;
    *"Audio Mixer"*)
      $TERM_APP --title "Audio Mixer (WireMix)" --class large-floating-term wiremix
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

  case "$choice" in
    *"Back to Main Menu"*)
      main_menu
      ;;
    *"Check Update"*)
      $TERM_APP --title "Check Update" --class floating-term bash "$SCRIPTS_DIR/check_updates.sh"
      ;;
    *"Update Arch"*)
      $TERM_APP --title "System Update" --class floating-term bash "$SCRIPTS_DIR/update_arch.sh"
      ;;
    *"Update AUR"*)
      $TERM_APP --title "AUR Update" --class floating-term bash "$SCRIPTS_DIR/aur_update.sh"
      ;;
    *"Update Device Firmware"*)
      $TERM_APP --title "Firmware Update" --class floating-term bash "$SCRIPTS_DIR/firmware_update.sh"
      ;;
    *"Disk Analyzer"*|*"Disk Analyser"*|*"ncdu"*)
      $TERM_APP --title "Disk Analyzer (ncdu)" --class large-floating-term ncdu --exclude-kernfs /
      ;;
    *"About This PC"*)
      $TERM_APP --title "About This PC" --class medium-floating-term bash "$SCRIPTS_DIR/about_pc.sh"
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
󰍹  Monitor Settings
󰒲  Hypridle Settings
󰂎  Power Management (Hyprlock)
󰂚  Notification Settings"

  local choice
  choice=$(rofi_menu " Config" "Control Center › Configurations" "$options")

  case "$choice" in
    *"Back to Main Menu"*)
      main_menu
      ;;
    *"Input & Touchpad"*)
      $TERM_APP --title "Input Settings" --class large-floating-term nvim "$HYPR_DIR/config/input.lua"
      ;;
    *"Core Keybindings"*)
      $TERM_APP --title "Core Keybindings" --class large-floating-term nvim "$HYPR_DIR/config/keybinds/core.lua"
      ;;
    *"Utility Bindings"*)
      $TERM_APP --title "Utility Bindings" --class large-floating-term nvim "$HYPR_DIR/config/keybinds/utilities.lua"
      ;;
    *"Monitor Settings"*)
      $TERM_APP --title "Monitor Settings" --class large-floating-term nvim "$HYPR_DIR/config/monitors.lua"
      ;;
    *"Hypridle Settings"*)
      $TERM_APP --title "Hypridle Settings" --class large-floating-term nvim "$HYPR_DIR/hypridle.conf"
      ;;
    *"Power Management"*)
      $TERM_APP --title "Power Management" --class large-floating-term nvim "$HYPR_DIR/hyprlock.conf"
      ;;
    *"Notification Settings"*)
      if [ -f "$HOME/.config/swaync/config.json" ]; then
        $TERM_APP --title "Notification Settings" --class large-floating-term nvim "$HOME/.config/swaync/config.json"
      elif [ -f "$HOME/.config/dunst/dunstrc" ]; then
        $TERM_APP --title "Notification Settings" --class large-floating-term nvim "$HOME/.config/dunst/dunstrc"
      else
        $TERM_APP --title "Notification Settings" --class large-floating-term nvim "$HOME/.config/swaync/config.json"
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

# Execute main menu
main_menu
