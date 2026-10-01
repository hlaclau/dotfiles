pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live Hyprland look settings. Changes apply instantly through `hyprctl eval`
// and last until the config is reloaded (or Hyprland restarts).
Singleton {
    id: root

    property int gapsIn: 5
    property int gapsOut: 20
    property int rounding: 10
    property int border: 2
    property bool blur: true
    property bool shadows: true
    property bool animations: true

    // Lua snippet for each setting, used to apply it
    readonly property var lua: ({
        gapsIn: v => `general = { gaps_in = ${v} }`,
        gapsOut: v => `general = { gaps_out = ${v} }`,
        rounding: v => `decoration = { rounding = ${v} }`,
        border: v => `general = { border_size = ${v} }`,
        blur: v => `decoration = { blur = { enabled = ${v} } }`,
        shadows: v => `decoration = { shadow = { enabled = ${v} } }`,
        animations: v => `animations = { enabled = ${v} }`,
    })

    function set(key, value) {
        if (root[key] === value) return;
        root[key] = value;
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ ${lua[key](value)} })`]);
    }

    // Back to hyprland.lua
    function reset() {
        Quickshell.execDetached(["sh", "-c", "hyprctl reload >/dev/null"]);
        resetRefresh.restart();
    }

    function refresh() {
        read.running = true;
    }

    Timer {
        id: resetRefresh
        interval: 500
        onTriggered: root.refresh()
    }

    Process {
        id: read
        command: ["sh", "-c", `
            for o in general:gaps_in general:gaps_out decoration:rounding general:border_size \
                     decoration:blur:enabled decoration:shadow:enabled animations:enabled; do
                hyprctl getoption "$o" -j
            done | jq -s -c .
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(this.text);
                    // gaps are reported as css ("5 5 5 5"); keep the first value
                    root.gapsIn = parseInt(o[0].css);
                    root.gapsOut = parseInt(o[1].css);
                    root.rounding = o[2].int;
                    root.border = o[3].int;
                    root.blur = o[4].bool;
                    root.shadows = o[5].bool;
                    root.animations = o[6].bool;
                } catch (e) {
                    console.warn("HyprSettings: could not read options:", e);
                }
            }
        }
    }

    Component.onCompleted: refresh()
}
