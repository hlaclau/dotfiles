---------------------
---- KEYBINDINGS ----
---------------------

-- Wiki: https://wiki.hypr.land/Configuring/Core/Binds/
-- Every bind has a description: the cheatsheet (SUPER + /) lists them.
-- `terminal`, `fileManager` and `browser` come from hyprland.lua.

local mainMod = "SUPER"

local function bind(keys, dispatcher, description, opts)
    opts = opts or {}
    opts.description = description
    hl.bind(keys, dispatcher, opts)
end

-- Apps
bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal),    "Terminal")
bind(mainMod .. " + F",      hl.dsp.exec_cmd(fileManager), "File manager")
bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser),     "Browser")
bind(mainMod .. " + O",      hl.dsp.exec_cmd("obsidian"),  "Obsidian")
bind(mainMod .. " + A",      hl.dsp.exec_cmd("pavucontrol"), "Volume control")
bind("ALT + SPACE",          hl.dsp.exec_cmd("vicinae toggle"), "Launcher")

-- Windows
bind(mainMod .. " + Q", hl.dsp.window.close(),                     "Close window")
bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mainMod .. " + P", hl.dsp.window.pseudo(),                    "Toggle pseudotile")
bind(mainMod .. " + X", hl.dsp.layout("togglesplit"),              "Toggle split direction")

-- Move focus with mainMod + hjkl
bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }),  "Focus left")
bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), "Focus right")
bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }),    "Focus up")
bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }),  "Focus down")

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       "Go to workspace " .. i)
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "Move window to workspace " .. i)
end

-- Scroll through existing workspaces with mainMod + scroll
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   "Drag window",   { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

-- Scratchpad: drop-down terminal (see the special:scratch workspace rule)
bind(mainMod .. " + T",         hl.dsp.workspace.toggle_special("scratch"),            "Toggle scratchpad")
bind(mainMod .. " + SHIFT + T", hl.dsp.window.move({ workspace = "special:scratch" }), "Move window to scratchpad")

-- Screenshots with hyprshot
bind(mainMod .. " + S",         hl.dsp.exec_cmd("hyprshot -m region"), "Screenshot region")
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m output"), "Screenshot monitor")
bind(mainMod .. " + CTRL + S",  hl.dsp.exec_cmd("hyprshot -m window"), "Screenshot window")
bind(mainMod .. " + ALT + S",   hl.dsp.exec_cmd("hyprshot -m region --raw | swappy -f -"), "Screenshot region and annotate")

-- Tools
bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), "Color picker (copies hex)")
bind(mainMod .. " + slash",     hl.dsp.exec_cmd("~/.config/hypr/scripts/keybinds.sh"), "Keybind cheatsheet")
bind(mainMod .. " + I",         hl.dsp.exec_cmd("qs ipc call island toggle"), "Toggle island (control center)")
bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call island clipboard"), "Clipboard history")
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("qs ipc call island record"), "Start/stop screen recording")
bind(mainMod .. " + TAB",       hl.dsp.exec_cmd("qs ipc call overview toggle"), "Workspace overview")

-- Lock screen
bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("loginctl lock-session"), "Lock screen")

-- Multimedia keys for volume and LCD brightness
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up",       { locked = true, repeating = true })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      "Volume down",     { locked = true, repeating = true })
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     "Mute",            { locked = true, repeating = true })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   "Mute microphone", { locked = true, repeating = true })
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  "Brightness up",   { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  "Brightness down", { locked = true, repeating = true })

-- Requires playerctl
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       "Next track",     { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Play/pause",     { locked = true })
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), "Play/pause",     { locked = true })
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   "Previous track", { locked = true })


--------------------
---- PANIC MODE ----
--------------------

-- First press hides every window in special:panic, mutes audio, pauses media
-- and turns on Do Not Disturb. Second press puts each window back on the
-- workspace it came from and undoes the rest.
local hidden = nil

local function selector(window)
    local address = window.address
    if not address:match("^0x") then address = "0x" .. address end
    return "address:" .. address
end

local function toggle_panic()
    if hidden == nil then
        hidden = {}
        for _, window in ipairs(hl.get_windows()) do
            local ws = window.workspace
            if ws and not ws.special then
                local target = ws.id > 0 and ws.id or ("name:" .. ws.name)
                table.insert(hidden, { window = selector(window), workspace = target })
                hl.dispatch(hl.dsp.window.move({ window = selector(window), workspace = "special:panic", follow = false }))
            end
        end
        hl.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 1; playerctl --all-players pause; qs ipc call island setDnd true")
    else
        for _, entry in ipairs(hidden) do
            hl.dispatch(hl.dsp.window.move({ window = entry.window, workspace = entry.workspace, follow = false }))
        end
        hidden = nil
        hl.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; qs ipc call island setDnd false")
    end
end

bind(mainMod .. " + ESCAPE", toggle_panic, "Panic mode (hide everything / restore)")
