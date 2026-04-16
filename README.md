# Arch Linux Post-Installation Workbench

A highly modular, automated, and visually polished Arch Linux post-installation framework. Transforms a fresh Arch install into a production-ready **Hyprland** workstation with curated aesthetics and a centralized theming engine.

[![Hyprland](https://img.shields.io/badge/DE-Hyprland-blue?style=for-the-badge&logo=hyprland)](https://hyprland.org)
[![Arch Linux](https://img.shields.io/badge/OS-Arch%20Linux-blue?style=for-the-badge&logo=arch-linux)](https://archlinux.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [File Structure](#file-structure)
- [Theming System](#theming-system)
- [Keybindings](#keybindings)
- [Included Stack](#included-stack)
- [Troubleshooting](#troubleshooting)
- [Customization](#customization)
- [Contributing](#contributing)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| **Modular Design** | Packages, services, user configuration, and dotfiles are decoupled into functional modules |
| **Unified Theming** | Dark (Macchiato) and Light (Latte) themes applied across all components via `SUPER + N` |
| **Profile-Based** | Supports `full`, `base`, or `dotfiles` installation modes |
| **Idempotent** | Uses `--needed` flags and pre-flight checks for safe re-runs |
| **Robust Logging** | Every step is timestamped and logged to `logs/` |
| **Symlinked Dotfiles** | Automated deployment with automatic backups of existing configs |

---

## Requirements

- Arch Linux (fresh installation)
- Non-root user with `sudo` privileges
- Active internet connection
- Git installed (`pacman -S git`)

---

## Quick Start

```bash
git clone https://github.com/sachinksamad1/arch-post-install.git
cd arch-post-install
chmod +x install.sh
./install.sh
```

---

## Usage

### Interactive Mode

```bash
./install.sh
```

### Modes

| Mode | Description |
|------|-------------|
| `full` | Base + Hyprland + dotfiles (default) |
| `base` | System essentials only (no DE) |
| `dotfiles` | Deploy configurations only |

### Command Line Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose output |
| `-d, --dry-run` | Preview actions without executing |
| `-h, --help` | Show help message |

### Examples

```bash
./install.sh full           # Full install non-interactively
./install.sh -v base        # Verbose base install
./install.sh -d dotfiles    # Preview dotfiles deployment
```

### Makefile

```bash
make full                   # Full install (base + Hyprland + dotfiles)
make base                   # Base packages only
make dotfiles               # Deploy dotfiles
make fonts                  # Install fonts
make fish                   # Setup Fish shell
make check                  # Check prerequisites
make help                   # Show all targets
```

With flags:
```bash
make full V=1               # Verbose output
make dotfiles DRY=1         # Dry-run mode
```

---

## File Structure

```
arch-post-install/
├── install.sh                 # Main entry point
├── config/
│   ├── base.yaml              # Core packages & system settings
│   └── hyprland.yaml          # Hyprland packages, services & dotfiles
├── modules/
│   ├── core.sh                # Engine: YAML parsing, logging, checks
│   ├── packages.sh            # Pacman & AUR package installation
│   ├── services.sh            # Systemd service management
│   ├── users.sh               # User configuration & locale
│   ├── dotfiles.sh            # Symlink deployment with backup
│   └── hyprland.sh            # Hyprland environment orchestrator
├── dotfiles/
│   ├── theme/                 # Unified theme definitions
│   ├── hypr/                  # Hyprland window manager config
│   ├── waybar/                # Status bar configuration
│   ├── kitty/                 # Terminal emulator config
│   ├── rofi/                  # App launcher themes
│   ├── alacritty/             # Alternative terminal config
│   ├── nvim/                  # Neovim IDE setup
│   ├── yazi/                  # Terminal file manager
│   ├── zellij/                # Terminal multiplexer
│   └── fish/                  # Fish shell configuration
├── scripts/
│   ├── install_yay.sh         # AUR helper setup
│   ├── setup_fish.sh         # Fish + Fisher + plugins
│   └── fonts.sh               # Font installation
├── logs/                      # Installation logs
└── Makefile                   # Development shortcuts
```

---

## Theming System

The unified theme engine uses **Catppuccin** color palettes:
- **Dark Mode**: Catppuccin Macchiato
- **Light Mode**: Catppuccin Latte

Toggle with `SUPER + N`. The theme synchronizes across:

1. **Hyprland** - Borders, shadows, window aesthetics
2. **Waybar** - CSS variables for modules and accents
3. **Kitty** - Terminal colorscheme
4. **Rofi** - Dynamic RASI variables
5. **GTK/Qt** - System-wide theme preferences

---

## Keybindings

| Keybinding | Action |
|------------|--------|
| `SUPER + Return` | Launch terminal (Kitty) |
| `SUPER + Space` | App launcher (Rofi) |
| `SUPER + E` | File manager |
| `SUPER + B` | Web browser |
| `SUPER + N` | Toggle Dark/Light theme |
| `SUPER + M` | System menu |
| `SUPER + L` | Lock screen |
| `SUPER + C` | Close active window |
| `SUPER + Shift + Q` | Exit/power menu |
| `Print` | Screenshot (selection) |

---

## Included Stack

| Category | Components |
|----------|------------|
| **Compositor** | Hyprland, hyprpaper, hypridle, hyprlock |
| **Bar/UI** | Waybar, Dunst |
| **Launcher** | Rofi (Modern, Spotlight, Launchpad themes) |
| **Terminal** | Kitty, Alacritty |
| **File Manager** | Nautilus, Yazi |
| **Editor** | Neovim (LazyVim) |
| **Multiplexer** | Zellij |
| **Browser** | Chromium |
| **Media** | MPv, IMV, Feh, Evince |
| **Audio** | PipeWire, WirePlumber, WireMix |
| **Network** | NetworkManager, Impala, Bluetui |
| **Theming** | Papirus Icons, Adwaita, Qt5ct, Kvantum |

---

## Troubleshooting

### Sudo requires password every time

Add to `/etc/sudoers` (use `visudo`):
```
username ALL=(ALL) NOPASSWD: ALL
```

### Fonts look broken

```bash
make fonts
```

### Theme toggle not working

Ensure the toggle script is executable:
```bash
chmod +x ~/.config/hypr/scripts/toggle_theme.sh
```

### AUR packages fail to build

Install required build tools:
```bash
sudo pacman -S --needed base-devel
```

### Hyprland doesn't start

Check logs:
```bash
cat ~/.hyprland/hyprland.log
```

### Sound not working

```bash
pulseaudio --kill
systemctl --user restart pipewire pipewire-pulse wireplumber
```

---

## Customization

### Add custom packages

Edit `config/base.yaml` or `config/hyprland.yaml`:

```yaml
packages:
  pacman:
    - your-package
  aur:
    - your-aur-package
```

### Add dotfiles

Edit `config/hyprland.yaml`:

```yaml
dotfiles:
  - your-dotfile-dir
```

### Change default theme

Edit `dotfiles/theme/config.conf`:
```bash
THEME=macchiato   # or: latte
```

### Add wallpapers

Place images in `~/.config/hypr/assets/` and select via `SUPER + M`.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Credits

- [Hyprland](https://hyprland.org) - Dynamic tiling compositor
- [Catppuccin](https://github.com/catppuccin/catppuccin) - Color palettes
- [LazyVim](https://lazyvim.github.io) - Neovim configuration
- All open-source contributors
