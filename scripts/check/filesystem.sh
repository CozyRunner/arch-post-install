#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: filesystem.sh
# Description: Validates root, boot, and home mounts, fstab entries, capacity,
#              inode limits, read-only status, and SMART/NVMe health.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_filesystem() {
    print_category_header "Filesystem & Mount Configuration"

    # 1. Root filesystem mount
    if mount_exists "/"; then
        local root_fs
        root_fs="$(findmnt -n -o FSTYPE,OPTIONS "/" 2>/dev/null || df -T / | tail -1 | awk '{print $2}')"
        pass "filesystem" "mount_root" "Root filesystem (/) mounted (${root_fs})"
    else
        fail "filesystem" "mount_root" "Root filesystem (/) not found in mount table"
    fi

    # 2. /boot mount (if separate partition)
    if [[ -d /boot ]]; then
        if mount_exists "/boot" || mount_exists "/efi" || mount_exists "/boot/efi"; then
            pass "filesystem" "mount_boot" "Boot filesystem mounted"
        else
            info "filesystem" "mount_boot" "/boot is part of the root partition"
        fi
    fi

    # 3. /home mount check
    if [[ -d /home ]]; then
        if mount_exists "/home"; then
            pass "filesystem" "mount_home" "Dedicated /home filesystem mounted"
        else
            info "filesystem" "mount_home" "/home is part of the root partition"
        fi
    fi

    # 4. /etc/fstab presence
    if [[ -f /etc/fstab ]]; then
        local fstab_entries
        fstab_entries="$(grep -vE '^(#|[[:space:]]*$)' /etc/fstab | wc -l || echo "0")"
        pass "filesystem" "fstab_configured" "/etc/fstab exists with ${fstab_entries} active entry/entries"
    else
        warn "filesystem" "fstab_configured" "/etc/fstab not found"
    fi
}

health_filesystem() {
    print_category_header "Storage & Filesystem Runtime Health"

    # 1. Capacity & Inode usage for key filesystems
    local -a check_mounts=("/" "/home" "/boot" "/var")
    local checked=()

    for mnt in "${check_mounts[@]}"; do
        if ! mount_exists "${mnt}"; then
            continue
        fi
        # Avoid duplicate checks if /home is on /
        local dev
        dev="$(findmnt -n -o SOURCE "${mnt}" 2>/dev/null || true)"
        [[ -z "${dev}" ]] && continue

        local already_done=false
        for d in "${checked[@]}"; do
            [[ "${d}" == "${dev}" ]] && already_done=true && break
        done
        ${already_done} && continue
        checked+=("${dev}")

        # Check capacity
        local use_pct
        use_pct="$(df -P "${mnt}" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")"
        local avail
        avail="$(df -h "${mnt}" 2>/dev/null | tail -1 | awk '{print $4}' || echo "N/A")"

        if [[ "${use_pct}" -ge "${DISK_FAIL_PERCENT}" ]]; then
            fail "filesystem" "disk_space_${mnt//\//_}" "Critical disk usage on ${mnt}: ${use_pct}% (Available: ${avail})" \
                 "Disk is nearly full! Free up space to prevent system crashes" \
                 "sudo paccache -r && sudo journalctl --vacuum-size=100M" \
                 "< ${DISK_WARN_PERCENT}%" "${use_pct}%"
        elif [[ "${use_pct}" -ge "${DISK_WARN_PERCENT}" ]]; then
            warn "filesystem" "disk_space_${mnt//\//_}" "High disk usage on ${mnt}: ${use_pct}% (Available: ${avail})" \
                 "Clean pacman cache or unnecessary files" \
                 "sudo paccache -rk2" \
                 "< ${DISK_WARN_PERCENT}%" "${use_pct}%"
        else
            pass "filesystem" "disk_space_${mnt//\//_}" "Disk usage on ${mnt}: ${use_pct}% (Available: ${avail})"
        fi

        # Check inode usage
        local inode_pct
        inode_pct="$(df -Pi "${mnt}" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")"
        if [[ -n "${inode_pct}" && "${inode_pct}" =~ ^[0-9]+$ ]]; then
            if [[ "${inode_pct}" -ge "${INODE_FAIL_PERCENT}" ]]; then
                fail "filesystem" "inode_space_${mnt//\//_}" "Critical inode usage on ${mnt}: ${inode_pct}%"
            elif [[ "${inode_pct}" -ge "${INODE_WARN_PERCENT}" ]]; then
                warn "filesystem" "inode_space_${mnt//\//_}" "High inode usage on ${mnt}: ${inode_pct}%"
            else
                pass "filesystem" "inode_space_${mnt//\//_}" "Inode usage on ${mnt}: ${inode_pct}%"
            fi
        fi
    done

    # 2. Read-only filesystem health check (detect unexpected read-only mounts)
    local -a ro_mounts=()
    while IFS= read -r ro_mnt; do
        [[ -n "${ro_mnt}" ]] && ro_mounts+=("${ro_mnt}")
    done < <(findmnt -n -o TARGET,OPTIONS 2>/dev/null | grep -E '\b(ext[234]|btrfs|xfs|f2fs)\b' | grep -E '\bro\b' | awk '{print $1}' || true)

    if [[ ${#ro_mounts[@]} -gt 0 ]]; then
        fail "filesystem" "readonly_mounts" "Writable filesystem remounted as read-only: ${ro_mounts[*]}" \
             "Indicates underlying storage errors or filesystem corruption" \
             "Inspect dmesg: sudo dmesg -T | grep -iE '(error|remount-ro)'" \
             "read-write" "read-only (${ro_mounts[*]})"
    else
        pass "filesystem" "readonly_mounts" "No corrupted read-only remounts detected"
    fi

    # 3. SMART / NVMe health check (opportunistic)
    if command_exists smartctl; then
        if is_root || has_sudo; then
            local smart_errors=0
            for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
                [[ ! -b "${disk}" ]] && continue
                if sudo smartctl -H "${disk}" 2>/dev/null | grep -q "PASSED"; then
                    pass "filesystem" "smart_${disk##*/}" "SMART health on ${disk}: PASSED"
                else
                    ((smart_errors++))
                    warn "filesystem" "smart_${disk##*/}" "SMART health warning on ${disk}"
                fi
            done
        else
            skip "filesystem" "smart_status" "SMART storage check requires root/sudo privileges"
        fi
    else
        skip "filesystem" "smart_status" "smartctl not installed (optional: install smartmontools)"
    fi
}
