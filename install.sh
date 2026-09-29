#!/usr/bin/env bash

# ─────────────────────────────────────────────
# Arch Linux Post-Installation Script
# Entry point — Hyprland desktop setup
# ─────────────────────────────────────────────

set -euo pipefail

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all modules
source "${SCRIPT_DIR}/modules/core.sh"
source "${SCRIPT_DIR}/modules/packages.sh"
source "${SCRIPT_DIR}/modules/services.sh"
source "${SCRIPT_DIR}/modules/users.sh"
source "${SCRIPT_DIR}/modules/dotfiles.sh"
source "${SCRIPT_DIR}/modules/system.sh"
source "${SCRIPT_DIR}/modules/btrfs.sh"
source "${SCRIPT_DIR}/modules/flatpak.sh"

# Load profiles (plugin-based)
if [[ -d "${SCRIPT_DIR}/profiles" ]]; then
    for profile in "${SCRIPT_DIR}/profiles/"*.sh; do
        # shellcheck disable=SC1090
        [[ -f "${profile}" ]] && source "${profile}"
    done
fi

# ── Help ──────────────────────────────────────
show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS] [MODE]

Modes:
  full        Full install (Base + Hyprland + dotfiles + optimizations)
  base        Base system only (no DE)
  dotfiles    Deploy dotfiles only

Options:
  -v, --verbose    Enable verbose output
  -d, --dry-run    Show what would be done without executing
  -h, --help       Show this help message

Examples:
  ./install.sh              Interactive mode
  ./install.sh full         Full install non-interactively
  ./install.sh -v base      Verbose base install
  ./install.sh -d dotfiles  Preview dotfiles deployment
EOF
}

# ── Parse Arguments ────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            # shellcheck disable=SC2034
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        full|base|dotfiles)
            MODE="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ── Banner ────────────────────────────────────
show_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║    Arch Linux Post-Install Script    ║"
    echo "  ║         Hyprland Edition             ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BLUE}Log file:${NC} ${LOG_FILE}"
    echo ""
}

# ── Mode Selection ────────────────────────────
select_mode() {
    echo -e "${BOLD}What would you like to install?${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} Full install    — Base + Hyprland + dotfiles"
    echo -e "  ${CYAN}2)${NC} Base only       — Packages & system config, no DE"
    echo -e "  ${CYAN}3)${NC} Dotfiles only   — Deploy configs to ~/.config/"
    echo -e "  ${CYAN}0)${NC} Exit"
    echo ""
    read -rp "  Choice [1-3]: " choice
    echo ""

    case "${choice}" in
        1) MODE="full" ;;
        2) MODE="base" ;;
        3) MODE="dotfiles" ;;
        0) echo "Bye!"; exit 0 ;;
        *) log_error "Invalid choice."; exit 1 ;;
    esac
}

# ── Confirmation ──────────────────────────────
confirm_install() {
    echo -e "${YELLOW}${BOLD}Install mode: ${MODE}${NC}"
    echo -e "This will:"

    case "${MODE}" in
        full)
            echo -e "  • Optimize pacman (parallel downloads, color)"
            echo -e "  • Update the system (pacman -Syu)"
            echo -e "  • Install base + Hyprland packages"
            echo -e "  • Configure ZRAM swap and UFW firewall"
            echo -e "  • Configure Btrfs Snapper automated snapshots (if Btrfs)"
            echo -e "  • Enable system services"
            echo -e "  • Configure user account"
            echo -e "  • Deploy dotfiles (symlinked to ~/.config/)"
            ;;
        base)
            echo -e "  • Optimize pacman (parallel downloads, color)"
            echo -e "  • Update the system (pacman -Syu)"
            echo -e "  • Install base packages"
            echo -e "  • Configure ZRAM swap and UFW firewall"
            echo -e "  • Configure Btrfs Snapper automated snapshots (if Btrfs)"
            echo -e "  • Enable base services"
            echo -e "  • Configure user account"
            ;;
        dotfiles)
            echo -e "  • Deploy Hyprland dotfiles (symlinked to ~/.config/)"
            ;;
    esac

    echo ""
    read -rp "  Proceed? [y/N]: " yn
    case "${yn}" in
        [Yy]*) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
}

