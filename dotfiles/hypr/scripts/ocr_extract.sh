#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║               OCR Text Extraction Controller                 ║
# ║   Extract & Copy Text from Screen, Selection Area, or Window ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ocr_extract.sh [area|screen|display|window|active|menu]
#
# Modes:
#   area     - Extract text from user-defined selection area (drag region)
#   screen   - Extract text from entire screen (all connected displays)
#   display  - Extract text from active display (cursor monitor)
#   window   - Extract text from clicked application window
#   active   - Extract text from currently focused application window
#   menu     - Launch interactive Rofi OCR mode selector
#
# Copies extracted text to the Wayland system clipboard (wl-copy)
# and displays a desktop notification with a text snippet.

set -euo pipefail

# ── Early Help ────────────────────────────────────────────────
case "${1:-}" in
    -h|--help|help)
        echo "Usage: $(basename "$0") [area|screen|display|window|active|menu]"
        echo ""
        echo "Modes:"
        echo "  area     - Extract text from user-selected region (default)"
        echo "  screen   - Extract text from entire screen (all monitors)"
        echo "  display  - Extract text from active display where cursor is"
        echo "  window   - Extract text from specific clicked window"
        echo "  active   - Extract text from currently focused window"
        echo "  menu     - Launch interactive Rofi selector"
        exit 0
        ;;
esac

# ── Dependencies Check ────────────────────────────────────────
MISSING_DEPS=()
for cmd in grim slurp wl-copy notify-send jq hyprctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "OCR Error" "Missing required tools: ${MISSING_DEPS[*]}"
    fi
    echo "Error: Missing required tools: ${MISSING_DEPS[*]}" >&2
    exit 1
fi

if ! command -v tesseract >/dev/null 2>&1; then
    MSG="Tesseract OCR engine is not installed.\nInstall via: sudo pacman -S tesseract tesseract-data-eng"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "OCR Error: Tesseract Missing" "$MSG" -i dialog-warning
    fi
    echo -e "\033[1;31m[ERROR]\033[0m $MSG" >&2
    exit 1
fi

# ── Slurp Visual Style ────────────────────────────────────────
SLURP_BORDER_COLOR="#818cf8ff"
SLURP_BG_COLOR="#00000088"
SLURP_SELECTION_COLOR="#818cf833"
SLURP_BORDER_WEIGHT=2

# ── Helpers ───────────────────────────────────────────────────
close_notification_panel() {
    if pgrep -x swaync >/dev/null 2>&1; then
        swaync-client -cp 2>/dev/null || true
        sleep 0.25
    elif command -v dunstctl >/dev/null 2>&1; then
        dunstctl close-all 2>/dev/null || true
        sleep 0.15
    fi
}

get_active_display() {
    local cursor cx cy
    cursor="$(hyprctl cursorpos 2>/dev/null || echo "")"

    if [[ -n "$cursor" && "$cursor" =~ ([0-9]+),[[:space:]]*([0-9]+) ]]; then
        cx="${BASH_REMATCH[1]}"
        cy="${BASH_REMATCH[2]}"

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
        hyprctl monitors -j | jq -r '(map(select(.focused == true))[0].name // .[0].name // empty)'
    fi
}

select_window_geometry() {
    local active_workspaces rects chosen_geom
    active_workspaces="$(hyprctl monitors -j | jq -r '[.[].activeWorkspace.id]')"
    rects="$(hyprctl clients -j | jq -r --argjson ws "$active_workspaces" '
        .[] |
        select(([.workspace.id] | inside($ws)) and .mapped == true and .hidden == false) |
        "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ')"

    if [[ -z "$rects" ]]; then
        chosen_geom="$(hyprctl activewindow -j | jq -r 'if .at and .size then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')"
        echo "$chosen_geom"
        return 0
    fi

    chosen_geom="$(echo "$rects" | slurp -r \
        -d \
        -b "$SLURP_BG_COLOR" \
        -c "$SLURP_BORDER_COLOR" \
        -s "$SLURP_SELECTION_COLOR" \
        -w "$SLURP_BORDER_WEIGHT" 2>/dev/null)" || return 1

    echo "$chosen_geom"
}

