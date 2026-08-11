-- Light Theme Configuration
-- Catppuccin Latte Blue Theme

hl.config({
    general = {
        col = {
            active_border   = { colors = { "rgba(7287fdff)", "rgba(04a5e5ff)" }, angle = 45 },
            inactive_border = "rgba(bac2deaa)",
        },
    },
    decoration = {
        shadow = {
            color = "rgba(cdd6f4aa)",
        },
    },
})

hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "wlogout" }, blur = true })
