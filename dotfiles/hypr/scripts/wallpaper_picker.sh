#!/bin/bash
# Wallpaper Changer — Browse and set wallpaper with image previews
# Uses rofi's icon column to show thumbnail previews in a grid

WALLPAPER_DIRS=(
  "$HOME/Pictures/wallpapers"
  "$HOME/Pictures/Wallpapers"
  "$HOME/.config/hypr/assets"
)

# Collect all wallpaper files
wallpapers=()
for dir in "${WALLPAPER_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    while IFS= read -r -d '' file; do
      wallpapers+=("$file")
    done < <(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 | sort -z)
  fi
done

if [ ${#wallpapers[@]} -eq 0 ]; then
  notify-send "Wallpaper Changer" "No wallpapers found in:\n~/Pictures/wallpapers\n~/Pictures/Wallpapers\n~/.config/hypr/assets" -i dialog-warning-symbolic
  exit 1
fi

# Build rofi list with image icons using \0icon\x1f protocol
# Each entry: "filename\0icon\x1f/full/path/to/image"
build_entries() {
  for wp in "${wallpapers[@]}"; do
    name=$(basename "$wp")
    # Remove extension for cleaner display
    label="${name%.*}"
    echo -en "${label}\0icon\x1f${wp}\n"
  done
}

# Show picker in rofi with the grid wallpaper-picker theme
selected=$(build_entries | rofi -dmenu -i \
  -p "󰋩  Wallpaper" \
  -theme ~/.config/rofi/wallpaper-picker.rasi)

[ -z "$selected" ] && exit 0

# Find the full path — match against basename without extension
selected_path=""
for wp in "${wallpapers[@]}"; do
  name=$(basename "$wp")
  label="${name%.*}"
  if [ "$label" == "$selected" ]; then
    selected_path="$wp"
    break
  fi
done

[ -z "$selected_path" ] && exit 1

# Apply using hyprctl + hyprpaper
hyprctl hyprpaper preload "$selected_path" 2>/dev/null
hyprctl hyprpaper wallpaper ",$selected_path" 2>/dev/null

# Update hyprpaper.conf so it persists across restarts
cat >"$HOME/.config/hypr/hyprpaper.conf" <<EOF
preload = $selected_path

wallpaper {
    monitor = 
    path = $selected_path
    fit_mode = cover
}

EOF

notify-send "Wallpaper Changed" "$(basename "$selected_path")" -i preferences-desktop-wallpaper-symbolic
