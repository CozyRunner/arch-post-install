# Changelog

All notable changes to the Arch Post-Install project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2026-11-12]

### Fixed
- `dotfiles/hypr/scripts/keep_awake.sh`:
  - Resolved UI defect in Custom Duration selection: replaced empty `rofi -dmenu` prompt (which rendered an awkward blank element in listview) with a dedicated `custom_duration_menu` sub-menu.
  - Added extended duration presets (`10m`, `20m`, `45m`, `90m`, `3h`, `5h`, `6h`, `12h`, `24h`) and seamless return navigation (`󰌍  Back to Keep Awake Menu`).
  - Enabled direct duration typing: entering any custom interval (e.g. `45m`, `1h30m`, `2.5h`) directly in the entry field in either the main menu or the sub-menu now automatically parses and activates Keep Awake.
  - Overhauled manual duration entry prompt (`prompt_custom_duration`) using `-theme-str` override to disable listview and provide a clean single-line dialog with contextual placeholder text.
  - Added support for decimal hour durations (e.g. `1.5h`, `0.5h`, `2.5h`) in `parse_duration` and visual desktop warnings via `notify-send` on invalid inputs.

## [2026-11-11]

### Added
- **Keep Awake — System Sleep Inhibitor** (`dotfiles/hypr/scripts/keep_awake.sh`): Temporarily prevents system sleep and suspend for a configurable period while allowing display power-saving timeouts to function normally:
  - Inhibits system sleep/suspend via `systemd-inhibit --what=sleep:handle-suspend-key:handle-lid-switch --mode=block` without modifying systemd or hypridle configuration files.
  - Keeps system awake while allowing the screen/monitor to dim and turn off automatically per existing DPMS settings.
  - Dynamic duration parser supporting flexible intervals: `15m`, `30m`, `1h`, `2h`, `4h`, `90m`, `1h30m`, and integer minutes.
  - Interactive Rofi duration picker (`keep_awake.sh menu`) with quick presets, custom duration prompt, live remaining countdown, and extension actions (+30m, +1h, +2h).
  - Immediate manual deactivation (`keep_awake.sh off`) and toggle support (`keep_awake.sh toggle`).
  - Automatic expiration with desktop notifications (`notify-send`) and automatic restoration of default sleep behavior.
  - Waybar status module (`custom/keep_awake`) displaying dynamic time-remaining indicator (`󰅶 45m`), distinct active/inactive styles, left-click menu, right-click toggle, and instant signal updates via `RTMIN+8`.
  - SwayNC Notification Center integration: added dedicated `󰅶 Awake` dropdown menu in `menubar#tools` with quick duration triggers.
  - Control Center integration: added "Keep System Awake" action to Quick Controls and Power & Session menus in `dotfiles/hypr/scripts/floating_menu.sh` and `power.json`.
  - Manual suspend protection in `dotfiles/hypr/scripts/session.sh`: checks inhibitor state before executing `systemctl suspend` to prevent accidental sleep.
  - User keybinding integration: mapped `SUPER + ALT + A` across `utilities.lua`, `personal.lua`, `config/user.yaml`, and `generate_user_bindings.sh`.

## [2026-11-08]

### Changed
- `dotfiles/waybar/scripts/clipboard.sh`:
  - Overhauled hover tooltip and alt text format with rich GTK/Pango markup, clear visual hierarchy, and distinct empty/active states.
  - Added live preview of up to 3 recent clipboard clips with automated `@html` entity escaping, whitespace normalization, and clean truncation.
  - Added `alt` text field (`Empty` / `${count} items`) and context-aware CSS classes (`active`, `empty`, `disabled`) to the Waybar JSON payload.
  - Expanded the middle-click clipboard action menu to integrate OCR screen text extraction (`ocr_extract.sh`) alongside Clipse manager and history clearing.

## [2026-11-07]

### Changed
- `dotfiles/hypr/scripts/app_launcher.sh`:
  - Limited recent applications displayed on launch to 5 (`MAX_RECENT=5`), ensuring the "View All Applications" action button is always immediately visible without scrolling.
  - Removed duplicate text arrow icon (`󰌍`) from "Back to Recent Applications", retaining a single clean SVG arrow icon from the system icon theme (`go-previous`).
  - Removed redundant prefix icon from "View All Applications" for clean alignment with the desktop icon slot.
  - Switched message header strings to theme-adaptive semantic markup (`<b>`, `<small>`) instead of hardcoded hex colors to adapt seamlessly to both dark and light palettes.
- `dotfiles/rofi/launcher.rasi`:
  - Enhanced design with accent-tinted 1px borders (`@border`), 18px radius, and jitter-free 1px transparent base borders on elements.
  - Styled message header with a subtle frosted glass pill background (`@bg-alt`, 10px radius) for visual balance.
  - Refined action button icon sizing (26px) and contrast states for seamless navigation feedback.

## [2026-11-06]

