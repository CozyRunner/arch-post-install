#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Waybar MPRIS / Media Controller Helper Script
# Designed for Hyprland + Waybar
# ──────────────────────────────────────────────────────────────────────────────

set -u

# Escape characters for JSON & Pango markup
escape_pango() {
    local str="$1"
    str="${str//&/&amp;}"
    str="${str//</&lt;}"
    str="${str//>/&gt;}"
    str="${str//\"/\\\"}"
    printf "%s" "$str"
}

escape_json_val() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/}"
    str="${str//$'\t'/\\t}"
    printf "%s" "$str"
}

# Check playerctl availability
if ! command -v playerctl &>/dev/null; then
    case "${1:-status}" in
        play-pause|prev|next)
            exit 0
            ;;
        *)
            echo '{"text":"󰎆","tooltip":"playerctl is not installed\nInstall with: sudo pacman -S playerctl","class":"stopped","alt":"Stopped"}'
            exit 0
            ;;
    esac
fi

action="${1:-status}"

case "$action" in
    play-pause)
        playerctl play-pause 2>/dev/null || true
        exit 0
        ;;
    prev|previous)
        playerctl previous 2>/dev/null || true
        exit 0
        ;;
    next)
        playerctl next 2>/dev/null || true
        exit 0
        ;;
esac

# Fetch status and metadata in a single fast query
# Format: status \t playerName \t title \t artist \t album \t artUrl
raw_meta=$(playerctl metadata --format '{{status}}	{{playerName}}	{{title}}	{{artist}}	{{album}}	{{mpris:artUrl}}' 2>/dev/null || true)

status=""
player=""
title=""
artist=""
album=""
art_url=""

if [[ -n "$raw_meta" ]]; then
    IFS=$'\t' read -r status player title artist album art_url <<< "$raw_meta"
fi

# Fallback status check if metadata was empty but status exists
if [[ -z "$status" ]]; then
    status=$(playerctl status 2>/dev/null || echo "Stopped")
fi

# Clean values
status="${status:-Stopped}"
player="${player:-}"
title="${title:-}"
artist="${artist:-}"
album="${album:-}"
art_url="${art_url:-}"

# Determine class and default icon
case "$status" in
    Playing)
        class="playing"
        icon="󰐊"
        play_btn_icon="󰏤"
        play_btn_tooltip="Pause"
        ;;
    Paused)
        class="paused"
        icon="󰏤"
        play_btn_icon="󰐊"
        play_btn_tooltip="Play"
        ;;
    *)
        class="stopped"
        icon="󰎆"
        play_btn_icon="󰐊"
        play_btn_tooltip="Play"
        ;;
esac

# Build display title string
if [[ -n "$title" && -n "$artist" ]]; then
    display_title="${title} — ${artist}"
elif [[ -n "$title" ]]; then
    display_title="${title}"
elif [[ -n "$player" ]]; then
    display_title="${player}"
else
    display_title=""
fi

# Build rich Pango tooltip
if [[ "$class" != "stopped" && (-n "$title" || -n "$player") ]]; then
    safe_status=$(escape_pango "$status")
    safe_player=$(escape_pango "$player")
    safe_title=$(escape_pango "$title")
    safe_artist=$(escape_pango "$artist")
    safe_album=$(escape_pango "$album")

    tooltip="<b>${safe_status}</b>"
    [[ -n "$safe_player" ]] && tooltip+=" (${safe_player})"
    tooltip+="\n"

    [[ -n "$safe_title" ]] && tooltip+="\n<b>Title:</b> ${safe_title}"
    [[ -n "$safe_artist" ]] && tooltip+="\n<b>Artist:</b> ${safe_artist}"
    [[ -n "$safe_album" ]] && tooltip+="\n<b>Album:</b> ${safe_album}"

    tooltip+="\n\n󰐊 <b>Left Click:</b> Play/Pause"
    tooltip+="\n󰒮 <b>Middle Click:</b> Previous"
    tooltip+="\n󰒭 <b>Right Click:</b> Next"
    tooltip+="\n󰝝 <b>Scroll:</b> Volume"
else
    tooltip="No media player active\n\n󰐊 <b>Left Click:</b> Play/Pause\n󰒮 <b>Middle Click:</b> Previous\n󰒭 <b>Right Click:</b> Next"
fi

# Render according to action
case "$action" in
    status)
        text_out="$icon"
        ;;
    title|info)
        text_out="$display_title"
        ;;
    play-icon)
        text_out="$play_btn_icon"
        tooltip="$play_btn_tooltip"
        ;;
    *)
        text_out="$icon"
        ;;
esac

# JSON output
safe_text=$(escape_json_val "$text_out")
safe_tooltip=$(escape_json_val "$tooltip")

printf '{"text":"%s","tooltip":"%s","class":"%s","alt":"%s"}\n' \
    "$safe_text" \
    "$safe_tooltip" \
    "$class" \
    "$status"
