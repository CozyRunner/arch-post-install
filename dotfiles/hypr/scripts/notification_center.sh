#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║             Notification Center Controller                  ║
# ║     SwayNotificationCenter (swaync) & Dunst Fallback         ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

ACTION="${1:-toggle}"

case "$ACTION" in
  toggle)
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client -t -sw
    elif command -v swaync >/dev/null 2>&1; then
      swaync &
      sleep 0.25
      swaync-client -t -sw 2>/dev/null || true
    elif command -v dunstctl >/dev/null 2>&1; then
      dunstctl history-pop
    else
      notify-send "Notification Center" "No notification center daemon found (install swaync)" -i dialog-information
    fi
    ;;
  open)
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client -op -sw
    elif command -v dunstctl >/dev/null 2>&1; then
      dunstctl history-pop
    fi
    ;;
  close)
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client -cp -sw
    elif command -v dunstctl >/dev/null 2>&1; then
      dunstctl close-all
    fi
    ;;
  dnd)
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client -d -sw
    elif command -v dunstctl >/dev/null 2>&1; then
      dunstctl set-paused toggle
    fi
    ;;
  clear)
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client -C 2>/dev/null || true
      swaync-client -c 2>/dev/null || true
    elif command -v dunstctl >/dev/null 2>&1; then
      dunstctl history-clear
      dunstctl close-all
    fi
    ;;
  sync|theme)
    # Synchronize SwayNC color palette with active desktop theme
    SWAYNC_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/swaync"
    SCHEME="$(cat "$HOME/.cache/theme_scheme" 2>/dev/null || echo "nord")"
    MODE="$(cat "$HOME/.cache/theme_mode" 2>/dev/null || echo "dark")"
    if [ -f "$SWAYNC_CONFIG/colors-${SCHEME}-${MODE}.css" ]; then
      (cd "$SWAYNC_CONFIG" && ln -sf "colors-${SCHEME}-${MODE}.css" colors.css)
    elif [ -f "$SWAYNC_CONFIG/colors-${MODE}.css" ]; then
      (cd "$SWAYNC_CONFIG" && ln -sf "colors-${MODE}.css" colors.css)
    fi
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client -rs 2>/dev/null || swaync-client -R 2>/dev/null || true
    fi
    ;;
  reload)
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client -rs 2>/dev/null || swaync-client -R 2>/dev/null || true
    fi
    ;;
  *)
    echo "Usage: $0 [toggle|open|close|dnd|clear|reload|sync]"
    exit 1
    ;;
esac
