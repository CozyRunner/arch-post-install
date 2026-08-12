#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: power.sh
# Description: Validates chassis type, battery detection (laptops), power profile
#              daemons, and thermal zones.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_power() {
    print_category_header "Power Management & Chassis Configuration"

    local chassis
    chassis="$(get_chassis_type)"

    if is_laptop; then
        pass "power" "chassis_type" "Chassis type detected: ${chassis} (mobile platform)"

        # Check battery presence
        if [[ -d /sys/class/power_supply ]]; then
            local -a bats=()
            while IFS= read -r b; do
                [[ -n "${b}" ]] && bats+=("${b}")
            done < <(ls -d /sys/class/power_supply/BAT* 2>/dev/null || true)

            if [[ ${#bats[@]} -gt 0 ]]; then
                pass "power" "battery_detected" "Battery detected: $(basename "${bats[0]}")"
            else
                info "power" "battery_detected" "No battery sysfs interface detected"
            fi
        fi

        # Check power management daemons
        local pm_found=false
        for svc in power-profiles-daemon tlp auto-cpufreq tuned; do
            if service_exists "${svc}"; then
                if service_enabled "${svc}" || service_active "${svc}"; then
                    pass "power" "power_daemon" "Power management daemon '${svc}' is enabled/active"
                    pm_found=true
                    break
                fi
            fi
        done

        if ! ${pm_found}; then
            info "power" "power_daemon" "Using standard Linux/systemd kernel power management (optional: power-profiles-daemon or tlp)"
        fi
    else
        pass "power" "chassis_type" "Chassis type: ${chassis} (stationary platform, battery checks omitted)"
    fi
}

health_power() {
    print_category_header "Power & Thermal Runtime Health"

    # 1. Battery status on laptops
    if [[ -d /sys/class/power_supply ]]; then
        for bat in /sys/class/power_supply/BAT*; do
            [[ ! -d "${bat}" ]] && continue
            local bat_name status cap
            bat_name="$(basename "${bat}")"
            status="$(cat "${bat}/status" 2>/dev/null || echo "Unknown")"
            cap="$(cat "${bat}/capacity" 2>/dev/null || echo "N/A")"
            pass "power" "battery_${bat_name}" "Battery ${bat_name}: ${cap}% (${status})"
        done
    fi

    # 2. Thermal zones
    if [[ -d /sys/class/thermal ]]; then
        local max_temp=0
        for tz in /sys/class/thermal/thermal_zone*/temp; do
            [[ ! -f "${tz}" ]] && continue
            local raw_t
            raw_t="$(cat "${tz}" 2>/dev/null || echo "0")"
            if [[ "${raw_t}" =~ ^[0-9]+$ ]]; then
                local c_temp=$(( raw_t / 1000 ))
                if [[ "${c_temp}" -gt "${max_temp}" ]]; then
                    max_temp="${c_temp}"
                fi
            fi
        done

        if [[ "${max_temp}" -gt 0 ]]; then
            if [[ "${max_temp}" -ge 90 ]]; then
                warn "power" "thermal_health" "High CPU temperature: ${max_temp}°C (thermal throttling risk)"
            else
                pass "power" "thermal_health" "Peak thermal temperature healthy (${max_temp}°C)"
            fi
        fi
    fi
}
