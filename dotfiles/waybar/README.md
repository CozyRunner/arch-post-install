# 🟢 Waybar Configuration

Welcome to your modern Waybar configuration directory. This setup is designed for **Hyprland** with a focus on aesthetics, glassmorphism, and performance.

## 📂 File Structure

- `config.jsonc`: The main layout and logic configuration.
- `style.css`: The visual appearance and animations.
- `scripts/`: Custom scripts for bar functionality (e.g., updates, power menu).
- `backup/`: Copies of previous stable configurations.
- `backups/`: Historical configuration snapshots.

---

## 📦 Dependencies

To ensure all modules and scripts function correctly, please install the following:

### Core & System
- `waybar`: The status bar itself.
- `hyprland`: Required for workspace and window modules.
- `hyprlock` or `swaylock`: For the lock screen functionality in the power menu.
- `systemd`: For power management commands (reboot, shutdown, suspend).

### Utilities & Scripts
- `playerctl`: MPRIS media player controller.
- `jq`: Required for processing keyboard layout data.
- `pacman-contrib`: Provides `checkupdates` for the update indicator.
- `yay`: Required for AUR update checking.
- `rofi`: Used for the application launcher and power menu.

### Terminal & Tools (GUI)
- `kitty`: The default terminal used for floating tool windows.
- `wiremix`: Terminal-based audio mixer (PipeWire/PulseAudio).
- `impala`: Terminal-based network manager.
- `bluetui`: Terminal-based Bluetooth manager.
- `btop`: Modern resource monitor.
- `wireplumber`: Provides `wpctl` for microphone and audio control.

### 🔡 Fonts
- **Inter**: Main Sans-serif font.
- **Font Awesome 6 Free**: For generic system icons.
- **Symbols Nerd Font**: Required for all special icons (e.g., Arch logo, media buttons, battery, etc.).

---

## 🚀 Getting Started

### 1. Structure of `config.jsonc`
The bar is divided into three sections:
- **Modules Left**: 
    - `custom/arch`: Arch Logo + **Update Checker** (Arch\|AUR counts).
    - `hyprland/workspaces`: Interactive desktop switcher.
    - `hyprland/window`: Currently active window title.
- **Modules Center**: `clock` (Date & Time).
- **Modules Right**: `group/media` (Hover-expanding MPRIS controller), `group/audio`, `pulseaudio#microphone`, `bluetooth`, `network`, `cpu`, `temperature`, `memory`, `custom/clipboard`, `custom/language`, `battery`, `custom/power`, and `group/tray`.

---

## 🎵 Hover Media Controller

The bar features a compact, hover-expanding media player widget with full MPRIS support:

- **Normal State**: Displays a compact status icon (`󰐊` playing, `󰏤` paused, `󰎆` stopped/no player).
- **Hover State**: Automatically slides open a smooth media controller drawer revealing:
  - `󰒮` **Previous track**
  - `󰐊` / `󰏤` **Play/Pause button**
  - `󰒭` **Next track**
  - **Song Title — Artist** (with rich tooltip containing Album, Player info, and controls).
- **Mouse Controls on Indicator**:
  - `Left Click`: Play / Pause (`playerctl play-pause`)
  - `Middle Click`: Previous track (`playerctl previous`)
  - `Right Click`: Next track (`playerctl next`)
  - `Scroll Up / Down`: Volume adjust (`playerctl volume 5%+/-`)
- **Hyprland Media Keys**:
  - `XF86AudioPlay` / `XF86AudioPause`: Play / Pause
  - `XF86AudioNext`: Next track
  - `XF86AudioPrev`: Previous track

---

## 🔄 Update Checking

The Arch Logo module now integrates a real-time update checker.

- **How it works**: Uses `~/.config/waybar/scripts/updates.sh` to poll for updates every 10 minutes.
- **Display**: Shows `Arch_Count | AUR_Count` (e.g., `5 | 12`).
- **Visual Cues**: 
    - **Orange**: Updates are available.
    - **Green**: System is up to date.
- **Requirements**:
    - `pacman-contrib` (for the `checkupdates` command).
    - `yay` (for AUR update checking).

---

### 2. Styling & Dynamic Theming
The style uses CSS variables imported from `colors.css`, which is dynamically updated by the global theme switcher (`~/.config/hypr/scripts/toggle_theme.sh`):
- **Colors File**: `~/.config/waybar/colors.css` (symlinked/copied from `colors-<scheme>-<mode>.css`)
- **Supported Palettes**: Catppuccin, Tokyo Night, Gruvbox, Everforest, Nord, Rosé Pine.
- **Glassmorphic Effect**: High-contrast blur and semi-transparent background.

---

## 🛠️ Common Tasks

### Reload Waybar
Waybar listens for `SIGUSR2` for seamless live style reloading:
```bash
pkill -SIGUSR2 waybar
```
To restart the process completely:
```bash
killall waybar && waybar &
```
*Note: If you have a Hyprland bind, usually `MOD + B` or similar is configured to toggle/reload the bar.*

### Check for Errors
If the bar doesn't appear after an edit, check the configuration for syntax errors:
```bash
waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css
```

### Adding new Modules
1. Find the module documentation at [Waybar Wiki](https://github.com/Alexays/Waybar/wiki).
2. Add the module name to one of the sections (`modules-left`, `modules-center`, or `modules-right`).
3. Define the module's logic at the bottom of `config.jsonc`.
4. Style the module using its ID in `style.css` (e.g., `#custom-my-module { ... }`).

---

## ✨ Design Principles
- **Glassmorphism**: High transparency (0.85) with a subtle blur effect.
- **Micro-interactions**: Subtle transitions on workspace switching and hovers.
- **Roundness**: Soft corners (12px - 14px) for a premium feel.

---
## 👤 Author
**Sachin K Samad**
