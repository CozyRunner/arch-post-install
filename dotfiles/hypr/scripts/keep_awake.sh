#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║             Keep Awake — System Sleep Inhibitor              ║
# ║  Temporarily prevent sleep/suspend · Display turns off OK   ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Features:
#   - Inhibits system sleep/suspend for a user-specified duration.
#   - Keeps system awake while allowing display to turn off normally on idle.
#   - Uses systemd-inhibit with mode=block; no permanent config changes.
#   - Automatically restores default power/sleep behavior when timer expires.
#   - Can be manually disabled at any time before timer expires.
#   - Waybar status module and interactive Rofi duration menu.
#
# Usage:
#   keep_awake.sh on [duration]    # Activate (e.g. 15m, 30m, 1h, 2h, 4h; default: 1h)
#   keep_awake.sh off              # Disable immediately and restore normal sleep
#   keep_awake.sh toggle [dur]     # Toggle on/off
#   keep_awake.sh status [--json]  # Print current status
#   keep_awake.sh is-active        # Exit 0 if active, 1 if not
#   keep_awake.sh waybar           # Waybar JSON output
#   keep_awake.sh menu             # Interactive Rofi duration picker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/keep_awake"
if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
    STATE_DIR="/tmp/keep-awake-${UID:-1000}"
    mkdir -p "$STATE_DIR" 2>/dev/null || true
fi
PID_FILE="${STATE_DIR}/inhibitor.pid"
META_FILE="${STATE_DIR}/state.json"

ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/floating-menu.rasi"
if [[ ! -f "$ROFI_THEME" ]]; then
    REPO_THEME="$(cd "$SCRIPT_DIR/../../rofi" 2>/dev/null && pwd)/floating-menu.rasi"
    [[ -f "$REPO_THEME" ]] && ROFI_THEME="$REPO_THEME"
fi

update_waybar() {
    pkill -RTMIN+8 waybar 2>/dev/null || true
}

# Parse duration string (e.g. 15m, 1h, 90m, 1h30m, 30) into seconds
parse_duration() {
    local input="${1:-1h}"
    [[ -z "$input" ]] && return 1

    local total_sec=0
    # Pure integer defaults to minutes
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        echo $(( input * 60 ))
        return 0
    fi

    local remaining="$input"
    local matched=0

    if [[ "$remaining" =~ ([0-9]+)h ]]; then
        total_sec=$(( total_sec + BASH_REMATCH[1] * 3600 ))
        remaining="${remaining//${BASH_REMATCH[0]}/}"
        matched=1
    fi
    if [[ "$remaining" =~ ([0-9]+)m ]]; then
        total_sec=$(( total_sec + BASH_REMATCH[1] * 60 ))
        remaining="${remaining//${BASH_REMATCH[0]}/}"
        matched=1
    fi
    if [[ "$remaining" =~ ([0-9]+)s ]]; then
        total_sec=$(( total_sec + BASH_REMATCH[1] ))
        remaining="${remaining//${BASH_REMATCH[0]}/}"
        matched=1
    fi

    if (( matched == 1 && total_sec > 0 )); then
        echo "$total_sec"
        return 0
    fi

    return 1
}

# Format seconds into friendly human duration
format_time_remaining() {
    local rem_sec="$1"
    if (( rem_sec <= 0 )); then
        echo "0m"
        return 0
    fi

    local hours=$(( rem_sec / 3600 ))
    local mins=$(( (rem_sec % 3600) / 60 ))
    local secs=$(( rem_sec % 60 ))

    if (( hours > 0 )); then
        if (( mins > 0 )); then
            echo "${hours}h ${mins}m"
        else
            echo "${hours}h"
        fi
    elif (( mins > 0 )); then
        echo "${mins}m"
    else
        echo "${secs}s"
    fi
}

