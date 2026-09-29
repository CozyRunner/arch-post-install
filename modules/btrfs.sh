#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: btrfs.sh
# Description: Configures automated Btrfs snapshot management using Snapper
#              and snap-pac for rollbacks and disaster recovery.
# ──────────────────────────────────────────────────────────────────────────────

# /**
#  * is_btrfs_root()
#  * Checks if the root filesystem is Btrfs.
#  */
is_btrfs_root() {
    local root_fstype
    root_fstype="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
    [[ "${root_fstype}" == "btrfs" ]]
}

# /**
#  * setup_btrfs_snapshots()
#  * Configures Snapper and snap-pac for automated pre/post pacman snapshots.
#  */
setup_btrfs_snapshots() {
    log_step "Configuring Btrfs snapshot management"

    if ! is_btrfs_root; then
        log_info "Root filesystem is not Btrfs. Skipping Snapper setup."
        return 0
    fi

    log_info "Btrfs root filesystem detected"

    # Ensure required packages are installed
    local -a pkgs_to_install=()
    for pkg in snapper snap-pac; do
        if ! pacman -Q "${pkg}" &>/dev/null; then
            pkgs_to_install+=("${pkg}")
        fi
    done

    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        log_info "Installing Snapper utilities: ${pkgs_to_install[*]}"
        if ! run_logged pacman -S --needed --noconfirm "${pkgs_to_install[@]}"; then
            log_error "Failed to install Snapper utilities. Aborting snapshot setup."
            return 1
        fi
    fi

    # Verify the tooling actually exists before relying on it. Previously the
    # guard below ran even when snapper was missing: `snapper list-configs` would
    # fail, `!` inverted the result, and the code concluded "no root config
    # exists" and deleted /.snapshots.
    if ! command -v snapper &>/dev/null; then
        log_error "snapper is not installed. Install it with: sudo pacman -S --needed snapper"
        return 1
    fi

    # Initialize Snapper config for root if not already configured
    local snapper_configs=""
    if ! snapper_configs="$(sudo snapper list-configs 2>/dev/null)"; then
        log_error "'snapper list-configs' failed; refusing to modify /.snapshots on an unknown state."
        return 1
    fi

    if ! grep -qw "root" <<< "${snapper_configs}"; then
        log_info "Creating Snapper configuration for root (/)"

        # /.snapshots may pre-exist as a btrfs subvolume or a plain directory.
        # `rm -rf` cannot delete a subvolume root (unlink returns ENOTEMPTY), so
        # the old code silently failed there while appearing to succeed. Probe the
        # type and handle each case explicitly; never issue an unverified rm -rf.
        if [[ -e "/.snapshots" ]]; then
            local fs_type=""
            fs_type="$(findmnt -n -o FSTYPE /.snapshots 2>/dev/null || echo "")"

            if [[ "${fs_type}" == "btrfs" ]] && command -v btrfs &>/dev/null; then
                log_warn "/.snapshots is a mounted btrfs subvolume; removing via btrfs subvolume delete"
                sudo umount /.snapshots 2>/dev/null || true
                if ! run_logged btrfs subvolume delete /.snapshots; then
                    log_error "Failed to remove existing /.snapshots subvolume. Aborting to avoid data loss."
                    return 1
                fi
            else
                # Plain directory: only remove it when it is empty, so real
                # user data can never be destroyed by this code path.
                if [[ -d "/.snapshots" ]] && [[ -z "$(sudo ls -A /.snapshots 2>/dev/null)" ]]; then
                    log_info "/.snapshots is an empty directory; removing it"
                    sudo rmdir /.snapshots 2>/dev/null || true
                else
                    log_warn "/.snapshots exists and is not an empty Snapper store."
                    log_warn "Refusing to remove it automatically. Resolve it manually, then re-run:"
                    log_warn "  sudo rm -rf /.snapshots   # only if you are certain it is not a live subvolume"
                    return 1
                fi
            fi
        fi

        if ! run_logged snapper -c root create-config /; then
            log_error "Failed to create Snapper configuration for root"
            return 1
        fi

        # Configure standard snapshot retention limits
        if [[ -f "/etc/snapper/configs/root" ]]; then
            sudo sed -i 's/^TIMELINE_CREATE=".*"/TIMELINE_CREATE="yes"/' /etc/snapper/configs/root
            sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=".*"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
            sudo sed -i 's/^TIMELINE_LIMIT_DAILY=".*"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
            sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=".*"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
            sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=".*"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
            sudo sed -i 's/^TIMELINE_LIMIT_YEARLY=".*"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root
            log_success "Snapper retention policy configured"
        fi
    else
        log_success "Snapper 'root' configuration already exists"
    fi

    # Enable and start Snapper maintenance timers
    for timer in snapper-timeline.timer snapper-cleanup.timer; do
        if systemctl cat "${timer}" &>/dev/null; then
            sudo systemctl enable --now "${timer}" 2>&1 | tee -a "${LOG_FILE}"
            log_success "Enabled timer: ${timer}"
        fi
    done

    log_success "Btrfs snapshot automation configured successfully"
}
