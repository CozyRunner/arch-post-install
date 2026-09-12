-- #########################################
-- ### GLASSMORPHISM LIGHT THEME PRESET  ###
-- ### "Lumina Light" — White Frost Glass ###
-- #########################################
-- Accent: Periwinkle (#6366f1) → Soft Pink (#f472b6)
-- Switch with: toggle_theme.sh light glassmorphism

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            -- Periwinkle → soft pink gradient for elegant light mode glass
            active_border   = { colors = { "rgba(6366f1ff)", "rgba(f472b6ff)" }, angle = 135 },
            inactive_border = "rgba(d1d5db88)",
        },
        resize_on_border = true,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 16,
        rounding_power = 2,

        -- Light glass: higher opacity than dark for better readability
        active_opacity   = 0.92,
        inactive_opacity = 0.82,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            -- Soft warm shadow for light glass (not black!)
            color        = "rgba(9ca3af44)",
            color_inactive = "rgba(9ca3af22)",
            offset       = { 0, 4 },
        },

        blur = {
            enabled           = true,
            -- Slightly lower blur for light mode (prevents washed-out look)
            size              = 9,
            passes            = 3,
            vibrancy          = 0.15,
            vibrancy_darkness = 0.0,
            ignore_opacity    = true,
            new_optimizations = true,
            xray              = false,
            noise             = 0.008,
            contrast          = 0.95,
            brightness        = 1.05,
            popups            = true,
            popups_ignorealpha = 0.2,
        },
    },
})

-- Layer rules: blur all floating UI layers for light glassmorphism
hl.layer_rule({ match = { namespace = "rofi" },                       blur = true })
hl.layer_rule({ match = { namespace = "wlogout" },                    blur = true })
hl.layer_rule({ match = { namespace = "waybar" },                     blur = true })
hl.layer_rule({ match = { namespace = "swaync-control-center" },      blur = true })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true })
hl.layer_rule({ match = { namespace = "hyprlock" },                   blur = true })
