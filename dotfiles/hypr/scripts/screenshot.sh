#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║                Screenshot Tool Controller                    ║
# ║  Entire Screen · Active Display · Selection Area · Window    ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ------------------------------------------------------------------------------
# Early Help Display (read-only, no dependencies or side effects needed)
# ------------------------------------------------------------------------------
case "${1:-}" in
    -h|--help|help)
        echo "Usage: $0 [screen|display|area|window|active|menu]"
        echo ""
        echo "Modes:"
        echo "  screen   - Capture entire screen (all connected displays)"
        echo "  display  - Capture active display where cursor is positioned"
        echo "  area     - Capture user-defined selection area (drag region)"
        echo "  window   - Capture specific application window (interactive click)"
        echo "  active   - Capture currently focused application window"
        echo "  menu     - Launch interactive Rofi screenshot selector"
        exit 0
        ;;
esac

# ------------------------------------------------------------------------------
# Dependencies Check
# ------------------------------------------------------------------------------
for cmd in grim slurp wl-copy notify-send jq hyprctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        notify-send -u critical "Screenshot Error" "Required dependency '$cmd' is not installed."
        echo "Error: '$cmd' is not installed." >&2
        exit 1
    fi
done

# ------------------------------------------------------------------------------
# Configuration & Paths
# ------------------------------------------------------------------------------
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$PICTURES_DIR/Screenshots}"
mkdir -p "$SCREENSHOT_DIR"

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
OUTPUT_FILE="$SCREENSHOT_DIR/Screenshot_${TIMESTAMP}.png"

# Slurp visual style (harmonized with Lumina theme: accent indigo/blue border)
SLURP_BORDER_COLOR="#818cf8ff"
SLURP_BG_COLOR="#00000088"
SLURP_SELECTION_COLOR="#818cf833"
SLURP_BORDER_WEIGHT=2

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Close notification center before capturing to avoid capturing the overlay panel
close_notification_panel() {
    if pgrep -x swaync >/dev/null 2>&1; then
        swaync-client -cp 2>/dev/null || true
        # Wait for panel slide-out transition (swaync transition-time is ~200ms)
        sleep 0.25
    elif command -v dunstctl >/dev/null 2>&1; then
        dunstctl close-all 2>/dev/null || true
        sleep 0.15
    fi
}

# Determine the display/monitor name where the cursor is currently positioned
get_active_display() {
    local cursor cx cy
    cursor="$(hyprctl cursorpos 2>/dev/null || echo "")"

    if [[ -n "$cursor" && "$cursor" =~ ([0-9]+),[[:space:]]*([0-9]+) ]]; then
        cx="${BASH_REMATCH[1]}"
        cy="${BASH_REMATCH[2]}"

        # Match cursor coordinates against monitor bounds (accounting for scale & rotation)
        hyprctl monitors -j | jq -r --argjson cx "$cx" --argjson cy "$cy" '
            (map(
                . as $m |
                ($m.scale // 1.0) as $s |
                ($m.width / $s) as $raw_w |
                ($m.height / $s) as $raw_h |
                (if ($m.transform == 1 or $m.transform == 3) then $raw_h else $raw_w end) as $w |
                (if ($m.transform == 1 or $m.transform == 3) then $raw_w else $raw_h end) as $h |
                select($cx >= $m.x and $cx < ($m.x + $w) and $cy >= $m.y and $cy < ($m.y + $h))
            )[0].name // empty) //
            (map(select(.focused == true))[0].name // empty) //
            (.[0].name // empty)
        '
    else
        # Fallback to focused monitor or primary
        hyprctl monitors -j | jq -r '(map(select(.focused == true))[0].name // .[0].name // empty)'
    fi
}

# Select an application window interactively by highlighting visible window rectangles
select_window_geometry() {
    local active_workspaces rects chosen_geom

    # Collect active workspace IDs from all monitors
    active_workspaces="$(hyprctl monitors -j | jq -r '[.[].activeWorkspace.id]')"

    # Extract geometry of visible, mapped windows on active workspaces
    rects="$(hyprctl clients -j | jq -r --argjson ws "$active_workspaces" '
        .[] |
        select(([.workspace.id] | inside($ws)) and .mapped == true and .hidden == false) |
        "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ')"

    if [[ -z "$rects" ]]; then
        # Fallback: if no client windows found, try active window geometry
        chosen_geom="$(hyprctl activewindow -j | jq -r 'if .at and .size then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')"
        echo "$chosen_geom"
        return 0
    fi

    # Restrict selection to predefined window bounding boxes with slurp -r
    chosen_geom="$(echo "$rects" | slurp -r \
        -d \
        -b "$SLURP_BG_COLOR" \
        -c "$SLURP_BORDER_COLOR" \
        -s "$SLURP_SELECTION_COLOR" \
        -w "$SLURP_BORDER_WEIGHT" 2>/dev/null)" || return 1

    echo "$chosen_geom"
}

# Post-processing: copy to clipboard and notify with interactive actions
finalize_screenshot() {
    local target_file="$1"
    local mode_desc="$2"

    if [[ ! -f "$target_file" || ! -s "$target_file" ]]; then
        return 1
    fi

    # Copy image to clipboard
    wl-copy --type image/png < "$target_file"

    local base_name
    base_name="$(basename "$target_file")"

    # Send notification asynchronously with action buttons
    (
        local action
        action="$(notify-send \
            -a "Screenshot Tool" \
            -i "$target_file" \
            --action="view=View" \
            --action="folder=Show in Folder" \
            "Screenshot Captured" \
            "${mode_desc}\nSaved: ${base_name}\nCopied to clipboard.")" || true

        case "$action" in
            view)
                if command -v imv >/dev/null 2>&1; then
                    imv "$target_file" >/dev/null 2>&1 &
                elif command -v xdg-open >/dev/null 2>&1; then
                    xdg-open "$target_file" >/dev/null 2>&1 &
                fi
                ;;
            folder)
                if command -v xdg-open >/dev/null 2>&1; then
                    xdg-open "$SCREENSHOT_DIR" >/dev/null 2>&1 &
                fi
                ;;
        esac
    ) >/dev/null 2>&1 &

    echo "$target_file"
}

# Interactive Rofi menu for screenshot options
show_rofi_menu() {
    local rofi_theme="${ROFI_THEME:-$HOME/.config/rofi/floating-menu.rasi}"
    local options="󰹑  Entire Screen\n󰍹  Active Display (Cursor)\n󰒅  Selection Area\n󰖯  Application Window (Click)\n󱂬  Active Window (Focused)"

    local choice
    if [[ -f "$rofi_theme" ]]; then
        choice="$(echo -e "$options" | rofi -dmenu -i -p "󰄀 Screenshot" -mesg "  Choose screenshot capture mode" -theme "$rofi_theme" 2>/dev/null)" || exit 0
    else
        choice="$(echo -e "$options" | rofi -dmenu -i -p "󰄀 Screenshot" 2>/dev/null)" || exit 0
    fi

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Entire Screen"*)
            capture_screen
            ;;
        *"Active Display"*)
            capture_display
            ;;
        *"Selection Area"*)
            capture_area
            ;;
        *"Application Window"*)
            capture_window
            ;;
        *"Active Window"*)
            capture_active_window
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Capture Handlers
# ------------------------------------------------------------------------------

