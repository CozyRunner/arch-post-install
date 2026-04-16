#!/usr/bin/env bash

# ─────────────────────────────────────────────
# install_yay.sh — Install yay AUR helper
# ─────────────────────────────────────────────

set -euo pipefail

YAY_REPO="https://aur.archlinux.org/yay.git"

if command -v yay &>/dev/null; then
    echo "[OK] yay is already installed."
    exit 0
fi

echo "[INFO] Installing yay AUR helper..."

# Ensure dependencies
if ! command -v git &>/dev/null; then
    sudo pacman -S --needed --noconfirm git
fi

if ! command -v makepkg &>/dev/null; then
    sudo pacman -S --needed --noconfirm base-devel
fi

# Build in a temporary directory
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "[INFO] Cloning yay repository..."
if ! git clone "${YAY_REPO}" "${TMPDIR}/yay"; then
    echo "[ERROR] Failed to clone yay repository."
    exit 1
fi

cd "${TMPDIR}/yay"

echo "[INFO] Building yay..."
if ! makepkg -si --noconfirm; then
    echo "[ERROR] Failed to build yay."
    exit 1
fi

# Verify installation
if command -v yay &>/dev/null; then
    echo "[OK] yay installed successfully."
else
    echo "[ERROR] yay installation verification failed."
    exit 1
fi