# Check if an inhibitor instance is currently running and valid
is_active() {
    if [[ -f "$PID_FILE" && -f "$META_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            local end_epoch
            end_epoch=$(jq -r '.end_epoch // 0' "$META_FILE" 2>/dev/null || echo 0)
            local now
            now=$(date +%s)
            if (( end_epoch > now )); then
                return 0
            fi
        fi
    fi
    return 1
}

# Internal background runner that holds the systemd-inhibit lock
_run_inhibitor() {
    local duration_sec="$1"
    local end_epoch="$2"
    local human_duration="$3"
    local end_time_human="$4"

    cleanup() {
        rm -f "$PID_FILE" "$META_FILE"
        update_waybar
    }
    trap cleanup EXIT INT TERM

    # Block sleep while explicitly allowing display idle & dpms timeouts
    if command -v systemd-inhibit &>/dev/null; then
        systemd-inhibit \
            --what=sleep:handle-suspend-key:handle-lid-switch \
            --who="KeepAwake" \
            --why="Temporary sleep prevention until ${end_time_human} while allowing display to turn off" \
            --mode=block \
            sleep "$duration_sec" 2>/dev/null || sleep "$duration_sec"
    else
        sleep "$duration_sec"
    fi

    # If ran to normal completion (not terminated early by off), send expiration notification
    local now
    now=$(date +%s)
    if (( now >= end_epoch - 2 )); then
        if command -v notify-send &>/dev/null; then
            notify-send "Keep Awake Expired" \
                "Configured period (${human_duration}) has ended.\nNormal system sleep behavior restored." \
                -i preferences-system-time -u normal 2>/dev/null || true
        fi
    fi
}

start_awake() {
    local duration_input="${1:-1h}"
    local duration_sec
    duration_sec=$(parse_duration "$duration_input") || {
        echo "Error: Invalid duration '$duration_input'. Use format like: 30m, 1h, 2h, 90m" >&2
        return 1
    }

    # Stop any running instance cleanly
    stop_awake --quiet

    local start_epoch
    start_epoch=$(date +%s)
    local end_epoch=$(( start_epoch + duration_sec ))
    local end_time_human
    end_time_human=$(date -d "@${end_epoch}" +'%H:%M' 2>/dev/null || date -r "${end_epoch}" +'%H:%M')
    local human_duration
    human_duration=$(format_time_remaining "$duration_sec")

    mkdir -p "$STATE_DIR"

    # Start inhibitor in background via internal _run
    "$0" _run "$duration_sec" "$end_epoch" "$human_duration" "$end_time_human" >/dev/null 2>&1 &
    local runner_pid=$!

    cat <<EOF > "$META_FILE"
{
  "pid": $runner_pid,
  "start_epoch": $start_epoch,
  "end_epoch": $end_epoch,
  "duration_sec": $duration_sec,
  "duration_human": "$human_duration",
  "end_time_human": "$end_time_human"
}
EOF
    echo "$runner_pid" > "$PID_FILE"

    if command -v notify-send &>/dev/null; then
        notify-send "Keep Awake Active" \
            "System sleep prevented for ${human_duration} (until ${end_time_human}).\nDisplay will still turn off normally on idle." \
            -i preferences-system-time -u normal 2>/dev/null || true
    fi

    update_waybar

    echo "Keep Awake activated for ${human_duration} (until ${end_time_human})."
    echo "System sleep is blocked; monitor/display will still turn off normally."
}

stop_awake() {
    local quiet="${1:-}"
    if is_active; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]]; then
            kill -TERM "$pid" 2>/dev/null || true
            pkill -P "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE" "$META_FILE"
        update_waybar

        if [[ "$quiet" != "--quiet" ]]; then
            if command -v notify-send &>/dev/null; then
                notify-send "Keep Awake Disabled" \
                    "Normal system sleep behavior restored." \
                    -i preferences-system-time -u normal 2>/dev/null || true
            fi
            echo "Keep Awake disabled. Normal system sleep behavior restored."
        fi
    else
        rm -f "$PID_FILE" "$META_FILE"
        update_waybar
        if [[ "$quiet" != "--quiet" ]]; then
            echo "Keep Awake is not active."
        fi
    fi
}

toggle_awake() {
    local duration="${1:-1h}"
    if is_active; then
        stop_awake
    else
        start_awake "$duration"
    fi
}

