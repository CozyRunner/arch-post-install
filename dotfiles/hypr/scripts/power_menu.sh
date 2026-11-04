#!/usr/bin/env bash

# Power and User Control Menu using Rofi
# Designed for Antigravity Waybar theme

USER_NAME=$(whoami)

# Load menu definition (JSON) and generate options list
MENU_FILE="$HOME/.config/hypr/menus/power.json"
if [[ ! -f "$MENU_FILE" ]]; then
  echo "Power menu definition not found at $MENU_FILE" >&2
  exit 1
fi
if ! command -v jq &>/dev/null; then
  echo "jq is required for dynamic power menu" >&2
  exit 1
fi
# Build options string: "<icon> <label>"
options=$(jq -r '.[] | "\(.icon) \(.label)"' "$MENU_FILE")

# Show menu — glassmorphic power card (fallback to simple theme)
POWER_THEME="$HOME/.config/rofi/glassmorphism-power.rasi"
[ ! -f "$POWER_THEME" ] && POWER_THEME="$HOME/.config/rofi/floating-menu.rasi"

selection=$(echo -e "$options" | rofi -dmenu -i \
  -p "" \
  -mesg "  $USER_NAME" \
  -theme "$POWER_THEME")

# If nothing selected, exit quietly
[[ -z "$selection" ]] && exit 0

# Extract label (everything after first space)
label=$(echo "$selection" | cut -d' ' -f2-)
# Retrieve command for selected label from JSON
cmd=$(jq -r --arg lbl "$label" '.[] | select(.label == $lbl) | .command' "$MENU_FILE")
if [[ -n "$cmd" ]]; then
  eval "$cmd"
fi
