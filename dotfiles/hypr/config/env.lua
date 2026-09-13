-- #############################
-- ### ENVIRONMENT VARIABLES ###
-- #############################

-- Dark Mode and Theme
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
-- NOTE: Do NOT set GTK_THEME here — it overrides dconf and nwg-look saved settings.
--       GTK apps will pick up the theme from ~/.config/gtk-3.0/settings.ini (written by nwg-look).
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
