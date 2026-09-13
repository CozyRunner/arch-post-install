#!/usr/bin/env bash
# ============================================================
# apply-gtk-settings.sh
# Restores GTK theme settings persisted by nwg-look at login.
#
# nwg-look writes settings to THREE places:
#   1. dconf  (org.gnome.desktop.interface)        ← source of truth
#   2. ~/.config/gtk-3.0/settings.ini              ← GTK3 apps
#   3. ~/.config/gtk-4.0/settings.ini              ← GTK4 apps
#   4. ~/.gtkrc-2.0                                ← legacy GTK2
#   5. ~/.config/xsettingsd/xsettingsd.conf        ← X11 broadcast
#
# This script reads dconf and re-emits the values so every
# subsystem is in sync on every Hyprland login.
# ============================================================

set -euo pipefail

# ── Read persisted values from dconf ─────────────────────────
GTK_THEME_NAME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)
FONT_NAME=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'")
COLOR_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")

# Fallback defaults (matches nwg-look's defaults)
GTK_THEME_NAME="${GTK_THEME_NAME:-Adwaita-dark}"
ICON_THEME="${ICON_THEME:-Papirus-Dark}"
CURSOR_THEME="${CURSOR_THEME:-default}"
CURSOR_SIZE="${CURSOR_SIZE:-24}"
FONT_NAME="${FONT_NAME:-Adwaita Sans 11}"
COLOR_SCHEME="${COLOR_SCHEME:-prefer-dark}"

# ── Re-apply via gsettings (no-op if already set, but ensures ─
# ── all dconf keys are consistent with settings.ini)         ─
gsettings set org.gnome.desktop.interface gtk-theme     "${GTK_THEME_NAME}"
gsettings set org.gnome.desktop.interface icon-theme    "${ICON_THEME}"
gsettings set org.gnome.desktop.interface cursor-theme  "${CURSOR_THEME}"
gsettings set org.gnome.desktop.interface cursor-size   "${CURSOR_SIZE}"
gsettings set org.gnome.desktop.interface font-name     "${FONT_NAME}"
gsettings set org.gnome.desktop.interface color-scheme  "${COLOR_SCHEME}"

# ── Set XCURSOR_THEME/SIZE via Hyprland env for Wayland apps ─
# (cursor env must match what nwg-look saved)
hyprctl --batch "\
    dispatch nop ;\
    keyword env XCURSOR_THEME,${CURSOR_THEME} ;\
    keyword env XCURSOR_SIZE,${CURSOR_SIZE}" 2>/dev/null || true

# ── Reload/start xsettingsd to broadcast settings to X11 apps─
# xsettingsd reads ~/.config/xsettingsd/xsettingsd.conf which
# nwg-look writes automatically when you apply settings.
if command -v xsettingsd &>/dev/null; then
    # Kill any stale instance then relaunch so it re-reads conf
    pkill -x xsettingsd 2>/dev/null || true
    sleep 0.1
    xsettingsd -c "${HOME}/.config/xsettingsd/xsettingsd.conf" &
    disown
fi
