#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Arch Linux System Update Script
# Full system update using pacman
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

ICON_ARCH="󰣇"
ICON_SYNC="󰚰"
ICON_OK=""
ICON_FAIL=""
ICON_WARN=""

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

print_header() {
  clear

  echo
  echo -e "${BLUE}╭──────────────────────────────────────────────────╮${RESET}"
  echo -e "${BLUE}│${CYAN}  ${ICON_ARCH}  Arch Linux System Update          ${BLUE}│${RESET}"
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

cleanup() {
  echo
  echo -e "${GRAY}Press Enter to close...${RESET}"
  read -r
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

if ! command -v pacman >/dev/null 2>&1; then
  print_error "pacman not found."
  exit 1
fi

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

trap cleanup EXIT

print_header

print_info "Synchronizing package databases..."
echo

START_TIME=$(date +%s)

# --needed avoids reinstalling up-to-date packages
# --noconfirm skips prompts

if sudo pacman -Syu --noconfirm --needed; then
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  echo
  print_success "System updated successfully!"
  echo
  echo -e "${GRAY}Update duration:${RESET} ${DURATION}s"

  send_notification \
    "Arch Linux Update" \
    "System updated successfully." \
    "software-update-available-symbolic"

else
  echo
  print_error "System update failed."
  print_warning "Check the terminal output above."

  send_notification \
    "Arch Linux Update Failed" \
    "System update failed. Check terminal output." \
    "dialog-error-symbolic" \
    "critical"

  exit 1
fi