# ── Process Extracted OCR Text ────────────────────────────────
finalize_ocr() {
    local raw_text="$1"
    local source_desc="$2"

    # Normalize whitespace: strip leading/trailing blank lines
    local text
    text="$(printf '%s' "$raw_text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if [[ -z "$text" ]]; then
        notify-send \
            -a "OCR Tool" \
            -i dialog-information \
            "No Text Detected" \
            "No readable text was found in ${source_desc}."
        echo "No text detected." >&2
        return 0
    fi

    # Copy to Wayland clipboard
    printf '%s' "$text" | wl-copy -t text/plain

    local char_count word_count line_count preview
    char_count="${#text}"
    word_count="$(echo "$text" | wc -w)"
    line_count="$(echo "$text" | wc -l)"
    ((line_count++)) || true

    # Prepare preview snippet (first 140 chars)
    preview="$(printf '%s' "$text" | head -c 140)"
    if [[ ${#text} -gt 140 ]]; then
        preview="${preview}..."
    fi

    notify-send \
        -a "OCR Tool" \
        -i edit-copy \
        "Text Copied to Clipboard" \
        "<b>${source_desc}</b> (${word_count} words, ${char_count} chars):\n\"${preview}\""

    echo "$text"
}

# ── Extraction Handlers ───────────────────────────────────────

extract_area() {
    close_notification_panel

    local geom
    geom="$(slurp \
        -d \
        -b "$SLURP_BG_COLOR" \
        -c "$SLURP_BORDER_COLOR" \
        -s "$SLURP_SELECTION_COLOR" \
        -w "$SLURP_BORDER_WEIGHT" 2>/dev/null)" || exit 0

    if [[ -n "$geom" ]]; then
        local raw_text
        raw_text="$(grim -g "$geom" - 2>/dev/null | tesseract stdin stdout -l eng 2>/dev/null || true)"
        finalize_ocr "$raw_text" "Selected Area"
    fi
}

extract_screen() {
    close_notification_panel

    local raw_text
    raw_text="$(grim - 2>/dev/null | tesseract stdin stdout -l eng 2>/dev/null || true)"
    finalize_ocr "$raw_text" "Entire Screen"
}

extract_display() {
    local display_name
    display_name="$(get_active_display)"
    close_notification_panel

    local raw_text
    if [[ -n "$display_name" ]]; then
        raw_text="$(grim -o "$display_name" - 2>/dev/null | tesseract stdin stdout -l eng 2>/dev/null || true)"
        finalize_ocr "$raw_text" "Active Display ($display_name)"
    else
        raw_text="$(grim - 2>/dev/null | tesseract stdin stdout -l eng 2>/dev/null || true)"
        finalize_ocr "$raw_text" "Display"
    fi
}

extract_window() {
    close_notification_panel

    local geom
    geom="$(select_window_geometry)" || exit 0

    if [[ -n "$geom" ]]; then
        local raw_text
        raw_text="$(grim -g "$geom" - 2>/dev/null | tesseract stdin stdout -l eng 2>/dev/null || true)"
        finalize_ocr "$raw_text" "Application Window"
    fi
}

extract_active_window() {
    close_notification_panel

    local geom app_title
    geom="$(hyprctl activewindow -j | jq -r 'if .at and .size then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')"
    app_title="$(hyprctl activewindow -j | jq -r '.class // "Active Window"')"

    if [[ -n "$geom" ]]; then
        local raw_text
        raw_text="$(grim -g "$geom" - 2>/dev/null | tesseract stdin stdout -l eng 2>/dev/null || true)"
        finalize_ocr "$raw_text" "Active Window ($app_title)"
    else
        extract_area
    fi
}

# ── Interactive Rofi Menu ─────────────────────────────────────
show_rofi_menu() {
    local rofi_theme="${ROFI_THEME:-$HOME/.config/rofi/floating-menu.rasi}"
    local options="󰚢  Selection Area (Drag Region)\n󰹑  Entire Screen (All Monitors)\n󰍹  Active Display (Cursor Monitor)\n󰖯  Application Window (Click Window)\n󱂬  Active Window (Focused)"

    local choice=""
    if [[ -f "$rofi_theme" ]]; then
        choice="$(echo -e "$options" | rofi -dmenu -i -p "󰚢 Extract Text (OCR)" -mesg "  Choose region to extract and copy text" -theme "$rofi_theme" 2>/dev/null)" || exit 0
    else
        choice="$(echo -e "$options" | rofi -dmenu -i -p "󰚢 Extract Text (OCR)" 2>/dev/null)" || exit 0
    fi

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Selection Area"*)
            extract_area
            ;;
        *"Entire Screen"*)
            extract_screen
            ;;
        *"Active Display"*)
            extract_display
            ;;
        *"Application Window"*)
            extract_window
            ;;
        *"Active Window"*)
            extract_active_window
            ;;
    esac
}

# ── Main Dispatcher ───────────────────────────────────────────
MODE="${1:-area}"

case "$MODE" in
    area|selection|crop|particular)
        extract_area
        ;;
    screen|fullscreen|all|entire)
        extract_screen
        ;;
    display|output|active-display|monitor)
        extract_display
        ;;
    window|app)
        extract_window
        ;;
    active|activewindow|focus)
        extract_active_window
        ;;
    menu|gui|interactive)
        show_rofi_menu
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        echo "Usage: $(basename "$0") [area|screen|display|window|active|menu]" >&2
        exit 1
        ;;
esac

