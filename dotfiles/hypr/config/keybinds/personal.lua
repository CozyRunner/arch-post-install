-- ################################################################################
-- # PERSONAL KEYBINDINGS
-- # Tool Shortcuts (theme picker, calcure, tjournal)
-- ################################################################################

local p = require("config.programs")
local mainMod = "SUPER"

-- Hot Keys / Programs
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_theme.sh"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/theme_picker.sh"))
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("~/.config/hypr/scripts/floating_menu.sh"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(p.terminal .. " -e calcure"))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.exec_cmd(p.terminal .. " -e tjournal"))
