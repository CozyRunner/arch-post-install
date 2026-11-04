# SwayNotificationCenter (SwayNC) — Unified Theming Architecture

SwayNC is integrated as the primary graphical Notification Center and Control Panel for this Hyprland environment.

## Theming & Palette Architecture

SwayNC styling uses a modular `@import "colors.css";` pattern matching Waybar, Rofi, Kitty, and Hyprland:

```
dotfiles/swaync/
├── config.json                     # Widgets layout, tools menubar & quick action grid
├── style.css                       # Primary stylesheet (imports colors.css)
├── colors.css                      # Relative symlink to active color scheme
│
├── colors-glassmorphism-dark.css   # Lumina Dark (frosted navy glass & electric indigo/cyan)
├── colors-glassmorphism-light.css  # Lumina Light (frosted white glass & indigo)
├── colors-nord-dark.css            # Nord Dark (polar night & arctic ice blue)
├── colors-nord-light.css           # Nord Light (snow storm & frost)
├── colors-catppuccin-dark.css      # Catppuccin Mocha (pastel dark)
├── colors-catppuccin-light.css     # Catppuccin Latte (pastel light)
├── colors-rose-pine-dark.css       # Rosé Pine Main (pine & rose)
├── colors-rose-pine-light.css      # Rosé Pine Dawn (warm paper)
├── colors-tokyonight-dark.css      # Tokyo Night (neon night)
├── colors-tokyonight-light.css     # Tokyo Night Day (high-contrast day)
├── colors-gruvbox-dark.css         # Gruvbox Dark (warm retro)
├── colors-gruvbox-light.css        # Gruvbox Light (warm paper)
├── colors-everforest-dark.css      # Everforest Dark (natural green)
├── colors-everforest-light.css     # Everforest Light (natural warm green)
├── colors-dark.css                 # Default neutral dark fallback
└── colors-light.css                # Default neutral light fallback
```

> **Note:** `style-dark.css` and `style-light.css` were removed — they were byte-for-byte copies of `style.css`. Theme differentiation is handled entirely by the `colors-*.css` files.

## Dynamic Color Synchronization

Theme colors stay in sync across **all** UI components (SwayNC, Waybar, Rofi, Kitty, Alacritty, Hyprland, Hyprlock) through several mechanisms:

| Trigger | Script | What It Does |
|---------|--------|--------------|
| Keyboard shortcut `SUPER + ALT + T` | `toggle_theme.sh` | Toggles light/dark and updates **all** components |
| Scheme selector `SUPER + SHIFT + T` | `theme_picker.sh` | Pick a scheme + mode, delegates to `toggle_theme.sh` |
| SwayNC quick button `󰖙 Theme` | `toggle_theme.sh` | Same as keyboard shortcut |
| CLI `notification_center.sh sync` | `sync_theme.sh --component swaync` | Re-syncs SwayNC only |
| CLI `sync_theme.sh` | `sync_theme.sh` | Re-syncs **all** components to cached state |
| CLI `sync_theme.sh --validate` | `sync_theme.sh` | Checks that all color files exist for current scheme |
| CLI `sync_theme.sh --status` | `sync_theme.sh` | Prints current theme state & active symlinks |

### How It Works

1. `toggle_theme.sh` writes the active scheme and mode to `~/.cache/theme_scheme` and `~/.cache/theme_mode`.
2. For each component, it symlinks or copies the matching `colors-${SCHEME}-${MODE}.css` into `colors.css`, falling back to `colors-${MODE}.css` if the scheme-specific file is missing.
3. `sync_theme.sh` can re-apply step 2 at any time without toggling — useful after manual edits, fresh login, or partial failures.
4. `swaync-client -rs` is called to hot-reload the notification center style.
