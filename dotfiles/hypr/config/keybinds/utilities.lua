-- ################################################################################
-- # UTILITY KEYBINDINGS
-- # Session Management, Scripts, Brightness Overrides, Screenshots
-- ################################################################################

local mainMod = "SUPER"

-- ------------------------------------------------------------------------------
-- --- SYSTEM UTILITIES ---
-- ------------------------------------------------------------------------------

-- Session Management
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + Escape",    hl.dsp.exec_cmd("~/.config/hypr/scripts/power_menu.sh"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd('loginctl terminate-user "$USER"'))

-- Emergency Kill/Close All
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("hyprctl clients -j | jq -r '.[].address' | xargs -I {} hyprctl dispatch closewindow address:{}"))

-- ------------------------------------------------------------------------------
-- --- USER SCRIPTS & MENUS ---
-- ------------------------------------------------------------------------------

-- Theme & UI Toggles
hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("~/.config/hypr/scripts/notification_center.sh toggle"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/notification_center.sh toggle"))
hl.bind(mainMod .. " + ALT + T",   hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_theme.sh"))
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("~/.config/hypr/scripts/floating_menu.sh"))

-- ------------------------------------------------------------------------------
-- --- HARDWARE CONTROLS ---
-- ------------------------------------------------------------------------------

-- Manual Brightness Overrides (if XF86 keys aren't enough)
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F2", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })

-- Maintenance
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd("~/.config/hypr/scripts/firmware_update.sh"))

-- ------------------------------------------------------------------------------
-- --- SCREENSHOTS (via ~/.config/hypr/scripts/screenshot.sh) ---
-- ------------------------------------------------------------------------------

-- Save selection area to file and clipboard (Print or Win + Shift + S Snipping Tool)
hl.bind("Print",                   hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh area"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh area"))

-- Select and save specific application window
hl.bind("ALT + Print",             hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh window"))

-- Save active display (cursor monitor) to file and clipboard
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh display"))

-- Save entire screen (all monitors) to file and clipboard
hl.bind("CTRL + Print",            hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh screen"))

-- Open interactive screenshot menu
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh menu"))

-- ------------------------------------------------------------------------------
-- --- SCREEN RECORDING (via ~/.config/hypr/scripts/screenrecord.sh) ---
-- ------------------------------------------------------------------------------

-- Record selection area
hl.bind(mainMod .. " + SHIFT + R",       hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh area"))

-- Record entire screen
hl.bind(mainMod .. " + CTRL + R",        hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh screen"))

-- Record active display
hl.bind(mainMod .. " + ALT + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh display"))

-- Stop active recording
hl.bind(mainMod .. " + ALT + S",         hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh stop"))

-- Open interactive screen recording menu
hl.bind(mainMod .. " + ALT + R",         hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh menu"))

