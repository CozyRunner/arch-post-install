#!/usr/bin/env bash

# ─────────────────────────────────────────────
# setup_fish.sh — Install and configure Fish
# ─────────────────────────────────────────────

set -euo pipefail

FISHER_URL="https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish"

echo "[INFO] Setting up Fish..."

# Install fish
if ! command -v fish &>/dev/null; then
    sudo pacman -S --needed --noconfirm fish
fi

# Set Fish as default shell
local fish_path
fish_path="$(command -v fish)"
if [[ -n "${fish_path}" && "$(getent passwd "${USER}" | cut -d: -f7)" != "${fish_path}" ]]; then
    echo "[INFO] Setting Fish as default shell..."
    chsh -s "${fish_path}"
    echo "[OK] Default shell changed to Fish."
else
    echo "[OK] Fish is already the default shell."
fi

# Optional: Install Fisher (plugin manager) and some plugins
if [[ ! -f "${HOME}/.config/fish/functions/fisher.fish" ]]; then
    echo "[INFO] Installing Fisher plugin manager..."

    local fisher_dir="${HOME}/.config/fish"
    mkdir -p "${fisher_dir}/functions"

    if curl -sL "${FISHER_URL}" -o "${fisher_dir}/functions/fisher.fish"; then
        echo "[OK] Fisher downloaded."
    else
        echo "[ERROR] Failed to download Fisher."
        exit 1
    fi
fi

# Note: Starship prompt is configured via dotfiles/fish/conf.d/tools.fish
if command -v starship &>/dev/null; then
    echo "[OK] Starship prompt detected."
fi

echo "[OK] Fish setup complete."
