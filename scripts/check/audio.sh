#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: audio.sh
# Description: Validates PipeWire audio stack, wireplumber, and audio sinks.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_audio() {
    print_category_header "Audio Subsystem Configuration (PipeWire)"

    # Check if audio packages are configured
    local has_audio_config=false
    for conf in "${CONFIG_DIR}/base.yaml" "${CONFIG_DIR}/${PROFILE:-${DEFAULT_PROFILE}}.yaml"; do
        if [[ -f "${conf}" ]] && grep -qE "(pipewire|wireplumber|pulseaudio)" "${conf}"; then
            has_audio_config=true
            break
        fi
    done

    if ! ${has_audio_config} && ! package_installed "pipewire"; then
        skip "audio" "audio_stack" "Audio stack not configured in repository profiles"
        return 0
    fi

    # 1. PipeWire core packages
    local -a audio_pkgs=("pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa")
    for pkg in "${audio_pkgs[@]}"; do
        if package_installed "${pkg}"; then
            pass "audio" "pkg_${pkg}" "Audio package '${pkg}' is installed"
        else
            warn "audio" "pkg_${pkg}" "Audio package '${pkg}' is not installed" \
                 "sudo pacman -S --needed ${pkg}"
        fi
    done
}

health_audio() {
    print_category_header "Audio Subsystem Runtime Health"

    if ! package_installed "pipewire" && ! command_exists pipewire; then
        skip "audio" "audio_services" "PipeWire not installed"
        return 0
    fi

    # Check user audio services
    local -a audio_services=("pipewire" "pipewire-pulse" "wireplumber")
    for svc in "${audio_services[@]}"; do
        if systemctl --user is-active --quiet "${svc}" 2>/dev/null; then
            pass "audio" "user_svc_${svc}" "User service '${svc}' is active (running)"
        else
            if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
                warn "audio" "user_svc_${svc}" "User service '${svc}' is inactive" \
                     "systemctl --user restart ${svc}"
            else
                info "audio" "user_svc_${svc}" "User service '${svc}' inactive (session not active)"
            fi
        fi
    done

    # Check audio sinks if wpctl or pactl is available
    if command_exists wpctl; then
        if wpctl status 2>/dev/null | grep -q "Audio"; then
            pass "audio" "audio_sinks" "PipeWire audio endpoints / sinks detected via wpctl"
        fi
    elif command_exists pactl; then
        if pactl info &>/dev/null; then
            pass "audio" "audio_sinks" "PulseAudio / PipeWire audio server responsive"
        fi
    fi
}
