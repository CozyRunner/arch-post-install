#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║             GPU Screen Recorder Controller                   ║
# ║  Entire Screen · Active Display · Selection Area · Window    ║
# ║           Start · Stop · Toggle · Status · Menu              ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Paths
# ------------------------------------------------------------------------------
VIDEOS_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"
RECORDINGS_DIR="${RECORDINGS_DIR:-$VIDEOS_DIR/Recordings}"
mkdir -p "$RECORDINGS_DIR"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/screenrecorder"
mkdir -p "$STATE_DIR"
PID_FILE="$STATE_DIR/recording.pid"
META_FILE="$STATE_DIR/recording.meta"

# Slurp visual style (harmonized with Lumina theme)
SLURP_BORDER_COLOR="#818cf8ff"
SLURP_BG_COLOR="#00000088"
SLURP_SELECTION_COLOR="#818cf833"
SLURP_BORDER_WEIGHT=2

# ------------------------------------------------------------------------------
# Dependency Verification
# ------------------------------------------------------------------------------
check_dependencies() {
    local missing=()
    for cmd in notify-send jq hyprctl slurp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if ! command -v gpu-screen-recorder >/dev/null 2>&1; then
        notify-send -u critical -a "Screen Recorder" \
            "Dependency Missing" \
            "gpu-screen-recorder is not installed.\nInstall it with: sudo pacman -S gpu-screen-recorder"
        echo "Error: gpu-screen-recorder is not installed." >&2
        echo "Install with: sudo pacman -S gpu-screen-recorder" >&2
        exit 1
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        notify-send -u critical -a "Screen Recorder" \
            "Dependencies Missing" \
            "Required utilities missing: ${missing[*]}"
        echo "Error: Missing utilities: ${missing[*]}" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Process & State Helpers
# ------------------------------------------------------------------------------

# Returns 0 if recording process is actively running, 1 otherwise
is_recording() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        # Remove stale state if process died
        rm -f "$PID_FILE" "$META_FILE" 2>/dev/null || true
    fi

    if pgrep -x "gpu-screen-recorder" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Get active PID
get_recording_pid() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
    fi
    pgrep -x "gpu-screen-recorder" | head -n 1 || true
}

# Close notification center before capturing to avoid capturing the overlay panel
close_notification_panel() {
    if command -v swaync-client >/dev/null 2>&1; then
        swaync-client -cp 2>/dev/null || true
        sleep 0.25
    elif command -v dunstctl >/dev/null 2>&1; then
        dunstctl close-all 2>/dev/null || true
        sleep 0.15
    fi
}

