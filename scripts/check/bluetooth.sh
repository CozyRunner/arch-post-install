#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: bluetooth.sh
# Description: Validates Bluetooth subsystem, service, and controller presence.
#              Gracefully marks SKIP if Bluetooth is unconfigured / unavailable.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_bluetooth() {
    print_category_header "Bluetooth Subsystem Configuration"

    # Check if Bluetooth is in config
    local has_bt_config=false
    for conf in "${CONFIG_DIR}/base.yaml" "${CONFIG_DIR}/${PROFILE:-${DEFAULT_PROFILE}}.yaml"; do
        if [[ -f "${conf}" ]] && grep -qE "(bluez|bluetooth)" "${conf}"; then
            has_bt_config=true
            break
        fi
    done

    # Check if hardware adapter exists
    local has_bt_hw=false
    if command_exists rfkill && rfkill list bluetooth 2>/dev/null | grep -q "bluetooth"; then
        has_bt_hw=true
    elif command_exists lsusb && lsusb 2>/dev/null | grep -qi "bluetooth"; then
        has_bt_hw=true
    elif command_exists lspci && lspci 2>/dev/null | grep -qi "bluetooth"; then
        has_bt_hw=true
    fi

    if ! ${has_bt_config} && ! ${has_bt_hw}; then
        skip "bluetooth" "bluetooth_stack" "Bluetooth hardware not detected and not configured in repository"
        return 0
    fi

    # 1. Packages
    local -a bt_pkgs=("bluez" "bluez-utils")
    for pkg in "${bt_pkgs[@]}"; do
        if package_installed "${pkg}"; then
            pass "bluetooth" "pkg_${pkg}" "Bluetooth package '${pkg}' is installed"
        else
            warn "bluetooth" "pkg_${pkg}" "Bluetooth package '${pkg}' is missing" \
                 "sudo pacman -S --needed ${pkg}"
        fi
    done

    # 2. Service enabled
    if service_exists "bluetooth"; then
        if service_enabled "bluetooth"; then
            pass "bluetooth" "service_enabled" "bluetooth.service is enabled"
        else
            warn "bluetooth" "service_enabled" "bluetooth.service is not enabled" \
                 "sudo systemctl enable --now bluetooth"
        fi
    fi
}

health_bluetooth() {
    print_category_header "Bluetooth Runtime Health"

    if ! service_exists "bluetooth"; then
        skip "bluetooth" "bluetooth_service" "Bluetooth service not available"
        return 0
    fi

    # 1. Service active
    if service_active "bluetooth"; then
        pass "bluetooth" "service_active" "bluetooth.service is active (running)"
    else
        warn "bluetooth" "service_active" "bluetooth.service is inactive" \
             "sudo systemctl start bluetooth"
    fi

    # 2. RFKILL block status
    if command_exists rfkill; then
        if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
            warn "bluetooth" "rfkill_status" "Bluetooth is soft-blocked by rfkill" \
                 "Unblock Bluetooth: sudo rfkill unblock bluetooth"
        elif rfkill list bluetooth 2>/dev/null | grep -q "Hard blocked: yes"; then
            warn "bluetooth" "rfkill_status" "Bluetooth is hard-blocked by hardware switch"
        elif rfkill list bluetooth 2>/dev/null | grep -q "bluetooth"; then
            pass "bluetooth" "rfkill_status" "Bluetooth adapter unblocked and available"
        fi
    fi
}
