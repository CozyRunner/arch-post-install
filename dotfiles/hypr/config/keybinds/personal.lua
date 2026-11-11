-- ################################################################################
-- # PERSONAL KEYBINDINGS
-- # Tool Shortcuts (theme picker, GTK settings, calcure, tjournal)
-- ################################################################################

local p = require("config.programs")
local mainMod = "SUPER"

-- Hot Keys / Programs
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("~/.config/hypr/scripts/notification_center.sh toggle"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/notification_center.sh toggle"))
hl.bind(mainMod .. " + ALT + T",   hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_theme.sh"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/theme_picker.sh"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("nwg-look"))
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("~/.config/hypr/scripts/floating_menu.sh"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(p.terminal .. " -e calcure"))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.exec_cmd(p.terminal .. " -e tjournal"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/spm.sh"))
hl.bind(mainMod .. " + ALT + P",   hl.dsp.exec_cmd("~/.config/hypr/scripts/tui_app.sh menu"))
hl.bind(mainMod .. " + ALT + A",   hl.dsp.exec_cmd("~/.config/hypr/scripts/keep_awake.sh menu"))

