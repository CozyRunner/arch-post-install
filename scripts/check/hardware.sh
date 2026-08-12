#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: hardware.sh
# Description: Detects and validates CPU, RAM, GPU, and system resources.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_hardware() {
    print_category_header "Hardware Devices & Topology"

    # 1. CPU
    if [[ -f /proc/cpuinfo ]]; then
        local model cores
        model="$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "CPU")"
        cores="$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo || echo "1")"
        pass "hardware" "cpu_info" "Processor: ${model} (${cores} threads)"
    fi

    # 2. Total RAM
    if command_exists free; then
        local total_ram
        total_ram="$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "Unknown")"
        pass "hardware" "total_memory" "Installed physical memory: ${total_ram}"
    fi

    # 3. GPU detection
    if command_exists lspci; then
        local -a gpus=()
        while IFS= read -r gpu_line; do
            [[ -n "${gpu_line}" ]] && gpus+=("${gpu_line}")
        done < <(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/^[0-9a-f:.]* //' || true)

        if [[ ${#gpus[@]} -gt 0 ]]; then
            for g in "${gpus[@]}"; do
                pass "hardware" "gpu_device" "Display Controller: ${g}"
            done
        else
            info "hardware" "gpu_device" "No PCI GPU detected (headless or virtual display)"
        fi
    elif [[ -d /sys/class/drm ]]; then
        local cards
        cards="$(ls -1 /sys/class/drm/card* 2>/dev/null | grep -v '-' | wc -l || echo "0")"
        if [[ "${cards}" -gt 0 ]]; then
            pass "hardware" "gpu_device" "DRM graphics cards detected: ${cards}"
        fi
    fi
}

health_hardware() {
    print_category_header "Hardware Resources & Memory Health"

    # 1. Memory Usage
    if [[ -f /proc/meminfo ]]; then
        local total_kb avail_kb used_pct
        total_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
        avail_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"

        if [[ -n "${total_kb}" && -n "${avail_kb}" && "${total_kb}" -gt 0 ]]; then
            used_pct=$(( ( (total_kb - avail_kb) * 100 ) / total_kb ))

            if [[ "${used_pct}" -ge "${MEM_FAIL_PERCENT:-95}" ]]; then
                fail "hardware" "memory_pressure" "Critical memory usage: ${used_pct}%" \
                     "System under extreme memory pressure" \
                     "Kill high-memory processes using btop/htop"
            elif [[ "${used_pct}" -ge "${MEM_WARN_PERCENT:-85}" ]]; then
                warn "hardware" "memory_pressure" "High memory usage: ${used_pct}%"
            else
                pass "hardware" "memory_pressure" "Memory utilization healthy (${used_pct}% used)"
            fi
        fi

        # 2. Swap Usage
        local swap_total swap_free
        swap_total="$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)"
        swap_free="$(awk '/SwapFree:/ {print $2}' /proc/meminfo)"

        if [[ -n "${swap_total}" && "${swap_total}" -gt 0 ]]; then
            local swap_used_pct=$(( ( (swap_total - swap_free) * 100 ) / swap_total ))
            if [[ "${swap_used_pct}" -ge "${SWAP_FAIL_PERCENT:-95}" ]]; then
                fail "hardware" "swap_usage" "Critical swap space usage: ${swap_used_pct}%"
            elif [[ "${swap_used_pct}" -ge "${SWAP_WARN_PERCENT:-80}" ]]; then
                warn "hardware" "swap_usage" "High swap space usage: ${swap_used_pct}%"
            else
                pass "hardware" "swap_usage" "Swap usage: ${swap_used_pct}%"
            fi
        else
            info "hardware" "swap_usage" "No swap configured (system running without swap)"
        fi
    fi
}
