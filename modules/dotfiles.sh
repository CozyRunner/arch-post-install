#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────────────────────────
# Module: dotfiles.sh
# Description: Manages configuration deployment via symlinks.
#              Includes automatic backup logic for existing configurations.
# ──────────────────────────────────────────────────────────────────────────────

# Timestamped backup directory for existing configurations
BACKUP_DIR="${HOME}/.config-backup-$(date +%Y%m%d-%H%M%S)"

# /**
#  * deploy_dotfiles_from_config()
#  * Reads a YAML config and symlinks repository directories to ~/.config/.
#  * @param {string} config - Path to the YAML config file.
#  */
deploy_dotfiles_from_config() {
    local config="$1"

    if [[ ! -f "${config}" ]]; then
        log_error "Config file not found: ${config}"
        return 1
    fi

    local -a dotfile_entries=()
    while IFS= read -r entry; do
        [[ -n "${entry}" ]] && dotfile_entries+=("${entry}")
    done < <(yaml_list "${config}" "dotfiles")

    if [[ ${#dotfile_entries[@]} -eq 0 ]]; then
        log_warn "No dotfiles declared in ${config}"
        return 0
    fi

    log_step "Deploying ${#dotfile_entries[@]} dotfile configs"

    for entry in "${dotfile_entries[@]}"; do
        local src="${DOTFILES_DIR}/${entry}"
        local dest="${HOME}/.config/${entry}"

        if [[ ! -d "${src}" ]]; then
            log_warn "Source not found: ${src} (skipped)"
            continue
        fi

        # Backup existing config if it's a real directory (not already a symlink)
        if [[ -d "${dest}" && ! -L "${dest}" ]]; then
            mkdir -p "${BACKUP_DIR}"
            log_info "Backing up existing ${dest} → ${BACKUP_DIR}/${entry}"
            mv "${dest}" "${BACKUP_DIR}/${entry}"
        elif [[ -L "${dest}" ]]; then
            # Remove old symlink
            rm -f "${dest}"
        fi

        # Create symlink (-n treats dest symlink as a file, preventing nesting)
        ln -sfn "${src}" "${dest}"
        log_success "Linked: ${src} → ${dest}"
    done

    # Make configured executables executable
    local -a exec_entries=()
    while IFS= read -r entry; do
        [[ -n "${entry}" ]] && exec_entries+=("${entry}")
    done < <(yaml_list "${config}" "executables")

    if [[ ${#exec_entries[@]} -gt 0 ]]; then
        for entry in "${exec_entries[@]}"; do
            local exec_path="${DOTFILES_DIR}/${entry}"
            if [[ -d "${exec_path}" ]]; then
                find "${exec_path}" -type f -exec chmod +x {} \;
                log_success "Marked files in ${entry} as executable"
            elif [[ -f "${exec_path}" ]]; then
                chmod +x "${exec_path}"
                log_success "Marked ${entry} as executable"
            else
                log_warn "Executables entry not found: ${exec_path} (skipped)"
            fi
        done
    fi
}
