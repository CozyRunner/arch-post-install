#!/usr/bin/env bash

# Waybar Cliphist Integration
# Provides tooltip, listing, and wiping functionality

case "$1" in
    --tooltip)
        # Get the first item from /usr/bin/cliphist
        # /usr/bin/cliphist list returns "ID  content"
        last_item=$(/usr/bin/cliphist list 2>/dev/null | head -n 1 | sed 's/^[0-9]*[[:space:]]*//' | cut -c 1-50)
        if [ -z "$last_item" ]; then
            last_item="Clipboard is empty"
        else
            last_item="Last copied: $last_item"
        fi
        jq -nc --arg text "" --arg tooltip "$last_item" '{text: $text, tooltip: $tooltip}'
        ;;
    --list)
        # Call the existing clipboard script
        bash ~/.config/hypr/scripts/clipboard.sh
        ;;
    --wipe)
        # Confirmation via rofi
        confirm=$(echo -e "No\nYes" | rofi -dmenu -i -p "󰗨 Clear Clipboard?" -theme ~/.config/rofi/floating-menu.rasi)
        if [ "$confirm" == "Yes" ]; then
            /usr/bin/cliphist wipe
            notify-send "Clipboard" "History cleared" -i clipboard
        fi
        ;;
    *)
        echo "Usage: $0 [--tooltip|--list|--wipe]"
        exit 1
        ;;
esac
