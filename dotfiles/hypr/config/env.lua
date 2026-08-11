-- #############################
-- ### ENVIRONMENT VARIABLES ###
-- #############################

-- Dark Mode and Theme
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("GTK_THEME", "Adwaita-dark")
hl.env("COLOR_SCHEME", "prefer-dark")
hl.env("GSETTINGS_BACKEND", "dconf")

-- Wayland Support
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Cursors
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Default Programs
hl.env("EDITOR", "nvim")
hl.env("BROWSER", "chromium")
hl.env("TERMINAL", "kitty")