status_awake() {
    local as_json="${1:-}"
    if is_active; then
        local end_epoch
        end_epoch=$(jq -r '.end_epoch // 0' "$META_FILE" 2>/dev/null || echo 0)
        local end_time_human
        end_time_human=$(jq -r '.end_time_human // ""' "$META_FILE" 2>/dev/null || echo "")
        local human_duration
        human_duration=$(jq -r '.duration_human // ""' "$META_FILE" 2>/dev/null || echo "")
        local now
        now=$(date +%s)
        local remaining_sec=$(( end_epoch - now ))
        (( remaining_sec < 0 )) && remaining_sec=0
        local remaining_human
        remaining_human=$(format_time_remaining "$remaining_sec")

        if [[ "$as_json" == "--json" ]]; then
            jq -nc \
                --argjson active true \
                --argjson remaining_sec "$remaining_sec" \
                --arg remaining_human "$remaining_human" \
                --arg end_time_human "$end_time_human" \
                --arg duration_human "$human_duration" \
                '{active: $active, remaining_sec: $remaining_sec, remaining_human: $remaining_human, end_time: $end_time_human, duration: $duration_human}'
        else
            echo "Keep Awake: ACTIVE"
            echo "Duration:   ${human_duration}"
            echo "Remaining:  ${remaining_human}"
            echo "Expires at: ${end_time_human}"
            echo "Behavior:   System sleep/suspend is prevented. Display turns off normally."
        fi
    else
        if [[ "$as_json" == "--json" ]]; then
            jq -nc \
                --argjson active false \
                --argjson remaining_sec 0 \
                --arg remaining_human "0m" \
                '{active: $active, remaining_sec: $remaining_sec, remaining_human: $remaining_human}'
        else
            echo "Keep Awake: INACTIVE"
            echo "Behavior:   Normal system power and sleep settings apply."
        fi
    fi
}

waybar_output() {
    if is_active; then
        local end_epoch
        end_epoch=$(jq -r '.end_epoch // 0' "$META_FILE" 2>/dev/null || echo 0)
        local end_time_human
        end_time_human=$(jq -r '.end_time_human // ""' "$META_FILE" 2>/dev/null || echo "")
        local now
        now=$(date +%s)
        local remaining_sec=$(( end_epoch - now ))
        (( remaining_sec < 0 )) && remaining_sec=0
        local remaining_human
        remaining_human=$(format_time_remaining "$remaining_sec")

        local tooltip="<span weight='bold' size='110%' foreground='#818cf8'>󰅶 Keep Awake (Active)</span>\n<b>Expires:</b> ${end_time_human} (${remaining_human} remaining)\n<small foreground='#94a3b8'>System sleep is blocked. Display will turn off normally.</small>\n\n<b>Actions:</b>\n  󰍽 <b>Left Click:</b> Open Duration Menu\n  󰍾 <b>Right Click:</b> Disable / Allow Sleep"

        jq -nc \
            --arg text "󰅶 ${remaining_human}" \
            --arg alt "active" \
            --arg tooltip "$tooltip" \
            --arg class "active" \
            '{text: $text, alt: $alt, tooltip: $tooltip, class: $class}'
    else
        local tooltip="<span weight='bold' size='110%' foreground='#94a3b8'>󰒲 Keep Awake (Inactive)</span>\n<small foreground='#94a3b8'>System sleep follows normal power settings.</small>\n\n<b>Actions:</b>\n  󰍽 <b>Left Click:</b> Open Duration Menu\n  󰍾 <b>Right Click:</b> Quick 1h Keep Awake"

        jq -nc \
            --arg text "󰒲" \
            --arg alt "inactive" \
            --arg tooltip "$tooltip" \
            --arg class "inactive" \
            '{text: $text, alt: $alt, tooltip: $tooltip, class: $class}'
    fi
}

prompt_custom_duration() {
    local custom=""
    if command -v rofi &>/dev/null; then
        custom=$(echo "" | rofi -dmenu -p "󱎫 Duration" \
            -mesg "  Enter duration (e.g. 45m, 90m, 1h30m, 3h):" \
            -theme "$ROFI_THEME") || true
    fi

    if [[ -n "$custom" ]]; then
        start_awake "$custom"
    fi
}

