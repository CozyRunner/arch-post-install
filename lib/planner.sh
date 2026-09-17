#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Library: planner.sh
# Description: Internal desired-state representation, read-only discovery engine,
#              and formatting for the declarative 'plan' / dry-run capability.
# ──────────────────────────────────────────────────────────────────────────────

# Source dependencies if not already loaded
if [[ -z "${LIB_DIR:-}" ]]; then
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi
if ! declare -f print_check_result &>/dev/null; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/output.sh"
fi

# ── Planner State Accumulator ──────────────────────────────────────────────────

PLAN_TOTAL=0
PLAN_CHANGES=0
PLAN_SATISFIED=0
PLAN_SAFE=0
PLAN_CAUTION=0
PLAN_DESTRUCTIVE=0

# Format: OPERATION|SUBSYSTEM|RESOURCE|CURRENT_STATE|DESIRED_STATE|REASON|RISK_LEVEL
PLAN_RECORDS=()

declare -g -A PLAN_PACMAN_CACHE=()
declare -g -A PLAN_AUR_CACHE=()
declare -g -A PLAN_FLATPAK_CACHE=()
declare -g PLAN_AUR_PROBED=false
declare -g PLAN_FLATPAK_PROBED=false

plan_reset() {
    PLAN_TOTAL=0
    PLAN_CHANGES=0
    PLAN_SATISFIED=0
    PLAN_SAFE=0
    PLAN_CAUTION=0
    PLAN_DESTRUCTIVE=0
    PLAN_RECORDS=()
    PLAN_PACMAN_CACHE=()
    PLAN_AUR_CACHE=()
    PLAN_FLATPAK_CACHE=()
    PLAN_AUR_PROBED=false
    PLAN_FLATPAK_PROBED=false
}

# /**
#  * plan_register()
#  * Registers a single planned action or verified state.
#  *
#  * @param {string} operation     ADD | REMOVE | CHANGE | ENABLE | DISABLE | CREATE | UPDATE | SKIP | NOOP
#  * @param {string} subsystem     packages | services | dotfiles | shell | system | profile
#  * @param {string} resource      Resource name/identifier
#  * @param {string} current_state Current discovered state
#  * @param {string} desired_state Target desired state
#  * @param {string} reason        Explanation for action or status
#  * @param {string} risk_level    safe | caution | destructive
#  */
plan_register() {
    local op="$1"
    local sub="$2"
    local res="$3"
    local cur="$4"
    local des="$5"
    local reason="$6"
    local risk="${7:-safe}"

    PLAN_TOTAL=$((PLAN_TOTAL + 1))

    if [[ "${op}" == "NOOP" || "${op}" == "SKIP" ]]; then
        if [[ "${op}" == "NOOP" ]]; then
            PLAN_SATISFIED=$((PLAN_SATISFIED + 1))
        fi
    else
        PLAN_CHANGES=$((PLAN_CHANGES + 1))
    fi

    case "${risk}" in
        safe) PLAN_SAFE=$((PLAN_SAFE + 1)) ;;
        caution) PLAN_CAUTION=$((PLAN_CAUTION + 1)) ;;
        destructive) PLAN_DESTRUCTIVE=$((PLAN_DESTRUCTIVE + 1)) ;;
        *) PLAN_SAFE=$((PLAN_SAFE + 1)) ;;
    esac

    # Sanitize pipe characters
    local c_op="${op//|/ - }"
    local c_sub="${sub//|/ - }"
    local c_res="${res//|/ - }"
    local c_cur="${cur//|/ - }"
    local c_des="${des//|/ - }"
    local c_reason="${reason//|/ - }"
    local c_risk="${risk//|/ - }"

    PLAN_RECORDS+=("${c_op}|${c_sub}|${c_res}|${c_cur}|${c_des}|${c_reason}|${c_risk}")
}

# ── Read-Only State Discovery Functions ────────────────────────────────────────

