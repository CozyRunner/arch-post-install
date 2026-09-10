-- Hyprland Theme — Rosé Pine (Dark)
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(ebbcbaff)", "rgba(c4a7e7ff)" }, angle = 45 },
            inactive_border = "rgba(26233aaa)",
        },
        resize_on_border = true,
    },
    decoration = {
        rounding = 10,
        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = "rgba(191724aa)",
        },
        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            ignore_opacity    = true,
            new_optimizations = true,
        },
    },
})

hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "wlogout" }, blur = true })
