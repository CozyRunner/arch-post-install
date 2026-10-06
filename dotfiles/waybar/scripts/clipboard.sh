#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Waybar Clipse Clipboard Integration & Menu Control
# Features:
#   --tooltip : Rich tooltip with item count, latest snippet, and action legend
#   --list    : Open Clipse TUI floating terminal
#   --delete  : Open Clipse menu or manager
#   --wipe    : Confirmation prompt to clear entire clipboard history
#   --menu    : Quick settings actions menu (Open Clipse, Clear History)
# ──────────────────────────────────────────────────────────────────────────────

CLIPSE_CMD="$(command -v clipse || echo "/usr/bin/clipse")"
ROFI_THEME="${HOME}/.config/rofi/clipboard.rasi"
HISTORY_FILE="${HOME}/.config/clipse/clipboard_history.json"

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

case "$1" in
    --tooltip)
        if ! command -v "$CLIPSE_CMD" &>/dev/null && [[ ! -x "$CLIPSE_CMD" ]]; then
            jq -nc --arg text "󰅍" --arg tooltip "clipse is not installed" '{text: $text, tooltip: $tooltip, class: "disabled"}'
            exit 0
        fi

        ensure_daemon

        count=0
        latest=""
        if [[ -f "$HISTORY_FILE" ]]; then
            count=$(jq '.clipboardHistory | length' "$HISTORY_FILE" 2>/dev/null || echo 0)
            latest=$(jq -r '.clipboardHistory[0].value // ""' "$HISTORY_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/^[ \t]*//' | cut -c 1-50)
        fi

        if [[ "$count" -eq 0 || -z "$count" ]]; then
            tooltip_msg="󰅍 Clipboard History (Clipse)\nStatus: Empty\n\n󰍽 Left-Click: Open Clipse\n󰍾 Right-Click: Clear History"
        else
            tooltip_msg="󰅍 Clipboard History (Clipse) (${count} items)\nLatest: ${latest}\n\n󰍽 Left-Click: Open Clipse\n󰍿 Middle-Click: Menu\n󰍾 Right-Click: Clear All History"
        fi

        jq -nc --arg text "󰅍" --arg tooltip "$tooltip_msg" '{text: $text, tooltip: $tooltip, class: "active"}'
        ;;

    --list)
        ensure_daemon
        if hyprctl clients 2>/dev/null | grep -q "class: clipse"; then
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
                "$CLIPSE_CMD" -clear-all
            elif [[ -f "$HISTORY_FILE" ]]; then
                echo '{"clipboardHistory":[]}' > "$HISTORY_FILE"
            fi
            notify-send "Clipboard" "History cleared" -i edit-clear
            update_waybar
        fi
        ;;

    --delete|--menu)
        menu_items="󰅍 Open Clipse Clipboard Manager\n󰗨 Clear All History"
        action=""
        if command -v rofi &>/dev/null && [[ -f "$ROFI_THEME" ]]; then
            action=$(echo -e "$menu_items" | rofi -dmenu -theme "$ROFI_THEME" -p "󰅍 Clipboard Menu")
        elif command -v rofi &>/dev/null; then
            action=$(echo -e "$menu_items" | rofi -dmenu -p "󰅍 Clipboard Menu")
        fi

        case "$action" in
            *"Open Clipse"*)
                "$0" --list
                ;;
            *"Clear All History"*)
                "$0" --wipe
                ;;
        esac
        ;;

    *)
        "$0" --list
        ;;
esac
