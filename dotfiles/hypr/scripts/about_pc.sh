#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║                                                                      ║
# ║   ⚡ About This PC — Modernized System Information Dashboard         ║
# ║   Theme: Catppuccin Mocha | Engine: Fastfetch                        ║
# ║                                                                      ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Colors (Catppuccin Mocha)
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'
BOLD='\033[1m'

# Clear terminal for a clean start
clear

echo -e "${BLUE}   ╭─────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${BLUE}   │${BOLD}${CYAN}  󰣇  Arch Linux — System Overview                           ${RESET}${BLUE}│${RESET}"
echo -e "${BLUE}   ╰─────────────────────────────────────────────────────────────╯${RESET}"
echo ""

# Execute Fastfetch with custom config
fastfetch --config ~/.config/fastfetch/about_pc.jsonc

echo ""
echo -e "${BLUE}   ───────────────────────────────────────────────────────────────${RESET}"
echo -e "   ${MAGENTA}󰄛${RESET}  Stay sharp. Stay fast. ${BLUE}󱓞${RESET}"
echo ""

# Keep the window open for the floating terminal
read -r -p "   Press Enter to close..."
