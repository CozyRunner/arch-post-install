#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Arch Linux System Installation Age Calculator
# Computes elapsed time since the operating system was installed.
# Used by About This PC (Fastfetch) and CLI utilities.
# -----------------------------------------------------------------------------

set -uo pipefail

get_install_epoch() {
  local epoch=""

  # 1. Primary method: First timestamp entry in /var/log/pacman.log
  if [ -r /var/log/pacman.log ]; then
    local first_line raw_ts
    first_line=$(head -n 1 /var/log/pacman.log 2>/dev/null || true)
    raw_ts=$(echo "$first_line" | grep -oP '^\[\K[^\]]+' || true)
    if [ -n "$raw_ts" ]; then
      epoch=$(date -d "$raw_ts" +%s 2>/dev/null || true)
    fi
  fi

  # 2. Fallback: Root filesystem birth / creation time
  if [ -z "$epoch" ] || [ "$epoch" -le 0 ]; then
    local btime
    btime=$(stat -c %W / 2>/dev/null || true)
    if [[ "$btime" =~ ^[0-9]+$ ]] && [ "$btime" -gt 0 ]; then
      epoch=$btime
    fi
  fi

  # 3. Fallback: /etc/machine-id creation or modification time
  if [ -z "$epoch" ] || [ "$epoch" -le 0 ]; then
    local mbtime
    mbtime=$(stat -c %W /etc/machine-id 2>/dev/null || true)
    if [[ "$mbtime" =~ ^[0-9]+$ ]] && [ "$mbtime" -gt 0 ]; then
      epoch=$mbtime
    else
      local mmtime
      mmtime=$(stat -c %Y /etc/machine-id 2>/dev/null || true)
      if [[ "$mmtime" =~ ^[0-9]+$ ]] && [ "$mmtime" -gt 0 ]; then
        epoch=$mmtime
      fi
    fi
  fi

  # 4. Fallback: /var/log/pacman.log modification time
  if [ -z "$epoch" ] || [ "$epoch" -le 0 ]; then
    if [ -e /var/log/pacman.log ]; then
      local pmtime
      pmtime=$(stat -c %Y /var/log/pacman.log 2>/dev/null || true)
      if [[ "$pmtime" =~ ^[0-9]+$ ]] && [ "$pmtime" -gt 0 ]; then
        epoch=$pmtime
      fi
    fi
  fi

  echo "${epoch:-0}"
}

format_human_breakdown() {
  local days="$1"
  local years=$(( days / 365 ))
  local rem_days=$(( days % 365 ))
  local months=$(( rem_days / 30 ))
  local final_days=$(( rem_days % 30 ))

  local parts=()
  if [ "$years" -gt 0 ]; then
    [ "$years" -eq 1 ] && parts+=("1 year") || parts+=("${years} years")
  fi
  if [ "$months" -gt 0 ]; then
    [ "$months" -eq 1 ] && parts+=("1 month") || parts+=("${months} months")
  fi
  if [ "$final_days" -gt 0 ] || [ ${#parts[@]} -eq 0 ]; then
    [ "$final_days" -eq 1 ] && parts+=("1 day") || parts+=("${final_days} days")
  fi

  local human=""
  for p in "${parts[@]}"; do
    [ -n "$human" ] && human="${human}, ${p}" || human="${p}"
  done

  echo "$human"
}

show_usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Calculate and display the age since Arch Linux installation.

Options:
  -d, --days      Print total days only (e.g. "72 days")
  -H, --human     Print human breakdown only (e.g. "2 months, 12 days")
  -s, --short     Print compact format (e.g. "72d")
      --date      Print original installation date (YYYY-MM-DD)
      --epoch     Print raw unix epoch timestamp
  -h, --help      Display this help message and exit

Default output:
  Total days with human breakdown if >= 30 days (e.g. "72 days (2 months, 12 days)").
EOF
}

main() {
  local mode="default"

  while [ $# -gt 0 ]; do
    case "$1" in
      -d|--days)
        mode="days"
        shift
        ;;
      -H|--human)
        mode="human"
        shift
        ;;
      -s|--short)
        mode="short"
        shift
        ;;
      --date)
        mode="date"
        shift
        ;;
      --epoch)
        mode="epoch"
        shift
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        show_usage >&2
        exit 1
        ;;
    esac
  done

  local install_epoch
  install_epoch=$(get_install_epoch)

  if [ -z "$install_epoch" ] || [ "$install_epoch" -le 0 ]; then
    echo "Unknown"
    exit 0
  fi

  if [ "$mode" = "epoch" ]; then
    echo "$install_epoch"
    exit 0
  fi

  if [ "$mode" = "date" ]; then
    date -d @"$install_epoch" "+%Y-%m-%d" 2>/dev/null || echo "Unknown"
    exit 0
  fi

  local now_epoch diff days
  now_epoch=$(date +%s)
  diff=$(( now_epoch - install_epoch ))

  if [ "$diff" -lt 0 ]; then
    days=0
  else
    days=$(( diff / 86400 ))
  fi

  case "$mode" in
    days)
      if [ "$days" -eq 1 ]; then
        echo "1 day"
      else
        echo "${days} days"
      fi
      ;;
    short)
      echo "${days}d"
      ;;
    human)
      format_human_breakdown "$days"
      ;;
    default)
      if [ "$days" -eq 0 ]; then
        echo "0 days (today)"
      elif [ "$days" -eq 1 ]; then
        echo "1 day"
      elif [ "$days" -lt 30 ]; then
        echo "${days} days"
      else
        local human
        human=$(format_human_breakdown "$days")
        echo "${days} days (${human})"
      fi
      ;;
  esac
}

main "$@"