show_menu() {
    if ! command -v rofi &>/dev/null; then
        echo "Rofi is required for interactive menu. Use CLI: keep_awake.sh on [duration]" >&2
        return 1
    fi

    local choice=""
    if is_active; then
        local end_epoch
        end_epoch=$(jq -r '.end_epoch // 0' "$META_FILE" 2>/dev/null || echo 0)
        local end_time_human
        end_time_human=$(jq -r '.end_time_human // ""' "$META_FILE" 2>/dev/null || echo "")
        local now
        now=$(date +%s)
        local remaining_sec=$(( end_epoch - now ))
        (( remaining_sec < 0 )) && remaining_sec=0
        local remaining_human
        remaining_human=$(format_time_remaining "$remaining_sec")

        local options="󰈆  Disable Keep Awake (Allow Sleep)
󱎫  Extend by 30 Minutes
󱎫  Extend by 1 Hour
󱎫  Extend by 2 Hours
󰄬  Set New Custom Duration...
󰌍  Cancel"

        choice=$(echo -e "$options" | rofi -dmenu -i \
            -p "󰅶 Keep Awake" \
            -mesg "  Active · ${remaining_human} remaining (until ${end_time_human}) · Display turns off normally" \
            -theme "$ROFI_THEME") || true

        case "$choice" in
            *"Disable"*)
                stop_awake
                ;;
            *"Extend by 30 Minutes"*)
                local new_dur=$(( remaining_sec + 1800 ))
                start_awake "${new_dur}s"
                ;;
            *"Extend by 1 Hour"*)
                local new_dur=$(( remaining_sec + 3600 ))
                start_awake "${new_dur}s"
                ;;
            *"Extend by 2 Hours"*)
                local new_dur=$(( remaining_sec + 7200 ))
                start_awake "${new_dur}s"
                ;;
            *"Set New Custom"*)
                prompt_custom_duration
                ;;
        esac
    else
        local options="󱎫  15 Minutes
󱎫  30 Minutes
󱎫  1 Hour
󱎫  2 Hours
󱎫  4 Hours
󱎫  8 Hours
󰄬  Custom Duration (e.g. 45m, 3h)...
󰌍  Cancel"

        choice=$(echo -e "$options" | rofi -dmenu -i \
            -p "󰅶 Keep Awake" \
            -mesg "  Prevent system sleep temporarily · Display will still turn off normally on idle" \
            -theme "$ROFI_THEME") || true

        case "$choice" in
            *"15 Minutes"*)
                start_awake "15m"
                ;;
            *"30 Minutes"*)
                start_awake "30m"
                ;;
            *"1 Hour"*)
                start_awake "1h"
                ;;
            *"2 Hours"*)
                start_awake "2h"
                ;;
            *"4 Hours"*)
                start_awake "4h"
                ;;
            *"8 Hours"*)
                start_awake "8h"
                ;;
            *"Custom Duration"*)
                prompt_custom_duration
                ;;
        esac
    fi
}

main() {
    local cmd="${1:-status}"
    case "$cmd" in
        _run)
            shift
            _run_inhibitor "$@"
            ;;
        on|start|enable)
            shift || true
            start_awake "${1:-1h}"
            ;;
        off|stop|disable)
            stop_awake
            ;;
        toggle)
            shift || true
            toggle_awake "${1:-1h}"
            ;;
        status)
            shift || true
            status_awake "${1:-}"
            ;;
        is-active)
            is_active
            ;;
        waybar)
            waybar_output
            ;;
        menu)
            show_menu
            ;;
        -h|--help|help)
            echo "Usage: keep_awake.sh [on <duration>|off|toggle|status|is-active|waybar|menu]"
            echo ""
            echo "Commands:"
            echo "  on [duration]    Temporarily disable sleep (e.g. 15m, 30m, 1h, 2h, 4h; default: 1h)"
            echo "  off              Disable immediately and restore normal sleep behavior"
            echo "  toggle [dur]     Toggle sleep inhibition on/off"
            echo "  status [--json]  Print current status and remaining time"
            echo "  is-active        Exit 0 if active, 1 if inactive"
            echo "  waybar           Output JSON formatted for Waybar module"
            echo "  menu             Open interactive Rofi duration selection menu"
            echo ""
            echo "Note: The screen/display will still turn off normally based on display idle timeouts."
            ;;
        *)
            # If argument matches duration format (e.g. 30m, 1h), treat as "on <duration>"
            if parse_duration "$cmd" &>/dev/null; then
                start_awake "$cmd"
            else
                echo "Unknown command: $cmd. Run '$0 --help' for usage." >&2
                exit 1
            fi
            ;;
    esac
}

main "$@"
