#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: packages.sh
# Description: Validates package database integrity, installed packages against
#              YAML declarations, orphan packages, and pending updates.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_packages() {
    print_category_header "Package Management & Declarative Conformance"

    # 1. Pacman binary presence
    if ! command_exists pacman; then
        fail "packages" "pacman_installed" "Pacman package manager is missing"
        return 1
    else
        pass "packages" "pacman_installed" "Pacman package manager available"
    fi

    # 2. Pacman database lock
    if [[ -f /var/lib/pacman/db.lck ]]; then
        # Check if pacman is actively running
        if pgrep -x pacman &>/dev/null; then
            info "packages" "db_lock" "Pacman is currently running (db.lck held)"
        else
            warn "packages" "db_lock" "Stale pacman database lock file found (/var/lib/pacman/db.lck)" \
                 "If no pacman process is running, remove the lock file" \
                 "sudo rm -f /var/lib/pacman/db.lck" \
                 "no stale lock" "stale lock present"
        fi
    else
        pass "packages" "db_lock" "Pacman database lock is free"
    fi

    # 3. Base packages from config/base.yaml
    local -a base_pkgs=()
    while IFS= read -r pkg; do
        [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && base_pkgs+=("${pkg}")
    done < <(yaml_list_get "${CONFIG_DIR}/base.yaml" "packages.pacman")

    if [[ ${#base_pkgs[@]} -gt 0 ]]; then
        local missing_base=()
        for pkg in "${base_pkgs[@]}"; do
            if ! package_installed "${pkg}"; then
                missing_base+=("${pkg}")
            fi
        done

        if [[ ${#missing_base[@]} -eq 0 ]]; then
            pass "packages" "base_packages" "All ${#base_pkgs[@]} base packages are installed"
        else
            fail "packages" "base_packages" "${#missing_base[@]} base package(s) missing" \
                 "Missing packages: ${missing_base[*]}" \
                 "sudo pacman -S --needed ${missing_base[*]}" \
                 "all base packages installed" "${missing_base[*]}"
        fi
    else
        info "packages" "base_packages" "No pacman packages defined in config/base.yaml"
    fi

    # 4. Profile packages (e.g. config/hyprland.yaml or configured profile)
    local profile_yaml="${CONFIG_DIR}/${PROFILE:-${DEFAULT_PROFILE}}.yaml"
    if [[ -f "${profile_yaml}" ]]; then
        local -a profile_pkgs=()
        while IFS= read -r pkg; do
            [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && profile_pkgs+=("${pkg}")
        done < <(yaml_list_get "${profile_yaml}" "packages.pacman")

        if [[ ${#profile_pkgs[@]} -gt 0 ]]; then
            local missing_profile=()
            for pkg in "${profile_pkgs[@]}"; do
                if ! package_installed "${pkg}"; then
                    missing_profile+=("${pkg}")
                fi
            done

            if [[ ${#missing_profile[@]} -eq 0 ]]; then
                pass "packages" "profile_packages" "All ${#profile_pkgs[@]} '${PROFILE:-${DEFAULT_PROFILE}}' profile packages installed"
            else
                warn "packages" "profile_packages" "${#missing_profile[@]} profile package(s) missing" \
                     "Missing profile packages: ${missing_profile[*]}" \
                     "sudo pacman -S --needed ${missing_profile[*]}" \
                     "all profile packages installed" "${missing_profile[*]}"
            fi
        fi

        # 5. AUR packages from profile
        local -a aur_pkgs=()
        while IFS= read -r pkg; do
            [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && aur_pkgs+=("${pkg}")
        done < <(yaml_list_get "${profile_yaml}" "packages.aur")

        if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
            local missing_aur=()
            for pkg in "${aur_pkgs[@]}"; do
                if ! aur_package_installed "${pkg}"; then
                    missing_aur+=("${pkg}")
                fi
            done

            if [[ ${#missing_aur[@]} -eq 0 ]]; then
                pass "packages" "aur_packages" "All ${#aur_pkgs[@]} AUR packages installed"
            else
                warn "packages" "aur_packages" "${#missing_aur[@]} AUR package(s) missing: ${missing_aur[*]}" \
                     "Install with yay: yay -S --needed ${missing_aur[*]}" \
                     "yay -S --needed ${missing_aur[*]}" \
                     "all AUR packages installed" "${missing_aur[*]}"
            fi
        fi
    fi
}

health_packages() {
    print_category_header "Package Health & Maintenance"

    # 1. Orphan packages
    if command_exists pacman; then
        local -a orphans=()
        while IFS= read -r o; do
            [[ -n "${o}" ]] && orphans+=("${o}")
        done < <(pacman -Qdtq 2>/dev/null || true)

        if [[ ${#orphans[@]} -eq 0 ]]; then
            pass "packages" "orphan_packages" "No orphaned packages found"
        else
            warn "packages" "orphan_packages" "${#orphans[@]} orphan package(s) detected" \
                 "Orphaned packages: ${orphans[*]}" \
                 "sudo pacman -Rns \$(pacman -Qdtq)" \
                 "0 orphans" "${#orphans[@]} orphans"
        fi
    fi

    # 2. Foreign / AUR package count
    if command_exists pacman; then
        local foreign_cnt
        foreign_cnt="$(pacman -Qmq 2>/dev/null | wc -l || echo "0")"
        info "packages" "foreign_packages" "${foreign_cnt} foreign / AUR packages installed"
    fi

    # 3. Pending updates check
    if command_exists checkupdates; then
        local -a updates=()
        while IFS= read -r u; do
            [[ -n "${u}" ]] && updates+=("${u}")
        done < <(checkupdates 2>/dev/null || true)

        if [[ ${#updates[@]} -eq 0 ]]; then
            pass "packages" "pending_updates" "System is up to date (0 pending updates)"
        else
            info "packages" "pending_updates" "${#updates[@]} package update(s) available"
        fi
    fi
}
