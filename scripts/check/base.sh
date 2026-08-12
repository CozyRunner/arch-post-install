#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: base.sh
# Description: Validates core system configuration (hostname, timezone, locale,
#              kernel, architecture, and microcode).
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_base() {
    print_category_header "Base System Configuration"

    # 1. Arch Linux verification
    if is_arch_linux; then
        pass "base" "os_distribution" "Arch Linux verified (/etc/arch-release)"
    else
        fail "base" "os_distribution" "System is not running Arch Linux" \
             "/etc/arch-release not found" "" "Arch Linux" "Non-Arch Linux"
    fi

    # 2. Architecture
    local arch
    arch="$(uname -m)"
    if [[ "${arch}" == "x86_64" ]]; then
        pass "base" "architecture" "Architecture is x86_64"
    else
        warn "base" "architecture" "Non-standard architecture: ${arch}"
    fi

    # 3. Kernel
    local kernel
    kernel="$(uname -r)"
    pass "base" "kernel_version" "Running Linux kernel ${kernel}"

    # 4. Hostname
    local expected_hostname current_hostname
    expected_hostname="$(yaml_value_get "${CONFIG_DIR}/base.yaml" "system.hostname")"
    current_hostname="$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || true)"

    if [[ -n "${expected_hostname}" ]]; then
        if [[ "${current_hostname}" == "${expected_hostname}" ]]; then
            pass "base" "hostname" "Hostname matches config: ${current_hostname}"
        else
            fail "base" "hostname" "Hostname mismatch: '${current_hostname}'" \
                 "Config expects '${expected_hostname}'" \
                 "sudo hostnamectl set-hostname ${expected_hostname}" \
                 "${expected_hostname}" "${current_hostname}"
        fi
    elif [[ -n "${current_hostname}" ]]; then
        pass "base" "hostname" "Hostname configured: ${current_hostname}"
    else
        fail "base" "hostname" "No hostname configured in /etc/hostname"
    fi

    # 5. Timezone
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
            pass "base" "timezone" "Timezone matches config: ${current_tz}"
        else
            warn "base" "timezone" "Timezone mismatch: '${current_tz}'" \
                 "Config expects '${expected_tz}'" \
                 "sudo timedatectl set-timezone ${expected_tz}" \
                 "${expected_tz}" "${current_tz}"
        fi
    elif [[ -n "${current_tz}" ]]; then
        pass "base" "timezone" "Timezone configured: ${current_tz}"
    else
        warn "base" "timezone" "Timezone not configured" \
             "Set timezone using timedatectl" \
             "sudo timedatectl set-timezone UTC"
    fi

    # 6. Locale
    local expected_locale current_locale
    expected_locale="$(yaml_value_get "${CONFIG_DIR}/base.yaml" "system.locale")"
    current_locale="$(locale 2>/dev/null | grep '^LANG=' | cut -d= -f2 | tr -d '"' || true)"

    if [[ -n "${expected_locale}" ]]; then
        if [[ "${current_locale}" == "${expected_locale}" ]]; then
            pass "base" "locale" "Locale matches config: ${current_locale}"
        else
            warn "base" "locale" "Locale mismatch: current '${current_locale}', expected '${expected_locale}'" \
                 "Check /etc/locale.gen and /etc/locale.conf" \
                 "sudo locale-gen && echo 'LANG=${expected_locale}' | sudo tee /etc/locale.conf" \
                 "${expected_locale}" "${current_locale}"
        fi
    elif [[ -n "${current_locale}" ]]; then
        pass "base" "locale" "Locale configured: ${current_locale}"
    fi

    # 7. CPU Microcode
    local cpu_vendor
    cpu_vendor="$(grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | awk '{print $3}' || echo "Unknown")"
    if [[ "${cpu_vendor}" == "GenuineIntel" ]]; then
        if package_installed "intel-ucode" || [[ -f /boot/intel-ucode.img ]]; then
            pass "base" "cpu_microcode" "Intel CPU microcode package/image installed"
        else
            warn "base" "cpu_microcode" "Intel CPU detected but intel-ucode package is missing" \
                 "Installing microcode improves system stability and security" \
                 "sudo pacman -S intel-ucode" \
                 "intel-ucode installed" "not installed"
        fi
    elif [[ "${cpu_vendor}" == "AuthenticAMD" ]]; then
        if package_installed "amd-ucode" || [[ -f /boot/amd-ucode.img ]]; then
            pass "base" "cpu_microcode" "AMD CPU microcode package/image installed"
        else
            warn "base" "cpu_microcode" "AMD CPU detected but amd-ucode package is missing" \
                 "Installing microcode improves system stability and security" \
                 "sudo pacman -S amd-ucode" \
                 "amd-ucode installed" "not installed"
        fi
    else
        info "base" "cpu_microcode" "Virtual CPU or non-x86 processor detected: ${cpu_vendor}"
    fi
}

health_base() {
    print_category_header "Base System Runtime Health"

    # Uptime
    if command_exists uptime; then
        local up_str
        up_str="$(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\), .*/\1/')"
        pass "base" "uptime" "System uptime: ${up_str}"
    fi

    # Kernel taint status
    if [[ -f /proc/sys/kernel/tainted ]]; then
        local taint
        taint="$(cat /proc/sys/kernel/tainted 2>/dev/null || echo "0")"
        if [[ "${taint}" -eq 0 ]]; then
            pass "base" "kernel_taint" "Kernel is clean (untainted: 0)"
        else
            info "base" "kernel_taint" "Kernel taint flag: ${taint} (out-of-tree modules or drivers loaded)"
        fi
    fi
}
