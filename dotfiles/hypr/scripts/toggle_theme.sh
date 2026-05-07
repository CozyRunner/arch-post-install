#!/bin/bash

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
THEME_STATE="$HOME/.cache/theme_mode"

# Get current color scheme
CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme)

if [ "$CURRENT_SCHEME" == "'prefer-dark'" ]; then
  # --- SWITCH TO LIGHT MODE ---
  echo "Switching to Light Mode..."
  echo "light" > "$THEME_STATE"

  # GTK / System-wide settings
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'

  # KDE / Plasma / Qt
  if command -v plasma-apply-lookandfeel >/dev/null; then
    plasma-apply-lookandfeel -a org.kde.breeze.desktop
  fi
  if command -v kvantummanager >/dev/null; then
    kvantummanager --set KvMojaveLight >/dev/null 2>&1 || kvantummanager --set KvArc >/dev/null 2>&1
  fi

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
  ln -sf "$ROFI_CONFIG/colors-light.rasi" "$ROFI_CONFIG/colors.rasi"

  # Alacritty colors
  cp "$ALACRITTY_CONFIG/themes/light.toml" "$ALACRITTY_CONFIG/theme.toml"
  sleep 0.1
  touch "$ALACRITTY_CONFIG/alacritty.toml"

  # Fish colors
  cp "$FISH_CONFIG/themes/light.fish" "$FISH_CONFIG/conf.d/theme.fish"
  fish -c "source $FISH_CONFIG/conf.d/theme.fish"

  # Wallpaper
  hyprctl hyprpaper preload "$HOME/.config/hypr/assets/Arch-Light.png" 2>/dev/null || true
  hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Light.png" 2>/dev/null || true

  # Zellij Sync
  sed -i 's/^[[:space:]]*[/# ]*theme[[:space:]]\+".*"/theme "catppuccin-latte"/' "$ZELLIJ_CONFIG/config.kdl"
  touch "$ZELLIJ_CONFIG/config.kdl"
  
  # Superfile Sync
  sed -i 's/^theme = ".*"/theme = "catppuccin-latte"/' "$SUPERFILE_CONFIG/config.toml"

  # Nudge active sessions to reload theme
  for session in $(zellij list-sessions -n 2>/dev/null | grep -v "EXITED" | awk '{print $1}'); do
    zellij -s "$session" action switch-mode normal
  done

  # Neovim Sync (Backgrounded)
  (
    for server in $(nvim --server list 2>/dev/null); do
      nvim --server "$server" --remote-send ":set background=light<CR>:lua require('catppuccin').setup({flavor='latte'}); vim.cmd.colorscheme('catppuccin')<CR>"
    done
  ) &

  # SwayNC
  if pgrep swaync >/dev/null; then
    swaync-client -rs
  fi

  notify-send "Theme Switched" "Light Mode Activated" -i weather-clear-symbolic
else
  # --- SWITCH TO DARK MODE ---
  echo "Switching to Dark Mode..."
  echo "dark" > "$THEME_STATE"

  # GTK / System-wide settings
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

  # KDE / Plasma / Qt
  if command -v plasma-apply-lookandfeel >/dev/null; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop
  fi
  if command -v kvantummanager >/dev/null; then
    kvantummanager --set KvMojave >/dev/null 2>&1 || kvantummanager --set KvArcDark >/dev/null 2>&1
  fi

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
  ln -sf "$ROFI_CONFIG/colors-dark.rasi" "$ROFI_CONFIG/colors.rasi"

  # Alacritty colors
  cp "$ALACRITTY_CONFIG/themes/dark.toml" "$ALACRITTY_CONFIG/theme.toml"
  sleep 0.1
  touch "$ALACRITTY_CONFIG/alacritty.toml"

  # Fish colors
  cp "$FISH_CONFIG/themes/dark.fish" "$FISH_CONFIG/conf.d/theme.fish"
  fish -c "source $FISH_CONFIG/conf.d/theme.fish"

  # Wallpaper
  hyprctl hyprpaper preload "$HOME/.config/hypr/assets/Arch-Dark.png" 2>/dev/null || true
  hyprctl hyprpaper wallpaper ",$HOME/.config/hypr/assets/Arch-Dark.png" 2>/dev/null || true

  # Zellij Sync
  sed -i 's/^[[:space:]]*[/# ]*theme[[:space:]]\+".*"/theme "catppuccin-mocha"/' "$ZELLIJ_CONFIG/config.kdl"
  touch "$ZELLIJ_CONFIG/config.kdl"

  # Superfile Sync
  sed -i 's/^theme = ".*"/theme = "catppuccin-mocha"/' "$SUPERFILE_CONFIG/config.toml"

  # Nudge active sessions to reload theme
  for session in $(zellij list-sessions -n 2>/dev/null | grep -v "EXITED" | awk '{print $1}'); do
    zellij -s "$session" action switch-mode normal
  done

  # Neovim Sync (Backgrounded)
  (
    for server in $(nvim --server list 2>/dev/null); do
      nvim --server "$server" --remote-send ":set background=dark<CR>:lua require('catppuccin').setup({flavor='mocha'}); vim.cmd.colorscheme('catppuccin')<CR>"
    done
  ) &

  # SwayNC
  if pgrep swaync >/dev/null; then
    swaync-client -rs
  fi

  notify-send "Theme Switched" "Dark Mode Activated" -i weather-clear-night-symbolic
fi













































































orscheme('catppuccin')<CR>"




































































rscheme('catppuccin')<CR>"










