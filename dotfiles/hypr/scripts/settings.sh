#!/usr/bin/env bash
# ╔══════════════════════════════════════╗
# ║           Settings Menu              ║
# ║      Edit Hyprland Configurations    ║
# ╚══════════════════════════════════════╝

set -euo pipefail

HYPR_DIR="$HOME/.config/hypr"
# Prefer $TERMINAL env var; fall back to kitty
TERM_APP="${TERMINAL:-kitty}"

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
  -p "  Settings" \
  -theme ~/.config/rofi/floating-menu.rasi)

# Handle selection
case "$selection" in
*"Input Settings"*)
  $TERM_APP --title "Input Settings" --class large-floating-term nvim "$HYPR_DIR/input.conf"
  ;;
*"Key Bindings"*)
  $TERM_APP --title "Key Bindings" --class large-floating-term nvim "$HYPR_DIR/bindings.conf"
  ;;
*"Additional Bindings"*)
  $TERM_APP --title "Additional Bindings" --class large-floating-term nvim "$HYPR_DIR/additional-bindings.conf"
  ;;
*"Monitor Settings"*)
  $TERM_APP --title "Monitor Settings" --class large-floating-term nvim "$HYPR_DIR/monitors.conf"
  ;;
*"Hypridle Settings"*)
  $TERM_APP --title "Hypridle Settings" --class large-floating-term nvim "$HYPR_DIR/hypridle.conf"
  ;;
*"Power Management"*)
  $TERM_APP --title "Power Management" --class large-floating-term nvim "$HYPR_DIR/hyprlock.conf"
  ;;
*"Network Settings"*)
  $TERM_APP --title "Network Settings (Impala)" --class large-floating-term impala
  ;;
*"Bluetooth Settings"*)
  $TERM_APP --title "Bluetooth Settings (Bluetui)" --class large-floating-term bluetui
  ;;
*"Audio Mixer"*)
  $TERM_APP --title "Audio Mixer (WireMix)" --class large-floating-term wiremix
  ;;
esac

