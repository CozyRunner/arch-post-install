-- ################################################################################
-- # CORE KEYBINDINGS
-- # Applications, Window Management, Focus, Workspaces, Mouse
-- ################################################################################

local p = require("config.programs")
local mainMod = "SUPER"

-- ------------------------------------------------------------------------------
-- --- APPLICATIONS & WINDOWS CONTROLS ---
-- ------------------------------------------------------------------------------

-- Launch Terminals
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(p.terminal2))
hl.bind(mainMod .. " + Q",      hl.dsp.exec_cmd(p.terminal))

-- Launch Browser & File Manager (Win + E = Explorer)
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(p.browser))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(p.fileManager))

-- Application Launchers & Settings (Win + R = Run, Win + I = Settings)
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(p.menu))
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mainMod .. " + I",      hl.dsp.exec_cmd("~/.config/hypr/scripts/floating_menu.sh"))

-- Task Manager & Clipboard (Ctrl + Shift + Esc = Task Manager, Win + V = Clipboard)
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(p.terminal .. " -e btop"))
hl.bind(mainMod .. " + V",       hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"))

-- ------------------------------------------------------------------------------
-- --- WINDOW MANAGEMENT ---
-- ------------------------------------------------------------------------------

-- Basic Window Operations (Alt + F4 = Close Window)
hl.bind("ALT + F4",             hl.dsp.window.kill())
hl.bind(mainMod .. " + C",      hl.dsp.window.kill())
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + T",      hl.dsp.window.pin())
hl.bind(mainMod .. " + BackSpace", hl.dsp.window.center())

-- Fullscreen & Maximize Modes (Win + Up = Maximize, Win + Down = Restore)
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + Up",     hl.dsp.window.fullscreen({ mode = "maximized", action = "set" }))
hl.bind(mainMod .. " + Down",   hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))

-- Layout Control
hl.bind(mainMod .. " + P",      hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",      hl.dsp.layout("togglesplit"))

-- ------------------------------------------------------------------------------
-- --- NAVIGATION & FOCUS ---
-- ------------------------------------------------------------------------------

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + Left",   hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right",  hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up",     hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down",   hl.dsp.focus({ direction = "down" }))

-- Move active window with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "down" }))

-- Windows Alt + Tab Window Switching
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind("ALT + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Super + Tab cycle navigation
hl.bind(mainMod .. " + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- ------------------------------------------------------------------------------
-- --- WORKSPACE MANAGEMENT & VIRTUAL DESKTOPS ---
-- ------------------------------------------------------------------------------

-- Windows Virtual Desktop Navigation (Ctrl + Win + Left/Right/D/F4)
hl.bind("CTRL + " .. mainMod .. " + Left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL + " .. mainMod .. " + Right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("CTRL + " .. mainMod .. " + D",     hl.dsp.focus({ workspace = "empty" }))
hl.bind("CTRL + " .. mainMod .. " + F4",    hl.dsp.window.kill())

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ------------------------------------------------------------------------------
-- --- MOUSE BINDINGS ---
-- ------------------------------------------------------------------------------

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
