#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: time.sh
# Description: Validates system clock, timezone, NTP synchronization, and
#              time synchronization daemon status.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_time() {
    print_category_header "Time & NTP Service Configuration"

    # 1. Timezone matching config
    local expected_tz current_tz
    expected_tz="$(yaml_value_get "${CONFIG_DIR}/base.yaml" "system.timezone")"
    if command_exists timedatectl; then
        current_tz="$(timedatectl show --property=Timezone --value 2>/dev/null || true)"
    fi
    if [[ -z "${current_tz}" && -L /etc/localtime ]]; then
        current_tz="$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')"
    fi

    if [[ -n "${expected_tz}" ]]; then
        if [[ "${current_tz}" == "${expected_tz}" ]]; then
            pass "time" "timezone_config" "Timezone is ${current_tz}"
        else
            warn "time" "timezone_config" "Timezone '${current_tz}' differs from config '${expected_tz}'" \
                 "sudo timedatectl set-timezone ${expected_tz}" \
                 "sudo timedatectl set-timezone ${expected_tz}" \
                 "${expected_tz}" "${current_tz}"
        fi
    elif [[ -n "${current_tz}" ]]; then
        pass "time" "timezone_config" "Timezone is ${current_tz}"
    fi

    # 2. Time synchronization service
    local timesync_found=false
    for svc in systemd-timesyncd chronyd ntpd openntpd; do
        if service_exists "${svc}"; then
            if service_enabled "${svc}" || service_active "${svc}"; then
                pass "time" "timesync_daemon" "Time sync service '${svc}' is active/enabled"
                timesync_found=true
                break
            fi
        fi
    done

    if ! ${timesync_found}; then
        # Check systemd-timesyncd via timedatectl
        if command_exists timedatectl && timedatectl show --property=NTP --value 2>/dev/null | grep -q "yes"; then
            pass "time" "timesync_daemon" "NTP service enabled via timedatectl"
        else
            warn "time" "timesync_daemon" "No NTP time synchronization daemon enabled" \
                 "Enable systemd-timesyncd: sudo timedatectl set-ntp true" \
                 "sudo timedatectl set-ntp true"
        fi
    fi
}

health_time() {
    print_category_header "Time Synchronization Runtime Health"

    if command_exists timedatectl; then
        local ntp_synced
        ntp_synced="$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || true)"
        if [[ "${ntp_synced}" == "yes" ]]; then
            pass "time" "clock_synchronized" "System clock is synchronized (NTP synced)"
        else
            warn "time" "clock_synchronized" "System clock is NOT NTP synchronized" \
                 "Synchronize clock: sudo timedatectl set-ntp true" \
                 "sudo timedatectl set-ntp true"
        fi

        # RTC in UTC mode check
        local rtc_utc
        rtc_utc="$(timedatectl show --property=RTCInLocalTZ --value 2>/dev/null || true)"
        if [[ "${rtc_utc}" == "no" ]]; then
            pass "time" "rtc_utc_mode" "Hardware RTC is configured in UTC mode"
        elif [[ "${rtc_utc}" == "yes" ]]; then
            info "time" "rtc_utc_mode" "Hardware RTC is in local time mode (common for dual-boot with Windows)"
        fi
    else
        pass "time" "current_time" "System time: $(date -u)"
    fi
}
