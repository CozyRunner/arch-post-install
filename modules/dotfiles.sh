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

    # Config-driven step: refuse to run on a mis-parsed config rather
    # than silently operating on an empty one.
    require_yaml_parser || return 1
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

    # ~/.config must exist before we can link into it.
    mkdir -p "${HOME}/.config"

    for entry in "${dotfile_entries[@]}"; do
        local src="${DOTFILES_DIR}/${entry}"
        local dest="${HOME}/.config/${entry}"

        if [[ ! -d "${src}" ]]; then
            log_warn "Source not found: ${src} (skipped)"
            continue
        fi

        # Remove an existing symlink first. -L must be tested before -e/-d so
        # symlinked directories are not mistaken for real ones.
        if [[ -L "${dest}" ]]; then
            log_debug "Removing existing symlink: ${dest}"
            rm -f "${dest}"
        elif [[ -e "${dest}" ]]; then
            # Anything else that exists here — a real directory OR a regular file
            # — is user-owned state and must be preserved before it is replaced.
            # Previously a plain file matched neither branch and was silently
            # destroyed by `ln -sfn` below.
            mkdir -p "${BACKUP_DIR}"
            if [[ -d "${dest}" ]]; then
                log_info "Backing up existing directory ${dest} → ${BACKUP_DIR}/${entry}"
            else
                log_info "Backing up existing file ${dest} → ${BACKUP_DIR}/${entry}"
            fi
            if ! mv "${dest}" "${BACKUP_DIR}/${entry}"; then
                log_error "Failed to back up ${dest} — skipping ${entry} to avoid data loss"
                continue
            fi
        fi

        # Create symlink (-n treats dest symlink as a file, preventing nesting)
        if ln -sfn "${src}" "${dest}"; then
            log_success "Linked: ${src} → ${dest}"
        else
            log_error "Failed to link ${dest} → ${src}"
        fi
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