# Determine the display/monitor name where the cursor is currently positioned
get_active_display() {
    local cursor cx cy
    cursor="$(hyprctl cursorpos 2>/dev/null || echo "")"

    if [[ -n "$cursor" && "$cursor" =~ ([0-9]+),[[:space:]]*([0-9]+) ]]; then
        cx="${BASH_REMATCH[1]}"
        cy="${BASH_REMATCH[2]}"

        hyprctl monitors -j | jq -r --argjson cx "$cx" --argjson cy "$cy" '
            (map(
                . as $m |
                ($m.scale // 1.0) as $s |
                ($m.width / $s) as $raw_w |
                ($m.height / $s) as $raw_h |
                (if ($m.transform == 1 or $m.transform == 3) then $raw_h else $raw_w end) as $w |
                (if ($m.transform == 1 or $m.transform == 3) then $raw_w else $raw_h end) as $h |
                select($cx >= $m.x and $cx < ($m.x + $w) and $cy >= $m.y and $cy < ($m.y + $h))
            )[0].name // empty) //
            (map(select(.focused == true))[0].name // empty) //
            (.[0].name // empty)
        '
    else
        hyprctl monitors -j | jq -r '(map(select(.focused == true))[0].name // .[0].name // empty)'
    fi
}

# Select an application window interactively by highlighting visible window rectangles
select_window_geometry() {
    local active_workspaces rects chosen_geom

    active_workspaces="$(hyprctl monitors -j | jq -r '[.[].activeWorkspace.id]')"

    rects="$(hyprctl clients -j | jq -r --argjson ws "$active_workspaces" '
        .[] |
        select(([.workspace.id] | inside($ws)) and .mapped == true and .hidden == false) |
        "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ')"

    if [[ -z "$rects" ]]; then
        chosen_geom="$(hyprctl activewindow -j | jq -r 'if .at and .size then "\(.size[0])x\(.size[1])+\(.at[0])+\(.at[1])" else empty end')"
        echo "$chosen_geom"
        return 0
    fi

    chosen_geom="$(echo "$rects" | slurp -r \
        -d \
        -b "$SLURP_BG_COLOR" \
        -c "$SLURP_BORDER_COLOR" \
        -s "$SLURP_SELECTION_COLOR" \
        -w "$SLURP_BORDER_WEIGHT" \
        -f "%wx%h+%x+%y" 2>/dev/null)" || return 1

    echo "$chosen_geom"
}

# ------------------------------------------------------------------------------
# Core Recording Engine
# ------------------------------------------------------------------------------

start_recording() {
    local mode_desc="$1"
    shift
    local -a gsr_args=("$@")

    # If already recording, stop first
    if is_recording; then
        notify-send -a "Screen Recorder" -u normal "Screen Recorder" "Stopping active recording before starting new session..."
        stop_recording
        sleep 0.5
    fi

    local timestamp
    timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
    local output_file="$RECORDINGS_DIR/Recording_${timestamp}.mp4"

    # Configure Audio: default to system output if PipeWire/Pulse is active
    local -a audio_args=()
    local audio_mode="${RECORD_AUDIO:-auto}"
    if [[ "$audio_mode" != "none" ]]; then
        if command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
            if [[ "$audio_mode" == "all" || "${RECORD_MIC:-false}" == "true" ]]; then
                audio_args+=("-a" "default_output|default_input")
            else
                audio_args+=("-a" "default_output")
            fi
        fi
    fi

    close_notification_panel

    # Start gpu-screen-recorder in background
    gpu-screen-recorder \
        "${gsr_args[@]}" \
        -f "${RECORD_FPS:-60}" \
        -c mp4 \
        -k "${RECORD_CODEC:-auto}" \
        "${audio_args[@]}" \
        -o "$output_file" >/dev/null 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    cat <<EOF > "$META_FILE"
output_file="${output_file}"
start_time="$(date +%s)"
mode_desc="${mode_desc}"
EOF

    # Verify recorder process started successfully
    sleep 0.35
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE" "$META_FILE"
        notify-send -u critical -a "Screen Recorder" \
            "Recording Failed" \
            "gpu-screen-recorder failed to start.\nVerify hardware acceleration and display permissions."
        echo "Error: gpu-screen-recorder failed to initialize." >&2
        return 1
    fi

    # Notify recording started with action to stop
    (
        local action
        action="$(notify-send \
            -a "Screen Recorder" \
            -i media-record \
            --action="stop=Stop Recording" \
            "Recording Started" \
            "${mode_desc}\nFile: $(basename "$output_file")")" || true

        if [[ "$action" == "stop" ]]; then
            stop_recording
        fi
    ) >/dev/null 2>&1 &

    echo "Recording started: $output_file (PID: $pid)"
}

stop_recording() {
    if ! is_recording; then
        notify-send -a "Screen Recorder" -u low "Screen Recorder" "No active recording in progress."
        echo "No recording in progress."
        return 0
    fi

    local pid
    pid="$(get_recording_pid)"

    local output_file=""
    local start_time=""
    local mode_desc="Screen Recording"

    if [[ -f "$META_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$META_FILE" 2>/dev/null || true
    fi

    # Gracefully stop recording (SIGINT ensures MP4 container headers are finalized)
    if [[ -n "$pid" ]]; then
        kill -SIGINT "$pid" 2>/dev/null || true
    else
        killall -SIGINT gpu-screen-recorder 2>/dev/null || true
    fi

    # Wait up to 5s for process cleanup
    local wait_count=50
    while [[ $wait_count -gt 0 ]] && is_recording; do
        sleep 0.1
        wait_count=$((wait_count - 1))
    done

    rm -f "$PID_FILE" "$META_FILE" 2>/dev/null || true

    # Compute duration
    local duration_str=""
    if [[ -n "$start_time" ]]; then
        local now elapsed mins secs
        now="$(date +%s)"
        elapsed=$((now - start_time))
        mins=$((elapsed / 60))
        secs=$((elapsed % 60))
        duration_str="$(printf '%02d:%02d' "$mins" "$secs")"
    fi

    if [[ -n "$output_file" && -f "$output_file" ]]; then
        local file_size base_name
        file_size="$(du -h "$output_file" 2>/dev/null | awk '{print $1}')"
        base_name="$(basename "$output_file")"

        # Send completion notification with actions
        (
            local action
            action="$(notify-send \
                -a "Screen Recorder" \
                -i video-x-generic \
                --action="play=Play Recording" \
                --action="folder=Show in Folder" \
                "Recording Saved" \
                "${mode_desc}\nSaved: ${base_name}\nDuration: ${duration_str:-completed} · ${file_size}")" || true

            case "$action" in
                play)
                    if command -v mpv >/dev/null 2>&1; then
                        mpv "$output_file" >/dev/null 2>&1 &
                    elif command -v xdg-open >/dev/null 2>&1; then
                        xdg-open "$output_file" >/dev/null 2>&1 &
                    fi
                    ;;
                folder)
                    if command -v xdg-open >/dev/null 2>&1; then
                        xdg-open "$RECORDINGS_DIR" >/dev/null 2>&1 &
                    fi
                    ;;
            esac
        ) >/dev/null 2>&1 &

        echo "Recording saved: $output_file"
    else
        notify-send -a "Screen Recorder" "Recording Stopped" "Screen recording finalized."
        echo "Recording stopped."
    fi
}

# ------------------------------------------------------------------------------
# Capture Handlers
# ------------------------------------------------------------------------------

# 1. Entire Screen (All connected monitors)
record_screen() {
    start_recording "Entire Screen" -w "screen"
}

# 2. Active Display (Cursor monitor)
record_display() {
    local display_name
    display_name="$(get_active_display)"

    if [[ -n "$display_name" ]]; then
        start_recording "Active Display ($display_name)" -w "$display_name"
    else
        start_recording "Entire Screen" -w "screen"
    fi
}

# 3. User Selection Area
record_area() {
    close_notification_panel

    local geom
    geom="$(slurp \
        -d \
        -b "$SLURP_BG_COLOR" \
        -c "$SLURP_BORDER_COLOR" \
        -s "$SLURP_SELECTION_COLOR" \
        -w "$SLURP_BORDER_WEIGHT" \
        -f "%wx%h+%x+%y" 2>/dev/null)" || exit 0

    if [[ -n "$geom" ]]; then
        start_recording "Selection Area" -w "region" -region "$geom"
    fi
}

# 4. Application Window
record_window() {
    close_notification_panel

    local geom
    geom="$(select_window_geometry)" || exit 0

    if [[ -n "$geom" ]]; then
        start_recording "Application Window" -w "region" -region "$geom"
    else
        # Fallback to desktop portal dialog
        start_recording "Desktop Portal" -w "portal"
    fi
}

# 5. Desktop Portal Picker
record_portal() {
    close_notification_panel
    start_recording "Desktop Portal" -w "portal"
}

# 6. Toggle recording state
toggle_recording() {
    if is_recording; then
        stop_recording
    else
        record_screen
    fi
}

# 7. Print status
print_status() {
    if is_recording; then
        local pid
        pid="$(get_recording_pid)"
        local start_time=""
        if [[ -f "$META_FILE" ]]; then
            # shellcheck disable=SC1090
            source "$META_FILE" 2>/dev/null || true
        fi
        local duration_str="active"
        if [[ -n "$start_time" ]]; then
            local now elapsed mins secs
            now="$(date +%s)"
            elapsed=$((now - start_time))
            mins=$((elapsed / 60))
            secs=$((elapsed % 60))
            duration_str="$(printf '%02d:%02d' "$mins" "$secs")"
        fi
        echo "recording (PID: ${pid:-unknown}, duration: ${duration_str})"
        return 0
    else
        echo "idle"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Interactive Rofi Menu
# ------------------------------------------------------------------------------
show_rofi_menu() {
    local rofi_theme="${ROFI_THEME:-$HOME/.config/rofi/floating-menu.rasi}"
    local options

    if is_recording; then
        options="󰙧  Stop Recording\n󰐊  Recording Status / Info"
    else
        options="󰑋  Entire Screen\n󰍹  Active Display (Cursor)\n󰒅  Selection Area\n󰖯  Application Window\n󰍺  Desktop Portal Picker"
    fi

    local choice
    if [[ -f "$rofi_theme" ]]; then
        choice="$(echo -e "$options" | rofi -dmenu -i -p "󰑋 Screen Recorder" -mesg "  GPU Screen Recorder Control" -theme "$rofi_theme" 2>/dev/null)" || exit 0
    else
        choice="$(echo -e "$options" | rofi -dmenu -i -p "󰑋 Screen Recorder" 2>/dev/null)" || exit 0
    fi

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *"Stop Recording"*)
            stop_recording
            ;;
        *"Recording Status"*)
            print_status
            ;;
        *"Entire Screen"*)
            record_screen
            ;;
        *"Active Display"*)
            record_display
            ;;
        *"Selection Area"*)
            record_area
            ;;
        *"Application Window"*)
            record_window
            ;;
        *"Desktop Portal"*)
            record_portal
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Main Dispatcher
# ------------------------------------------------------------------------------
MODE="${1:-menu}"

