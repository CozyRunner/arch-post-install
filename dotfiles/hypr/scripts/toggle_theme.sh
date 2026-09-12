#!/usr/bin/env bash
# ============================================================
# toggle_theme.sh — Glassmorphism "Lumina" Theme Switcher
# Usage:
#   toggle_theme.sh [light|dark|auto] [scheme]
#
# Scheme examples: glassmorphism catppuccin everforest gruvbox
#                  nord rose-pine tokyonight
#
# Examples:
#   toggle_theme.sh dark glassmorphism     ← Lumina Dark
#   toggle_theme.sh light glassmorphism    ← Lumina Light
#   toggle_theme.sh dark catppuccin        ← Original presets
#   toggle_theme.sh                        ← Auto-detect + last scheme
# ============================================================

# ── Config paths ─────────────────────────────────────────────
THEME_DIR="$HOME/.config/hypr/themes/presets"
HYPR_THEME="$HOME/.config/hypr/theme.lua"
HYPR_THEME_CONF="$HOME/.config/hypr/theme.conf"
HYPRLOCK_DIR="$HOME/.config/hypr"
WAYBAR_CONFIG="$HOME/.config/waybar"
KITTY_CONFIG="$HOME/.config/kitty"
ROFI_CONFIG="$HOME/.config/rofi"
ALACRITTY_CONFIG="$HOME/.config/alacritty"
SWAYNC_CONFIG="$HOME/.config/swaync"
GTK3_CONFIG="$HOME/.config/gtk-3.0"
KVANTUM_CONFIG="$HOME/.config/Kvantum"
FISH_CONFIG="$HOME/.config/fish"
ZELLIJ_CONFIG="$HOME/.config/zellij"
SUPERFILE_CONFIG="$HOME/.config/superfile"
OHMYPOSH_CONFIG="$HOME/.config/ohmyposh"
THEME_STATE="$HOME/.cache/theme_mode"
SCHEME_STATE="$HOME/.cache/theme_scheme"

# ── Read state ────────────────────────────────────────────────
SCHEME=$(cat "$SCHEME_STATE" 2>/dev/null || echo "glassmorphism")
CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")

if [ "$CURRENT_SCHEME" == "'prefer-dark'" ]; then
  TARGET_MODE="light"
else
  TARGET_MODE="dark"
fi

# Override via arguments
if [ "${1:-}" == "light" ] || [ "${1:-}" == "dark" ]; then
  TARGET_MODE="$1"
fi

if [ -n "${2:-}" ]; then
  SCHEME="$2"
  echo "$SCHEME" > "$SCHEME_STATE"
fi

echo "🎨 Activating: ${SCHEME^} (${TARGET_MODE} mode)…"
echo "$TARGET_MODE" > "$THEME_STATE"

