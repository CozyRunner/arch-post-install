#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║         Modern Application Launcher (Rofi Engine)            ║
# ║   Recent Apps by Default · View All Apps · Instant Search    ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Features:
#   - Shows Most Recently Used (MRU) applications by default.
#   - Automatically tracks and promotes launched apps to top of list.
#   - Prominent "View All Applications" action to browse full desktop list.
#   - "Back to Recent Applications" navigation breadcrumb.
#   - Instant fuzzy search across app names, generic names, and keywords.
#   - Native Rofi script mode: 0-flicker view toggling in the same window.
#   - Shift+Delete deletes an app from recent history.
#
# Usage:
#   app_launcher.sh            # Launch Rofi (Recent Apps view by default)
#   app_launcher.sh all        # Launch directly into All Apps view
#   app_launcher.sh recent     # Launch directly into Recent Apps view
#   app_launcher.sh clear      # Clear recent applications history
#   app_launcher.sh list       # Print recent applications to stdout

set -euo pipefail

# ── Paths & Configuration ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
# Ensure directories exist with fallback for restricted/sandbox environments
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rofi"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi"
if ! mkdir -p "$DATA_DIR" 2>/dev/null; then
    DATA_DIR="/tmp/rofi-data-${UID:-1000}"
    mkdir -p "$DATA_DIR" 2>/dev/null || true
fi
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_DIR="/tmp/rofi-cache-${UID:-1000}"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
fi

RECENT_FILE="${DATA_DIR}/recent_apps.list"
APPS_CACHE="${CACHE_DIR}/desktop_apps.tsv"

ROFI_THEME="${ROFI_THEME:-$ROFI_DIR/launcher.rasi}"
if [[ ! -f "$ROFI_THEME" ]]; then
    # Fallback to repo copy or floating-menu if not yet deployed
    REPO_THEME="$(cd "$SCRIPT_DIR/../../rofi" 2>/dev/null && pwd)/launcher.rasi"
    if [[ -f "$REPO_THEME" ]]; then
        ROFI_THEME="$REPO_THEME"
    else
        ROFI_THEME="$ROFI_DIR/spotlight.rasi"
    fi
fi

# Maximum number of recent apps displayed in recent view (defaults to 5)
MAX_RECENT="${MAX_RECENT:-5}"

# ── Internal Storage ──────────────────────────────────────────
declare -A APP_NAMES=()
declare -A APP_ICONS=()
declare -A APP_PATHS=()
declare -A APP_METAS=()
declare -a ALL_IDS=()

