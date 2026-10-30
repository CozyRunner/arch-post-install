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

## Dynamic Color Synchronization

When themes switch via any of the following triggers:
- Keyboard shortcut: `SUPER + ALT + T` (`toggle_theme.sh`)
- Scheme selector: `SUPER + SHIFT + T` (`theme_picker.sh`)
- SwayNC quick button: `󰖙 Theme` inside the Control Center
- CLI command: `~/.config/hypr/scripts/notification_center.sh sync`

`toggle_theme.sh` automatically updates `colors.css` to `colors-${SCHEME}-${TARGET_MODE}.css` and invokes `swaync-client -rs` to re-render the control center in real time.

