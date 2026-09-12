-- ########################################
-- ### GLASSMORPHISM DARK THEME PRESET  ###
-- ### "Lumina Dark" — Deep Navy Glass   ###
-- ########################################
-- Accent: Electric Indigo (#818cf8) → Cyan (#67e8f9)
-- Switch with: toggle_theme.sh dark glassmorphism

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            -- Indigo → cyan gradient: premium glassmorphism look
            active_border   = { colors = { "rgba(818cf8ff)", "rgba(67e8f9ff)" }, angle = 135 },
            inactive_border = "rgba(1e1e3a66)",
        },
        resize_on_border = true,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 16,
        rounding_power = 2,

        -- Glassmorphism: semi-transparent windows
        active_opacity   = 0.88,
        inactive_opacity = 0.75,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 4,
            -- Deep navy glow shadow for dark glass effect
            color        = "rgba(020212bb)",
            color_inactive = "rgba(02021266)",
            offset       = { 0, 8 },
        },

        blur = {
            enabled           = true,
            -- Higher blur for true frosted glass look
            size              = 10,
            passes            = 4,
            vibrancy          = 0.20,
            vibrancy_darkness = 0.05,
            ignore_opacity    = true,
            new_optimizations = true,
            -- xray=false is CRITICAL: allows blur to show wallpaper through windows
            xray              = false,
            noise             = 0.012,
            contrast          = 1.1,
            brightness        = 0.95,
            popups            = true,
            popups_ignorealpha = 0.2,
        },
    },
})

-- Layer rules: blur all floating UI layers for glassmorphism consistency
hl.layer_rule({ match = { namespace = "rofi" },                     blur = true })
hl.layer_rule({ match = { namespace = "wlogout" },                  blur = true })
hl.layer_rule({ match = { namespace = "waybar" },                   blur = true })
hl.layer_rule({ match = { namespace = "swaync-control-center" },    blur = true })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true })
hl.layer_rule({ match = { namespace = "hyprlock" },                 blur = true })
