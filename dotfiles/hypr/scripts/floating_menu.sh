#!/usr/bin/env bash
# ╔══════════════════════════════════════╗
# ║    Floating Quick Settings Menu      ║
# ║    Theme · Wallpaper · Update · Info ║
# ╚══════════════════════════════════════╝

set -euo pipefail

SCRIPTS_DIR="$HOME/.config/hypr/scripts"

# Detect current theme for dynamic icon
CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
if [ "$CURRENT_SCHEME" == "'prefer-dark'" ]; then
  THEME_LABEL="󰖙  Toggle Theme  →  Light"
else
  THEME_LABEL="󰖔  Toggle Theme  →  Dark"
fi

# Menu entries with Nerd Font icons
options="$THEME_LABEL
󱘖  Clipboard History
󰋩  Change Wallpaper
󰚰  Update
  Settings
󰍹  About This PC
⏻  Power Menu"

# Show the rofi menu
selection=$(echo -e "$options" | rofi -dmenu -i \
  -p "⚡ Quick Settings" \
  -mesg "  Hyprland Control Center" \
  -theme ~/.config/rofi/floating-menu.rasi)

# Handle selection
case "$selection" in
*"Toggle Theme"*)
  bash "$SCRIPTS_DIR/toggle_theme.sh"
  ;;
*"Clipboard History"*)
  bash "$SCRIPTS_DIR/clipboard.sh"
  ;;
*"Change Wallpaper"*)
  bash "$SCRIPTS_DIR/wallpaper_picker.sh"
  ;;
*"Update"*)
  # Sub-menu for Update group
  update_options="󰚐  Check Updates
󰣇  Update Arch Linux
󰚙  Update AUR"

  update_selection=$(echo -e "$update_options" | rofi -dmenu -i \
    -p "󰚰  Update" \
    -theme ~/.config/rofi/floating-menu.rasi)

  case "$update_selection" in
  *"Check Update"*)
    kitty --title "Check Update" --class floating-term bash "$SCRIPTS_DIR/check_updates.sh"
    ;;
  *"Update Arch"*)
    kitty --title "System Update" --class floating-term bash "$SCRIPTS_DIR/update_arch.sh"
    ;;
  *"Update AUR"*)
    kitty --title "AUR Update" --class floating-term bash "$SCRIPTS_DIR/aur_update.sh"
    ;;
  esac
  ;;
*"Settings"*)
  bash "$SCRIPTS_DIR/settings.sh"
  ;;
*"About This PC"*)

  kitty --title "About This PC" --class meduim-floating-term bash "$SCRIPTS_DIR/about_pc.sh"
  ;;
*"Power Menu"*)
  bash "$SCRIPTS_DIR/power_menu.sh"
  ;;
esac