# ────────────────────────────────────────────────────────────
# ──  LIGHT MODE  ──────────────────────────────────────────
# ────────────────────────────────────────────────────────────
if [ "$TARGET_MODE" == "light" ]; then

  # GTK color scheme
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
  gsettings set org.gnome.desktop.interface cursor-size 24

  # ── Hyprland Lua theme ──
  if [ -f "$THEME_DIR/${SCHEME}-light.lua" ]; then
    cp "$THEME_DIR/${SCHEME}-light.lua" "$HYPR_THEME"
  elif [ -f "$THEME_DIR/light.lua" ]; then
    cp "$THEME_DIR/light.lua" "$HYPR_THEME"
  fi

  # Legacy .conf theme (if used)
  if [ -f "$THEME_DIR/${SCHEME}-light.conf" ]; then
    cp "$THEME_DIR/${SCHEME}-light.conf" "$HYPR_THEME_CONF"
  elif [ -f "$THEME_DIR/light.conf" ]; then
    cp "$THEME_DIR/light.conf" "$HYPR_THEME_CONF"
  fi

  # ── Waybar colors ──
  if [ -f "$WAYBAR_CONFIG/colors-${SCHEME}-light.css" ]; then
    cp "$WAYBAR_CONFIG/colors-${SCHEME}-light.css" "$WAYBAR_CONFIG/colors.css"
  elif [ -f "$WAYBAR_CONFIG/colors-light.css" ]; then
    cp "$WAYBAR_CONFIG/colors-light.css" "$WAYBAR_CONFIG/colors.css"
  fi
  pkill -SIGUSR2 waybar 2>/dev/null || true

  # ── Kitty colors ──
  if [ -f "$KITTY_CONFIG/${SCHEME}-light.conf" ]; then
    cp "$KITTY_CONFIG/${SCHEME}-light.conf" "$KITTY_CONFIG/theme.conf"
  elif [ -f "$KITTY_CONFIG/light-theme.conf" ]; then
    cp "$KITTY_CONFIG/light-theme.conf" "$KITTY_CONFIG/theme.conf"
  fi
  pkill -SIGUSR2 kitty 2>/dev/null || true

  # ── Rofi colors ──
  if [ -f "$ROFI_CONFIG/colors-${SCHEME}-light.rasi" ]; then
    ln -sf "$ROFI_CONFIG/colors-${SCHEME}-light.rasi" "$ROFI_CONFIG/colors.rasi"
  elif [ -f "$ROFI_CONFIG/colors-light.rasi" ]; then
    ln -sf "$ROFI_CONFIG/colors-light.rasi" "$ROFI_CONFIG/colors.rasi"
  fi

  # ── Alacritty colors ──
  if [ -f "$ALACRITTY_CONFIG/themes/${SCHEME}-light.toml" ]; then
    cp "$ALACRITTY_CONFIG/themes/${SCHEME}-light.toml" "$ALACRITTY_CONFIG/theme.toml"
  elif [ -f "$ALACRITTY_CONFIG/themes/light.toml" ]; then
    cp "$ALACRITTY_CONFIG/themes/light.toml" "$ALACRITTY_CONFIG/theme.toml"
  fi
  sleep 0.1
  touch "$ALACRITTY_CONFIG/alacritty.toml" 2>/dev/null || true

  # ── SwayNC style ── [NEW]
  if [ -f "$SWAYNC_CONFIG/style-light.css" ]; then
    cp "$SWAYNC_CONFIG/style-light.css" "$SWAYNC_CONFIG/style.css"
    swaync-client -rs 2>/dev/null || true
  fi

  # ── Hyprlock colors ── [NEW]
  if [ -f "$HYPRLOCK_DIR/hyprlock-colors-light.conf" ]; then
    cp "$HYPRLOCK_DIR/hyprlock-colors-light.conf" "$HYPRLOCK_DIR/hyprlock-colors.conf"
  fi

  # ── GTK3 headerbar patch ── [NEW]
  if [ -f "$HOME/.config/hypr/dotfiles-extra/gtk-3.0/gtk-light.css" ]; then
    cp "$HOME/.config/hypr/dotfiles-extra/gtk-3.0/gtk-light.css" "$GTK3_CONFIG/gtk.css"
  elif [ -f "$HOME/.local/share/arch-install/dotfiles/gtk/gtk-3.0/gtk-light.css" ]; then
    cp "$HOME/.local/share/arch-install/dotfiles/gtk/gtk-3.0/gtk-light.css" "$GTK3_CONFIG/gtk.css"
  fi

  # ── Kvantum Qt theme ── [NEW]
  if command -v kvantummanager &>/dev/null; then
    kvantummanager --set GlassmorphismLight 2>/dev/null || true
  fi

  # ── Superfile ──
  sed -i "s/^theme = \".*\"/theme = \"${SCHEME}-latte\"/" "$SUPERFILE_CONFIG/config.toml" 2>/dev/null || true

  # ── Wallpaper ──
  if [ -f "$HOME/.config/hypr/assets/${SCHEME}-light.jpg" ]; then
    hyprctl hyprpaper preload  "$HOME/.config/hypr/assets/${SCHEME}-light.jpg" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/${SCHEME}-light.jpg" 2>/dev/null || true
  elif [ -f "$HOME/.config/hypr/assets/${SCHEME}-light.png" ]; then
    hyprctl hyprpaper preload  "$HOME/.config/hypr/assets/${SCHEME}-light.png" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/${SCHEME}-light.png" 2>/dev/null || true
  else
    hyprctl hyprpaper preload  "$HOME/.config/hypr/assets/Arch-Light.png" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Light.png" 2>/dev/null || true
  fi

  # Reload Hyprland config
  hyprctl reload 2>/dev/null || true

  notify-send "🌅 Theme Activated" \
    "Scheme: ${SCHEME^} · Light Mode" \
    -i weather-clear-symbolic \
    -u low -t 3000

