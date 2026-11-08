#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Waybar Clipse Clipboard Integration & Menu Control
# Features:
#   --tooltip : Rich Pango-formatted tooltip with item count, snippet preview, and actions
#   --list    : Open Clipse TUI floating terminal
#   --delete  : Open Clipse menu or manager
#   --wipe    : Confirmation prompt to clear entire clipboard history
#   --menu    : Quick settings actions menu (Open Clipse, OCR Extract, Clear History)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIPSE_CMD="$(command -v clipse || echo "/usr/bin/clipse")"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
ROFI_THEME="${CONFIG_DIR}/rofi/clipboard.rasi"
if [[ ! -f "$ROFI_THEME" ]]; then
    REPO_THEME="$(cd "$SCRIPT_DIR/../../rofi" 2>/dev/null && pwd)/clipboard.rasi"
    [[ -f "$REPO_THEME" ]] && ROFI_THEME="$REPO_THEME"
fi

HISTORY_FILE="${CONFIG_DIR}/clipse/clipboard_history.json"
if [[ ! -f "$HISTORY_FILE" ]]; then
    REPO_HIST="$(cd "$SCRIPT_DIR/../../clipse" 2>/dev/null && pwd)/clipboard_history.json"
    [[ -f "$REPO_HIST" ]] && HISTORY_FILE="$REPO_HIST"
fi

OCR_SCRIPT="${CONFIG_DIR}/hypr/scripts/ocr_extract.sh"
if [[ ! -f "$OCR_SCRIPT" ]]; then
    REPO_OCR="$(cd "$SCRIPT_DIR/../../hypr/scripts" 2>/dev/null && pwd)/ocr_extract.sh"
    [[ -f "$REPO_OCR" ]] && OCR_SCRIPT="$REPO_OCR"
fi

update_waybar() {
    pkill -RTMIN+9 waybar 2>/dev/null || true
}

ensure_daemon() {
    if command -v "$CLIPSE_CMD" &>/dev/null; then
        if ! pgrep -f "clipse --wl-store" >/dev/null && ! pgrep -f "clipse -listen" >/dev/null; then
            "$CLIPSE_CMD" -listen >/dev/null 2>&1 &
        fi
    fi
}

