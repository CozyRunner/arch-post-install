#!/usr/bin/env bash
# ╔══════════════════════════════════════╗
# ║           Settings Menu              ║
# ║      Edit Hyprland Configurations    ║
# ╚══════════════════════════════════════╝

set -euo pipefail

HYPR_DIR="$HOME/.config/hypr"

# Menu entries with Nerd Font icons
options="󰌌  Input Settings
󰌓  Key Bindings
󱕰  Additional Bindings
󰍹  Monitor Settings
󰒲  Hypridle Settings
󰂎  Power Management
󰖩  Network Settings
󰂯  Bluetooth Settings
󰓃  Audio Mixer"

# Show the rofi menu
selection=$(echo -e "$options" | rofi -dmenu -i \
  -p "  Settings" \
  -theme ~/.config/rofi/floating-menu.rasi)

# Handle selection
case "$selection" in
*"Input Settings"*)
  kitty --title "Input Settings" --class large-floating-term nvim "$HYPR_DIR/input.conf"
  ;;
*"Key Bindings"*)
  kitty --title "Key Bindings" --class large-floating-term nvim "$HYPR_DIR/bindings.conf"
  ;;
*"Additional Bindings"*)
  kitty --title "Additional Bindings" --class large-floating-term nvim "$HYPR_DIR/additional-bindings.conf"
  ;;
*"Monitor Settings"*)
  kitty --title "Monitor Settings" --class large-floating-term nvim "$HYPR_DIR/monitors.conf"
  ;;
*"Hypridle Settings"*)
  kitty --title "Hypridle Settings" --class large-floating-term nvim "$HYPR_DIR/hypridle.conf"
  ;;
*"Power Management"*)
  kitty --title "Power Management" --class large-floating-term nvim "$HYPR_DIR/hypridle.conf"
  ;;
*"Network Settings"*)
  kitty --title "Network Settings (Impala)" --class large-floating-term impala
  ;;
*"Bluetooth Settings"*)
  kitty --title "Bluetooth Settings (Bluetui)" --class large-floating-term bluetui
  ;;
*"Audio Mixer"*)
  kitty --title "Audio Mixer (WireMix)" --class large-floating-term wiremix
  ;;
esac
