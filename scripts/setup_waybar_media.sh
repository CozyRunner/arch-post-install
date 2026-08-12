#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Script: setup_waybar_media.sh
# Description: Idempotent installer & patcher for Waybar Hover Media Controller.
#              Installs playerctl, merges configuration, backs up existing files,
#              configures Hyprland keybinds, and safely reloads Waybar.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Formatting colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; }
log_step()    { echo -e "\n${CYAN}${BOLD}▸ $*${NC}\n"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAYBAR_CONFIG_DIR="${HOME}/.config/waybar"
WAYBAR_SCRIPTS_DIR="${WAYBAR_CONFIG_DIR}/scripts"
BACKUP_DIR="${WAYBAR_CONFIG_DIR}/backup"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# ── 1. Ensure Dependencies (playerctl) ───────────────────────────────────────
ensure_playerctl() {
    log_step "Checking dependencies"
    if ! command -v playerctl &>/dev/null; then
        log_info "playerctl is not installed. Installing via pacman..."
        if [[ $EUID -eq 0 ]]; then
            pacman -S --needed --noconfirm playerctl
        else
            sudo pacman -S --needed --noconfirm playerctl
        fi
        log_success "playerctl installed successfully"
    else
        log_success "playerctl is already installed"
    fi
}

# ── 2. Deploy media.sh Script ────────────────────────────────────────────────
deploy_media_script() {
    log_step "Deploying media.sh helper script"
    mkdir -p "${WAYBAR_SCRIPTS_DIR}"
    local src_script="${SCRIPT_DIR}/dotfiles/waybar/scripts/media.sh"
    local dest_script="${WAYBAR_SCRIPTS_DIR}/media.sh"

    if [[ -f "${src_script}" ]]; then
        if [[ "${src_script}" -ef "${dest_script}" ]]; then
            chmod +x "${dest_script}"
            log_success "media.sh already linked: ${dest_script}"
        else
            cp -f "${src_script}" "${dest_script}"
            chmod +x "${dest_script}"
            log_success "Installed and made executable: ${dest_script}"
        fi
    else
        log_error "Source media.sh not found at: ${src_script}"
        exit 1
    fi
}

# ── 3. Find Waybar Config & Style Files ───────────────────────────────────────
detect_waybar_files() {
    mkdir -p "${WAYBAR_CONFIG_DIR}" "${BACKUP_DIR}"

    CONFIG_FILE=""
    for candidate in "${WAYBAR_CONFIG_DIR}/config.jsonc" "${WAYBAR_CONFIG_DIR}/config.json" "${WAYBAR_CONFIG_DIR}/config"; do
        if [[ -f "${candidate}" ]]; then
            CONFIG_FILE="${candidate}"
            break
        fi
    done

    # If no config file exists yet, copy repository default
    if [[ -z "${CONFIG_FILE}" ]]; then
        CONFIG_FILE="${WAYBAR_CONFIG_DIR}/config.jsonc"
        log_info "No existing config found. Copying default config from repository..."
        cp "${SCRIPT_DIR}/dotfiles/waybar/config.jsonc" "${CONFIG_FILE}"
        log_success "Created ${CONFIG_FILE}"
    fi

    STYLE_FILE="${WAYBAR_CONFIG_DIR}/style.css"
    if [[ ! -f "${STYLE_FILE}" ]]; then
        log_info "No existing style.css found. Copying default style from repository..."
        cp "${SCRIPT_DIR}/dotfiles/waybar/style.css" "${STYLE_FILE}"
        log_success "Created ${STYLE_FILE}"
    fi
}

# ── 4. Backup Existing Files ─────────────────────────────────────────────────
backup_waybar_files() {
    log_step "Backing up existing Waybar configuration"
    if [[ -f "${CONFIG_FILE}" ]]; then
        local cfg_bak="${BACKUP_DIR}/$(basename "${CONFIG_FILE}").bak_${TIMESTAMP}"
        cp "${CONFIG_FILE}" "${cfg_bak}"
        log_success "Backed up config: ${cfg_bak}"
    fi

    if [[ -f "${STYLE_FILE}" ]]; then
        local style_bak="${BACKUP_DIR}/style.css.bak_${TIMESTAMP}"
        cp "${STYLE_FILE}" "${style_bak}"
        log_success "Backed up style: ${style_bak}"
    fi
}

# ── 5. Patch Waybar Configuration (Idempotent) ───────────────────────────────
patch_waybar_config() {
    log_step "Updating Waybar configuration"

    python3 - <<EOF
import re
import sys
import json

config_file = "${CONFIG_FILE}"

with open(config_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if group/media or custom/media is already present
has_group_media = '"group/media"' in content or "'group/media'" in content
has_custom_media = '"custom/media"' in content or "'custom/media'" in content

if has_group_media and has_custom_media:
    print("Media modules already present in config. Skipping insertion.")
    sys.exit(0)

# If group/media not in modules-left/modules-center/modules-right, add to modules-left
if not has_group_media and not has_custom_media:
    # Try inserting into modules-left
    left_match = re.search(r'("modules-left"\s*:\s*\[)([^\]]*)(\])', content, re.DOTALL)
    if left_match:
        prefix = left_match.group(1)
        items = left_match.group(2)
        suffix = left_match.group(3)
        
        # Insert after custom/arch if present, else at beginning of list
        if '"custom/arch"' in items:
            new_items = items.replace('"custom/arch"', '"custom/arch",\n    "group/media"')
        elif "'custom/arch'" in items:
            new_items = items.replace("'custom/arch'", "'custom/arch',\n    'group/media'")
        else:
            new_items = '\n    "group/media",' + items
        content = content[:left_match.start()] + prefix + new_items + suffix + content[left_match.end():]
        print("Added 'group/media' to modules-left.")

# Append module definitions before final closing brace if not present
media_module_defs = '''
  "group/media": {
    "orientation": "horizontal",
    "drawer": {
      "transition-duration": 400,
      "transition-left-to-right": true,
      "click-to-reveal": false,
    },
    "modules": [
      "custom/media",
      "custom/media-prev",
      "custom/media-play",
      "custom/media-next",
      "custom/media-text",
    ],
  },
  "custom/media": {
    "format": "{}",
    "return-type": "json",
    "exec": "~/.config/waybar/scripts/media.sh status",
    "interval": 1,
    "tooltip": true,
    "on-click": "~/.config/waybar/scripts/media.sh play-pause",
    "on-click-right": "~/.config/waybar/scripts/media.sh next",
    "on-click-middle": "~/.config/waybar/scripts/media.sh prev",
    "on-scroll-up": "playerctl volume 0.05+",
    "on-scroll-down": "playerctl volume 0.05-",
    "smooth-scrolling-threshold": 1,
  },
  "custom/media-prev": {
    "format": "󰒮",
    "tooltip": true,
    "tooltip-format": "Previous Track",
    "on-click": "~/.config/waybar/scripts/media.sh prev",
  },
  "custom/media-play": {
    "format": "{}",
    "return-type": "json",
    "exec": "~/.config/waybar/scripts/media.sh play-icon",
    "interval": 1,
    "tooltip": true,
    "on-click": "~/.config/waybar/scripts/media.sh play-pause",
  },
  "custom/media-next": {
    "format": "󰒭",
    "tooltip": true,
    "tooltip-format": "Next Track",
    "on-click": "~/.config/waybar/scripts/media.sh next",
  },
  "custom/media-text": {
    "format": "{}",
    "return-type": "json",
    "exec": "~/.config/waybar/scripts/media.sh title",
    "interval": 1,
    "tooltip": true,
    "max-length": 35,
    "on-click": "~/.config/waybar/scripts/media.sh play-pause",
    "on-click-right": "~/.config/waybar/scripts/media.sh next",
    "on-click-middle": "~/.config/waybar/scripts/media.sh prev",
  },
'''

# Find the last closing brace
last_brace_idx = content.rfind('}')
if last_brace_idx != -1:
    content = content[:last_brace_idx].rstrip() + ',\n' + media_module_defs + '}\n'
    with open(config_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Appended media controller module definitions.")
else:
    print("Error: Could not find closing brace in config file.", file=sys.stderr)
    sys.exit(1)
EOF

    log_success "Waybar config updated"
}

# ── 6. Patch Waybar Style (Idempotent) ───────────────────────────────────────
patch_waybar_style() {
    log_step "Updating Waybar style.css"

    if grep -q "custom-media-prev" "${STYLE_FILE}" 2>/dev/null; then
        log_info "Media controller styles already present in style.css"
    else
        cat << 'EOF' >> "${STYLE_FILE}"

/* ── Media Controller (Hover Expanding) ───────────────────────────────── */
#group-media {
    padding: 0 4px;
    margin: 2px 0;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

#custom-media,
#mpris {
    padding: 0 8px;
    margin: 2px 0;
    color: @accent-blue;
    font-size: 15px;
    transition: all 0.3s ease;
}

#custom-media.playing,
#mpris.Playing {
    color: @accent-green;
}

#custom-media.paused,
#mpris.Paused {
    color: @accent-orange;
}

#custom-media.stopped,
#mpris.Stopped {
    color: alpha(@foreground, 0.4);
}