### Added
- **Modern Rofi Application Launcher** (`app_launcher.sh` + `launcher.rasi`): Clean, minimal, and responsive application launcher powered by Rofi script mode:
  - Defaults to displaying Most Recently Used (MRU) applications on open for fast, uncluttered access.
  - Prominent "View All Applications" action switches seamlessly to the complete installed applications catalog.
  - "Back to Recent" action allows quick return to the MRU view.
  - Automatic usage tracking dynamically elevates launched applications to the top of the recent list.
  - Rich search indexing matching `.desktop` names, generic names, localized comments, and category keywords.
  - Keyboard shortcut `Shift + Delete` allows instant removal of entries from launcher history.
  - Pre-seeded default application recommendations on clean installations.
  - Dedicated glassmorphic theme (`dotfiles/rofi/launcher.rasi`) featuring a 2-column grid and theme variable integration.
  - Keybindings mapped to `SUPER + Space` and `SUPER + R` across Hyprland configurations.
- **Screenshot OCR Text Extraction Engine** (`ocr_extract.sh`): Extract and copy text from screen captures directly to the Wayland clipboard (`wl-copy`) using the Tesseract OCR engine:
  - Interactive area selection mode (`slurp`), full screen capture (`grim`), active focused window capture (`hyprctl activewindow`), specific display output capture, and an interactive Rofi menu selector.
  - Hyprland keybindings: `SUPER + Shift + O` (area selection), `SUPER + Ctrl + O` (entire screen), `SUPER + Alt + O` (active window), and `SUPER + Alt + Print` (OCR menu).
- **Screenshot CLI & Menu OCR Subcommands** (`screenshot.sh`): Extended screenshot script with `ocr`, `ocr-area`, `ocr-screen`, `ocr-window`, `ocr-display`, `ocr-active`, and `ocr-menu` modes, and integrated OCR options directly into the screenshot Rofi selector menu.
- **Notification Center & Control Center OCR Integration**:
  - SwayNC quick actions grid button (`󰚢 OCR Text`) in `dotfiles/swaync/config.json`.
  - SwayNC tools menubar dropdown (`menubar#tools`) featuring a dedicated `󰚢 OCR Tool` menu with Area, Active Window, and Full Screen actions.
  - Quick Controls hub integration in `dotfiles/hypr/scripts/floating_menu.sh`.
- **User Keybinding Mapping for OCR** (`config/user.yaml` + `generate_user_bindings.sh`): Added user-configurable `ocr_area` and `ocr_screen` bindings.

### Changed
- `dotfiles/hypr/config/keybinds/core.lua`: Bound application launcher to `app_launcher.sh` for `SUPER + Space`.
- `dotfiles/hypr/config/programs.lua`: Updated primary `programs.menu` definition to invoke `app_launcher.sh`.
- `dotfiles/swaync/config.json`: Optimized tools menubar layout and styling for enhanced dropdown menu visibility.
- `.gitignore`: Comprehensive review and overhaul to prevent symlinked dotfiles runtime/state leaks (dynamic keybinding overrides, crash reports, TUI journal databases, Clipse history, Calcure backups, file manager logs), add local user override patterns (`*.local.yaml`, `.env.local`), expand editor/IDE coverage (Neovim ShaDa/swap, Cursor, VSCode, JetBrains), and ignore Linux core dumps and packaging artifacts.

### Fixed
- `dotfiles/rofi/launcher.rasi`: Resolved Rofi RASI parser syntax errors caused by unsupported CSS `box-shadow` property and invalid `:hover` pseudo-class, replacing them with standard Rofi state classes (`element selected.normal`, `element normal.active`).

## [2026-11-05]

