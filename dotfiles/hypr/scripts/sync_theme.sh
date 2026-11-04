#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║               Global Theme Sync                             ║
# ║   Re-synchronize all UI components to the active theme      ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   sync_theme.sh              # sync everything to cached state
#   sync_theme.sh --status     # print current theme state
#   sync_theme.sh --validate   # check all color files exist
#   sync_theme.sh --component swaync   # sync only one component
#
# This script does NOT toggle. It reads ~/.cache/theme_mode and
# ~/.cache/theme_scheme, then ensures every component's colors.css
# (or equivalent) points to the correct scheme+mode file.
#
# Components synced:
#   swaync, waybar, rofi, kitty, alacritty, hyprland, hyprlock

set -euo pipefail

# ── Config paths ──────────────────────────────────────────────
SWAYNC_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync"
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
ALACRITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
THEME_PRESETS="$HYPR_DIR/themes/presets"

# ── State ─────────────────────────────────────────────────────
MODE=$(cat "$HOME/.cache/theme_mode" 2>/dev/null || echo "dark")
SCHEME=$(cat "$HOME/.cache/theme_scheme" 2>/dev/null || echo "glassmorphism")

# ── Helpers ───────────────────────────────────────────────────

# Try scheme-specific file first, then generic mode fallback
# Usage: resolve_file <dir> <prefix> <ext>
#   e.g. resolve_file "$SWAYNC_DIR" "colors" "css"
#   tries: colors-glassmorphism-dark.css → colors-dark.css
resolve_file() {
    local dir="$1" prefix="$2" ext="$3"
    if [[ -f "$dir/${prefix}-${SCHEME}-${MODE}.${ext}" ]]; then
        echo "${prefix}-${SCHEME}-${MODE}.${ext}"
    elif [[ -f "$dir/${prefix}-${MODE}.${ext}" ]]; then
        echo "${prefix}-${MODE}.${ext}"
    else
        echo ""
    fi
}

# Symlink a color file into place
# Usage: sync_symlink <dir> <source_basename> <target_basename>
sync_symlink() {
    local dir="$1" src="$2" target="$3"
    if [[ -n "$src" && -f "$dir/$src" ]]; then
        (cd "$dir" && ln -sf "$src" "$target")
        echo "  ✓ $target → $src"
    else
        echo "  ✗ $target — no matching file found"
    fi
}

# Copy a color file into place
# Usage: sync_copy <dir> <source_basename> <target_basename>
sync_copy() {
    local dir="$1" src="$2" target="$3"
    if [[ -n "$src" && -f "$dir/$src" ]]; then
        cp "$dir/$src" "$dir/$target"
        echo "  ✓ $target ← $src"
    else
        echo "  ✗ $target — no matching file found"
    fi
}

# ── Component sync functions ─────────────────────────────────

sync_swaync() {
    echo "SwayNC:"
    local src
    src=$(resolve_file "$SWAYNC_DIR" "colors" "css")
    sync_symlink "$SWAYNC_DIR" "$src" "colors.css"
    if pgrep -x swaync >/dev/null 2>&1; then
        swaync-client -rs 2>/dev/null || swaync-client -R 2>/dev/null || true
    fi
}

sync_waybar() {
    echo "Waybar:"
    local src
    src=$(resolve_file "$WAYBAR_DIR" "colors" "css")
    sync_copy "$WAYBAR_DIR" "$src" "colors.css"
    pkill -SIGUSR2 waybar 2>/dev/null || true
}

sync_rofi() {
    echo "Rofi:"
    local src
    src=$(resolve_file "$ROFI_DIR" "colors" "rasi")
    sync_symlink "$ROFI_DIR" "$src" "colors.rasi"
}

sync_kitty() {
    echo "Kitty:"
    local src
    if [[ -f "$KITTY_DIR/${SCHEME}-${MODE}.conf" ]]; then
        src="${SCHEME}-${MODE}.conf"
    elif [[ -f "$KITTY_DIR/${MODE}-theme.conf" ]]; then
        src="${MODE}-theme.conf"
    else
        src=""
    fi
    sync_copy "$KITTY_DIR" "$src" "theme.conf"
    pkill -SIGUSR2 kitty 2>/dev/null || true
}

sync_alacritty() {
    echo "Alacritty:"
    local src
    if [[ -f "$ALACRITTY_DIR/themes/${SCHEME}-${MODE}.toml" ]]; then
        src="themes/${SCHEME}-${MODE}.toml"
    elif [[ -f "$ALACRITTY_DIR/themes/${MODE}.toml" ]]; then
        src="themes/${MODE}.toml"
    else
        src=""
    fi
    if [[ -n "$src" && -f "$ALACRITTY_DIR/$src" ]]; then
        cp "$ALACRITTY_DIR/$src" "$ALACRITTY_DIR/theme.toml"
        echo "  ✓ theme.toml ← $src"
        touch "$ALACRITTY_DIR/alacritty.toml" 2>/dev/null || true
    else
        echo "  ✗ theme.toml — no matching file found"
    fi
}

