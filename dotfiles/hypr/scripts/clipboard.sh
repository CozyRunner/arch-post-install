#!/bin/bash
# ╔══════════════════════════════════════╗
# ║        Clipboard Manager             ║
# ║        Using cliphist & rofi         ║
# ╚══════════════════════════════════════╝

# Show clipboard history via rofi
# cliphist list: Lists history
# rofi -dmenu: Show list in rofi
# cliphist decode: Extracts selected item
# wl-copy: Copies it back to clipboard

selection=$(cliphist list | rofi -dmenu \
  -p "󱘖  Clipboard" \
  -mesg "  Select an item to copy" \
  -theme ~/.config/rofi/floating-menu.rasi)

if [ -n "$selection" ]; then
  echo "$selection" | cliphist decode | wl-copy
  notify-send "Clipboard" "Item copied to clipboard" -i clipboard
fi
