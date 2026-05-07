#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# AUR Package Update Script
# Updates only AUR packages using yay
# -----------------------------------------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------

RESET="\033[0m"

BLUE="\033[1;34m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
GRAY="\033[1;90m"

# -----------------------------------------------------------------------------
# Icons
# -----------------------------------------------------------------------------

ICON_AUR="󰣇"
ICON_OK=""
ICON_FAIL=""
ICON_SYNC="󰚰"
ICON_WARN=""

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

print_header() {
  clear

  echo
  echo -e "${BLUE}╭──────────────────────────────────────────────────╮${RESET}"
  echo -e "${BLUE}│${CYAN}  ${ICON_AUR}  AUR Packages Update                ${BLUE}│${RESET}"
  echo -e "${BLUE}╰──────────────────────────────────────────────────╯${RESET}"
  echo
}

print_info() {
  echo -e "${YELLOW}${ICON_SYNC}  $1${RESET}"
}

print_success() {
  echo -e "${GREEN}${ICON_OK}  $1${RESET}"
}

print_error() {
  echo -e "${RED}${ICON_FAIL}  $1${RESET}"
}

print_warning() {
  echo -e "${MAGENTA}${ICON_WARN}  $1${RESET}"
}

cleanup() {
  echo
  echo -e "${GRAY}Press Enter to close...${RESET}"
  read -r
}

send_notification() {
  local title="$1"
  local message="$2"
  local icon="$3"
  local urgency="${4:-normal}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$message" \
      -i "$icon" \
      -u "$urgency"
  fi
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

if ! command -v yay >/dev/null 2>&1; then
  print_error "yay is not installed."

  echo
  echo -e "${GRAY}Install yay first before running this script.${RESET}"

  exit 1
fi

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

trap cleanup EXIT

print_header

print_info "Checking and updating AUR packages only..."
echo

START_TIME=$(date +%s)

# --aur      -> only AUR packages
# --devel    -> update development packages
# --timeupdate -> check git package updates properly

if yay -Sua --aur --devel --timeupdate --noconfirm; then
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  echo
  print_success "AUR packages updated successfully!"
  echo
  echo -e "${GRAY}Update duration:${RESET} ${DURATION}s"

  send_notification \
    "AUR Update" \
    "AUR packages updated successfully." \
    "software-update-available-symbolic"

else
  echo
  print_error "AUR update failed."
  print_warning "Check the output above for details."

  send_notification \
    "AUR Update Failed" \
    "AUR package update failed." \
    "dialog-error-symbolic" \
    "critical"

  exit 1
fi