case "${1:-status}" in
    --tooltip|status)
        if ! command -v "$CLIPSE_CMD" &>/dev/null && [[ ! -x "$CLIPSE_CMD" ]]; then
            jq -nc \
                --arg text "󰅍" \
                --arg alt "Disabled" \
                --arg tooltip "<span weight='bold' foreground='#f87171'>󰅍 Clipboard History (Clipse)</span>\n<span foreground='#94a3b8'>Clipse is not installed or not in PATH.</span>\n<small>Install via: <i>sudo pacman -S clipse</i></small>" \
                --arg class "disabled" \
                '{text: $text, alt: $alt, tooltip: $tooltip, class: $class}'
            exit 0
        fi

        ensure_daemon

        count=0
        if [[ -f "$HISTORY_FILE" ]]; then
            count=$(jq '.clipboardHistory | length' "$HISTORY_FILE" 2>/dev/null || echo 0)
        fi

        if [[ "$count" -eq 0 || -z "$count" ]]; then
            alt_text="Empty"
            css_class="empty"
            tooltip_msg="<span weight='bold' size='110%' foreground='#818cf8'>󰅍 Clipboard History</span>  <small foreground='#94a3b8'>(Clipse)</small>\n<span foreground='#94a3b8'><i>Status: Clipboard history is empty</i></span>\n\n<b>Actions:</b>\n  󰍽 <b>Left Click:</b> Open Clipboard Manager\n  󰍿 <b>Middle Click:</b> Quick Actions Menu\n  󰍾 <b>Right Click:</b> Clear History"
        else
            item_label="items"
            [[ "$count" -eq 1 ]] && item_label="item"
            alt_text="${count} ${item_label}"
            css_class="active"

            # Extract and format up to 3 recent snippets with @html escaping and line collapsing
            snippets=$(jq -r '
                .clipboardHistory[:3] | to_entries[] |
                "  <span foreground=\"#818cf8\">\(.key + 1).</span> <i>\(.value.value // "" | gsub("[\\r\\n\\t]+"; " ") | gsub("^\\s+|\\s+$"; "") | if length > 45 then .[:45] + "…" else . end | @html)</i>"
            ' "$HISTORY_FILE" 2>/dev/null || true)

            if [[ -n "$snippets" ]]; then
                tooltip_msg="<span weight='bold' size='110%' foreground='#818cf8'>󰅍 Clipboard History</span>  <small foreground='#94a3b8'>(${count} ${item_label})</small>\n\n<b>Recent Clips:</b>\n${snippets}\n\n<b>Actions:</b>\n  󰍽 <b>Left Click:</b> Open Clipboard Manager\n  󰍿 <b>Middle Click:</b> Quick Actions Menu\n  󰍾 <b>Right Click:</b> Clear All History"
            else
                tooltip_msg="<span weight='bold' size='110%' foreground='#818cf8'>󰅍 Clipboard History</span>  <small foreground='#94a3b8'>(${count} ${item_label})</small>\n\n<b>Actions:</b>\n  󰍽 <b>Left Click:</b> Open Clipboard Manager\n  󰍿 <b>Middle Click:</b> Quick Actions Menu\n  󰍾 <b>Right Click:</b> Clear All History"
            fi
        fi

        jq -nc \
            --arg text "󰅍" \
            --arg alt "$alt_text" \
            --arg tooltip "$tooltip_msg" \
            --arg class "$css_class" \
            '{text: $text, alt: $alt, tooltip: $tooltip, class: $class}'
        ;;

    --list)
        ensure_daemon
        if command -v hyprctl &>/dev/null && hyprctl clients 2>/dev/null | grep -q "class: clipse"; then
            hyprctl dispatch focuswindow "class:clipse"
        else
            kitty --class clipse -e "$CLIPSE_CMD" &
        fi
        ;;

    --wipe)
        confirm="Yes"
        if command -v rofi &>/dev/null && [[ -f "$ROFI_THEME" ]]; then
            confirm=$(echo -e "No\nYes" | rofi -dmenu -theme "$ROFI_THEME" -p "󰗨 Clear All Clipboard History?")
        elif command -v rofi &>/dev/null; then
            confirm=$(echo -e "No\nYes" | rofi -dmenu -p "󰗨 Clear All Clipboard History?")
        fi

        if [[ "$confirm" == "Yes" ]]; then
            if [[ -x "$CLIPSE_CMD" ]] || command -v "$CLIPSE_CMD" &>/dev/null; then
                "$CLIPSE_CMD" -clear-all 2>/dev/null || true
            fi
            if [[ -f "$HISTORY_FILE" ]]; then
                echo '{"clipboardHistory":[]}' > "$HISTORY_FILE"
            fi
            if command -v notify-send &>/dev/null; then
                notify-send "Clipboard" "History cleared" -i edit-clear
            fi
            update_waybar
        fi
        ;;

    --delete|--menu)
        menu_items="󰅍 Open Clipboard Manager (Clipse)\n󰗨 Clear All Clipboard History"
        if [[ -f "$OCR_SCRIPT" ]] || command -v ocr_extract.sh &>/dev/null; then
            menu_items="󰅍 Open Clipboard Manager (Clipse)\n󰚢 Extract & Copy Text (OCR)\n󰗨 Clear All Clipboard History"
        fi

        action=""
        if command -v rofi &>/dev/null && [[ -f "$ROFI_THEME" ]]; then
            action=$(echo -e "$menu_items" | rofi -dmenu -theme "$ROFI_THEME" -p "󰅍 Clipboard Menu")
        elif command -v rofi &>/dev/null; then
            action=$(echo -e "$menu_items" | rofi -dmenu -p "󰅍 Clipboard Menu")
        fi

        case "$action" in
            *"Open Clipboard Manager"*)
                "$0" --list
                ;;
            *"Extract & Copy Text"*)
                if [[ -f "$OCR_SCRIPT" ]]; then
                    bash "$OCR_SCRIPT" menu
                elif command -v ocr_extract.sh &>/dev/null; then
                    ocr_extract.sh menu
                fi
                ;;
            *"Clear All Clipboard History"*)
                "$0" --wipe
                ;;
        esac
        ;;

    *)
        "$0" --list
        ;;
esac
