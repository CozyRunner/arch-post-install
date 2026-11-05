#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║          Simple Package Manager (SPM) Launcher               ║
# ║  Interactive Visual Package Browser & Manager for Arch Linux ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Source: https://github.com/adelmonte/Simple_Package_Manager
# Package: spm-arch (AUR)
# Requires: fzf (>= 0.58.0), curl, yay
#
# Launches SPM inside a centered floating terminal window.
# Supports passing subcommands/flags directly (e.g. spm.sh -u, spm.sh -o).

set -euo pipefail

TERM_APP="${TERMINAL:-kitty}"
WINDOW_TITLE="Simple Package Manager (SPM)"
WINDOW_CLASS="large-floating-term"

# ── Launch terminal application with proper flags and detached execution ──
launch_term() {
    local title="$1"
    local class="$2"
    shift 2

    local term_bin
    term_bin="$(command -v "$TERM_APP" 2>/dev/null || command -v kitty 2>/dev/null || command -v alacritty 2>/dev/null || echo "kitty")"

    if [[ "$term_bin" == *"alacritty"* ]]; then
        "$term_bin" --title "$title" --class "$class" -e "$@" & disown
    elif [[ "$term_bin" == *"foot"* ]]; then
        "$term_bin" --title "$title" --app-id "$class" "$@" & disown
    elif [[ "$term_bin" == *"ghostty"* ]]; then
        "$term_bin" --title="$title" --class="$class" -e "$@" & disown
    else
        "$term_bin" --title "$title" --class "$class" "$@" & disown
    fi
}

# ── Check if SPM binary exists ──────────────────────────────────────────
if command -v spm &>/dev/null; then
    launch_term "$WINDOW_TITLE" "$WINDOW_CLASS" spm "$@"
    exit 0
fi

# ── Fallback if not yet installed ───────────────────────────────────────
MSG="SPM (Simple Package Manager) is not installed.\nInstall via AUR: yay -S spm-arch\n\nSource: https://github.com/adelmonte/Simple_Package_Manager"

if command -v notify-send &>/dev/null; then
    notify-send "Simple Package Manager (SPM)" "$MSG" -i software-properties -u normal
fi

echo -e "\033[1;33m[WARN]\033[0m $MSG" >&2
echo ""
read -r -p "Would you like to install spm-arch now via yay? [y/N] " response || true
if [[ "${response,,}" =~ ^(y|yes)$ ]]; then
    if command -v yay &>/dev/null; then
        yay -S --needed spm-arch
        if command -v spm &>/dev/null; then
            exec spm "$@"
        fi
    else
        echo -e "\033[1;31m[ERROR]\033[0m 'yay' AUR helper is not installed. Please install yay first." >&2
        exit 1
    fi
fi

