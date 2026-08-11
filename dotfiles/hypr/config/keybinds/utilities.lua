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
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

-- Emergency Kill/Close All
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("hyprctl clients -j | jq -r '.[].address' | xargs -I {} hyprctl dispatch closewindow address:{}"))

-- ------------------------------------------------------------------------------
-- --- USER SCRIPTS & MENUS ---
-- ------------------------------------------------------------------------------

-- Theme & UI Toggles
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_theme.sh"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/floating_menu.sh"))

-- ------------------------------------------------------------------------------
-- --- HARDWARE CONTROLS ---
-- ------------------------------------------------------------------------------

-- Manual Brightness Overrides (if XF86 keys aren't enough)
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F2", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })

-- Maintenance
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd("~/.config/hypr/scripts/firmware_update.sh"))

-- ------------------------------------------------------------------------------
-- --- SCREENSHOTS (via grimblast) ---
-- ------------------------------------------------------------------------------

-- Save area to file and clipboard (Print or Win + Shift + S Snipping Tool)
hl.bind("Print",                   hl.dsp.exec_cmd("grimblast --notify copysave area"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast --notify copysave area"))

-- Save active window to file and clipboard
hl.bind("ALT + Print",             hl.dsp.exec_cmd("grimblast --notify copysave active"))

-- Save current monitor to file and clipboard
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd("grimblast --notify copysave output"))
