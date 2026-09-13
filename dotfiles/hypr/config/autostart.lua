-- #################
-- ### AUTOSTART ###
-- #################

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("~/.config/hypr/scripts/xdg-portal-hyprland.sh")

    hl.exec_cmd("waybar")
    hl.exec_cmd("command -v swaync >/dev/null 2>&1 && swaync || dunst")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("/usr/bin/kwalletd6")
    hl.exec_cmd("/usr/lib/pam_kwallet_init")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    -- Restore GTK/icon/cursor settings saved by nwg-look (dconf-backed).
    -- Do NOT hardcode theme names here — that would override nwg-look on every login.
    hl.exec_cmd("~/.config/hypr/scripts/apply-gtk-settings.sh")

    hl.exec_cmd("wl-paste --type text --watch /usr/bin/cliphist store")
    hl.exec_cmd("wl-paste --type image --watch /usr/bin/cliphist store")
end)
