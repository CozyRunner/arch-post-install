#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Check Category: network.sh
# Description: Validates network interfaces, IP assignment, default route, DNS,
#              reachability, and network management services.
# ──────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2154,SC1091,SC2034

check_network() {
    print_category_header "Network Configuration & Daemon Posture"

    # 1. Active network interfaces
    if command_exists ip; then
        local -a ifaces=()
        while IFS= read -r iface; do
            [[ -n "${iface}" ]] && ifaces+=("${iface}")
        done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v '^lo$' || true)

        if [[ ${#ifaces[@]} -gt 0 ]]; then
            pass "network" "network_interfaces" "Network interface(s) present: ${ifaces[*]}"
        else
            warn "network" "network_interfaces" "No non-loopback network interfaces detected"
        fi
    fi

    # 2. Configured Network Management Service
    local net_mgr_found=false
    for svc in NetworkManager systemd-networkd iwd dhcpcd connman; do
        if service_exists "${svc}"; then
            if service_enabled "${svc}"; then
                pass "network" "manager_${svc}" "Network manager service '${svc}' is enabled"
                net_mgr_found=true
            fi
        fi
    done

    if ! ${net_mgr_found}; then
        if is_virtual_machine; then
            info "network" "network_manager" "No standard network daemon enabled (host-bridged networking)"
        else
            warn "network" "network_manager" "No standard network manager service (NetworkManager/systemd-networkd) enabled" \
                 "Enable NetworkManager: sudo systemctl enable --now NetworkManager" \
                 "sudo systemctl enable --now NetworkManager"
        fi
    fi
}

health_network() {
    print_category_header "Network Runtime Health & Connectivity"

    # 1. IP address assignment
    local has_ip=false
    local ip_addr=""
    if command_exists ip; then
        ip_addr="$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{print $2}' | head -1 || true)"
        if [[ -n "${ip_addr}" ]]; then
            has_ip=true
            pass "network" "ip_assigned" "Active IP address: ${ip_addr}"
        else
            warn "network" "ip_assigned" "No global IPv4 address assigned"
        fi
    fi

    # 2. Default route
    if command_exists ip; then
        local gw
        gw="$(ip route show default 2>/dev/null | head -1 | awk '{print $3}' || true)"
        if [[ -n "${gw}" ]]; then
            pass "network" "default_route" "Default gateway configured (${gw})"
        else
            warn "network" "default_route" "No default gateway / route configured"
        fi
    fi

    # 3. DNS resolution
    local dns_works=false
    if getent hosts "${PING_HOST:-archlinux.org}" &>/dev/null; then
        dns_works=true
        pass "network" "dns_resolution" "DNS resolution operational (resolved ${PING_HOST:-archlinux.org})"
    elif getent hosts localhost &>/dev/null; then
        warn "network" "dns_resolution" "Local DNS works but failed to resolve ${PING_HOST:-archlinux.org}"
    else
        fail "network" "dns_resolution" "DNS resolution completely non-functional" \
             "Check /etc/resolv.conf or systemd-resolved service" \
             "sudo systemctl restart systemd-resolved || cat /etc/resolv.conf"
    fi

    # 4. Internet reachability
    local internet_connected=false
    if command_exists curl; then
        if curl -s --connect-timeout "${HTTP_TIMEOUT:-5}" --max-time "${HTTP_TIMEOUT:-5}" "${HTTP_URL:-https://archlinux.org}" >/dev/null 2>&1; then
            internet_connected=true
            pass "network" "internet_connectivity" "Internet connectivity verified (HTTP/HTTPS)"
        fi
    fi

    if ! ${internet_connected} && command_exists ping; then
        if ping -c 1 -W "${PING_TIMEOUT:-3}" "${PING_HOST:-archlinux.org}" >/dev/null 2>&1; then
            internet_connected=true
            pass "network" "internet_connectivity" "Internet connectivity verified (ICMP ping)"
        fi
    fi

    if ! ${internet_connected}; then
        warn "network" "internet_connectivity" "Cannot reach ${HTTP_URL:-https://archlinux.org}" \
             "Check network cables, Wi-Fi credentials, or routing table"
    fi
}
