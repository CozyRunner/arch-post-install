#!/usr/bin/env bash
# ╔══════════════════════════════════════╗
# ║           Settings Menu              ║
# ║      Edit Hyprland Configurations    ║
# ╚══════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPTS_DIR:-$HOME/.config/hypr/scripts}"
[[ ! -d "$SCRIPTS_DIR" ]] && SCRIPTS_DIR="$SCRIPT_DIR"

# Delegate directly to the configuration submenu of the control center
exec bash "$SCRIPTS_DIR/floating_menu.sh" config
