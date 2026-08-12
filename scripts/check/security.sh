#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: security.sh
# Description: Validates user permissions, wheel group, sudo posture, UID 0 accounts,
#              SSH configuration, firewall state, and listening ports.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_security() {
    print_category_header "Users, Sudo & Security Configuration"

    local current_user="${USER:-$(id -un)}"

    # 1. Normal user validation
    if [[ ${EUID:-$(id -u)} -eq 0 && "${current_user}" == "root" ]]; then
        warn "security" "user_account" "Running directly as root user (recommended: dedicated sudo user)"
    else
        pass "security" "user_account" "Operating under unprivileged user: ${current_user}"
    fi

    # 2. Wheel group membership
    if getent group wheel &>/dev/null; then
        if id -nG "${current_user}" 2>/dev/null | grep -qw "wheel"; then
            pass "security" "wheel_group" "User '${current_user}' is member of 'wheel' group"
        else
            warn "security" "wheel_group" "User '${current_user}' is NOT in 'wheel' group" \
                 "Add user to wheel: sudo usermod -aG wheel ${current_user}" \
                 "sudo usermod -aG wheel ${current_user}"
        fi
    fi

    # 3. Configured groups from config/base.yaml
    local -a exp_groups=()
    while IFS= read -r grp; do
        [[ -n "${grp}" && ! "${grp}" =~ ^# ]] && exp_groups+=("${grp}")
    done < <(yaml_list_get "${CONFIG_DIR}/base.yaml" "user.groups")

    for grp in "${exp_groups[@]}"; do
        if getent group "${grp}" &>/dev/null; then
            if id -nG "${current_user}" 2>/dev/null | grep -qw "${grp}"; then
                pass "security" "group_${grp}" "User '${current_user}' is member of '${grp}'"
            else
                warn "security" "group_${grp}" "User '${current_user}' missing supplementary group '${grp}'" \
                     "sudo usermod -aG ${grp} ${current_user}" \
                     "sudo usermod -aG ${grp} ${current_user}"
            fi
        else
            info "security" "group_${grp}" "System group '${grp}' not created on system"
        fi
    done

    # 4. Unexpected UID 0 accounts
    if [[ -f /etc/passwd ]]; then
        local -a uid_zero_users=()
        while IFS= read -r u; do
            [[ -n "${u}" && "${u}" != "root" ]] && uid_zero_users+=("${u}")
        done < <(awk -F: '($3 == 0) {print $1}' /etc/passwd 2>/dev/null || true)

        if [[ ${#uid_zero_users[@]} -eq 0 ]]; then
            pass "security" "uid_zero_accounts" "Only 'root' has UID 0"
        else
            fail "security" "uid_zero_accounts" "Security hazard: Unexpected accounts with UID 0: ${uid_zero_users[*]}" \
                 "Inspect /etc/passwd immediately"
        fi
    fi

    # 5. SSH Configuration (if OpenSSH is installed)
    if package_installed "openssh" || [[ -d /etc/ssh ]]; then
        if [[ -f /etc/ssh/sshd_config ]]; then
            pass "security" "ssh_config" "OpenSSH configuration file present"
        fi

        # Check permissions of ~/.ssh if exists
        if [[ -d "${HOME}/.ssh" ]]; then
            local ssh_perm
            ssh_perm="$(stat -c '%a' "${HOME}/.ssh" 2>/dev/null || true)"
            if [[ "${ssh_perm}" == "700" ]]; then
                pass "security" "ssh_dir_perms" "Directory ~/.ssh permissions secure (700)"
            else
                warn "security" "ssh_dir_perms" "Directory ~/.ssh permissions are ${ssh_perm} (expected 700)" \
                     "chmod 700 ~/.ssh" "chmod 700 ~/.ssh" "700" "${ssh_perm}"
            fi
        fi
    fi
}

health_security() {
    print_category_header "Security Runtime Health & Firewall"

    # 1. Firewall status
    local fw_active=false
    local fw_name=""

    if service_exists "ufw" && service_active "ufw"; then
        fw_active=true
        fw_name="ufw"
    elif service_exists "firewalld" && service_active "firewalld"; then
        fw_active=true
        fw_name="firewalld"
    elif service_exists "nftables" && service_active "nftables"; then
        fw_active=true
        fw_name="nftables"
    elif command_exists iptables && iptables -L -n 2>/dev/null | grep -q "Chain"; then
        fw_active=true
        fw_name="iptables"
    fi

    if ${fw_active}; then
        pass "security" "firewall_status" "Active firewall detected (${fw_name})"
    else
        warn "security" "firewall_status" "No active firewall daemon detected (ufw/firewalld/nftables)" \
             "Consider enabling a firewall for untrusted network environments" \
             "sudo pacman -S ufw && sudo systemctl enable --now ufw && sudo ufw default deny && sudo ufw enable"
    fi

    # 2. Listening network ports
    if command_exists ss; then
        local listening_ports
        listening_ports="$(ss -tuln 2>/dev/null | grep -E '^tcp|^udp' | wc -l || echo "0")"
        info "security" "listening_ports" "${listening_ports} listening TCP/UDP port(s)"
    fi
}
