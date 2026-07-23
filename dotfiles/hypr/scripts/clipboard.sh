#!/usr/bin/env bash

# Delegate to unified cliphist manager script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_CLIPHIST="${HOME}/.config/waybar/scripts/cliphist.sh"

if [[ -x "${WAYBAR_CLIPHIST}" ]]; then
    exec "${WAYBAR_CLIPHIST}" "${1:---list}"
else
    # Fallback to repository path if not yet deployed to home
    REPO_CLIPHIST="$(dirname "${SCRIPT_DIR}")/../waybar/scripts/cliphist.sh"
    if [[ -x "${REPO_CLIPHIST}" ]]; then
        exec "${REPO_CLIPHIST}" "${1:---list}"
    fi
fi
