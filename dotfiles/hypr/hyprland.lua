-- #######################################################################################
-- HYPRLAND MAIN CONFIGURATION (LUA)
-- #######################################################################################

-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Add ~/.config/hypr to Lua module search path
local config_dir = os.getenv("HOME") .. "/.config/hypr/"
package.path = config_dir .. "?.lua;" .. config_dir .. "?/init.lua;" .. package.path

-- Core configurations
require("config.monitors")
require("config.programs")
require("config.env")
require("config.autostart")
require("config.permissions")
require("config.looknfeel")
require("config.input")
require("config.rules")

-- Keybindings
require("config.keybinds")

-- Active Theme
require("theme")