#custom-media:hover,
#mpris:hover {
    color: @accent-purple;
}

#custom-media-prev,
#custom-media-play,
#custom-media-next {
    padding: 0 6px;
    margin: 2px 0;
    color: @foreground;
    font-size: 14px;
    transition: all 0.2s ease;
}

#custom-media-prev:hover,
#custom-media-next:hover {
    color: @accent-blue;
    background: alpha(@accent-blue, 0.15);
    border-radius: 6px;
}

#custom-media-play:hover {
    color: @accent-green;
    background: alpha(@accent-green, 0.15);
    border-radius: 6px;
}

#custom-media-text {
    padding: 0 8px;
    margin: 2px 0;
    color: @foreground;
    font-weight: 500;
    transition: all 0.3s ease;
}

#custom-media-text:hover {
    color: @accent-blue;
}
EOF
        log_success "Appended media controller styles to ${STYLE_FILE}"
    fi
}

# ── 7. Ensure Hyprland Media Keybindings ─────────────────────────────────────
ensure_hyprland_keybinds() {
    log_step "Checking Hyprland media keybindings"

    local hypr_dir="${HOME}/.config/hypr"
    local lua_media="${hypr_dir}/config/keybinds/media.lua"
    local conf_hypr="${hypr_dir}/hyprland.conf"

    if [[ -f "${lua_media}" ]]; then
        if grep -q "playerctl play-pause" "${lua_media}"; then
            log_success "Hyprland media bindings already configured in ${lua_media}"
        else
            cat << 'EOF' >> "${lua_media}"

-- Media player controls (requires playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
EOF
            log_success "Appended media bindings to ${lua_media}"
        fi
    elif [[ -f "${conf_hypr}" ]]; then
        if grep -q "playerctl play-pause" "${conf_hypr}"; then
            log_success "Hyprland media bindings already configured in ${conf_hypr}"
        else
            cat << 'EOF' >> "${conf_hypr}"

# Media player controls (requires playerctl)
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPause, exec, playerctl play-pause
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioPrev, exec, playerctl previous
EOF
            log_success "Appended media bindings to ${conf_hypr}"
        fi
    else
        log_info "No active Hyprland config found in ~/.config/hypr; repository dotfiles will provide keybinds."
    fi
}

# ── 8. Validate Waybar Configuration ─────────────────────────────────────────
validate_and_reload() {
    log_step "Validating Waybar configuration"

    if ! command -v waybar &>/dev/null; then
        log_warn "Waybar binary not found. Skipping live validation."
        return 0
    fi

    # Run waybar briefly to test syntax
    local validation_log="/tmp/waybar_media_validation.log"
    if timeout 1.5s waybar -c "${CONFIG_FILE}" -s "${STYLE_FILE}" -l error &> "${validation_log}"; then
        log_success "Waybar configuration validated with 0 errors"
    else
        local err_content
        err_content=$(cat "${validation_log}" 2>/dev/null || true)
        if echo "${err_content}" | grep -Ei "error|critical|parse"; then
            log_error "Waybar validation failed! Errors detected:"
            echo -e "${RED}${err_content}${NC}"
            log_warn "Restoring backups..."
            local last_cfg_bak
            last_cfg_bak=$(find "${BACKUP_DIR}" -name "config.*.bak_${TIMESTAMP}" | head -n1 || true)
            [[ -n "${last_cfg_bak}" && -f "${last_cfg_bak}" ]] && cp -f "${last_cfg_bak}" "${CONFIG_FILE}"
            local last_style_bak="${BACKUP_DIR}/style.css.bak_${TIMESTAMP}"
            [[ -f "${last_style_bak}" ]] && cp -f "${last_style_bak}" "${STYLE_FILE}"
            exit 1
        else
            log_success "Waybar configuration validated"
        fi
    fi

    # Reload / Restart running Waybar instance
    log_step "Reloading Waybar"
    if pgrep -x waybar &>/dev/null; then
        log_info "Signaling Waybar to reload styles and config..."
        pkill -SIGUSR2 waybar || true
        # Also restart cleanly if needed
        sleep 0.5
        if ! pgrep -x waybar &>/dev/null; then
            waybar &>/dev/null &
            disown || true
        fi
        log_success "Waybar reloaded"
    else
        log_info "Waybar is not currently running. Starting Waybar..."
        waybar &>/dev/null &
        disown || true
        log_success "Waybar started"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║     Waybar Hover Media Controller        ║"
    echo "  ║               Setup                      ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    ensure_playerctl
    detect_waybar_files
    backup_waybar_files
    deploy_media_script
    patch_waybar_config
    patch_waybar_style
    ensure_hyprland_keybinds
    validate_and_reload

    echo ""
    log_success "Waybar Hover Media Controller setup successfully completed!"
    echo -e "  • ${BOLD}Normal state:${NC} Compact indicator (󰐊 playing / 󰏤 paused / 󰎆 stopped)"
    echo -e "  • ${BOLD}Hover state:${NC}  Expanded media drawer (󰒮 Prev | 󰐊 Play/Pause | 󰒭 Next | Title — Artist)"
    echo -e "  • ${BOLD}Mouse clicks:${NC} Left: Play/Pause | Middle: Prev | Right: Next | Scroll: Volume"
    echo ""
}

main "$@"
