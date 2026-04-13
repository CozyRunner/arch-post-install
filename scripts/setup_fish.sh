#!/usr/bin/env bash

# ─────────────────────────────────────────────
# setup_fish.sh — Install and configure Fish
# ─────────────────────────────────────────────

set -e

echo "[INFO] Setting up Fish..."

# Install fish
sudo pacman -S --needed --noconfirm fish

# Set Fish as default shell
if [[ "$(getent passwd "${USER}" | cut -d: -f7)" != "$(which fish)" ]]; then
    echo "[INFO] Setting Fish as default shell..."
    chsh -s "$(which fish)"
    echo "[OK] Default shell changed to Fish."
else
    echo "[OK] Fish is already the default shell."
fi

# Optional: Install Fisher (plugin manager) and some plugins
if [[ ! -f "${HOME}/.config/fish/functions/fisher.fish" ]]; then
    echo "[INFO] Installing Fisher plugin manager..."
    fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    echo "[OK] Fisher installed."
    
    # Install helpful plugins (like autosuggestions, though fish has it built-in, there are prompt themes like tide or sponge)
    echo "[INFO] Installing tide prompt..."
    fish -c "fisher install IlanCosman/tide@v6"
    echo "[OK] Tide prompt installed."
fi

echo "[OK] Fish setup complete."