# 1. Packages (Pacman, AUR, Flatpak)
plan_discover_packages() {
    local config_file="$1"
    [[ ! -f "${config_file}" ]] && return 0

    # Populate Pacman package cache once
    if [[ ${#PLAN_PACMAN_CACHE[@]} -eq 0 ]] && command_exists pacman; then
        while IFS= read -r p; do
            [[ -n "${p}" ]] && PLAN_PACMAN_CACHE["${p}"]=1
        done < <(pacman -Qq 2>/dev/null)
    fi

    # Pacman packages
    local -a pacman_pkgs=()
    while IFS= read -r pkg; do
        [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && pacman_pkgs+=("${pkg}")
    done < <(yaml_list_get "${config_file}" "packages.pacman")

    for pkg in "${pacman_pkgs[@]}"; do
        if [[ -n "${PLAN_PACMAN_CACHE["${pkg}"]:-}" ]]; then
            plan_register "NOOP" "packages" "${pkg}" "installed" "installed" "already installed" "safe"
        elif package_installed "${pkg}"; then
            plan_register "NOOP" "packages" "${pkg}" "installed" "installed" "already installed" "safe"
        else
            plan_register "ADD" "packages" "${pkg}" "missing" "installed" "Declared in packages.pacman" "safe"
        fi
    done

    # Populate AUR package cache once
    if [[ "${PLAN_AUR_PROBED}" != true ]]; then
        PLAN_AUR_PROBED=true
        if command_exists yay; then
            while IFS= read -r p; do
                [[ -n "${p}" ]] && PLAN_AUR_CACHE["${p}"]=1
            done < <(yay -Qqm 2>/dev/null)
        elif command_exists pacman; then
            while IFS= read -r p; do
                [[ -n "${p}" ]] && PLAN_AUR_CACHE["${p}"]=1
            done < <(pacman -Qqm 2>/dev/null)
        fi
    fi

    # AUR packages
    local -a aur_pkgs=()
    while IFS= read -r pkg; do
        [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && aur_pkgs+=("${pkg}")
    done < <(yaml_list_get "${config_file}" "packages.aur")

    for pkg in "${aur_pkgs[@]}"; do
        if [[ -n "${PLAN_AUR_CACHE["${pkg}"]:-}" ]]; then
            plan_register "NOOP" "packages" "${pkg} (AUR)" "installed" "installed" "already installed" "safe"
        elif aur_package_installed "${pkg}"; then
            plan_register "NOOP" "packages" "${pkg} (AUR)" "installed" "installed" "already installed" "safe"
        elif command_exists yay || command_exists pacman; then
            plan_register "ADD" "packages" "${pkg} (AUR)" "missing" "installed" "Declared in packages.aur" "safe"
        else
            plan_register "ADD" "packages" "${pkg} (AUR)" "unavailable" "installed" "AUR helper not available; install yay first" "caution"
        fi
    done

    # Populate Flatpak package cache once
    if [[ "${PLAN_FLATPAK_PROBED}" != true ]]; then
        PLAN_FLATPAK_PROBED=true
        if command_exists flatpak; then
            while IFS= read -r p; do
                [[ -n "${p}" ]] && PLAN_FLATPAK_CACHE["${p}"]=1
            done < <(flatpak list --app --columns=application 2>/dev/null)
        fi
    fi

    # Flatpak packages
    local -a flatpak_pkgs=()
    while IFS= read -r pkg; do
        [[ -n "${pkg}" && ! "${pkg}" =~ ^# ]] && flatpak_pkgs+=("${pkg}")
    done < <(yaml_list_get "${config_file}" "packages.flatpak")

    for pkg in "${flatpak_pkgs[@]}"; do
        if [[ -n "${PLAN_FLATPAK_CACHE["${pkg}"]:-}" ]]; then
            plan_register "NOOP" "packages" "${pkg} (Flatpak)" "installed" "installed" "already installed" "safe"
        elif command_exists flatpak; then
            if flatpak info "${pkg}" &>/dev/null 2>&1; then
                plan_register "NOOP" "packages" "${pkg} (Flatpak)" "installed" "installed" "already installed" "safe"
            else
                plan_register "ADD" "packages" "${pkg} (Flatpak)" "missing" "installed" "Declared in packages.flatpak" "safe"
            fi
        else
            plan_register "ADD" "packages" "${pkg} (Flatpak)" "unavailable" "installed" "Flatpak runtime not installed" "caution"
        fi
    done
}

# 2. Services (Systemd System & User units)
plan_discover_services() {
    local config_file="$1"
    [[ ! -f "${config_file}" ]] && return 0

    local -a services=()
    while IFS= read -r svc; do
        [[ -n "${svc}" && ! "${svc}" =~ ^# ]] && services+=("${svc}")
    done < <(yaml_list_get "${config_file}" "services")

    for svc in "${services[@]}"; do
        local unit_name="${svc}"
        local is_user=false
        local unit_found=false

        # Probe system vs user unit
        if service_exists "${svc}"; then
            unit_found=true
            unit_name="${svc}"
            [[ ! "${unit_name}" =~ \.(service|timer|socket)$ ]] && unit_name="${unit_name}.service"
        elif service_exists "${svc}.timer"; then
            unit_found=true
            unit_name="${svc}.timer"
        elif user_service_exists "${svc}"; then
            unit_found=true
            is_user=true
            unit_name="${svc}"
            [[ ! "${unit_name}" =~ \.(service|timer|socket)$ ]] && unit_name="${unit_name}.service"
        fi

        if ! ${unit_found}; then
            # Unit does not currently exist on disk
            plan_register "SKIP" "services" "${svc}" "missing" "enabled" "Unit file not found on system" "caution"
            continue
        fi

        local enabled=false
        local active=false

        if ${is_user}; then
            user_service_enabled "${unit_name}" && enabled=true
            user_service_active "${unit_name}" && active=true
        else
            service_enabled "${unit_name}" && enabled=true
            service_active "${unit_name}" && active=true
        fi

        if ${enabled} && ${active}; then
            plan_register "NOOP" "services" "${unit_name}" "enabled,active" "enabled,active" "already enabled and active" "safe"
        elif ${enabled} && ! ${active}; then
            plan_register "ENABLE" "services" "${unit_name}" "enabled,inactive" "enabled,active" "Unit enabled but inactive; start needed" "safe"
        else
            plan_register "ENABLE" "services" "${unit_name}" "disabled" "enabled,active" "Unit disabled; enable and start required" "safe"
        fi
    done
}

# 3. Dotfiles & Executables
plan_discover_dotfiles() {
    local config_file="$1"
    [[ ! -f "${config_file}" ]] && return 0

    local -a dotfile_entries=()
    while IFS= read -r entry; do
        [[ -n "${entry}" && ! "${entry}" =~ ^# ]] && dotfile_entries+=("${entry}")
    done < <(yaml_list_get "${config_file}" "dotfiles")

    for entry in "${dotfile_entries[@]}"; do
        local src="${DOTFILES_DIR}/${entry}"
        local dest="${HOME}/.config/${entry}"

        if [[ ! -d "${src}" ]]; then
            plan_register "SKIP" "dotfiles" "~/.config/${entry}" "missing_source" "symlinked" "Source directory dotfiles/${entry} not found" "caution"
            continue
        fi

        if [[ -L "${dest}" ]]; then
            local target
            target="$(readlink -f "${dest}" 2>/dev/null || true)"
            local expected_target
            expected_target="$(readlink -f "${src}" 2>/dev/null || true)"
            if [[ "${target}" == "${expected_target}" ]]; then
                plan_register "NOOP" "dotfiles" "~/.config/${entry}" "symlinked" "symlinked" "already linked to repository" "safe"
            else
                plan_register "UPDATE" "dotfiles" "~/.config/${entry}" "symlinked_elsewhere" "symlinked" "Existing symlink points to ${target}; will be repointed" "caution"
            fi
        elif [[ -d "${dest}" ]]; then
            plan_register "UPDATE" "dotfiles" "~/.config/${entry}" "directory" "symlinked" "Existing directory will be backed up and replaced with symlink" "caution"
        elif [[ -e "${dest}" ]]; then
            plan_register "UPDATE" "dotfiles" "~/.config/${entry}" "file" "symlinked" "Existing file will be backed up and replaced with symlink" "caution"
        else
            plan_register "CREATE" "dotfiles" "~/.config/${entry}" "missing" "symlinked" "Symlink will be created" "safe"
        fi
    done

    # Executables
    local -a exec_entries=()
    while IFS= read -r entry; do
        [[ -n "${entry}" && ! "${entry}" =~ ^# ]] && exec_entries+=("${entry}")
    done < <(yaml_list_get "${config_file}" "executables")

    for entry in "${exec_entries[@]}"; do
        local exec_path="${DOTFILES_DIR}/${entry}"
        if [[ -d "${exec_path}" ]]; then
            local unexec_count=0
            while IFS= read -r -d '' f; do
                [[ ! -x "${f}" ]] && unexec_count=$((unexec_count + 1))
            done < <(find "${exec_path}" -type f -print0 2>/dev/null)

            if [[ ${unexec_count} -gt 0 ]]; then
                plan_register "UPDATE" "dotfiles" "permissions:${entry}" "${unexec_count} non-executable files" "executable" "Ensure chmod +x on scripts" "safe"
            else
                plan_register "NOOP" "dotfiles" "permissions:${entry}" "executable" "executable" "All scripts executable" "safe"
            fi
        elif [[ -f "${exec_path}" ]]; then
            if [[ -x "${exec_path}" ]]; then
                plan_register "NOOP" "dotfiles" "permissions:${entry}" "executable" "executable" "File is executable" "safe"
            else
                plan_register "UPDATE" "dotfiles" "permissions:${entry}" "non-executable" "executable" "Ensure chmod +x" "safe"
            fi
        fi
    done
}

# 4. System Settings (Hostname, Timezone, Locale, Keymap, Pacman, ZRAM, UFW, Bluetooth, Btrfs)
plan_discover_system() {
    local base_config="$1"
    [[ ! -f "${base_config}" ]] && return 0

    # Hostname
    local target_hostname
    target_hostname="$(yaml_value_get "${base_config}" "system.hostname")"
    if [[ -n "${target_hostname}" ]]; then
        local cur_hostname=""
        [[ -f /etc/hostname ]] && cur_hostname="$(cat /etc/hostname 2>/dev/null | tr -d '[:space:]')"
        if [[ -z "${cur_hostname}" ]] && command_exists hostnamectl; then
            cur_hostname="$(hostnamectl hostname 2>/dev/null || true)"
        fi

        if [[ "${cur_hostname}" == "${target_hostname}" ]]; then
            plan_register "NOOP" "system" "hostname" "${cur_hostname}" "${target_hostname}" "already set to ${target_hostname}" "safe"
        else
            plan_register "CHANGE" "system" "hostname" "${cur_hostname:-empty}" "${target_hostname}" "Update hostname to ${target_hostname}" "caution"
        fi
    fi

    # Timezone
    local target_tz
    target_tz="$(yaml_value_get "${base_config}" "system.timezone")"
    if [[ -n "${target_tz}" ]]; then
        local cur_tz=""
        if [[ -L /etc/localtime ]]; then
            cur_tz="$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')"
        elif command_exists timedatectl; then
            cur_tz="$(timedatectl show --property=Timezone --value 2>/dev/null || true)"
        fi

        if [[ "${cur_tz}" == "${target_tz}" ]]; then
            plan_register "NOOP" "system" "timezone" "${cur_tz}" "${target_tz}" "already set to ${target_tz}" "safe"
        else
            plan_register "CHANGE" "system" "timezone" "${cur_tz:-unset}" "${target_tz}" "Update timezone to ${target_tz}" "safe"
        fi
    fi

    # Locale
    local target_locale
    target_locale="$(yaml_value_get "${base_config}" "system.locale")"
    if [[ -n "${target_locale}" ]]; then
        local cur_locale=""
        if [[ -f /etc/locale.conf ]]; then
            cur_locale="$(grep -E '^LANG=' /etc/locale.conf 2>/dev/null | cut -d= -f2 | tr -d '"')"
        fi
        if [[ "${cur_locale}" == "${target_locale}" ]]; then
            plan_register "NOOP" "system" "locale" "${cur_locale}" "${target_locale}" "already set to ${target_locale}" "safe"
        else
            plan_register "CHANGE" "system" "locale" "${cur_locale:-unset}" "${target_locale}" "Generate and set default locale" "safe"
        fi
    fi

    # Keymap
    local target_keymap
    target_keymap="$(yaml_value_get "${base_config}" "system.keymap")"
    if [[ -n "${target_keymap}" ]]; then
        local cur_keymap=""
        if [[ -f /etc/vconsole.conf ]]; then
            cur_keymap="$(grep -E '^KEYMAP=' /etc/vconsole.conf 2>/dev/null | cut -d= -f2 | tr -d '"')"
        fi
        if [[ "${cur_keymap}" == "${target_keymap}" ]]; then
            plan_register "NOOP" "system" "keymap" "${cur_keymap}" "${target_keymap}" "already set to ${target_keymap}" "safe"
        else
            plan_register "CHANGE" "system" "keymap" "${cur_keymap:-unset}" "${target_keymap}" "Configure console keymap" "safe"
        fi
    fi

    # Pacman optimizations
    local pacman_conf="/etc/pacman.conf"
    if [[ -f "${pacman_conf}" ]]; then
        local pacman_ok=true
        grep -q '^Color' "${pacman_conf}" || pacman_ok=false
        grep -q '^ParallelDownloads' "${pacman_conf}" || pacman_ok=false
        grep -q 'ILoveCandy' "${pacman_conf}" || pacman_ok=false
        grep -q '^VerbosePkgLists' "${pacman_conf}" || pacman_ok=false

        if ${pacman_ok}; then
            plan_register "NOOP" "system" "pacman configuration" "optimized" "optimized" "already optimized (Color, ILoveCandy, ParallelDownloads=5)" "safe"
        else
            plan_register "UPDATE" "system" "pacman configuration" "default" "optimized" "Enable Color, ParallelDownloads=5, ILoveCandy, VerbosePkgLists" "safe"
        fi
    else
        plan_register "SKIP" "system" "pacman configuration" "missing" "optimized" "/etc/pacman.conf not found" "caution"
    fi

    # ZRAM swap
    local zram_conf="/etc/systemd/zram-generator.conf"
    if [[ -f "${zram_conf}" ]] && grep -q '\[zram0\]' "${zram_conf}" 2>/dev/null; then
        plan_register "NOOP" "system" "zram configuration" "configured" "configured" "already configured via zram-generator" "safe"
    else
        plan_register "CREATE" "system" "zram configuration" "missing" "configured" "Configure fast in-memory zram compressed swap" "safe"
    fi

    # UFW Firewall
    if command_exists ufw && ufw status 2>/dev/null | grep -qi "Status: active"; then
        plan_register "NOOP" "system" "ufw firewall" "active" "active" "already active with default deny incoming posture" "safe"
    else
        plan_register "ENABLE" "system" "ufw firewall" "inactive" "active" "Enable UFW firewall with default deny incoming posture" "safe"
    fi

    # Bluetooth AutoEnable
    local bt_conf="/etc/bluetooth/main.conf"
    if [[ -f "${bt_conf}" ]]; then
        if grep -q "^AutoEnable[[:space:]]*=[[:space:]]*true" "${bt_conf}" 2>/dev/null; then
            plan_register "NOOP" "system" "bluetooth auto-enable" "enabled" "enabled" "already enabled in main.conf" "safe"
        else
            plan_register "UPDATE" "system" "bluetooth auto-enable" "disabled/commented" "enabled" "Set AutoEnable = true in /etc/bluetooth/main.conf" "safe"
        fi
    fi

    # Btrfs Snapper
    local root_fstype
    root_fstype="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
    if [[ "${root_fstype}" == "btrfs" ]]; then
        if [[ -f "/etc/snapper/configs/root" ]]; then
            plan_register "NOOP" "system" "btrfs snapper snapshots" "configured" "configured" "already configured for root (/)" "safe"
        else
            plan_register "CREATE" "system" "btrfs snapper snapshots" "missing" "configured" "Configure Snapper root config and automated pre/post pacman snapshots" "caution"
        fi
    else
        plan_register "SKIP" "system" "btrfs snapper snapshots" "non-btrfs (${root_fstype:-unknown})" "n/a" "Root filesystem is not Btrfs" "safe"
    fi
}

# 5. User accounts and shell
plan_discover_users_and_shell() {
    local base_config="$1"
    [[ ! -f "${base_config}" ]] && return 0

    local target_shell
    target_shell="$(yaml_value_get "${base_config}" "user.shell")"
    if [[ -n "${target_shell}" ]]; then
        local current_user="${USER:-$(id -un 2>/dev/null || echo "")}"
        local cur_shell=""
        if [[ -n "${current_user}" ]]; then
            cur_shell="$(getent passwd "${current_user}" 2>/dev/null | cut -d: -f7)"
        fi

        if [[ "${cur_shell}" == "${target_shell}" ]]; then
            plan_register "NOOP" "shell" "user shell (${target_shell})" "${cur_shell}" "${target_shell}" "already set to ${target_shell}" "safe"
        else
            plan_register "CHANGE" "shell" "user shell (${target_shell})" "${cur_shell:-unset}" "${target_shell}" "Change user shell to ${target_shell}" "safe"
        fi
    fi

    # Groups
    local -a groups=()
    while IFS= read -r grp; do
        [[ -n "${grp}" && ! "${grp}" =~ ^# ]] && groups+=("${grp}")
    done < <(yaml_list_get "${base_config}" "user.groups")

    local current_user="${USER:-$(id -un 2>/dev/null || echo "")}"
    for grp in "${groups[@]}"; do
        if ! getent group "${grp}" &>/dev/null; then
            plan_register "SKIP" "shell" "group:${grp}" "missing_group" "member" "System group '${grp}' does not exist" "safe"
        elif id -nG "${current_user}" 2>/dev/null | grep -qw "${grp}"; then
            plan_register "NOOP" "shell" "group:${grp}" "member" "member" "User already member of ${grp}" "safe"
        else
            plan_register "ADD" "shell" "group:${grp}" "not_member" "member" "Add ${current_user} to group ${grp}" "safe"
        fi
    done
}

# 6. Profile-specific configuration (Hyprland)
plan_discover_profile() {
    local profile_name="$1"
    local profile_config="$2"

    if [[ "${profile_name}" == "hyprland" ]]; then
        # GTK dark mode
        if command_exists gsettings; then
            local cur_cs
            cur_cs="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)"
            if [[ "${cur_cs}" == "'prefer-dark'" ]]; then
                plan_register "NOOP" "profile" "gtk color-scheme" "prefer-dark" "prefer-dark" "already set to dark mode" "safe"
            else
                plan_register "UPDATE" "profile" "gtk color-scheme" "${cur_cs:-default}" "prefer-dark" "Set GTK dark mode preference" "safe"
            fi
        fi

        # XDG user dirs
        if [[ -f "${HOME}/.config/user-dirs.dirs" ]]; then
            plan_register "NOOP" "profile" "xdg user directories" "created" "created" "already initialized" "safe"
        else
            plan_register "CREATE" "profile" "xdg user directories" "missing" "created" "Run xdg-user-dirs-update" "safe"
        fi

        # KWallet PAM
        local pam_login="/etc/pam.d/login"
        if [[ -f "${pam_login}" ]] && grep -q "pam_kwallet5" "${pam_login}" 2>/dev/null; then
            plan_register "NOOP" "profile" "kwallet pam integration" "configured" "configured" "already configured in pam.d" "safe"
        else
            plan_register "UPDATE" "profile" "kwallet pam integration" "unconfigured" "configured" "Configure KWallet unlock on login" "safe"
        fi
    fi
}

# ── Renderers ─────────────────────────────────────────────────────────────────

# Human-readable CLI diff-style renderer
render_plan_text() {
    echo -e "${C_BOLD}Arch Post-Install Plan${C_RESET}\n"

    local current_sub=""
    local -a subsystems=("packages" "services" "dotfiles" "shell" "system" "profile")

    for target_sub in "${subsystems[@]}"; do
        local found=false
        for record in "${PLAN_RECORDS[@]}"; do
            IFS='|' read -r op sub res cur des reason risk <<< "${record}"
            if [[ "${sub}" == "${target_sub}" ]]; then
                if ! ${found}; then
                    # Capitalize subsystem header
                    local header
                    case "${target_sub}" in
                        packages) header="Packages" ;;
                        services) header="Services" ;;
                        dotfiles) header="Dotfiles" ;;
                        shell)    header="Shell & Permissions" ;;
                        system)   header="System Configuration" ;;
                        profile)  header="Profile-Specific" ;;
                        *)        header="${target_sub^}" ;;
                    esac
                    echo -e "${C_BOLD}${header}${C_RESET}"
                    found=true
                fi

                case "${op}" in
                    ADD|CREATE|ENABLE)
                        echo -e "  ${C_GREEN}+${C_RESET} ${res}"
                        ;;
                    REMOVE|DISABLE)
                        echo -e "  ${C_RED}-${C_RESET} ${res}"
                        ;;
                    CHANGE|UPDATE)
                        echo -e "  ${C_YELLOW}~${C_RESET} ${res} (${reason})"
                        ;;
                    NOOP)
                        echo -e "  ${C_GRAY}~ ${res} (${reason})${C_RESET}"
                        ;;
                    SKIP)
                        echo -e "  ${C_BLUE}○ ${res} (skipped: ${reason})${C_RESET}"
                        ;;
                esac
            fi
        done
        ${found} && echo ""
    done

    # Summary
    echo -e "${C_BOLD}Summary:${C_RESET}"
    echo -e "  ${C_GREEN}${PLAN_CHANGES}${C_RESET} changes"
    echo -e "  ${C_BLUE}${PLAN_SATISFIED}${C_RESET} already satisfied"
    echo -e "  ${C_RED}${PLAN_DESTRUCTIVE}${C_RESET} destructive changes"
}

# JSON serialization conforming to stable schema
render_plan_json() {
    local active_profile="${PROFILE:-hyprland}"
    local active_config="${CUSTOM_CONFIG:-${CONFIG_DIR}/${active_profile}.yaml}"

    printf '{\n'
    printf '  "schema_version": "1.0.0",\n'
    printf '  "status": "success",\n'
    printf '  "profile": "%s",\n' "$(json_escape "${active_profile}")"
    printf '  "config_file": "%s",\n' "$(json_escape "${active_config}")"
    printf '  "summary": {\n'
    printf '    "total_operations": %d,\n' "${PLAN_TOTAL}"
    printf '    "changes": %d,\n' "${PLAN_CHANGES}"
    printf '    "already_satisfied": %d,\n' "${PLAN_SATISFIED}"
    printf '    "safe": %d,\n' "${PLAN_SAFE}"
    printf '    "caution": %d,\n' "${PLAN_CAUTION}"
    printf '    "destructive": %d\n' "${PLAN_DESTRUCTIVE}"
    printf '  },\n'
    printf '  "plan": [\n'

    local total=${#PLAN_RECORDS[@]}
    local i=0

    for record in "${PLAN_RECORDS[@]}"; do
        i=$((i + 1))
        IFS='|' read -r op sub res cur des reason risk <<< "${record}"

        local esc_op esc_sub esc_res esc_cur esc_des esc_reason esc_risk
        esc_op="$(json_escape "${op}")"
        esc_sub="$(json_escape "${sub}")"
        esc_res="$(json_escape "${res}")"
        esc_cur="$(json_escape "${cur}")"
        esc_des="$(json_escape "${des}")"
        esc_reason="$(json_escape "${reason}")"
        esc_risk="$(json_escape "${risk}")"

        printf '    {\n'
        printf '      "operation": "%s",\n' "${esc_op}"
        printf '      "subsystem": "%s",\n' "${esc_sub}"
        printf '      "resource": "%s",\n' "${esc_res}"
        printf '      "current_state": "%s",\n' "${esc_cur}"
        printf '      "desired_state": "%s",\n' "${esc_des}"
        printf '      "reason": "%s",\n' "${esc_reason}"
        printf '      "risk_level": "%s"\n' "${esc_risk}"
        printf '    }'

        if [[ ${i} -lt ${total} ]]; then
            printf ',\n'
        else
            printf '\n'
        fi
    done

    printf '  ]\n'
    printf '}\n'
}

# ── Main Planner Engine Orchestration ─────────────────────────────────────────

execute_plan() {
    local target_profile="${PROFILE:-hyprland}"
    local base_config="${CONFIG_DIR}/base.yaml"
    local profile_config="${CUSTOM_CONFIG:-${CONFIG_DIR}/${target_profile}.yaml}"

    if [[ -n "${CUSTOM_CONFIG:-}" && ! -f "${CUSTOM_CONFIG}" ]]; then
        echo "Error: Configuration file not found: ${CUSTOM_CONFIG}" >&2
        return 3
    fi

    plan_reset

    # 1. Base configuration discovery
    if [[ -f "${base_config}" ]]; then
        plan_discover_packages "${base_config}"
        plan_discover_services "${base_config}"
        plan_discover_system "${base_config}"
        plan_discover_users_and_shell "${base_config}"
    fi

    # 2. Profile configuration discovery
    if [[ -f "${profile_config}" && "${profile_config}" != "${base_config}" ]]; then
        plan_discover_packages "${profile_config}"
        plan_discover_services "${profile_config}"
        plan_discover_dotfiles "${profile_config}"
        plan_discover_profile "${target_profile}" "${profile_config}"
    elif [[ -n "${CUSTOM_CONFIG:-}" && "${CUSTOM_CONFIG}" == "${base_config}" ]]; then
        # Custom config pointed directly to base or custom file
        plan_discover_dotfiles "${base_config}"
    fi

    # 3. Output rendering
    if [[ "${JSON_OUTPUT:-false}" == true ]]; then
        render_plan_json
    else
        render_plan_text
    fi

    return 0
}
