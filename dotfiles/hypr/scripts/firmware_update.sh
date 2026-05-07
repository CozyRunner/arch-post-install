#!/usr/bin/env bash
# fwupdater.sh — check firmware updates, prompt, install, log
set -euo pipefail
IFS=$'\n\t'

LOG="/var/log/fw-update-check.log"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

timestamp() { date --iso-8601=seconds; }

# Ensure fwupdmgr exists
if ! command -v fwupdmgr >/dev/null 2>&1; then
  echo "fwupdmgr not found; please install fwupd" >&2
  exit 2
fi

# Refresh metadata
echo "$(timestamp) - Refreshing fwupd metadata" | tee -a "$LOG"
if ! sudo fwupdmgr refresh 2>&1 | tee "$TMP" >>"$LOG"; then
  echo "$(timestamp) - REFRESH FAILED; see $LOG" | tee -a "$LOG"
  exit 3
fi

# Get updates (machine-readable)
echo "$(timestamp) - Checking for updates" | tee -a "$LOG"
if ! sudo fwupdmgr get-updates --show-all --json >"$TMP" 2>>"$LOG"; then
  echo "$(timestamp) - GET-UPDATES FAILED; see $LOG" | tee -a "$LOG"
  exit 4
fi

# Parse JSON summary (jq recommended)
if command -v jq >/dev/null 2>&1; then
  updates_count=$(jq '.Devices | map(.Updates // []) | map(length) | add' <"$TMP")
  if [ "${updates_count:-0}" -eq 0 ]; then
    echo "$(timestamp) - No firmware updates available" | tee -a "$LOG"
    exit 0
  fi

  echo "Available firmware updates:"
  jq -r '.Devices[] | select(.Updates) | "\(.Vendor) \(.DeviceId) \(.DeviceVersion) -> \(.Updates[] | .Version) (\(.Updates[] | .title // ""))"' <"$TMP" | tee -a "$LOG"
else
  # Fallback: human-readable list
  sudo fwupdmgr get-updates --show-all | tee -a "$LOG"
  # crude check for presence of "No supported devices found" or "up to date"
  if sudo fwupdmgr get-updates --show-all | grep -qiE 'No supported devices found|up to date'; then
    echo "$(timestamp) - No firmware updates available" | tee -a "$LOG"
    exit 0
  fi
fi

# Prompt for confirmation (interactive)
read -r -p "Install available firmware updates now? [y/N] " resp
resp=${resp:-N}
case "$resp" in
[yY] | [yY][eE][sS])
  echo "$(timestamp) - User approved installation" | tee -a "$LOG"
  ;;
*)
  echo "$(timestamp) - User declined installation" | tee -a "$LOG"
  exit 0
  ;;
esac

# Run update
echo "$(timestamp) - Starting firmware update (may require reboot)" | tee -a "$LOG"
if sudo fwupdmgr update 2>&1 | tee -a "$LOG"; then
  echo "$(timestamp) - fwupdmgr update completed successfully" | tee -a "$LOG"
else
  echo "$(timestamp) - fwupdmgr update encountered errors; check $LOG" | tee -a "$LOG"
  exit 5
fi

# Check for pending reboot (fwupd reports a "reboot" requirement)
if sudo fwupdmgr get-devices --json 2>/dev/null | (jq -e '.Devices | map(select(.HasUpdate==true or .RebootNeeded==true)) | length > 0' >/dev/null 2>&1); then
  echo "$(timestamp) - One or more updates require reboot" | tee -a "$LOG"
  read -r -p "Reboot now to apply updates? [y/N] " r2
  r2=${r2:-N}
  case "$r2" in
  [yY] | [yY][eE][sS])
    echo "$(timestamp) - Rebooting now (user approved)" | tee -a "$LOG"
    sudo systemctl reboot
    ;;
  *)
    echo "$(timestamp) - Reboot postponed by user" | tee -a "$LOG"
    ;;
  esac
else
  echo "$(timestamp) - No reboot required" | tee -a "$LOG"
fi

exit 0
