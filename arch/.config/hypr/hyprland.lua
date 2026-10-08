-- Hyprland config (Lua, Hyprland >= 0.55)
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- API stubs for the LSP: /usr/share/hypr/stubs/hl.meta.lua


------------------
---- MONITORS ----
------------------

-- Left monitor (BenQ ZOWIE 1080p)
hl.monitor({
    output   = "desc:BNQ ZOWIE XL LCD EBACN01401SL0",
    mode     = "1920x1080@120",
    position = "0x0",
    scale    = 1,
})

-- Right monitor (MSI ultrawide 3440x1440 OLED)
hl.monitor({
    output   = "desc:Microstep MAG 341C OLED",
    mode     = "3440x1440@174.96",
    position = "1920x0",
    scale    = 1,
})


---------------------
---- MY PROGRAMS ----
---------------------

terminal    = "ghostty"
fileManager = "thunar"
browser     = "google-chrome-stable"
chat        = "vesktop"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- Only the autostarted terminal goes to workspace 3; a class rule would
    -- also catch the scratchpad and every SUPER+RETURN terminal
    hl.exec_cmd(terminal, { workspace = "3" })
    hl.exec_cmd("hyprpaper & hypridle & " .. chat)
    -- Quickshell runs as a systemd user service so it restarts if it crashes.
    -- It, and the apps it launches through uwsm, need the variables set by
    -- hl.env above, which systemd doesn't see.
    hl.exec_cmd("systemctl --user import-environment TERMINAL BROWSER HYPRSHOT_DIR XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_SIZE QT_QPA_PLATFORMTHEME"
        .. " && systemctl --user reset-failed quickshell.service; systemctl --user start quickshell.service")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    -- Clipboard history for the island (text and images)
    hl.exec_cmd("wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store")
    -- Night light daemon, neutral until the island turns it on
    hl.exec_cmd("hyprsunset --identity")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "Catppuccin-Mocha-Dark-Cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "26")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures")
hl.env("TERMINAL", terminal)
hl.env("BROWSER", browser)
-- Qt apps: qt6ct picks the Kvantum Catppuccin theme (arch/.config/qt6ct, Kvantum)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    cursor = {
        no_hardware_cursors = true,
    },

    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = "rgba(b4befeee)", -- catppuccin lavender
            inactive_border = "rgba(45475aaa)", -- catppuccin surface1
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(11111bee)", -- catppuccin crust
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper  = -1,
        disable_hyprland_logo    = false,
        disable_splash_rendering = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "intl",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity    = 0, -- -1.0 - 1.0, 0 means no modification.
        accel_profile  = "flat",
        force_no_accel = true,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.device({
    name          = "epic-mouse-v1",
    sensitivity   = -0.5,
    accel_profile = "flat",
})


---------------------
---- KEYBINDINGS ----
---------------------

require("bindings")


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Volume control as a centered floating window
hl.window_rule({
    name   = "pavucontrol-float",
    match  = { class = "^(org.pulseaudio.pavucontrol)$" },
    float  = true,
    center = true,
    size   = "900 600",
})

-- btop from the bar: floating and big enough for all its panels
hl.window_rule({
    name   = "btop-float",
    match  = { class = "^(ghostty\\.btop)$" },
    float  = true,
    center = true,
    size   = "1600 950",
})

-- Pin apps to their own workspace
hl.window_rule({ name = "browser-ws", match = { class = "^(google-chrome)$" },     workspace = "1" })
hl.window_rule({ name = "orca-ws",    match = { class = "^(orca)$" },              workspace = "4" })
hl.window_rule({ name = "spotify-ws", match = { class = "^(Spotify)$" },           workspace = "8" })
hl.window_rule({ name = "discord-ws", match = { class = "^(discord|vesktop)$" },   workspace = "9" })

-- Drop-down terminal: the scratch workspace spawns one when opened empty
hl.workspace_rule({ workspace = "special:scratch", on_created_empty = terminal })


---------------------
---- LAYER RULES ----
---------------------

hl.layer_rule({
    name      = "bar-slide",
    match     = { namespace = "bar" },
    animation = "slide top",
})

hl.layer_rule({
    name  = "overlay-blur",
    match = { namespace = "^(overview|launcher|keybinds|wallpaper)$" },
    blur  = true,
})
