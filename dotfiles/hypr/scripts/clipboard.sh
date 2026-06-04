#!/bin/bash
# ╔══════════════════════════════════════╗
# ║        Clipboard Manager             ║
# ║        Using /usr/bin/cliphist & rofi         ║
# ╚══════════════════════════════════════╝

# Show clipboard history via rofi
# /usr/bin/cliphist list: Lists history
# rofi -dmenu: Show list in rofi
# /usr/bin/cliphist decode: Extracts selected item
# wl-copy: Copies it back to clipboard

selection=$(/usr/bin/cliphist list | rofi -dmenu \
  -p "󱘖  Clipboard" \
  -mesg "  Select an item to copy" \
  -theme ~/.config/rofi/floating-menu.rasi)

if [ -n "$selection" ]; then
  echo "$selection" | /usr/bin/cliphist decode | wl-copy
  notify-send "Clipboard" "Item copied to clipboard" -i clipboard
fi