sync_hyprland() {
    echo "Hyprland:"
    local src
    if [[ -f "$THEME_PRESETS/${SCHEME}-${MODE}.lua" ]]; then
        src="${SCHEME}-${MODE}.lua"
    elif [[ -f "$THEME_PRESETS/${MODE}.lua" ]]; then
        src="${MODE}.lua"
    else
        src=""
    fi
    if [[ -n "$src" ]]; then
        cp "$THEME_PRESETS/$src" "$HYPR_DIR/theme.lua"
        echo "  ✓ theme.lua ← presets/$src"
    else
        echo "  ✗ theme.lua — no matching preset found"
    fi
    hyprctl reload 2>/dev/null || true
}

sync_hyprlock() {
    echo "Hyprlock:"
    if [[ -f "$HYPR_DIR/hyprlock-colors-${MODE}.conf" ]]; then
        cp "$HYPR_DIR/hyprlock-colors-${MODE}.conf" "$HYPR_DIR/hyprlock-colors.conf"
        echo "  ✓ hyprlock-colors.conf ← hyprlock-colors-${MODE}.conf"
    else
        echo "  ✗ hyprlock-colors.conf — no matching file found"
    fi
}

# ── Validate: check that all color files exist for current scheme ──
do_validate() {
    echo "Validating color files for scheme=${SCHEME} mode=${MODE}:"
    local errors=0

    local components=(
        "$SWAYNC_DIR:colors:css"
        "$WAYBAR_DIR:colors:css"
        "$ROFI_DIR:colors:rasi"
    )

    for entry in "${components[@]}"; do
        IFS=':' read -r dir prefix ext <<< "$entry"
        local name
        name=$(basename "$dir")
        local src
        src=$(resolve_file "$dir" "$prefix" "$ext")
        if [[ -n "$src" ]]; then
            echo "  ✓ $name: $src"
        else
            echo "  ✗ $name: MISSING ${prefix}-${SCHEME}-${MODE}.${ext} (and no fallback)"
            ((errors++)) || true
        fi
    done

    if [[ $errors -eq 0 ]]; then
        echo "All color files present."
    else
        echo "$errors missing file(s)."
        return 1
    fi
}

# ── Status ────────────────────────────────────────────────────
do_status() {
    echo "Current theme state:"
    echo "  Scheme : $SCHEME"
    echo "  Mode   : $MODE"
    echo ""
    echo "State files:"
    echo "  ~/.cache/theme_mode   = $(cat "$HOME/.cache/theme_mode" 2>/dev/null || echo '(not set)')"
    echo "  ~/.cache/theme_scheme = $(cat "$HOME/.cache/theme_scheme" 2>/dev/null || echo '(not set)')"
    echo ""

    # Show what each component currently points to
    echo "Active color files:"
    for dir in "$SWAYNC_DIR" "$WAYBAR_DIR" "$ROFI_DIR"; do
        local name
        name=$(basename "$dir")
        local target_file=""
        if [[ "$name" == "rofi" ]]; then
            target_file="colors.rasi"
        else
            target_file="colors.css"
        fi
        if [[ -L "$dir/$target_file" ]]; then
            echo "  $name: $target_file → $(readlink "$dir/$target_file")"
        elif [[ -f "$dir/$target_file" ]]; then
            echo "  $name: $target_file (regular file)"
        else
            echo "  $name: $target_file (not found)"
        fi
    done
}

# ── All components ────────────────────────────────────────────
sync_all() {
    echo "Syncing all components to: ${SCHEME} (${MODE})"
    echo "────────────────────────────────────────────"
    sync_swaync
    sync_waybar
    sync_rofi
    sync_kitty
    sync_alacritty
    sync_hyprland
    sync_hyprlock
    echo "────────────────────────────────────────────"
    echo "✓ Theme sync complete"
}

# ── Main ──────────────────────────────────────────────────────
COMPONENT=""
case "${1:-}" in
    --status)
        do_status
        exit 0
        ;;
    --validate)
        do_validate
        exit $?
        ;;
    --component)
        COMPONENT="${2:-}"
        if [[ -z "$COMPONENT" ]]; then
            echo "Usage: $(basename "$0") --component <name>" >&2
            exit 1
        fi
        echo "Syncing $COMPONENT to: ${SCHEME} (${MODE})"
        echo "────────────────────────────────────────────"
        case "$COMPONENT" in
            swaync)     sync_swaync ;;
            waybar)     sync_waybar ;;
            rofi)       sync_rofi ;;
            kitty)      sync_kitty ;;
            alacritty)  sync_alacritty ;;
            hyprland)   sync_hyprland ;;
            hyprlock)   sync_hyprlock ;;
            *)
                echo "Unknown component: $COMPONENT" >&2
                echo "Available: swaync, waybar, rofi, kitty, alacritty, hyprland, hyprlock" >&2
                exit 1
                ;;
        esac
        echo "────────────────────────────────────────────"
        echo "✓ Done"
        ;;
    ""|--all)
        sync_all
        ;;
    *)
        echo "Usage: $(basename "$0") [--status|--validate|--component <name>|--all]" >&2
        exit 1
        ;;
esac

