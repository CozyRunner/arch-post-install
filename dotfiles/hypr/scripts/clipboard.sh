#!/usr/bin/env bash

# Clipse Clipboard Manager Launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_CLIPBOARD="${HOME}/.config/waybar/scripts/clipboard.sh"

if [[ -x "${WAYBAR_CLIPBOARD}" ]]; then
    exec "${WAYBAR_CLIPBOARD}" "${@}"
else
    # Fallback to repository path if not yet deployed to home
    REPO_CLIPBOARD="$(dirname "${SCRIPT_DIR}")/../waybar/scripts/clipboard.sh"
    if [[ -x "${REPO_CLIPBOARD}" ]]; then
        exec "${REPO_CLIPBOARD}" "${@}"
    fi
fi

# Standalone fallback if waybar script is unavailable
CLIPSE_CMD="$(command -v clipse || echo "/usr/bin/clipse")"
if hyprctl clients 2>/dev/null | grep -q "class: clipse"; then
    hyprctl dispatch focuswindow "class:clipse"
else
    exec kitty --class clipse -e "$CLIPSE_CMD"
fi
