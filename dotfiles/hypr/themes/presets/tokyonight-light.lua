-- Hyprland Theme — Tokyo Night Day (Light)
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(2e7de9ff)", "rgba(9854f6ff)" }, angle = 45 },
            inactive_border = "rgba(a8aecb22)",
        },
        resize_on_border = true,
    },
    decoration = {
        rounding = 10,
        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = "rgba(b4b5b9aa)",
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
