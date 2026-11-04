# Changelog

All notable changes to the Arch Post-Install project are documented here.

## [Unreleased] — 2026-11-04

### Added
- **Unified Session Manager** (`session.sh`): Central entry point for `logout`, `lock`, `suspend`, `reboot`, `poweroff`. All keybindings, power menus, and floating menu actions now delegate here.
- **Data-Driven Power Menu** (`menus/power.json`): Power/session menu entries are defined in JSON instead of hard-coded `case` blocks. Both the Hyprland and Waybar power menu scripts read this file via `jq`.
- **Global Theme Sync** (`sync_theme.sh`): Standalone script to re-synchronize all UI components (SwayNC, Waybar, Rofi, Kitty, Alacritty, Hyprland, Hyprlock) to the cached theme state. Supports `--status`, `--validate`, `--component <name>`, and `--all` sub-commands.
- **Theme Preview CLI** (`preview_theme.sh`): Generates an HTML color swatch page for any scheme+mode and opens it in the browser. Supports `--list`, `--compare <mode>`, and single-scheme preview.
- **User-Configurable Keybindings** (`config/user.yaml` + `generate_user_bindings.sh`): Users can override default keybinding shortcuts (logout, lock, power menu) by editing `config/user.yaml` and regenerating the Lua binding file.
- **Pre-commit hook** (`.git/hooks/pre-commit`): Runs `lint_check_slots.sh` and `shellcheck` before every commit.
- **Project roadmap** (`docs/roadmap.md`): Tracks implementation phases and progress.
- **CHANGELOG.md**: This file.

### Changed
- `floating_menu.sh`: Power & Session section now delegates all actions to `session.sh`. Added "Preview Theme Colors" and "Sync Theme" entries to the Appearance sub-menu.
- `notification_center.sh`: The `sync` action now delegates to `sync_theme.sh --component swaync` with an inline fallback.
- `utilities.lua`: Logout keybinding calls `session.sh logout` instead of inline `loginctl`.
- `docs/archive/hypr/additional-bindings.conf`: Fallback logout binding updated to use `session.sh logout`.
- Documentation updated across `README.md`, `dotfiles/hypr/README.md`, `dotfiles/waybar/README.md`, and `dotfiles/swaync/README.md`.

### Removed
- `dotfiles/swaync/style-dark.css` and `style-light.css`: Byte-for-byte copies of `style.css` that served no purpose. Theme differentiation is handled entirely by `colors-*.css` files.

