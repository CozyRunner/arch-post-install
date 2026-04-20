#!/bin/bash

# Define paths
THEME_DIR="$HOME/.config/hypr/themes"
HYPR_THEME="$HOME/.config/hypr/theme.conf"
WAYBAR_CONFIG="$HOME/.config/waybar"
KITTY_CONFIG="$HOME/.config/kitty/"
ROFI_CONFIG="$HOME/.config/rofi/"
ALACRITTY_CONFIG="$HOME/.config/alacritty/"
FISH_CONFIG="$HOME/.config/fish"

# Get current color scheme
CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme)

if [ "$CURRENT_SCHEME" == "'prefer-dark'" ]; then
  # Switch to LIGHT mode
  echo "Switching to Light Mode..."

  # GTK / System-wide settingsm
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'

  # Hyprland colors
  cp "$THEME_DIR/light.conf" "$HYPR_THEME"
  hyprctl keyword general:col.active_border "rgba(0a362fFF) rgba(145a4bFF) 45deg"
  hyprctl keyword general:col.inactive_border "rgba(0000001a)"
  hyprctl keyword decoration:shadow:color "rgba(00000033)"

  # Waybar colors
  cp "$WAYBAR_CONFIG/colors-light.css" "$WAYBAR_CONFIG/colors.css"
  pkill -SIGUSR2 waybar

  # Kitty colors
  cp "$KITTY_CONFIG/light-theme.conf" "$KITTY_CONFIG/theme.conf"
  pkill -SIGUSR2 kitty

  # Rofi colors
  cp "$ROFI_CONFIG/colors-light.rasi" "$ROFI_CONFIG/colors.rasi"

  # Wallpaper
  hyprctl hyprpaper preload "$HOME/.config/hypr/assets/Arch-Light.png"
  hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Light.png"

  # Update other tools if they exist
  # SwayNC
  if pgrep swaync >/dev/null; then
    swaync-client -rs # Reload stylesheet
  fi

  notify-send "Theme Switched" "Light Mode Activated" -i weather-clear-symbolic
else
  # Switch to DARK mode
  echo "Switching to Dark Mode..."

  # GTK / System-wide settings
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

  # Hyprland colors
  cp "$THEME_DIR/dark.conf" "$HYPR_THEME"
  hyprctl keyword general:col.active_border "rgba(2eb398ff) rgba(42ffd6ff) 45deg"
  hyprctl keyword general:col.inactive_border "rgba(1e2024aa)"
  hyprctl keyword decoration:shadow:color "rgba(0f1014aa)"

  # Waybar colors
  cp "$WAYBAR_CONFIG/colors-dark.css" "$WAYBAR_CONFIG/colors.css"
  pkill -SIGUSR2 waybar

  # Kitty colors
  cp "$KITTY_CONFIG/dark-theme.conf" "$KITTY_CONFIG/theme.conf"
  pkill -SIGUSR2 kitty

  # Rofi colors
  cp "$ROFI_CONFIG/colors-dark.rasi" "$ROFI_CONFIG/colors.rasi"

  # Wallpaper
  hyprctl hyprpaper preload "$HOME/.config/hypr/assets/Arch-Dark.png"
  hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Dark.png"

  # Update other tools if they exist
  if pgrep swaync >/dev/null; then
    swaync-client -rs
  fi

  notify-send "Theme Switched" "Dark Mode Activated" -i weather-clear-night-symbolic
fi

# Note: Hyprland usually auto-reloads when theme.conf is modified because it's sourced.
# If not, we could add: hyprctl reload
