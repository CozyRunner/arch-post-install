#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: maintenance.sh
# Description: Validates system maintenance timers (fstrim, paccache, reflector),
#              journal disk footprint, pacman cache, and update hygiene.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_maintenance() {
    print_category_header "System Maintenance & Housekeeping Configuration"

    # 1. Periodic SSD Trim (fstrim.timer)
    if service_exists "fstrim.timer"; then
        if service_enabled "fstrim.timer"; then
            pass "maintenance" "timer_fstrim" "Weekly SSD trim timer (fstrim.timer) is enabled"
        else
            warn "maintenance" "timer_fstrim" "fstrim.timer is installed but disabled" \
                 "Enable SSD trim: sudo systemctl enable --now fstrim.timer" \
                 "sudo systemctl enable --now fstrim.timer"
        fi
    fi

    # 2. Pacman cache cleanup
    if package_installed "pacman-contrib"; then
        pass "maintenance" "pacman_contrib" "pacman-contrib utilities available (paccache)"
        if service_exists "paccache.timer"; then
            if service_enabled "paccache.timer"; then
                pass "maintenance" "timer_paccache" "Automatic pacman cache cleaner (paccache.timer) enabled"
            else
                info "maintenance" "timer_paccache" "paccache.timer available (optional: sudo systemctl enable paccache.timer)"
            fi
        fi
    else
        info "maintenance" "pacman_contrib" "pacman-contrib not installed (recommended for paccache)"
    fi

    # 3. Reflector mirror ranking
    if package_installed "reflector"; then
        pass "maintenance" "reflector_installed" "Reflector mirror management tool installed"
        if service_exists "reflector.timer" && service_enabled "reflector.timer"; then
            pass "maintenance" "timer_reflector" "Automatic mirror ranking timer (reflector.timer) enabled"
        fi
    fi
}

health_maintenance() {
    print_category_header "Maintenance Runtime Health & Disk Footprint"

    # 1. Systemd Journal Size
    if command_exists journalctl; then
        local j_usage
        j_usage="$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGTP]?B' | head -1 || echo "0B")"
        if [[ -n "${j_usage}" ]]; then
            # Convert to rough MB for comparison if possible
            local j_mb=0
            if [[ "${j_usage}" =~ ([0-9.]+)G ]]; then
                j_mb="$(awk "BEGIN {print int(${BASH_REMATCH[1]} * 1024)}")"
            elif [[ "${j_usage}" =~ ([0-9.]+)M ]]; then
                j_mb="$(awk "BEGIN {print int(${BASH_REMATCH[1]})}")"
            fi

            if [[ "${j_mb}" -ge "${JOURNAL_FAIL_MB:-2048}" ]]; then
                warn "maintenance" "journal_size" "Large journal footprint: ${j_usage} (exceeds ${JOURNAL_FAIL_MB}MB)" \
                     "Vacuum old journals: sudo journalctl --vacuum-size=200M" \
                     "sudo journalctl --vacuum-size=200M"
            elif [[ "${j_mb}" -ge "${JOURNAL_WARN_MB:-500}" ]]; then
                info "maintenance" "journal_size" "Journal storage size: ${j_usage}"
            else
                pass "maintenance" "journal_size" "Journal size healthy: ${j_usage}"
            fi
        fi
    fi

    # 2. Pacman Cache Size
    if [[ -d /var/cache/pacman/pkg ]]; then
        local cache_size
        cache_size="$(du -sh /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}' || echo "N/A")"
        pass "maintenance" "pacman_cache" "Pacman package cache footprint: ${cache_size}"
    fi
}
