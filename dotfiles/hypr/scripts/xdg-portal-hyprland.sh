#!/usr/bin/env bash
# xdg-portal-hyprland.sh
# Restarts XDG desktop portals cleanly using systemd user services.
# Called once at Hyprland startup via exec-once in autostart.conf.

set -euo pipefail

# Stop any running instances gracefully
systemctl --user stop \
    xdg-desktop-portal-hyprland.service \
    xdg-desktop-portal-gtk.service \
    xdg-desktop-portal.service 2>/dev/null || true

# Start Hyprland-specific portal first (it must be ready before the main portal)
systemctl --user start xdg-desktop-portal-hyprland.service

# Give the Hyprland portal a moment to register on the session bus
sleep 0.5

# Start the main portal aggregator (picks up hyprland portal automatically)
systemctl --user start xdg-desktop-portal.service