# ────────────────────────────────────────────────────────────
# ──  DARK MODE  ───────────────────────────────────────────
# ────────────────────────────────────────────────────────────
else

  # GTK color scheme
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
  gsettings set org.gnome.desktop.interface cursor-size 24

  # ── Hyprland Lua theme ──
  if [ -f "$THEME_DIR/${SCHEME}-dark.lua" ]; then
    cp "$THEME_DIR/${SCHEME}-dark.lua" "$HYPR_THEME"
  elif [ -f "$THEME_DIR/dark.lua" ]; then
    cp "$THEME_DIR/dark.lua" "$HYPR_THEME"
  fi

  if [ -f "$THEME_DIR/${SCHEME}-dark.conf" ]; then
    cp "$THEME_DIR/${SCHEME}-dark.conf" "$HYPR_THEME_CONF"
  elif [ -f "$THEME_DIR/dark.conf" ]; then
    cp "$THEME_DIR/dark.conf" "$HYPR_THEME_CONF"
  fi

  # ── Waybar colors ──
  if [ -f "$WAYBAR_CONFIG/colors-${SCHEME}-dark.css" ]; then
    cp "$WAYBAR_CONFIG/colors-${SCHEME}-dark.css" "$WAYBAR_CONFIG/colors.css"
  elif [ -f "$WAYBAR_CONFIG/colors-dark.css" ]; then
    cp "$WAYBAR_CONFIG/colors-dark.css" "$WAYBAR_CONFIG/colors.css"
  fi
  pkill -SIGUSR2 waybar 2>/dev/null || true

  # ── Kitty colors ──
  if [ -f "$KITTY_CONFIG/${SCHEME}-dark.conf" ]; then
    cp "$KITTY_CONFIG/${SCHEME}-dark.conf" "$KITTY_CONFIG/theme.conf"
  elif [ -f "$KITTY_CONFIG/dark-theme.conf" ]; then
    cp "$KITTY_CONFIG/dark-theme.conf" "$KITTY_CONFIG/theme.conf"
  fi
  pkill -SIGUSR2 kitty 2>/dev/null || true

  # ── Rofi colors ──
  if [ -f "$ROFI_CONFIG/colors-${SCHEME}-dark.rasi" ]; then
    ln -sf "$ROFI_CONFIG/colors-${SCHEME}-dark.rasi" "$ROFI_CONFIG/colors.rasi"
  elif [ -f "$ROFI_CONFIG/colors-dark.rasi" ]; then
    ln -sf "$ROFI_CONFIG/colors-dark.rasi" "$ROFI_CONFIG/colors.rasi"
  fi

  # ── Alacritty colors ──
  if [ -f "$ALACRITTY_CONFIG/themes/${SCHEME}-dark.toml" ]; then
    cp "$ALACRITTY_CONFIG/themes/${SCHEME}-dark.toml" "$ALACRITTY_CONFIG/theme.toml"
  elif [ -f "$ALACRITTY_CONFIG/themes/dark.toml" ]; then
    cp "$ALACRITTY_CONFIG/themes/dark.toml" "$ALACRITTY_CONFIG/theme.toml"
  fi
  sleep 0.1
  touch "$ALACRITTY_CONFIG/alacritty.toml" 2>/dev/null || true

  # ── SwayNC style ── [NEW]
  if [ -f "$SWAYNC_CONFIG/style-dark.css" ]; then
    cp "$SWAYNC_CONFIG/style-dark.css" "$SWAYNC_CONFIG/style.css"
    swaync-client -rs 2>/dev/null || true
  fi

  # ── Hyprlock colors ── [NEW]
  if [ -f "$HYPRLOCK_DIR/hyprlock-colors-dark.conf" ]; then
    cp "$HYPRLOCK_DIR/hyprlock-colors-dark.conf" "$HYPRLOCK_DIR/hyprlock-colors.conf"
  fi

  # ── GTK3 headerbar patch ── [NEW]
  if [ -f "$HOME/.config/hypr/dotfiles-extra/gtk-3.0/gtk-dark.css" ]; then
    cp "$HOME/.config/hypr/dotfiles-extra/gtk-3.0/gtk-dark.css" "$GTK3_CONFIG/gtk.css"
  elif [ -f "$HOME/.local/share/arch-install/dotfiles/gtk/gtk-3.0/gtk-dark.css" ]; then
    cp "$HOME/.local/share/arch-install/dotfiles/gtk/gtk-3.0/gtk-dark.css" "$GTK3_CONFIG/gtk.css"
  fi

  # ── Kvantum Qt theme ── [NEW]
  if command -v kvantummanager &>/dev/null; then
    kvantummanager --set GlassmorphismDark 2>/dev/null || true
  fi

  # ── Superfile ──
  sed -i "s/^theme = \".*\"/theme = \"${SCHEME}\"/" "$SUPERFILE_CONFIG/config.toml" 2>/dev/null || true

  # ── Wallpaper ──
  if [ -f "$HOME/.config/hypr/assets/${SCHEME}-dark.jpg" ]; then
    hyprctl hyprpaper preload  "$HOME/.config/hypr/assets/${SCHEME}-dark.jpg" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/${SCHEME}-dark.jpg" 2>/dev/null || true
  elif [ -f "$HOME/.config/hypr/assets/${SCHEME}-dark.png" ]; then
    hyprctl hyprpaper preload  "$HOME/.config/hypr/assets/${SCHEME}-dark.png" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/${SCHEME}-dark.png" 2>/dev/null || true
  else
    hyprctl hyprpaper preload  "$HOME/.config/hypr/assets/Arch-Dark.png" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Dark.png" 2>/dev/null || true
  fi

  # Reload Hyprland config
  hyprctl reload 2>/dev/null || true

  notify-send "🌙 Theme Activated" \
    "Scheme: ${SCHEME^} · Dark Mode" \
    -i weather-clear-night-symbolic \
    -u low -t 3000

fi

echo "✓ Theme switch complete: ${SCHEME} (${TARGET_MODE})"
