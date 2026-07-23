#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Waybar Cliphist Clipboard Integration & Menu Control
# Features:
#   --tooltip : Rich tooltip with item count, latest snippet, and action legend
#   --list    : Open Rofi clipboard picker to copy selected item
#   --delete  : Interactive Rofi menu to remove a single item from cliphist
#   --wipe    : Confirmation prompt to clear entire clipboard history
#   --menu    : Quick settings actions menu (View, Delete Item, Wipe All)
# ──────────────────────────────────────────────────────────────────────────────

CLIPHIST_CMD="$(command -v cliphist || echo "/usr/bin/cliphist")"
ROFI_THEME="${HOME}/.config/rofi/clipboard.rasi"

update_waybar() {
    pkill -RTMIN+9 waybar 2>/dev/null || true
}

case "$1" in
    --tooltip)
        if ! command -v cliphist &>/dev/null && [[ ! -x "$CLIPHIST_CMD" ]]; then
            jq -nc --arg text "󱘖" --arg tooltip "cliphist is not installed" '{text: $text, tooltip: $tooltip, class: "disabled"}'
            exit 0
        fi

        raw_list=$("$CLIPHIST_CMD" list 2>/dev/null)
        if [[ -z "$raw_list" ]]; then
            tooltip_msg="󱘖 Clipboard History\nStatus: Empty\n\n󰍽 Left-Click: Open Clipboard\n󰍾 Right-Click: Clear History"
            text="󱘖"
        else
            count=$(echo "$raw_list" | wc -l)
            first_line=$(echo "$raw_list" | head -n 1 | sed -E 's/^[0-9]+[[:space:]]+//' | cut -c 1-60)
            text="󱘖"
            tooltip_msg="󱘖 Clipboard History (${count} items)\nLatest: ${first_line}\n\n󰍽 Left-Click:   Select & Copy item\n󰍿 Middle-Click: Delete item\n󰍾 Right-Click:  Clear all history"
        fi

        jq -nc --arg text "$text" --arg tooltip "$tooltip_msg" '{text: $text, tooltip: $tooltip, class: "active"}'
        ;;

    --list)
        if [[ ! -x "$CLIPHIST_CMD" ]] && ! command -v cliphist &>/dev/null; then
            notify-send "Clipboard Error" "cliphist is not installed" -u critical
            exit 1
        fi

        selection=$("$CLIPHIST_CMD" list 2>/dev/null | rofi -dmenu -theme "$ROFI_THEME" -p "󱘖  Clipboard")
        if [[ -n "$selection" ]]; then
            echo "$selection" | "$CLIPHIST_CMD" decode | wl-copy
            notify-send "Clipboard" "Item copied to clipboard" -i clipboard
            update_waybar
        fi
        ;;

    --delete)
        if [[ ! -x "$CLIPHIST_CMD" ]] && ! command -v cliphist &>/dev/null; then
            notify-send "Clipboard Error" "cliphist is not installed" -u critical
            exit 1
        fi

        selection=$("$CLIPHIST_CMD" list 2>/dev/null | rofi -dmenu -theme "$ROFI_THEME" -p "󰆴  Delete Item")
        if [[ -n "$selection" ]]; then
            echo "$selection" | "$CLIPHIST_CMD" delete
            notify-send "Clipboard" "Item removed from history" -i edit-delete
            update_waybar
        fi
        ;;

    --wipe)
        confirm=$(echo -e "No\nYes" | rofi -dmenu -theme "$ROFI_THEME" -p "󰗨 Clear All Clipboard History?")
        if [[ "$confirm" == "Yes" ]]; then
            "$CLIPHIST_CMD" wipe
            notify-send "Clipboard" "History cleared" -i edit-clear
            update_waybar
        fi
        ;;

    --menu)
        action=$(echo -e "󱘖 View Clipboard History\n󰆴 Delete Single Item\n󰗨 Clear All History" | rofi -dmenu -theme "$ROFI_THEME" -p "󱘖 Clipboard Menu")
        case "$action" in
            *"View Clipboard History"*)
                "$0" --list
                ;;
            *"Delete Single Item"*)
                "$0" --delete
                ;;
            *"Clear All History"*)
                "$0" --wipe
                ;;
        esac
        ;;

    *)
        echo "Usage: $0 [--tooltip|--list|--delete|--wipe|--menu]"
        exit 1
        ;;
esac
