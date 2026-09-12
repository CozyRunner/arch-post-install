#!/usr/bin/env bash

# Power and User Control Menu using Rofi
# Designed for Antigravity Waybar theme

USER_NAME=$(whoami)

# Icons (Nerd Fonts)
ICON_LOCK="󰌾"
ICON_LOGOUT="󰍃"
ICON_SUSPEND="󰤄"
ICON_REBOOT="󰑐"
ICON_SHUTDOWN=""

# Build menu options
options="$ICON_LOCK  Lock Session\n$ICON_LOGOUT  Logout ($USER_NAME)\n$ICON_SUSPEND  Suspend System\n$ICON_REBOOT  Reboot System\n$ICON_SHUTDOWN  Power Off"

# Show menu — glassmorphic power card
# Falls back to floating-menu.rasi if glassmorphism-power.rasi is missing
POWER_THEME="$HOME/.config/rofi/glassmorphism-power.rasi"
[ ! -f "$POWER_THEME" ] && POWER_THEME="$HOME/.config/rofi/floating-menu.rasi"

selection=$(echo -e "$options" | rofi -dmenu -i \
  -p "" \
  -mesg "  $USER_NAME" \
  -theme "$POWER_THEME")

# Parse selection and execute
case "$selection" in
*"Lock"*)
  hyprlock || swaylock
  ;;
*"Logout"*)
  hyprctl dispatch exit
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
esac