# Ensure dependencies are satisfied unless just printing help or status
case "$MODE" in
    -h|--help|help)
        echo "Usage: $0 [screen|display|area|window|portal|toggle|stop|status|menu]"
        echo ""
        echo "GPU Screen Recorder Controller (Hyprland / Wayland)"
        echo ""
        echo "Modes:"
        echo "  screen   - Record entire screen (all monitors)"
        echo "  display  - Record active display where cursor is positioned"
        echo "  area     - Record user-defined selection area (drag region)"
        echo "  window   - Record application window (interactive click)"
        echo "  portal   - Record screen/window via desktop portal picker"
        echo "  toggle   - Toggle recording (stop active session or start screen recording)"
        echo "  stop     - Stop active screen recording and finalize output"
        echo "  status   - Print current recording state (recording/idle)"
        echo "  menu     - Launch interactive Rofi screen recording selector"
        exit 0
        ;;
    status)
        print_status
        exit $?
        ;;
    stop)
        stop_recording
        exit 0
        ;;
    *)
        check_dependencies
        ;;
esac

case "$MODE" in
    screen|fullscreen|all)
        record_screen
        ;;
    display|output|active-display|monitor)
        record_display
        ;;
    area|selection|crop)
        record_area
        ;;
    window|app)
        record_window
        ;;
    portal)
        record_portal
        ;;
    toggle)
        toggle_recording
        ;;
    menu|gui|interactive)
        show_rofi_menu
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        echo "Usage: $0 [screen|display|area|window|portal|toggle|stop|status|menu]" >&2
        exit 1
        ;;
esac
