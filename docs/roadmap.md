# Project Roadmap

This file tracks the high‑level implementation plan for the new feature ideas.

## Phases

| Phase | Goal | Status |
|------|------|--------|
| 0 | Prepare repository (pre‑commit hook, roadmap file) | ✅ Done |
| 1 | Unified **session.sh** script for logout, lock, suspend, reboot, poweroff | ✅ Done |
| 2 | Data‑driven Power Menu (JSON definition via `menus/power.json`) | ✅ Done |
| 3 | Global theme‑color sync (`sync_theme.sh`) + SwayNC cleanup | ✅ Done |
| 4 | Theme Preview CLI (`preview_theme.sh`) | ✅ Done |
| 5 | User‑configurable keybindings (`config/user.yaml` + generator) | ✅ Done |
| 6 | Final documentation, CHANGELOG, release | ✅ Done |
| 7 | TUI Applications Hub & SPM (Simple Package Manager) integration | ✅ Done |

## Completed Work

### Phase 0 — Preparation
- Added `.git/hooks/pre-commit` (runs `lint_check_slots.sh` + `shellcheck`)
- Created `docs/roadmap.md`

### Phase 1 — Unified Session Manager
- Created `dotfiles/hypr/scripts/session.sh` supporting: `logout`, `lock`, `suspend`, `reboot`, `poweroff`
- Updated keybinding `SUPER+Shift+Q` → `session.sh logout`
- Updated `floating_menu.sh` power section → all actions delegate to `session.sh`

### Phase 2 — Data‑Driven Power Menu
- Created `dotfiles/hypr/menus/power.json` with 5 entries
- Refactored `dotfiles/hypr/scripts/power_menu.sh` to read JSON via `jq`
- Refactored `dotfiles/waybar/scripts/power_menu.sh` to read the same JSON
- No hard‑coded `case` statements remain in power menus

### Phase 3 — Global Theme‑Color Sync
- Created `dotfiles/hypr/scripts/sync_theme.sh` with sub‑commands:
  `--status`, `--validate`, `--component <name>`, `--all`
- Updated `notification_center.sh` sync action to delegate to `sync_theme.sh`
- Removed dead `style-dark.css` / `style-light.css` from SwayNC
- Updated SwayNC README with full sync architecture documentation

### Phase 4 — Theme Preview CLI
- Created `dotfiles/hypr/scripts/preview_theme.sh`
  - `preview_theme.sh` — preview current theme
  - `preview_theme.sh glassmorphism dark` — preview specific scheme
  - `preview_theme.sh --list` — list available schemes
  - `preview_theme.sh --compare dark` — side-by-side all schemes
- Added "Preview Theme Colors" entry to floating menu Appearance hub

### Phase 5 — User‑Configurable Keybindings
- Created `config/user.yaml` with keybinding override section
- Created `dotfiles/hypr/scripts/generate_user_bindings.sh`
  - Reads `user.yaml`, emits `user_overrides.lua`
  - Supports `--dry-run` mode
- Added "Sync Theme (All Components)" entry to floating menu Appearance hub

### Phase 6 — Documentation & Release
- Created `CHANGELOG.md` documenting all additions, changes, and removals
- Updated `docs/roadmap.md` with final status
- Updated README.md, hypr README, waybar README, and swaync README

### Phase 7 — TUI Applications Hub & SPM Integration
- Included `spm-arch` in `config/hyprland.yaml` under `packages.aur`
- Created `dotfiles/hypr/scripts/spm.sh` dedicated launcher for SPM with fallback handling
- Created `dotfiles/hypr/scripts/tui_app.sh` central launcher & Rofi interactive menu for all TUI apps
- Added dedicated `💻 TUI Applications` sub-menu and SPM entry in `dotfiles/hypr/scripts/floating_menu.sh`
- Added keybindings: `Super + Shift + P` (SPM) and `Super + Alt + P` (TUI menu) in `personal.lua`
- Configurable via `config/user.yaml` and `generate_user_bindings.sh`

## New Files Added
| File | Purpose |
|------|---------|
| `dotfiles/hypr/scripts/spm.sh` | SPM (Simple Package Manager) launcher |
| `dotfiles/hypr/scripts/tui_app.sh` | TUI apps launcher and interactive selector |
| `dotfiles/hypr/scripts/session.sh` | Unified session manager |
| `dotfiles/hypr/scripts/sync_theme.sh` | Global theme re-synchronization |
| `dotfiles/hypr/scripts/preview_theme.sh` | HTML theme color preview |
| `dotfiles/hypr/scripts/generate_user_bindings.sh` | Generate Lua keybindings from YAML |
| `dotfiles/hypr/menus/power.json` | Data-driven power menu definition |
| `config/user.yaml` | User-configurable overrides |
| `docs/roadmap.md` | This roadmap |
| `CHANGELOG.md` | Project changelog |
| `.git/hooks/pre-commit` | Pre-commit lint hook |

## Files Removed
| File | Reason |
|------|--------|
| `dotfiles/swaync/style-dark.css` | Byte-for-byte duplicate of `style.css` |
| `dotfiles/swaync/style-light.css` | Byte-for-byte duplicate of `style.css` |