# 1. Capture the entire screen (all connected displays / full desktop)
capture_screen() {
    close_notification_panel
    grim "$OUTPUT_FILE"
    finalize_screenshot "$OUTPUT_FILE" "Entire Screen"
}

# 2. Capture the active display where cursor is positioned
capture_display() {
    local display_name
    display_name="$(get_active_display)"
    close_notification_panel

    if [[ -n "$display_name" ]]; then
        grim -o "$display_name" "$OUTPUT_FILE"
        finalize_screenshot "$OUTPUT_FILE" "Active Display ($display_name)"
    else
        grim "$OUTPUT_FILE"
        finalize_screenshot "$OUTPUT_FILE" "Display (Fallback Fullscreen)"
    fi
}

# 3. Capture a user-defined selection area
capture_area() {
    close_notification_panel

    local geom
    geom="$(slurp \
        -d \
        -b "$SLURP_BG_COLOR" \
        -c "$SLURP_BORDER_COLOR" \
        -s "$SLURP_SELECTION_COLOR" \
        -w "$SLURP_BORDER_WEIGHT" 2>/dev/null)" || exit 0

    if [[ -n "$geom" ]]; then
        grim -g "$geom" "$OUTPUT_FILE"
        finalize_screenshot "$OUTPUT_FILE" "Selection Area"
    fi
}

# 4. Capture a specific application window (hover & click)
capture_window() {
    close_notification_panel

    local geom
    geom="$(select_window_geometry)" || exit 0

    if [[ -n "$geom" ]]; then
        grim -g "$geom" "$OUTPUT_FILE"
        finalize_screenshot "$OUTPUT_FILE" "Application Window"
    fi
}

# 5. Capture currently focused/active window directly
capture_active_window() {
    close_notification_panel

    local geom app_title
    geom="$(hyprctl activewindow -j | jq -r 'if .at and .size then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')"
    app_title="$(hyprctl activewindow -j | jq -r '.class // "Active Window"')"

    if [[ -n "$geom" ]]; then
        grim -g "$geom" "$OUTPUT_FILE"
        finalize_screenshot "$OUTPUT_FILE" "Active Window ($app_title)"
    else
        capture_area
    fi
}

# ------------------------------------------------------------------------------
# Main Dispatcher
# ------------------------------------------------------------------------------
MODE="${1:-menu}"

case "$MODE" in
    screen|fullscreen|all)
        capture_screen
        ;;
    display|output|active-display|monitor)
        capture_display
        ;;
    area|selection|crop)
        capture_area
        ;;
    window|app)
        capture_window
        ;;
    active|activewindow)
        capture_active_window
        ;;
    menu|gui|interactive)
        show_rofi_menu
        ;;
    -h|--help|help)
        echo "Usage: $0 [screen|display|area|window|active|menu]"
        echo ""
        echo "Modes:"
        echo "  screen   - Capture entire screen (all connected displays)"
        echo "  display  - Capture active display where cursor is positioned"
        echo "  area     - Capture user-defined selection area (drag region)"
        echo "  window   - Capture specific application window (interactive click)"
        echo "  active   - Capture currently focused application window"
        echo "  menu     - Launch interactive Rofi screenshot selector"
        exit 0
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        echo "Usage: $0 [screen|display|area|window|active|menu]" >&2
        exit 1
        ;;
esac
