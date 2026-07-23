<!-- markdownlint-disable -->
# 🖥️ Hyprland Dotfiles

A personal Hyprland configuration with a clean, minimal aesthetic featuring smooth animations, a teal/cyan accent color scheme, and a powerful floating quick-settings menu.

![Hyprland Desktop](.github/screenshots/desktop.png)

---

## 📦 Requirements

### Essential

| Package | Purpose |
|---------|---------|
| [Hyprland](https://github.com/hyprwm/Hyprland) | Wayland compositor |
| [Waybar](https://github.com/Alexays/Waybar) | Status bar |
| [Rofi](https://github.com/lbonn/rofi) | App launcher & menus |
| [Dunst](https://github.com/dunst-project/dunst) | Notification daemon |
| [Hyprpaper](https://github.com/hyprwm/hyprpaper) | Wallpaper daemon |
| [Hypridle](https://github.com/hyprwm/hypridle) | Idle daemon |
| [Hyprlock](https://github.com/hyprwm/hyprlock) | Screen locker |

### Programs

| Program | Purpose |
|---------|---------|
| `kitty` | Terminal emulator |
| `nautilus` | File manager |
| `chromium` | Web browser |
| `brightnessctl` | Backlight control |
| `wpctl` | Audio control (WirePlumber) |
| `playerctl` | Media player control |
| `grimblast` | Screenshot utility |
| `jq` | JSON processor (used by scripts) |
| `fastfetch` | System info (optional, for About PC) |
| `polkit-kde-authentication-agent-1` | Authentication agent |

### Fonts

- **JetBrainsMono Nerd Font** — used across rofi, waybar, and terminal

### Install all (Arch Linux)

```bash
sudo pacman -S hyprland waybar rofi-wayland dunst hyprpaper hypridle hyprlock \
    kitty nautilus chromium brightnessctl wireplumber playerctl grimblast jq fastfetch \
    ttf-jetbrains-mono-nerd polkit-kde-agent
```

---

## 🚀 Installation

```bash
# Backup existing config
mv ~/.config/hypr ~/.config/hypr.bak

# Clone repository
git clone https://github.com/sachinksamad1/hyprland-dotfiles.git ~/.config/hypr

# Restart Hyprland (or log out and back in)
hyprctl reload
```

---

## 📁 Configuration Structure

```
hypr/
├── hyprland.conf          # Main config — sources all modules below
│
├── autostart.conf         # Startup applications (waybar, dunst, hyprpaper, etc.)
├── bindings.conf          # Core keybindings (workspaces, windows, screenshots)
├── personal-bindings.conf # Personal keybindings (browser, theme toggle, menu)
├── media.conf             # Volume, brightness, and media player controls
├── env.conf               # Environment variables (GTK, QT, cursor)
├── input.conf             # Keyboard, mouse, and touchpad settings
├── looknfeel.conf         # Gaps, borders, animations, blur, shadows
├── monitors.conf          # Display/monitor configuration
├── permissions.conf       # Permission rules
├── programs.conf          # Default programs ($terminal, $menu, $browser)
├── theme.conf             # Active theme colors (sourced dynamically)
├── windowrules.conf       # Window rules (floating, sizing, positioning)
│
├── hyprpaper.conf         # Wallpaper configuration
├── hypridle.conf          # Idle timeouts and actions
├── hyprlock.conf          # Lock screen layout and style
├── wallpaper.sh           # Animated wallpaper startup script
│
├── themes/                # Theme presets
│   ├── dark.conf          # Dark mode colors
│   └── light.conf         # Light mode colors
│
├── scripts/               # Automation scripts
│   ├── floating_menu.sh   # ⚡ Quick Settings floating menu
│   ├── toggle_theme.sh    # 🌗 Light/Dark theme toggle
│   ├── wallpaper_picker.sh# 🖼️ Wallpaper picker with image previews
│   ├── update_arch.sh     # 📦 System update (pacman -Syu)
│   └── about_pc.sh        # 💻 System information display
│
└── assets/                # Wallpapers and images
    ├── Arch-Dark.png
    ├── Arch-Light.png
    └── wallpaper.jpg
```

---

## ⚡ Floating Quick Settings Menu

A rofi-powered control center accessible with a single keybinding. Provides quick access to common system tasks without opening a terminal.

### Launch

```
Super + M
```

### Menu Options

| Entry | Icon | Action | Implementation |
|-------|------|--------|----------------|
| **Toggle Theme** | 󰖙 / 󰖔 | Switch between light and dark mode | `toggle_theme.sh` |
| **Change Wallpaper** | 󰋩 | Browse wallpapers with image previews | `wallpaper_picker.sh` |
| **Update Arch Linux** | 󰣇 | Run full system update | `update_arch.sh` |
| **About This PC** | 󰍹 | View system information | `about_pc.sh` |

### How It Works

The menu is rendered by `rofi` in dmenu mode using a custom glassmorphic theme (`~/.config/rofi/floating-menu.rasi`). Each option dispatches to a dedicated script:

```
Super + M  →  rofi (floating-menu.rasi)
                 ├─ Toggle Theme    →  toggle_theme.sh  (inline, no terminal)
                 ├─ Change Wallpaper →  wallpaper_picker.sh  (rofi sub-menu)
                 ├─ Update Arch     →  kitty --class floating-term  (terminal)
                 └─ About This PC   →  kitty --class floating-term  (terminal)
```

Terminal-based actions spawn a **floating kitty window** (class `floating-term`) that is automatically floated, centered, and sized to `650×450` via a window rule in `windowrules.conf`.

---

### 🌗 Theme Toggle — `toggle_theme.sh`

Switches the full desktop between light and dark mode. The menu dynamically detects the current theme and shows the target state (e.g., "Toggle Theme → Light").

**What gets switched:**

| Component | Dark | Light |
|-----------|------|-------|
| GTK color scheme | `prefer-dark` | `prefer-light` |
| GTK theme | `Adwaita-dark` | `Adwaita` |
| Hyprland borders | Teal/cyan gradient | Blue gradient |
| Waybar stylesheet | `colors-dark.css` | `colors-light.css` |
| Wallpaper | `Arch-Dark.png` | `Arch-Light.png` |
| SwayNC (if running) | Reloaded | Reloaded |

**Flow:**

```
1. Read current scheme via gsettings
2. Apply opposite GTK settings
3. Copy theme preset → theme.conf
4. Apply border colors via hyprctl
5. Swap waybar color stylesheet → reload waybar
6. Preload + set wallpaper via hyprpaper
7. Send desktop notification
```

---

### 🖼️ Wallpaper Picker — `wallpaper_picker.sh`

A visual wallpaper browser with **image thumbnail previews** displayed in a 4-column grid.

**Scan directories:**

- `~/Pictures/wallpapers/`
- `~/Pictures/Wallpapers/`
- `~/.config/hypr/assets/`

**Supported formats:** `.jpg`, `.jpeg`, `.png`, `.webp`

**How preview works:**

The script uses rofi's icon protocol to embed image thumbnails directly into each menu entry:

```bash
# Each entry sent to rofi follows this format:
"filename\0icon\x1f/full/path/to/image"
```

Rofi renders these as 200×200px thumbnails using the `wallpaper-picker.rasi` theme, which defines a grid layout with large icon elements.

**After selection:**

1. Preloads the wallpaper via `hyprctl hyprpaper preload`
2. Applies it to all monitors via `hyprctl hyprpaper wallpaper`
3. Updates `hyprpaper.conf` so the choice persists across restarts
4. Sends a desktop notification confirming the change

---

### 📦 System Update — `update_arch.sh`

Runs a full Arch Linux system update (`pacman -Syu`) inside a styled floating terminal.

**Features:**

- Color-coded terminal output with status headers
- `--noconfirm` flag for non-interactive updates
- Desktop notification on success or failure
- Press Enter to close when done

**Opens in:** Floating kitty terminal (`650×450`, centered)

---

### 💻 About This PC — `about_pc.sh`

Displays detailed system information in a styled floating terminal panel with Nerd Font icons.

**Information displayed:**

| Field | Source |
|-------|--------|
| OS | `/etc/os-release` |
| Kernel | `uname -r` |
| Resolution | `hyprctl monitors` |
| DE | `hyprctl version` |
| Shell | `$SHELL` |
| Packages | `pacman -Q \| wc -l` |
| CPU | `lscpu` |
| GPU | `lspci` |
| RAM | `free -h` |
| Disk | `df -h /` |
| Uptime | `uptime -p` |
| Hostname | `hostnamectl` |

**Opens in:** Floating kitty terminal (`650×450`, centered)

---

## ⌨️ Keybindings

### Core (bindings.conf)

| Keybind | Action |
|---------|--------|
| `Super + Q` | Open terminal (kitty) |
| `Alt + F4` / `Super + C` | Close active window |
| `Ctrl + Shift + Escape` | Open Task Manager (btop) |
| `Ctrl + Alt + Delete` | Power & Session Menu |
| `Super + E` | Open file manager (Explorer) |
| `Super + R` | Run command dialog |
| `Super + I` | Quick Settings menu |
| `Super + V` | Clipboard history |
| `Super + Up` | Maximize active window |
| `Super + Down` | Restore / unmaximize window |
| `Super + F` | Fullscreen |
| `Super + Shift + V` | Toggle floating mode |
| `Super + T` | Pin window |
| `Super + Backspace` | Center window |
| `Super + Space` | Rofi app launcher |
| `Super + P` | Pseudo-tile (dwindle) |
| `Super + J` | Toggle split (dwindle) |
| `Super + S` | Toggle special workspace (scratchpad) |
| `Super + Alt + S` | Move window to special workspace |
| `Super + L` | Lock screen |
| `Alt + Tab` / `Alt + Shift + Tab` | Switch active windows (forward/reverse) |
| `Super + Tab` | Task View / Cycle windows |
| `Super + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | Move window to workspace |
| `Super + Arrow` | Move focus (left/right/up/down) |
| `Super + Shift + Arrow` | Move active window position |
| `Super + Mouse` | Drag to move/resize window |

### 🪟 Windows Virtual Desktops & Controls

| Keybind | Action |
|---------|--------|
| `Ctrl + Super + Left` | Switch to previous virtual desktop |
| `Ctrl + Super + Right` | Switch to next virtual desktop |
| `Ctrl + Super + D` | Create / switch to new empty virtual desktop |
| `Ctrl + Super + F4` | Close active window / desktop task |

### Personal (personal-bindings.conf)

| Keybind | Action |
|---------|--------|
| `Super + Return` | Open terminal |
| `Super + B` | Open browser |
| `Super + Shift + C` | Calendar & Tasks (calcure) |
| `Super + N` | Toggle theme (light/dark) |
| `Super + M` | **Quick Settings menu** |
| `Super + Alt + F` | Maximize (monocle) |
| `Super + F1` | Brightness down |
| `Super + F2` | Brightness up |

### Screenshots

| Keybind | Action |
|---------|--------|
| `Print` / `Super + Shift + S` | Snipping Tool / Screenshot area → clipboard + file |
| `Alt + Print` | Screenshot active window |
| `Shift + Print` | Screenshot current monitor |

### Media (media.conf)

| Keybind | Action |
|---------|--------|
| `Volume Up/Down` | Adjust volume |
| `Volume Mute` | Toggle mute |
| `Mic Mute` | Toggle microphone |
| `Brightness Up/Down` | Adjust brightness |
| `Media Play/Pause` | Play/pause |
| `Media Next/Prev` | Next/previous track |

---

## 🎨 Rofi Themes

Custom rofi themes live in `~/.config/rofi/`:

| Theme | Purpose |
|-------|---------|
| `modern.rasi` | General-purpose launcher (600px, vertical list) |
| `floating-menu.rasi` | Quick Settings menu (380px, glassmorphic cards) |
| `wallpaper-picker.rasi` | Wallpaper grid (60% width, 4-column, 200px thumbnails) |
| `spotlight.rasi` | macOS Spotlight-style launcher |
| `launchpad.rasi` | macOS Launchpad-style grid |
| `theme-picker.rasi` | Theme selection menu |

---

## 🪟 Window Rules

Key floating rules defined in `windowrules.conf`:

| Class / Pattern | Rule |
|-----------------|------|
| `floating-term` | Float, 650×450, centered — used by Quick Settings sub-panels |
| `pavucontrol`, `blueman-manager`, `nm-*` | Float |
| `imv`, `mpv`, `feh` | Float (feh: 1000×600) |
| `nautilus`, `thunar` | Float, 1000×600 |
| File dialogs (Open/Save) | Float, 800×500 |
| All floating windows | Auto-centered |

---

## 🎭 Customization

### Theme Colors

Edit `themes/dark.conf` or `themes/light.conf`, then toggle with `Super + N`:

```bash
general {
    col.active_border   = rgba(2eb398ff) rgba(42ffd6ff) 45deg
    col.inactive_border = rgba(1e2024aa)
}
```

### Wallpapers

Drop images into any of these directories:

```
~/Pictures/wallpapers/
~/Pictures/Wallpapers/
~/.config/hypr/assets/
```

Then open the picker with `Super + M` → **Change Wallpaper**.

### Default Programs

Edit `programs.conf`:

```bash
$terminal    = kitty
$fileManager = nautilus
$menu        = rofi -show drun
$browser     = chromium
```

---

## 🔧 Troubleshooting

### Floating menu doesn't open

```bash
# Check if scripts are executable
ls -la ~/.config/hypr/scripts/

# Make them executable if needed
chmod +x ~/.config/hypr/scripts/*.sh

# Test directly
~/.config/hypr/scripts/floating_menu.sh
```

### Wallpaper picker shows no images

```bash
# Check wallpaper directories exist and have images
ls ~/Pictures/wallpapers/ ~/Pictures/Wallpapers/ ~/.config/hypr/assets/

# Test the picker script directly
~/.config/hypr/scripts/wallpaper_picker.sh
```

### Theme toggle not working

```bash
# Check current color scheme
gsettings get org.gnome.desktop.interface color-scheme

# Verify theme files exist
ls ~/.config/hypr/themes/
# Should show: dark.conf  light.conf

# Test toggle directly
~/.config/hypr/scripts/toggle_theme.sh
```

### Waybar not starting / not reloading

```bash
# Restart waybar
pkill waybar && waybar &

# Force reload after theme switch
pkill -SIGUSR2 waybar
```

---

## 📜 Credits

- [Hyprland](https://github.com/hyprwm/Hyprland) — Wayland compositor
- [Hyprland Wiki](https://wiki.hyprland.org/) — Configuration reference
- [awesome-hyprland](https://github.com/hyprland-community/awesome-hyprland) — Community resources
- [Nerd Fonts](https://www.nerdfonts.com/) — Icon glyphs

## 📄 License

MIT License — feel free to use and modify.
