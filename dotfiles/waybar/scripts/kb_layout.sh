#!/bin/bash
# Script to get current keyboard layout for Waybar

LAYOUT=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap')

case "$LAYOUT" in
    "English (US)")
        ICON=""
        TEXT="US"
        ;;
    "English (India, with rupee)")
        ICON=""
        TEXT="IN"
        ;;
    *)
        ICON=""
        TEXT="$LAYOUT"
        ;;
esac

echo "{\"text\": \"$ICON $TEXT\", \"tooltip\": \"$LAYOUT\"}"