### Added
- **SPM (Simple Package Manager) Integration** (`spm.sh`): Added wrapper and launcher for `spm-arch` ([adelmonte/Simple_Package_Manager](https://github.com/adelmonte/Simple_Package_Manager)), an interactive visual Arch Linux package browser and manager powered by `fzf`.
  - Added AUR dependency `spm-arch` to `config/hyprland.yaml`.
  - Keybinding `SUPER + Shift + P` mapped in `dotfiles/hypr/config/keybinds/personal.lua`.
  - Integrated into Control Center quick menus.
- **TUI Applications Hub** (`tui_app.sh`): Central launcher and interactive Rofi picker for terminal user interface applications:
  - Supported TUI applications: SPM, btop, lazygit, lazydocker, yazi, calcure, tui-journal, posting, wiremix, impala, bluetui, and zellij.
  - Keybinding `SUPER + Alt + P` mapped in `dotfiles/hypr/config/keybinds/personal.lua`.
  - Dedicated TUI Applications sub-menu in Control Center (`floating_menu.sh`).

## [2026-11-04]

### Added
- **Unified Session Manager** (`session.sh`): Central entry point for handling `logout`, `lock`, `suspend`, `reboot`, and `poweroff`. Keybindings, power menus, and floating menu actions delegate to this script.
- **Data-Driven Power Menu** (`menus/power.json`): Power/session menu entries defined in structured JSON format. Refactored both Hyprland (`dotfiles/hypr/scripts/power_menu.sh`) and Waybar (`dotfiles/waybar/scripts/power_menu.sh`) power menus to parse `power.json` via `jq`.
- **Global Theme Synchronization** (`sync_theme.sh`): Multi-component theme sync utility to re-synchronize SwayNC, Waybar, Rofi, Kitty, Alacritty, Hyprland, and Hyprlock to the active theme state. Supports `--status`, `--validate`, `--component <name>`, and `--all`.
- **Theme Preview CLI** (`preview_theme.sh`): Generates an HTML color swatch preview page for any scheme and mode with browser preview, scheme comparison, and palette listing.
- **User-Configurable Keybindings** (`config/user.yaml` + `generate_user_bindings.sh`): Allows overriding default keybindings (logout, lock, power menu, OCR, etc.) via user configuration compiled into Lua.
- **Repository Quality & Governance**:
  - Pre-commit hook (`.git/hooks/pre-commit`): Enforces `lint_check_slots.sh` and ShellCheck before commits.
  - Project architecture roadmap (`docs/roadmap.md`): Implementation phase and milestones tracker.

### Changed
- `dotfiles/hypr/scripts/floating_menu.sh`: Power & Session section delegates all actions to `session.sh`. Added "Preview Theme Colors" and "Sync Theme" entries to the Appearance sub-menu.
- `dotfiles/hypr/scripts/notification_center.sh`: Sourcing and `sync` action delegates to `sync_theme.sh --component swaync` with inline fallback.
- `dotfiles/hypr/config/keybinds/utilities.lua`: Logout keybinding updated to invoke `session.sh logout`.
- `docs/archive/hypr/additional-bindings.conf`: Fallback logout keybinding updated to `session.sh logout`.
- Documentation updated across `README.md`, `dotfiles/hypr/README.md`, `dotfiles/waybar/README.md`, and `dotfiles/swaync/README.md`.

### Removed
- `dotfiles/swaync/style-dark.css` and `style-light.css`: Removed redundant duplicate copies of `style.css`; theme customization is handled exclusively through `colors-*.css`.

### Fixed
- `tests/test_plan.sh`: Fixed test assertion for already-installed package NOOP operations.
- `lib/planner.sh` & `modules/core.sh`: Enhanced command quoting and error status checks.

## [2026-10-30]

### Added
- **SwayNC Theme Switcher Integration**: Integrated SwayNC notification center color scheme switching with modular CSS variables and real-time reload.

### Changed
- **Session Logout**: Replaced `hyprctl exit` with `loginctl terminate-user` for clean PAM session termination and proper resource cleanup.

## [2026-10-21]

### Added
- **Screen Recording Suite**: Added screen recording capabilities using `wf-recorder` with configurable audio capture, interactive area/monitor selection, Hyprland keybindings, status notifications, and SwayNC status widgets.

## [2026-10-20]

### Added
- **Rosé Pine Theme**: Added Rosé Pine color scheme palette variants across desktop components.
- **Screenshot Tool Suite**: Integrated screenshot workflow utilizing `grim`, `slurp`, and `swappy` with area, window, and full screen modes.

### Changed
- **SwayNC Layout**: Updated notification center quick action buttons grid layout and interactive button styles.

## [2026-10-05]

### Added
- **NCDU Disk Usage Analyzer**: Integrated `ncdu` terminal disk analyzer with dedicated menu options and keybinds.

### Changed
- **Glassmorphic Floating Quick Menu**: Redesigned floating settings menu with glassmorphic styling, enhanced icons, and robust script fallbacks.

## [2026-09-29]

### Added
- **Clipse Clipboard Manager**: Migrated clipboard management from `cliphist` to `clipse`, providing a modern TUI clipboard manager with floating window rules.

### Fixed
- **Engine Reliability**: Resolved 11 silent-failure defects in the post-install engine and verification test suite.

## [2026-09-17]

### Added
- **Declarative Plan & Dry-Run Mode**: Implemented `bin/arch-postinstall plan` for pre-execution inspection of planned system changes without mutating the host.
- Comprehensive automated plan testing suite (`tests/test_plan.sh`).

## [2026-08-26]

### Added
- **System Hardening & Optimization**: Added ZRAM swap configuration, Btrfs subvolume layout optimization, and UFW firewall profile setup.
- **Interactive Doctor Remediation**: Added `doctor --fix` interactive system remediation engine.

## [2026-08-12]

### Added
- **System Check & Health Framework**: Modular diagnostics framework (`scripts/check/*.sh`, `bin/arch-postinstall check/health`) with automated test suite and CLI runner.
- **Waybar MPRIS Media Controller**: Hover-expanding media controller widget for Waybar.
- **Catppuccin Mocha Color Theme**: System-wide theme styling across window manager and status bar.

## [2026-08-11]

### Changed
- **Modular Lua Hyprland Architecture**: Refactored static Hyprland configuration into a modular Lua-based structure (`hyprland.lua`, `config/*.lua`) leveraging Hyprland 0.55+ Lua configuration bindings.
