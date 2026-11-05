#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║             TUI Applications Hub & Launcher                  ║
# ║    Interactive Selector & Runner for Terminal UI Tools       ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   tui_app.sh menu                  # Interactive Rofi selection menu
#   tui_app.sh <app_name> [args...]  # Launch specific TUI app in floating term
#
# Supported apps:
#   spm, btop, htop, yazi, superfile, lazygit, lazydocker,
#   calcure, tui-journal, ncdu, dust, posting, wiremix, impala, bluetui, zellij

set -euo pipefail

TERM_APP="${TERMINAL:-kitty}"
ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/floating-menu.rasi}"

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

# ── Notify when tool is missing ─────────────────────────────────────────
notify_missing() {
    local name="$1"
    local pkg="$2"
    local repo="${3:-pacman}"
    local install_cmd
    if [[ "$repo" == "aur" ]]; then
        install_cmd="yay -S $pkg"
    else
        install_cmd="sudo pacman -S $pkg"
    fi

    if command -v notify-send &>/dev/null; then
        notify-send "$name" "Not installed. Install via:\n$install_cmd" -i dialog-warning -u normal
    fi
    echo -e "\033[1;33m[WARN]\033[0m $name is not installed. Install via: $install_cmd" >&2
}

# ── Run specific TUI app ────────────────────────────────────────────────
run_app() {
    local app="$1"
    shift || true

    case "$app" in
        spm)
            if command -v spm &>/dev/null; then
                launch_term "Simple Package Manager (SPM)" "large-floating-term" spm "$@"
            else
                notify_missing "SPM (Simple Package Manager)" "spm-arch" "aur"
            fi
            ;;
        btop)
            if command -v btop &>/dev/null; then
                launch_term "System Monitor (btop)" "large-floating-term" btop "$@"
            elif command -v htop &>/dev/null; then
                launch_term "System Monitor (htop)" "large-floating-term" htop "$@"
            else
                notify_missing "btop" "btop" "pacman"
            fi
            ;;
        htop)
            if command -v htop &>/dev/null; then
                launch_term "Process Viewer (htop)" "large-floating-term" htop "$@"
            else
                notify_missing "htop" "htop" "pacman"
            fi
            ;;
        yazi)
            if command -v yazi &>/dev/null; then
                launch_term "File Manager (Yazi)" "large-floating-term" yazi "$@"
            else
                notify_missing "Yazi" "yazi" "pacman"
            fi
            ;;
        superfile|spf)
            if command -v superfile &>/dev/null; then
                launch_term "File Manager (superfile)" "large-floating-term" superfile "$@"
            elif command -v spf &>/dev/null; then
                launch_term "File Manager (superfile)" "large-floating-term" spf "$@"
            else
                notify_missing "superfile" "superfile" "pacman"
            fi
            ;;
        lazygit)
            if command -v lazygit &>/dev/null; then
                launch_term "Git Client (lazygit)" "large-floating-term" lazygit "$@"
            else
                notify_missing "lazygit" "lazygit" "pacman"
            fi
            ;;
        lazydocker)
            if command -v lazydocker &>/dev/null; then
                launch_term "Docker Manager (lazydocker)" "large-floating-term" lazydocker "$@"
            else
                notify_missing "lazydocker" "lazydocker" "pacman"
            fi
            ;;
        calcure)
            if command -v calcure &>/dev/null; then
                launch_term "Calendar & Tasks (Calcure)" "large-floating-term" calcure "$@"
            else
                notify_missing "Calcure" "calcure" "aur"
            fi
            ;;
        tjournal|tui-journal)
            if command -v tjournal &>/dev/null; then
                launch_term "Journal & Notes (tui-journal)" "large-floating-term" tjournal "$@"
            elif command -v tui-journal &>/dev/null; then
                launch_term "Journal & Notes (tui-journal)" "large-floating-term" tui-journal "$@"
            else
                notify_missing "tui-journal" "tui-journal" "pacman"
            fi
            ;;
        ncdu)
            if command -v ncdu &>/dev/null; then
                launch_term "Disk Analyzer (ncdu)" "large-floating-term" ncdu --exclude-kernfs /
            else
                notify_missing "ncdu" "ncdu" "pacman"
            fi
            ;;
        dust)
            if command -v dust &>/dev/null; then
                launch_term "Disk Usage (dust)" "large-floating-term" bash -c "dust /; read -r -p 'Press Enter to close...'"
            else
                notify_missing "dust" "dust" "pacman"
            fi
            ;;
        posting)
            if command -v posting &>/dev/null; then
                launch_term "REST & API Client (posting)" "large-floating-term" posting "$@"
            else
                notify_missing "posting" "posting" "aur"
            fi
            ;;
        wiremix)
            if command -v wiremix &>/dev/null; then
                launch_term "Audio Mixer (WireMix)" "large-floating-term" wiremix "$@"
            elif command -v pulsemixer &>/dev/null; then
                launch_term "Audio Mixer (pulsemixer)" "large-floating-term" pulsemixer "$@"
            else
                notify_missing "WireMix" "wiremix" "aur"
            fi
            ;;
        impala)
            if command -v impala &>/dev/null; then
                launch_term "Network Manager (Impala)" "large-floating-term" impala "$@"
            elif command -v nmtui &>/dev/null; then
                launch_term "Network Manager (nmtui)" "large-floating-term" nmtui "$@"
            else
                notify_missing "Impala" "impala" "pacman"
            fi
            ;;
        bluetui)
            if command -v bluetui &>/dev/null; then
                launch_term "Bluetooth Manager (Bluetui)" "large-floating-term" bluetui "$@"
            elif command -v bluetoothctl &>/dev/null; then
                launch_term "Bluetooth Settings" "large-floating-term" bluetoothctl
            else
                notify_missing "Bluetui" "bluetui" "pacman"
            fi
            ;;
        zellij)
            if command -v zellij &>/dev/null; then
                launch_term "Workspace Multiplexer (Zellij)" "large-floating-term" zellij "$@"
            else
                notify_missing "Zellij" "zellij" "pacman"
            fi
            ;;
        *)
            echo "Unknown TUI application: $app" >&2
            echo "Available: spm, btop, htop, yazi, superfile, lazygit, lazydocker, calcure, tjournal, ncdu, dust, posting, wiremix, impala, bluetui, zellij" >&2
            exit 1
            ;;
    esac
}

