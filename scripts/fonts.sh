#!/usr/bin/env bash

# ─────────────────────────────────────────────
# fonts.sh — Install Nerd Fonts and system fonts
# ─────────────────────────────────────────────

set -euo pipefail

echo "[INFO] Installing fonts..."

# Pacman fonts
sudo pacman -S --needed --noconfirm \
    ttf-jetbrains-mono-nerd \
    ttf-font-awesome \
    noto-fonts \
    noto-fonts-emoji \
    noto-fonts-cjk \
    ttf-liberation \
    ttf-dejavu

# Refresh font cache
echo "[INFO] Refreshing font cache..."
fc-cache -fv

echo "[OK] Fonts installed and cached."
