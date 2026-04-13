#  Arch Linux Post-Installation Workbench

[![Hyprland](https://img.shields.io/badge/DE-Hyprland-blue?style=for-the-badge&logo=hyprland)](https://hyprland.org)
[![Arch Linux](https://img.shields.io/badge/OS-Arch%20Linux-blue?style=for-the-badge&logo=arch-linux)](https://archlinux.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

A highly modular, automated, and visually polished Arch Linux post-installation framework. Designed to transform a fresh Arch install into a production-ready **Hyprland** workstation with curated aesthetics and a centralized theming engine.

---

## sparkles: Key Features

- ** Modular Design**: Decoupling packages, services, user configuration, and dotfiles into functional modules.
- ** Unified Theming Engine**: Centralized "Macchiato" (Dark) and "Latte" (Light) themes applied across Hyprland, Waybar, Kitty, Rofi, and GTK via a single shortcut.
- ** Profile-Based**: Supports `full` installation, `base` system setup, or standalone `dotfiles` deployment.
- ** Reliable & Idempotent**: Uses `--needed` flags and pre-flight checks to ensure safe re-runs without breaking existing configurations.
- ** Robust Logging**: Every installation step is timestamped and logged under `logs/` for easy troubleshooting.
- ** Symlinked Dotfiles**: Automated deployment of configurations to `~/.config/` with automatic backups of existing files.

---

## 🚀 Quick Start

### 1. Prerequisite
Ensure you have a fresh Arch Linux installation with a non-root user that has `sudo` privileges and an active internet connection.

### 2. Clone and Execute
```bash
git clone https://github.com/sachinksamad1/arch-post-install.git
cd arch-post-install
chmod +x install.sh
./install.sh
```

### 3. Alternative Usage (Make)
The included `Makefile` provides convenient shortcuts for common tasks:
- `make full`: Complete automated installation (Base + Hyprland + Dotfiles).
- `make base`: Setup system essentials, users, and base packages only.
- `make dotfiles`: Deploy/refresh configuration files via symlinks.
- `make fonts`: Install JetBrainsMono Nerd Font and system fonts.
- `make fish`: Configure Fish with Fisher and essential plugins.

---

## 📁 File Structure

```bash
arch-post-install/
├── install.sh                 # Main entry point & profile selector
├── config/
│   ├── base.yaml              # Core system packages & global settings
│   └── hyprland.yaml          # Hyprland ecosystem, AUR pkgs & dotfile maps
├── modules/
│   ├── core.sh                # The engine: YAML parsing, logging, core updates
│   ├── packages.sh            # Pacman & AUR helper integration
│   ├── services.sh            # Automated Systemd unit management
│   ├── users.sh               # Account hardening, locale, and shell setup
│   ├── dotfiles.sh            # Symlink management with backup logic
│   └── hyprland.sh            # Orchestrator for the Hyprland environment
├── dotfiles/
│   ├── theme/                 #  Unified theme definitions (Dark/Light)
│   ├── hypr/                  # Hyprland window manager configurations
│   ├── waybar/                # CSS-styled status bar
│   ├── kitty/                 # GPU-accelerated terminal config
│   ├── rofi/                  # 8+ Dynamic launcher themes
│   ├── nvim/                  # Neovim (LazyVim) IDE setup
│   ├── yazi/                  # Modern terminal file manager
│   └── zellij/                # Terminal workspace multiplexer
├── scripts/
│   ├── install_yay.sh         # Zero-config AUR helper setup
│   ├── setup_fish.sh          # Fish + Fisher + Plugins
│   └── fonts.sh               # System-wide typography injection
├── logs/                      # Comprehensive history of installations
└── Makefile                   # Developer/Power-user shortcuts
```

---

##  Theming System

This workbench uses a centralized **Unified Theme Engine**.
- **Dark Mode**: Catppuccin Macchiato based.
- **Light Mode**: Catppuccin Latte based.

**How it works:**
The script in `~/.config/hypr/scripts/toggle_theme.sh` (bound to `SUPER + N`) synchronizes:
1. **Hyprland**: Border colors, shadows, and active window aesthetics.
2. **Waybar**: CSS variables for background, modules, and accents.
3. **Kitty**: Colorscheme (`theme.conf`) for the terminal emulator.
4. **Rofi**: Dynamic RASI variables across all launcher modes.
5. **GTK/System**: Synchronizes GNOME color-scheme and icon themes.

---

## ⌨️ Critical Keybindings (Default)

| Keybinding | Action |
|---|---|
| `SUPER + RETURN` | Launch Kitty Terminal |
| `SUPER + SPACE` | App Launcher (Rofi) |
| `SUPER + E` | File Manager (Nautilus/Yazi) |
| `SUPER + B` | Web Browser (Chromium) |
| `SUPER + N` | **Toggle Dark/Light Theme** |
| `SUPER + M` | Quick System Menu |
| `SUPER + L` | Lock Screen |
| `SUPER + C` | Kill Active Window |
| `SUPER + SHIFT + Q` | Elegant Exit/Power Menu |
| `PRINT` | Screenshot Area (Grimblast) |

---

## 🛠️ Included Stack

| Category | Components |
|---|---|
| **Compositor** | Hyprland, hyprpaper, hypridle, hyprlock |
| **Bar / UI** | Waybar, Dunst (Notifications) |
| **Launcher** | Rofi-wayland (Modern, Spotlight, Launchpad themes) |
| **Tools** | Kitty, Yazi, Neovim, Zellij, Btop, Fastfetch |
| **Media** | MPv, IMV, Feh, Evince |
| **Network** | NetworkManager, Impala (TUI), Bluetui (Bluetooth) |
| **Theming** | Papirus Icons, Adwaita GTK, Qt5ct, Kvantum |

---

## 📦 Comprehensive Dependencies List

<details>
<summary>Click to view all Base and Hyprland packages</summary>

### Base Packages (Pacman)
`base-devel`, `btop`, `curl`, `fastfetch`, `git`, `htop`, `jq`, `man-db`, `man-pages`, `openssh`, `p7zip`, `pacman-contrib`, `polkit`, `reflector`, `rsync`, `unar`, `unzip`, `wget`, `xdg-user-dirs`, `xdg-utils`, `yq`, `zip`

### Hyprland Environment (Pacman)
`adwaita-icon-theme`, `bluetui`, `bluez`, `bluez-utils`, `brightnessctl`, `chromium`, `dunst`, `evince`, `feh`, `ffmpegthumbnailer`, `grim`, `hypridle`, `hyprland`, `hyprlock`, `hyprpaper`, `impala`, `imv`, `kitty`, `kvantum`, `mpv`, `nautilus`, `neovim`, `noto-fonts`, `noto-fonts-emoji`, `nwg-look`, `papirus-icon-theme`, `pipewire`, `pipewire-alsa`, `pipewire-pulse`, `playerctl`, `polkit-kde-agent`, `poppler`, `qt5ct`, `rofi-wayland`, `slurp`, `ttf-font-awesome`, `ttf-jetbrains-mono-nerd`, `waybar`, `wl-clipboard`, `wireplumber`, `xdg-desktop-portal-hyprland`, `yazi`, `zellij`

### AUR Packages (via Yay)
`grimblast-git`, `hyprshutdown`, `wiremix`

</details>

---

##  Post-Installation Tips

1. **Wallpaper**: Add your own wallpapers to `~/.config/hypr/assets/` or use the `SUPER + M` menu selection.
2. **Fonts**: If symbols look broken, run `make fonts` to ensure all Nerd Fonts are properly installed.
3. **Browser**: Chromium is the default; you can change this in `~/.config/hypr/programs.conf`.

---

## 🤝 Credits & Acknowledgements
- [Hyprland Team](https://hyprland.org) for the amazing compositor.
- [Catppuccin](https://github.com/catppuccin/catppuccin) for the beautiful color palettes.
- All the developers of the open-source tools included in this stack.