# ── Desktop App Discovery & Parsing ───────────────────────────
# Parses .desktop files across XDG search paths using high-speed awk (~15ms)
load_all_desktop_apps() {
    # Check if cached index exists and is newer than system applications directory
    if [[ -f "$APPS_CACHE" && -s "$APPS_CACHE" ]]; then
        if [[ "$APPS_CACHE" -nt /usr/share/applications ]]; then
            while IFS=$'\t' read -r id name icon meta path; do
                [[ -z "$id" || -z "$name" ]] && continue
                if [[ -z "${APP_NAMES[$id]:-}" ]]; then
                    APP_NAMES["$id"]="$name"
                    APP_ICONS["$id"]="${icon:-application-x-executable}"
                    APP_METAS["$id"]="${meta:-}"
                    APP_PATHS["$id"]="$path"
                    ALL_IDS+=("$id")
                fi
            done < "$APPS_CACHE"
            return 0
        fi
    fi

    shopt -s nullglob
    local dirs=(
        "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
        /usr/local/share/applications
        /usr/share/applications
        /var/lib/flatpak/exports/share/applications
        "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share/applications"
    )

    local desktop_files=()
    for d in "${dirs[@]}"; do
        if [[ -d "$d" ]]; then
            desktop_files+=("$d/"*.desktop)
        fi
    done
    shopt -u nullglob

    [[ ${#desktop_files[@]} -eq 0 ]] && return 0

    # Parse and index desktop entries
    while IFS=$'\t' read -r id name icon meta path; do
        [[ -z "$id" || -z "$name" ]] && continue
        if [[ -z "${APP_NAMES[$id]:-}" ]]; then
            APP_NAMES["$id"]="$name"
            APP_ICONS["$id"]="${icon:-application-x-executable}"
            APP_METAS["$id"]="${meta:-}"
            APP_PATHS["$id"]="$path"
            ALL_IDS+=("$id")
        fi
    done < <(
        awk '
        BEGINFILE {
            name = ""; icon = ""; nodisplay = 0; hidden = 0; type = ""; meta = ""
        }
        /^\[Desktop Entry\]/ { in_entry = 1; next }
        /^\[/ { in_entry = 0 }
        in_entry && /^Name=/ && !name {
            sub(/^Name=/, "")
            name = $0
        }
        in_entry && /^Icon=/ && !icon {
            sub(/^Icon=/, "")
            icon = $0
        }
        in_entry && /^GenericName=/ {
            sub(/^GenericName=/, "")
            meta = meta " " $0
        }
        in_entry && /^Keywords=/ {
            sub(/^Keywords=/, "")
            gsub(/;/, " ", $0)
            meta = meta " " $0
        }
        in_entry && /^NoDisplay=(true|TRUE)/ { nodisplay = 1 }
        in_entry && /^Hidden=(true|TRUE)/ { hidden = 1 }
        in_entry && /^Type=/ && !type {
            sub(/^Type=/, "")
            type = $0
        }
        ENDFILE {
            if (name != "" && nodisplay == 0 && hidden == 0 && (type == "" || type == "Application")) {
                id = FILENAME
                sub(/.*\//, "", id)
                if (!seen[id]++) {
                    if (icon == "") icon = "application-x-executable"
                    gsub(/^[ \t]+|[ \t]+$/, "", meta)
                    print id "\t" name "\t" icon "\t" meta "\t" FILENAME
                }
            }
        }
        ' "${desktop_files[@]}" 2>/dev/null
    )

    # Persist cache for subsequent sub-millisecond launches
    if [[ ${#ALL_IDS[@]} -gt 0 ]]; then
        mkdir -p "$(dirname "$APPS_CACHE")"
        local cache_tmp
        cache_tmp=$(mktemp)
        for id in "${ALL_IDS[@]}"; do
            printf '%s\t%s\t%s\t%s\t%s\n' "$id" "${APP_NAMES[$id]}" "${APP_ICONS[$id]}" "${APP_METAS[$id]:-}" "${APP_PATHS[$id]}" >> "$cache_tmp"
        done
        mv "$cache_tmp" "$APPS_CACHE"
    fi
}

# ── Recent Apps Management ────────────────────────────────────
# Prepend app ID to recent file, deduplicating and capping at 30 entries
record_recent() {
    local id="$1"
    [[ -z "$id" ]] && return 0
    mkdir -p "$(dirname "$RECENT_FILE")"

    local tmp
    tmp=$(mktemp)
    echo "$id" > "$tmp"
    if [[ -f "$RECENT_FILE" ]]; then
        grep -v -F -x "$id" "$RECENT_FILE" >> "$tmp" 2>/dev/null || true
    fi
    head -n 30 "$tmp" > "$RECENT_FILE"
    rm -f "$tmp"
}

# Remove app ID from recent file (Shift+Delete handler)
remove_recent() {
    local id="$1"
    [[ -z "$id" || ! -f "$RECENT_FILE" ]] && return 0
    local tmp
    tmp=$(mktemp)
    grep -v -F -x "$id" "$RECENT_FILE" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$RECENT_FILE"
}

# Seed common default applications if history is empty (first boot / fresh install)
seed_default_recent() {
    local defaults=(
        "chromium.desktop"
        "firefox.desktop"
        "brave-browser-beta.desktop"
        "kitty.desktop"
        "Alacritty.desktop"
        "org.gnome.Nautilus.desktop"
        "code-oss.desktop"
        "antigravity-ide.desktop"
        "btop.desktop"
        "nwg-look.desktop"
    )
    local seeded=0
    for id in "${defaults[@]}"; do
        if [[ -n "${APP_NAMES[$id]:-}" ]]; then
            echo "$id" >> "$RECENT_FILE"
            seeded=$((seeded + 1))
            [[ $seeded -ge $MAX_RECENT ]] && break
        fi
    done
}

# ── Application Execution ─────────────────────────────────────
launch_app() {
    local id="$1"
    local path="${APP_PATHS[$id]:-}"

    # Record app in recent history
    record_recent "$id"

    # Check if Terminal=true is set in the desktop entry
    local is_terminal=false
    if [[ -n "$path" && -f "$path" ]]; then
        if grep -qi '^Terminal=true' "$path"; then
            is_terminal=true
        fi
    fi

    # Launch application detached from Rofi process
    if [[ "$is_terminal" == "true" ]]; then
        local exec_cmd=""
        if [[ -n "$path" && -f "$path" ]]; then
            exec_cmd=$(awk -F= '/^Exec=/ { sub(/^Exec=/, ""); sub(/%[a-zA-Z]/, ""); print; exit }' "$path")
        fi
        [[ -z "$exec_cmd" ]] && exec_cmd="${id%.desktop}"
        ( kitty --class floating-term -e $exec_cmd >/dev/null 2>&1 & )
    elif command -v gtk-launch &>/dev/null; then
        ( gtk-launch "$id" >/dev/null 2>&1 & )
    elif command -v gio &>/dev/null && [[ -n "$path" && -f "$path" ]]; then
        ( gio launch "$path" >/dev/null 2>&1 & )
    else
        local exec_cmd=""
        if [[ -n "$path" && -f "$path" ]]; then
            exec_cmd=$(awk -F= '/^Exec=/ { sub(/^Exec=/, ""); sub(/%[a-zA-Z]/, ""); print; exit }' "$path")
        fi
        [[ -z "$exec_cmd" ]] && exec_cmd="${id%.desktop}"
        ( $exec_cmd >/dev/null 2>&1 & )
    fi
}

# ── Rofi Output Generators ────────────────────────────────────
render_recent_mode() {
    local total_apps="${#ALL_IDS[@]}"
    local recent_count=0

    # Ensure recent file exists and is populated
    if [[ ! -f "$RECENT_FILE" || ! -s "$RECENT_FILE" ]]; then
        seed_default_recent
    fi

    echo -en "\0prompt\x1f  Recent\n"
    echo -en "\0data\x1frecent\n"
    echo -en "\0message\x1f<b>Recent Applications</b>  <small>· Type to filter or browse all below</small>\n"

    # Print recent applications in MRU order (capped at MAX_RECENT)
    if [[ -f "$RECENT_FILE" ]]; then
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            if [[ -n "${APP_NAMES[$id]:-}" ]]; then
                local name="${APP_NAMES[$id]}"
                local icon="${APP_ICONS[$id]}"
                local meta="${APP_METAS[$id]:-}"
                echo -en "${name}\0icon\x1f${icon}\x1finfo\x1f${id}\x1fmeta\x1f${meta}\n"
                recent_count=$((recent_count + 1))
                [[ $recent_count -ge $MAX_RECENT ]] && break
            fi
        done < "$RECENT_FILE"
    fi

    # Prominent "View All Applications" action button
    # Marked with permanent=true so it stays visible even during search filtering
    echo -en "View All Applications (${total_apps})\0icon\x1fview-app-grid\x1finfo\x1ftoggle_all\x1factive\x1ftrue\x1fpermanent\x1ftrue\x1fmeta\x1fall apps applications view browse more catalog list search installed\n"
}

render_all_mode() {
    echo -en "\0prompt\x1f󰍜  All Apps\n"
    echo -en "\0data\x1fall\n"
    echo -en "\0keep-filter\x1ftrue\n"
    echo -en "\0message\x1f<b>All Applications</b>  <small>· Select 'Back to Recent Applications' to return</small>\n"

    # Action button to navigate back to Recent Apps view (single arrow from icon)
    echo -en "Back to Recent Applications\0icon\x1fgo-previous\x1finfo\x1ftoggle_recent\x1factive\x1ftrue\x1fpermanent\x1ftrue\x1fmeta\x1fback recent return previous\n"

    # Sort applications alphabetically by display name (case-insensitive)
    local sorted_entries=()
    for id in "${ALL_IDS[@]}"; do
        sorted_entries+=("${APP_NAMES[$id]}"$'\t'"${APP_ICONS[$id]}"$'\t'"${id}"$'\t'"${APP_METAS[$id]:-}")
    done

    while IFS=$'\t' read -r name icon id meta; do
        [[ -z "$name" ]] && continue
        echo -en "${name}\0icon\x1f${icon}\x1finfo\x1f${id}\x1fmeta\x1f${meta}\n"
    done < <(printf '%s\n' "${sorted_entries[@]}" | sort -f -t$'\t' -k1,1)
}

# ── Rofi Script Mode Engine ───────────────────────────────────
# Invoked when running inside Rofi (ROFI_RETV is defined)
handle_rofi_script_mode() {
    load_all_desktop_apps

    local retv="${ROFI_RETV:-0}"
    local selected="${1:-}"
    local info="${ROFI_INFO:-}"
    local current_data="${ROFI_DATA:-recent}"

    case "$retv" in
        0)
            # Initial invocation
            local initial_mode="${ROFI_LAUNCHER_MODE:-recent}"
            if [[ "$initial_mode" == "all" ]]; then
                render_all_mode
            else
                render_recent_mode
            fi
            ;;

        1)
            # User selected an entry
            if [[ "$info" == "toggle_all" || "$selected" == *"View All Applications"* ]]; then
                render_all_mode
            elif [[ "$info" == "toggle_recent" || "$selected" == *"Back to Recent Applications"* ]]; then
                render_recent_mode
            elif [[ -n "$info" && -n "${APP_NAMES[$info]:-}" ]]; then
                # Valid desktop app selected
                launch_app "$info"
                exit 0
            elif [[ -n "$selected" ]]; then
                # Lookup by display name fallback
                local matched_id=""
                for id in "${ALL_IDS[@]}"; do
                    if [[ "${APP_NAMES[$id]}" == "$selected" ]]; then
                        matched_id="$id"
                        break
                    fi
                done
                if [[ -n "$matched_id" ]]; then
                    launch_app "$matched_id"
                fi
                exit 0
            fi
            ;;

        2)
            # User typed custom input not in the list and pressed Enter
            if [[ -n "$selected" ]]; then
                if command -v "$selected" &>/dev/null; then
                    ( "$selected" >/dev/null 2>&1 & )
                fi
            fi
            exit 0
            ;;

        3)
            # User pressed Shift+Delete to remove an entry from history
            if [[ -n "$info" ]]; then
                remove_recent "$info"
            fi
            if [[ "$current_data" == "all" ]]; then
                render_all_mode
            else
                render_recent_mode
            fi
            ;;

        *)
            exit 0
            ;;
    esac
}

# ── Standalone CLI / Hyprland Entry Point ──────────────────────
main() {
    # If running inside Rofi as script mode, dispatch to handler
    if [[ -n "${ROFI_RETV:-}" ]]; then
        handle_rofi_script_mode "${1:-}"
        return 0
    fi

    # CLI sub-commands
    local mode="recent"
    case "${1:-}" in
        all)
            mode="all"
            ;;
        recent|"")
            mode="recent"
            ;;
        clear|clear-history)
            rm -f "$RECENT_FILE"
            echo "✓ Recent applications history cleared."
            return 0
            ;;
        list|list-recent)
            load_all_desktop_apps
            if [[ -f "$RECENT_FILE" ]]; then
                cat "$RECENT_FILE"
            else
                echo "No recent applications recorded yet."
            fi
            return 0
            ;;
        list-all)
            load_all_desktop_apps
            for id in "${ALL_IDS[@]}"; do
                echo "${id}: ${APP_NAMES[$id]}"
            done
            return 0
            ;;
        -h|--help|help)
            echo "Usage: app_launcher.sh [all|recent|clear|list|list-all]"
            return 0
            ;;
        *)
            mode="recent"
            ;;
    esac

    # Ensure theme exists; if custom theme not present, fallback
    local theme_arg=()
    if [[ -f "$ROFI_THEME" ]]; then
        theme_arg=(-theme "$ROFI_THEME")
    fi

    export ROFI_LAUNCHER_MODE="$mode"
    exec rofi -show apps -modes "apps:$0" "${theme_arg[@]}"
}

main "$@"
