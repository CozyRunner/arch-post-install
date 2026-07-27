#!/usr/bin/env bash

# Define paths
THEME_DIR="$HOME/.config/hypr/themes"
HYPR_THEME="$HOME/.config/hypr/theme.conf"
WAYBAR_CONFIG="$HOME/.config/waybar"
KITTY_CONFIG="$HOME/.config/kitty"
ROFI_CONFIG="$HOME/.config/rofi"
ALACRITTY_CONFIG="$HOME/.config/alacritty"
FISH_CONFIG="$HOME/.config/fish"
ZELLIJ_CONFIG="$HOME/.config/zellij"
SUPERFILE_CONFIG="$HOME/.config/superfile"
OHMYPOSH_CONFIG="$HOME/.config/ohmyposh"
THEME_STATE="$HOME/.cache/theme_mode"
SCHEME_STATE="$HOME/.cache/theme_scheme"

# Read active scheme (default: catppuccin)
SCHEME=$(cat "$SCHEME_STATE" 2>/dev/null || echo "catppuccin")

# Get current color scheme
CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")

if [ "$CURRENT_SCHEME" == "'prefer-dark'" ]; then
  TARGET_MODE="light"
else
  TARGET_MODE="dark"
fi

# Override target mode if argument passed
if [ "${1:-}" == "light" ] || [ "${1:-}" == "dark" ]; then
  TARGET_MODE="$1"
fi

if [ -n "${2:-}" ]; then
  SCHEME="$2"
  echo "$SCHEME" > "$SCHEME_STATE"
fi

echo "Setting Theme Scheme: $SCHEME ($TARGET_MODE mode)..."
echo "$TARGET_MODE" > "$THEME_STATE"

if [ "$TARGET_MODE" == "light" ]; then
  # --- LIGHT MODE ---
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'

  if command -v plasma-apply-lookandfeel >/dev/null; then
    plasma-apply-lookandfeel -a org.kde.breeze.desktop
  fi

  # Hyprland colors
  if [ -f "$THEME_DIR/${SCHEME}-light.conf" ]; then
    cp "$THEME_DIR/${SCHEME}-light.conf" "$HYPR_THEME"
  else
    cp "$THEME_DIR/light.conf" "$HYPR_THEME"
  fi

  # Waybar colors
  if [ -f "$WAYBAR_CONFIG/colors-${SCHEME}-light.css" ]; then
    cp "$WAYBAR_CONFIG/colors-${SCHEME}-light.css" "$WAYBAR_CONFIG/colors.css"
  else
    cp "$WAYBAR_CONFIG/colors-light.css" "$WAYBAR_CONFIG/colors.css"
  fi
  pkill -SIGUSR2 waybar 2>/dev/null || true

  # Kitty colors
  if [ -f "$KITTY_CONFIG/${SCHEME}-light.conf" ]; then
    cp "$KITTY_CONFIG/${SCHEME}-light.conf" "$KITTY_CONFIG/theme.conf"
  else
    cp "$KITTY_CONFIG/light-theme.conf" "$KITTY_CONFIG/theme.conf"
  fi
  pkill -SIGUSR2 kitty 2>/dev/null || true

  # Rofi colors
  if [ -f "$ROFI_CONFIG/colors-${SCHEME}-light.rasi" ]; then
    ln -sf "$ROFI_CONFIG/colors-${SCHEME}-light.rasi" "$ROFI_CONFIG/colors.rasi"
  else
    ln -sf "$ROFI_CONFIG/colors-light.rasi" "$ROFI_CONFIG/colors.rasi"
  fi

  # Alacritty colors
  if [ -f "$ALACRITTY_CONFIG/themes/${SCHEME}-light.toml" ]; then
    cp "$ALACRITTY_CONFIG/themes/${SCHEME}-light.toml" "$ALACRITTY_CONFIG/theme.toml"
  else
    cp "$ALACRITTY_CONFIG/themes/light.toml" "$ALACRITTY_CONFIG/theme.toml"
  fi
  sleep 0.1
  touch "$ALACRITTY_CONFIG/alacritty.toml" 2>/dev/null || true

  # Superfile Sync
  sed -i "s/^theme = \".*\"/theme = \"${SCHEME}-latte\"/" "$SUPERFILE_CONFIG/config.toml" 2>/dev/null || true

  # Wallpaper
  hyprctl hyprpaper preload "$HOME/.config/hypr/assets/Arch-Light.png" 2>/dev/null || true
  hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Light.png" 2>/dev/null || true

  notify-send "Theme Activated" "Scheme: ${SCHEME^} (Light Mode)" -i weather-clear-symbolic
else
  # --- DARK MODE ---
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

  if command -v plasma-apply-lookandfeel >/dev/null; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop
  fi

  # Hyprland colors
  if [ -f "$THEME_DIR/${SCHEME}-dark.conf" ]; then
    cp "$THEME_DIR/${SCHEME}-dark.conf" "$HYPR_THEME"
  else
    cp "$THEME_DIR/dark.conf" "$HYPR_THEME"
  fi

  # Waybar colors
  if [ -f "$WAYBAR_CONFIG/colors-${SCHEME}-dark.css" ]; then
    cp "$WAYBAR_CONFIG/colors-${SCHEME}-dark.css" "$WAYBAR_CONFIG/colors.css"
  else
    cp "$WAYBAR_CONFIG/colors-dark.css" "$WAYBAR_CONFIG/colors.css"
  fi
  pkill -SIGUSR2 waybar 2>/dev/null || true

  # Kitty colors
  if [ -f "$KITTY_CONFIG/${SCHEME}-dark.conf" ]; then
    cp "$KITTY_CONFIG/${SCHEME}-dark.conf" "$KITTY_CONFIG/theme.conf"
  else
    cp "$KITTY_CONFIG/dark-theme.conf" "$KITTY_CONFIG/theme.conf"
  fi
  pkill -SIGUSR2 kitty 2>/dev/null || true

  # Rofi colors
  if [ -f "$ROFI_CONFIG/colors-${SCHEME}-dark.rasi" ]; then
    ln -sf "$ROFI_CONFIG/colors-${SCHEME}-dark.rasi" "$ROFI_CONFIG/colors.rasi"
  else
    ln -sf "$ROFI_CONFIG/colors-dark.rasi" "$ROFI_CONFIG/colors.rasi"
  fi

  # Alacritty colors
  if [ -f "$ALACRITTY_CONFIG/themes/${SCHEME}-dark.toml" ]; then
    cp "$ALACRITTY_CONFIG/themes/${SCHEME}-dark.toml" "$ALACRITTY_CONFIG/theme.toml"
  else
    cp "$ALACRITTY_CONFIG/themes/dark.toml" "$ALACRITTY_CONFIG/theme.toml"
  fi
  sleep 0.1
  touch "$ALACRITTY_CONFIG/alacritty.toml" 2>/dev/null || true

  # Superfile Sync
  sed -i "s/^theme = \".*\"/theme = \"${SCHEME}\"/" "$SUPERFILE_CONFIG/config.toml" 2>/dev/null || true

  # Wallpaper
  hyprctl hyprpaper preload "$HOME/.config/hypr/assets/Arch-Dark.png" 2>/dev/null || true
  hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Dark.png" 2>/dev/null || true

  notify-send "Theme Activated" "Scheme: ${SCHEME^} (Dark Mode)" -i weather-clear-night-symbolic
fi