# ── Dry-run: delegate to the planner ───────────
# The previous implementation printed the 14 function names it *would* call
# without performing any state discovery, and it disagreed with the planner
# (e.g. it implied dotfile backups that deploy_dotfiles_from_config never
# performed). `arch-postinstall plan` is the real desired-vs-current
# implementation, so it is now the single source of truth for previews.
# This also means a dry run needs no sudo and makes no changes at all.
show_execution_plan() {
    local planner="${SCRIPT_DIR}/bin/arch-postinstall"

    if [[ ! -x "${planner}" ]]; then
        log_error "Planner not found at ${planner}"
        return 4
    fi

    log_warn "DRY RUN MODE — no changes will be made"
    log_info "Delegating to the planner for real desired-vs-current state"
    echo ""

    if [[ "${MODE}" == "dotfiles" ]]; then
        "${planner}" plan --config "${CONFIG_DIR}/hyprland.yaml"
    else
        "${planner}" plan
    fi
}

# ── Main ──────────────────────────────────────
main() {
    show_banner

    # Pre-flight checks
    require_arch

    # Mode selection (can be overridden via CLI arg)
    if [[ -z "${MODE:-}" ]]; then
        select_mode
    fi

    # Dry-run short-circuits before any privileged or mutating step.
    if [[ "${DRY_RUN}" == true ]]; then
        show_execution_plan
        exit $?
    fi

    require_root
    confirm_install

    log_step "Starting '${MODE}' installation"

    case "${MODE}" in
        full)
            tune_pacman
            apply_system_updates
            # setup_core() installs yq; verify before the first config read.
            require_yaml_parser || exit 4
            install_base_packages
            enable_base_services
            setup_users
            setup_zram
            setup_firewall
            setup_btrfs_snapshots
            tune_bluetooth
            ensure_yay
            setup_system_fonts
            setup_system_shell
            setup_flatpak
            setup_hyprland
            ;;
        base)
            tune_pacman
            apply_system_updates
            # setup_core() installs yq; verify before the first config read.
            require_yaml_parser || exit 4
            install_base_packages
            enable_base_services
            setup_users
            setup_zram
            setup_firewall
            setup_btrfs_snapshots
            setup_system_fonts
            setup_system_shell
            ;;
        dotfiles)
            # This mode skips setup_core, so yq may not be installed yet.
            require_yaml_parser || exit 4
            deploy_dotfiles_from_config "${CONFIG_DIR}/hyprland.yaml"
            ;;
        *)
            log_error "Unknown mode: ${MODE}"
            echo "Usage: ./install.sh [full|base|dotfiles]"
            exit 1
            ;;
    esac

    # Done
    echo ""
    log_step "Installation complete!"
    echo -e "  ${GREEN}${BOLD}✔ Mode:${NC}  ${MODE}"
    echo -e "  ${GREEN}${BOLD}✔ Log:${NC}   ${LOG_FILE}"
    echo ""
    if [[ -x "${SCRIPT_DIR}/bin/arch-postinstall" ]]; then
        echo -e "  ${CYAN}${BOLD}System Validation & Health:${NC}"
        echo -e "    Validate setup:    ${BOLD}./bin/arch-postinstall check${NC}"
        echo -e "    System health:     ${BOLD}./bin/arch-postinstall health${NC}"
        echo -e "    Diagnose issues:   ${BOLD}./bin/arch-postinstall doctor${NC}"
        echo -e "    Apply fixes:       ${BOLD}./bin/arch-postinstall doctor --fix${NC}"
        echo ""
    fi
    echo -e "  ${YELLOW}Reboot recommended:${NC} ${BOLD}sudo reboot${NC}"
    echo ""
}

main "$@"
