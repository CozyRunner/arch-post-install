#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║              Unified Session Manager                        ║
# ║   Central entry point for all power & session actions       ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   session.sh {logout|lock|suspend|reboot|poweroff}
#
# All keybindings, menus, and scripts delegate here so that the
# actual command for each action lives in exactly one place.

set -euo pipefail

ACTION="${1:-}"

case "$ACTION" in
    logout)
        loginctl terminate-user "$USER"
        ;;
    lock)
        if command -v hyprlock &>/dev/null; then
            hyprlock
        elif command -v swaylock &>/dev/null; then
            swaylock
        else
            echo "No screen locker found (install hyprlock or swaylock)" >&2
            exit 1
        fi
        ;;
    suspend)
        systemctl suspend
        ;;
    reboot)
        systemctl reboot
        ;;
    poweroff)
        systemctl poweroff
        ;;
    *)
        echo "Usage: $(basename "$0") {logout|lock|suspend|reboot|poweroff}" >&2
        exit 1
        ;;
esac

