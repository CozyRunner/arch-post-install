#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║         Generate User Keybindings                           ║
# ║   Reads config/user.yaml and emits a Lua keybinding file    ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   generate_user_bindings.sh                # generate from user.yaml
#   generate_user_bindings.sh --dry-run      # print to stdout only
#
# Reads keybinding overrides from config/user.yaml and generates
# ~/.config/hypr/config/keybinds/user_overrides.lua
#
# This script requires yq (the Go version).

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd)}"
USER_CONFIG="${USER_CONFIG:-$REPO_ROOT/config/user.yaml}"
OUTPUT_DIR="$HOME/.config/hypr/config/keybinds"
OUTPUT_FILE="$OUTPUT_DIR/user_overrides.lua"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ── Check dependencies ────────────────────────────────────────
if ! command -v yq &>/dev/null; then
    echo "Error: yq is required but not installed." >&2
    echo "Install with: pacman -S yq" >&2
    exit 4
fi

if [[ ! -f "$USER_CONFIG" ]]; then
    echo "No user config found at $USER_CONFIG — using defaults." >&2
    exit 0
fi

# ── Read keybindings ──────────────────────────────────────────
# Map action → script command
declare -A ACTION_CMDS=(
    [logout]="$HOME/.config/hypr/scripts/session.sh logout"
    [lock]="$HOME/.config/hypr/scripts/session.sh lock"
    [power_menu]="$HOME/.config/hypr/scripts/power_menu.sh"
    [package_manager]="$HOME/.config/hypr/scripts/spm.sh"
    [tui_menu]="$HOME/.config/hypr/scripts/tui_app.sh menu"
    [ocr_area]="$HOME/.config/hypr/scripts/ocr_extract.sh area"
    [ocr_screen]="$HOME/.config/hypr/scripts/ocr_extract.sh screen"
)

# Parse key combos from YAML — yq outputs null for missing keys
read_binding() {
    local key="$1"
    local val
    val=$(yq -r ".keybindings.${key} // empty" "$USER_CONFIG" 2>/dev/null)
    echo "$val"
}

# Convert user-friendly key string to Lua format
# e.g. "SUPER + SHIFT + Q" → mainMod .. " + SHIFT + Q"  (with mainMod = SUPER)
# We keep it simple: pass through as-is since utilities.lua uses literal strings
format_binding() {
    local combo="$1"
    # Normalize spacing
    combo=$(echo "$combo" | sed 's/\s*+\s*/ + /g' | sed 's/^\s*//;s/\s*$//')
    # Replace leading SUPER with mainMod concatenation
    if [[ "$combo" == SUPER* ]]; then
        local rest="${combo#SUPER}"
        rest="${rest# }"       # trim leading space
        rest="${rest#+ }"      # trim leading "+ "
        if [[ -z "$rest" ]]; then
            echo 'mainMod'
        else
            echo "mainMod .. \" + ${rest}\""
        fi
    else
        echo "\"${combo}\""
    fi
}

# ── Generate Lua ──────────────────────────────────────────────
generate_lua() {
    cat <<'LUA'
-- ══════════════════════════════════════════════════════════════
-- User Override Keybindings (auto-generated)
-- Source: config/user.yaml
-- Regenerate with: ~/.config/hypr/scripts/generate_user_bindings.sh
-- ══════════════════════════════════════════════════════════════

local mainMod = "SUPER"

LUA

    local any_binding=false
    for action in "${!ACTION_CMDS[@]}"; do
        local combo
        combo=$(read_binding "$action")
        if [[ -n "$combo" ]]; then
            local lua_key
            lua_key=$(format_binding "$combo")
            local cmd="${ACTION_CMDS[$action]}"
            echo "hl.bind(${lua_key}, hl.dsp.exec_cmd('${cmd}'))"
            any_binding=true
        fi
    done

    if [[ "$any_binding" == "false" ]]; then
        echo "-- No user keybinding overrides defined"
    fi
}

# ── Output ────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
    echo "-- DRY RUN: would write to $OUTPUT_FILE"
    echo ""
    generate_lua
else
    mkdir -p "$OUTPUT_DIR"
    generate_lua > "$OUTPUT_FILE"
    echo "✓ User keybindings written to $OUTPUT_FILE"
fi

