#!/usr/bin/env bash
# ╔══════════════════════════════════════╗
# ║        Theme Scheme Picker           ║
# ║  Select & Apply Desktop Color Scheme ║
# ╚══════════════════════════════════════╝

set -euo pipefail

SCRIPTS_DIR="$HOME/.config/hypr/scripts"
ROFI_CONFIG="$HOME/.config/rofi"

options=" Catppuccin — Soothing pastel aesthetic
 Tokyo Night — Neon synthwave aesthetic
 Gruvbox — Retro warm earthy aesthetic
 Everforest — Soft natural green aesthetic
 Nord / Snow — Cool arctic ice aesthetic
 Rosé Pine — Dreamy pastel pink & lavender"

selection=$(echo -e "$options" | rofi -dmenu -i \
  -p "󰸉  Theme Schemes" \
  -theme "$ROFI_CONFIG/theme-picker.rasi")

case "$selection" in
  *"Catppuccin"*)
    scheme="catppuccin"
    ;;
  *"Tokyo Night"*)
    scheme="tokyonight"
    ;;
  *"Gruvbox"*)
    scheme="gruvbox"
    ;;
  *"Everforest"*)
    scheme="everforest"
    ;;
  *"Nord"*)
    scheme="nord"
    ;;
  *"Rosé Pine"*)
    scheme="rose-pine"
    ;;
  *)
    exit 0
    ;;
esac

# Ask mode: Dark or Light
mode_options="🌑 Dark Variant
☀️ Light Variant"

mode_selection=$(echo -e "$mode_options" | rofi -dmenu -i \
  -p "🎨 Select Variant" \
  -theme "$ROFI_CONFIG/floating-menu.rasi")

case "$mode_selection" in
  *"Dark"*)
    mode="dark"
    ;;
  *"Light"*)
    mode="light"
    ;;
  *)
    # Fallback to current mode
    CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")
    if [ "$CURRENT_SCHEME" == "'prefer-dark'" ]; then
      mode="dark"
    else
      mode="light"
    fi
    ;;
esac

bash "$SCRIPTS_DIR/toggle_theme.sh" "$mode" "$scheme"
