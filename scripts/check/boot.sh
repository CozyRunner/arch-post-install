#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: boot.sh
# Description: Validates bootloader presence, EFI system partition, kernel and
#              initramfs image consistency.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_boot() {
    print_category_header "Bootloader & Kernel Configuration"

    # Virtual machine / container detection
    if is_virtual_machine && [[ ! -d /boot || -z "$(ls -A /boot 2>/dev/null)" ]]; then
        info "boot" "container_environment" "Virtual or containerized environment detected with host-managed boot"
    fi

    # 1. UEFI vs BIOS mode
    if is_uefi; then
        pass "boot" "boot_mode" "UEFI boot mode active"

        # Check ESP mount
        local esp_mounted=false
        local esp_path=""
        for p in /boot /boot/efi /efi; do
            if mount_exists "${p}"; then
                esp_mounted=true
                esp_path="${p}"
                break
            fi
        done

        if ${esp_mounted}; then
            pass "boot" "esp_mount" "EFI System Partition (ESP) mounted at ${esp_path}"
        else
            # If /boot is non-empty and has vmlinuz, might be root on same fs or container
            if [[ -d /boot && -n "$(ls /boot/vmlinuz* 2>/dev/null || true)" ]]; then
                info "boot" "esp_mount" "UEFI mode with unpartitioned /boot or systemd EFI mount"
            else
                warn "boot" "esp_mount" "EFI partition (/boot or /boot/efi) is not mounted" \
                     "ESP should be mounted to ensure kernel updates correctly install" \
                     "Check /etc/fstab for EFI partition mount definition"
            fi
        fi
    else
        info "boot" "boot_mode" "Legacy BIOS boot mode detected"
    fi

    # 2. Bootloader detection
    local bootloader_found=false
    local bootloader_name=""

    # Check systemd-boot
    if command_exists bootctl && bootctl is-installed &>/dev/null; then
        bootloader_found=true
        bootloader_name="systemd-boot"
    elif [[ -f /boot/loader/loader.conf || -f /efi/loader/loader.conf || -f /boot/efi/loader/loader.conf ]]; then
        bootloader_found=true
        bootloader_name="systemd-boot"
    fi

    # Check GRUB
    if [[ -d /boot/grub || -f /boot/grub/grub.cfg ]]; then
        bootloader_found=true
        bootloader_name="${bootloader_name:+${bootloader_name}, }GRUB"
    fi

    # Check Limine
    if [[ -f /boot/limine.conf || -f /boot/limine.sys || -f /boot/limine/limine.conf ]]; then
        bootloader_found=true
        bootloader_name="${bootloader_name:+${bootloader_name}, }Limine"
    fi

    # Check rEFInd
    if [[ -d /boot/refind || -d /boot/EFI/refind || -d /boot/efi/EFI/refind ]]; then
        bootloader_found=true
        bootloader_name="${bootloader_name:+${bootloader_name}, }rEFInd"
    fi

    # Check UKI / EFISTUB
    if [[ -d /boot/EFI/Linux || -d /efi/EFI/Linux || -d /boot/efi/EFI/Linux ]]; then
        bootloader_found=true
        bootloader_name="${bootloader_name:+${bootloader_name}, }Unified Kernel Images (UKI/EFISTUB)"
    fi

    if ${bootloader_found}; then
        pass "boot" "bootloader" "Detected bootloader: ${bootloader_name}"
    else
        if is_virtual_machine; then
            info "boot" "bootloader" "No standalone bootloader detected (managed by hypervisor)"
        else
            warn "boot" "bootloader" "No standard bootloader configuration detected in /boot" \
                 "Verify bootloader (systemd-boot, GRUB, Limine, or EFISTUB) is installed"
        fi
    fi

    # 3. Installed Kernel Images
    local kernels
    kernels="$(ls -1 /boot/vmlinuz-* 2>/dev/null || true)"
    if [[ -n "${kernels}" ]]; then
        local k_list
        k_list="$(echo "${kernels}" | xargs -n1 basename | paste -sd, -)"
        pass "boot" "kernel_images" "Kernel image(s) found in /boot: ${k_list}"
    else
        if is_virtual_machine; then
            info "boot" "kernel_images" "No local /boot/vmlinuz (managed by container host)"
        else
            fail "boot" "kernel_images" "No kernel image (vmlinuz-*) found in /boot" \
                 "Reinstall kernel package to regenerate boot image" \
                 "sudo pacman -S linux" \
                 "vmlinuz-* present" "missing"
        fi
    fi

    # 4. Initramfs Images
    local initramfs
    initramfs="$(ls -1 /boot/initramfs-*.img 2>/dev/null || true)"
    if [[ -n "${initramfs}" ]]; then
        local init_list
        init_list="$(echo "${initramfs}" | xargs -n1 basename | paste -sd, -)"
        pass "boot" "initramfs_images" "Initramfs image(s) found: ${init_list}"

        # Consistency check: verify initramfs is not zero-byte and matches kernel
        for k in /boot/vmlinuz-*; do
            [[ ! -f "${k}" ]] && continue
            local k_name
            k_name="$(basename "${k}" | sed 's/vmlinuz-//')"
            local matching_init="/boot/initramfs-${k_name}.img"
            if [[ -f "${matching_init}" ]]; then
                if [[ ! -s "${matching_init}" ]]; then
                    fail "boot" "initramfs_${k_name}" "Initramfs ${matching_init} is 0 bytes (corrupt)" \
                         "Regenerate initramfs with mkinitcpio" \
                         "sudo mkinitcpio -P" \
                         "valid initramfs" "empty file"
                else
                    pass "boot" "initramfs_${k_name}_sync" "Initramfs for '${k_name}' present and valid"
                fi
            fi
        done
    else
        if ! is_virtual_machine; then
            warn "boot" "initramfs_images" "No initramfs-*.img found in /boot" \
                 "Regenerate initramfs images" \
                 "sudo mkinitcpio -P"
        fi
    fi
}

health_boot() {
    print_category_header "Bootloader Runtime Health"

    if is_uefi && command_exists efibootmgr; then
        if has_sudo || is_root; then
            local efi_entries
            efi_entries="$(sudo efibootmgr 2>/dev/null | grep -E "^Boot[0-9]+" | wc -l || true)"
            if [[ "${efi_entries}" -gt 0 ]]; then
                pass "boot" "efibootmgr" "EFI NVRAM boot entries verified (${efi_entries} entries)"
            else
                info "boot" "efibootmgr" "efibootmgr returned no active NVRAM boot entries"
            fi
        else
            info "boot" "efibootmgr" "Skipping EFI NVRAM inspection (requires root/sudo)"
        fi
    fi
}
