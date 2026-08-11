-- ##############################
-- ### WINDOWS AND WORKSPACES ###
-- ##############################

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Suppress maximize events
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix XWayland drag issues
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Hyprland-run placement
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Floating rules for common utilities
hl.window_rule({
    name  = "floating-utilities",
    match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|nm-applet)$" },
    float = true,
})

-- Floating media
hl.window_rule({
    name  = "floating-media",
    match = { class = "^(imv|mpv|feh)$" },
    float = true,
})

-- Explicit rules for feh
hl.window_rule({
    name   = "feh-rules",
    match  = { class = "^(feh)$" },
    float  = true,
    size   = { 1000, 600 },
    center = true,
})

-- File managers
hl.window_rule({
    name  = "floating-file-managers",
    match = { class = "^(nautilus|thunar)$" },
    float = true,
    size  = { 1000, 600 },
})

-- File dialogs
hl.window_rule({
    name  = "floating-file-dialogs",
    match = { title = "^(Open File|Save File|File Picker|Select a File|Choose Download Folder)$" },
    float = true,
    size  = { 800, 500 },
})

-- Floating terminal (Quick Settings sub-panels)
hl.window_rule({
    name   = "floating-term",
    match  = { class = "^(floating-term)$" },
    float  = true,
    size   = { 650, 450 },
    center = true,
})

-- Floating terminal (About PC)
hl.window_rule({
    name   = "medium-floating-term",
    match  = { class = "^(medium-floating-term)" },
    float  = true,
    size   = { 850, 650 },
    center = true,
})

-- Large floating terminal (Config editing)
hl.window_rule({
    name   = "large-floating-term",
    match  = { class = "^(large-floating-term)$" },
    float  = true,
    size   = { 1000, 750 },
    center = true,
})

-- Center all floating windows
hl.window_rule({
    name   = "center-floating",
    match  = { float = true },
    center = true,
})

-- Persistent Workspaces
for i = 1, 5 do
    hl.workspace_rule({
        workspace  = i,
        persistent = true,
    })
end

