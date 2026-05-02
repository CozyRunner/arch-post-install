#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Arch Linux Update Checker
# Lists available updates for pacman + AUR packages
# -----------------------------------------------------------------------------

set -uo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------

RESET="\033[0m"

BLUE="\033[1;34m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
GRAY="\033[1;90m"

# -----------------------------------------------------------------------------
# Icons
# -----------------------------------------------------------------------------

ICON_ARCH="󰣇"
ICON_CHECK="󰚰"
ICON_OK=""
ICON_WARN=""
ICON_PACKAGE="󰏖"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

print_header() {
  clear

  echo
  echo -e "${BLUE}╭──────────────────────────────────────────────────╮${RESET}"
  echo -e "${BLUE}│${CYAN}  ${ICON_ARCH}  Arch Linux Update Checker         ${BLUE}│${RESET}"
  echo -e "${BLUE}╰──────────────────────────────────────────────────╯${RESET}"
  echo
}

print_info() {
  echo -e "${YELLOW}${ICON_CHECK}  $1${RESET}"
}

print_success() {
  echo -e "${GREEN}${ICON_OK}  $1${RESET}"
}

print_warning() {
  echo -e "${RED}${ICON_WARN}  $1${RESET}"
}

pause_exit() {
  echo
  echo -e "${GRAY}Press any key to exit...${RESET}"
  read -rn 1
  echo
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

print_header

if ! command -v checkupdates >/dev/null 2>&1; then
  print_warning "Missing package: pacman-contrib"
  echo
  echo -e "${GRAY}Install it using:${RESET}"
  echo "sudo pacman -S pacman-contrib"

  pause_exit
  exit 1
fi

if ! command -v yay >/dev/null 2>&1; then
  print_warning "yay is not installed."

  pause_exit
  exit 1
fi

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

print_info "Checking official repository updates..."
echo

PACMAN_UPDATES=$(checkupdates 2>/dev/null || true)

if [[ -n "${PACMAN_UPDATES}" ]]; then
  echo -e "${CYAN}${ICON_PACKAGE}  Official Repository Updates:${RESET}"
  echo
  echo "${PACMAN_UPDATES}"
else
  print_success "No official repository updates available."
fi

echo
print_info "Checking AUR updates..."
echo

AUR_UPDATES=$(yay -Qua 2>/dev/null || true)

if [[ -n "${AUR_UPDATES}" ]]; then
  echo -e "${CYAN}${ICON_PACKAGE}  AUR Package Updates:${RESET}"
  echo
  echo "${AUR_UPDATES}"
else
  print_success "No AUR updates available."
fi

echo

TOTAL_UPDATES=$(
  (
    echo "${PACMAN_UPDATES}"
    echo "${AUR_UPDATES}"
  ) | sed '/^$/d' | wc -l
)

if [[ "${TOTAL_UPDATES}" -gt 0 ]]; then
  echo -e "${YELLOW}${ICON_CHECK}  Total available updates: ${TOTAL_UPDATES}${RESET}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send \
      "Arch Linux Updates" \
      "${TOTAL_UPDATES} updates available." \
      -i software-update-available-symbolic
  fi
else
  print_success "System is fully up to date."

  if command -v notify-send >/dev/null 2>&1; then
    notify-send \
      "Arch Linux Updates" \
      "System is fully up to date." \
      -i dialog-information-symbolic
  fi
fi

pause_exit
