#!/usr/bin/env bash

# Power and User Control Menu using Rofi
# Designed for Antigravity Waybar theme

USER_NAME=$(whoami)
HOST_NAME=$(hostname)

# Icons (Nerd Fonts)
ICON_LOCK="󰌾"
ICON_LOGOUT="󰍃"
ICON_SUSPEND="󰤄"
ICON_REBOOT="󰑐"
ICON_SHUTDOWN=""

# Build menu options
options="$ICON_LOCK  Lock Session\n$ICON_LOGOUT  Logout ($USER_NAME)\n$ICON_SUSPEND  Suspend System\n$ICON_REBOOT  Reboot System\n$ICON_SHUTDOWN  Power Off"

# Show menu
# Using rofi in dmenu mode with modern theme and custom overrides
selection=$(echo -e "$options" | rofi -dmenu -i -p "System Menu" -theme ~/.config/rofi/floating-menu.rasi -theme-str 'window {width: 450px;} listview {lines: 5;}')

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
