#!/usr/bin/env bash

# Waybar Power and User Control Menu using Rofi
# Dynamically generated from JSON definition

USER_NAME=$(whoami)

# Load menu definition (JSON) and build options list
MENU_FILE="$HOME/.config/hypr/menus/power.json"
if [[ ! -f "$MENU_FILE" ]]; then
  echo "Power menu definition not found at $MENU_FILE" >&2
  exit 1
fi
if ! command -v jq &>/dev/null; then
  echo "jq is required for dynamic power menu" >&2
  exit 1
fi
options=$(jq -r '.[] | "\(.icon) \(.label)"' "$MENU_FILE")

# Show menu using rofi (fallback to existing theme)
POWER_THEME="$HOME/.config/rofi/floating-menu.rasi"
selection=$(echo -e "$options" | rofi -dmenu -i \
  -p "" \
  -mesg "  $USER_NAME" \
  -theme "$POWER_THEME")

# If nothing selected, exit
[[ -z "$selection" ]] && exit 0

# Extract label and execute associated command
label=$(echo "$selection" | cut -d' ' -f2-)
cmd=$(jq -r --arg lbl "$label" '.[] | select(.label == $lbl) | .command' "$MENU_FILE")
if [[ -n "$cmd" ]]; then
  eval "$cmd"
fi
