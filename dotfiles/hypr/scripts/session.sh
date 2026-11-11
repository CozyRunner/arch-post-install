#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║              Unified Session Manager                        ║
# ║   Central entry point for all power & session actions       ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   session.sh {logout|lock|suspend|reboot|poweroff|keep-awake}
#
# All keybindings, menus, and scripts delegate here so that the
# actual command for each action lives in exactly one place.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
        AWAKE_SCRIPT="${SCRIPT_DIR}/keep_awake.sh"
        if [[ -x "$AWAKE_SCRIPT" ]] && "$AWAKE_SCRIPT" is-active 2>/dev/null; then
            if command -v notify-send &>/dev/null; then
                notify-send "Suspend Blocked" "System sleep is inhibited by Keep Awake.\nDisable Keep Awake first to allow sleep." -i dialog-warning -u normal 2>/dev/null || true
            fi
            echo "Warning: System sleep is currently inhibited by Keep Awake." >&2
            exit 1
        fi
        systemctl suspend
        ;;
    reboot)
        systemctl reboot
        ;;
    poweroff)
        systemctl poweroff
        ;;
    keep-awake|awake)
        shift || true
        "${SCRIPT_DIR}/keep_awake.sh" "$@"
        ;;
    *)
        echo "Usage: $(basename "$0") {logout|lock|suspend|reboot|poweroff|keep-awake}" >&2
        exit 1
        ;;
esac

