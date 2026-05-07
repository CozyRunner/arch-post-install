#!/usr/bin/env bash
# theme-toggle.sh — Switch Rofi colors between Catppuccin Latte (light) and Mocha (dark)
# Usage: ./theme-toggle.sh [light|dark|auto]

ROFI_DIR="$HOME/.config/rofi"
COLORS_LINK="$ROFI_DIR/colors.rasi"

set_theme() {
    local target="$1"
    local link_target

    case "$target" in
        light) link_target="colors-light.rasi" ;;
        dark)  link_target="colors-dark.rasi" ;;
        *)     echo "Usage: $0 [light|dark|auto]"; exit 1 ;;
    esac

    # Remove existing symlink/file
    rm -f "$COLORS_LINK"
    ln -s "$link_target" "$COLORS_LINK"
    echo "Rofi theme set to: $target ($link_target)"
}

detect_theme() {
    # Try GNOME
    if command -v gsettings &>/dev/null; then
        local scheme
        scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
        if echo "$scheme" | grep -q "prefer-dark"; then
            echo "dark"
            return
        elif echo "$scheme" | grep -q "prefer-light"; then
            echo "light"
            return
        fi
    fi

    # Try KDE
    if command -v kreadconfig5 &>/dev/null; then
        local scheme
        scheme=$(kreadconfig5 --group Colors:View --key BackgroundNormal 2>/dev/null)
        # KDE doesn't expose a direct light/dark toggle via this key, fallback
    fi

    # Try hyprland/sway environment
    if [ -n "$GTK_THEME" ]; then
        if echo "$GTK_THEME" | grep -qi "dark"; then
            echo "dark"
            return
        elif echo "$GTK_THEME" | grep -qi "light"; then
            echo "light"
            return
        fi
    fi

    # Fallback: check if dark cursor theme is set
    if [ -f "$HOME/.Xresources" ] && grep -q "Xcursor.theme" "$HOME/.Xresources"; then
        echo "dark"
        return
    fi

    # Default to dark
    echo "dark"
}

# Main
case "${1:-auto}" in
    light|dark)
        set_theme "$1"
        ;;
    auto)
        detected=$(detect_theme)
        set_theme "$detected"
        ;;
    *)
        echo "Usage: $0 [light|dark|auto]"
        exit 1
        ;;
esac