# ── Interactive Menu Selector ───────────────────────────────────────────
show_menu() {
    local options="󰏗  Package Manager (SPM)
󰇧  System Monitor (btop)
  Git Client (lazygit)
󰡨  Docker Manager (lazydocker)
  File Manager (Yazi)
󰋊  Disk Analyzer (ncdu)
  Calendar & Tasks (Calcure)
󰠮  Journal & Notes (tui-journal)
󰛳  REST & API Client (posting)
󰓃  Audio Mixer (WireMix)
󰖩  Network Manager (Impala)
󰂯  Bluetooth Devices (Bluetui)
󰆍  Multiplexer (Zellij)"

    local choice=""
    choice=$(echo -e "$options" | rofi -dmenu -i \
        -p "💻 TUI Apps" \
        -mesg "  Interactive Terminal User Interfaces" \
        -theme "$ROFI_THEME") || true

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Package Manager"*|*"SPM"*)
            run_app spm
            ;;
        *"System Monitor"*|*"btop"*)
            run_app btop
            ;;
        *"Git Client"*|*"lazygit"*)
            run_app lazygit
            ;;
        *"Docker Manager"*|*"lazydocker"*)
            run_app lazydocker
            ;;
        *"File Manager"*|*"Yazi"*)
            run_app yazi
            ;;
        *"Disk Analyzer"*|*"ncdu"*)
            run_app ncdu
            ;;
        *"Calendar"*|*"Calcure"*)
            run_app calcure
            ;;
        *"Journal"*|*"tui-journal"*)
            run_app tjournal
            ;;
        *"REST"*|*"posting"*)
            run_app posting
            ;;
        *"Audio Mixer"*|*"WireMix"*)
            run_app wiremix
            ;;
        *"Network Manager"*|*"Impala"*)
            run_app impala
            ;;
        *"Bluetooth"*|*"Bluetui"*)
            run_app bluetui
            ;;
        *"Multiplexer"*|*"Zellij"*)
            run_app zellij
            ;;
    esac
}

# ── Main Dispatcher ─────────────────────────────────────────────────────
ACTION="${1:-menu}"
if [[ "$ACTION" == "menu" ]]; then
    show_menu
else
    run_app "$@"
fi

