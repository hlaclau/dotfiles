pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Monitors: switch one off or on, show only one, or mirror one on another (a console, a work
// pc). Applied live through `hyprctl eval` until the config is reloaded or Hyprland restarts;
// "Restore" goes back to hyprland.lua.
Singleton {
    id: root

    // Name, description, mode, position, scale, disabled and mirrorName ("" when not mirrored)
    property var monitors: []
    // Last known mode, position and scale of every screen that was on, to bring it back the same
    property var specs: ({})

    readonly property int activeCount: monitors.filter(m => !m.disabled).length

    function refresh() {
        if (!read.running) read.running = true;
    }

    function modeText(m) {
        return `${m.width}x${m.height}@${Math.round(m.refreshRate)}Hz`;
    }

    function find(name) {
        return monitors.find(m => m.name === name);
    }

    // Lua to switch `name` on: its remembered mode and position, or the best mode placed
    // automatically for a screen that was plugged in after the shell started
    function enableLua(name, mirror, position) {
        const s = specs[name];
        const mode = s ? s.mode : "highrr";
        const pos = position ?? (s ? s.position : "auto");
        const scale = s ? s.scale : 1;
        return `hl.monitor({ output = "${name}", disabled = false, mode = "${mode}", position = "${pos}", scale = ${scale}, mirror = "${mirror}" })`;
    }

    function disableLua(name) {
        return `hl.monitor({ output = "${name}", disabled = true })`;
    }

    // Show the change right away, the next read confirms it
    function patch(name, props) {
        monitors = monitors.map(m => m.name === name ? Object.assign({}, m, props) : m);
    }

    function run(lua) {
        Quickshell.execDetached(["hyprctl", "eval", lua]);
        settle.restart();
    }

    function enable(name) {
        patch(name, { disabled: false, mirrorName: "" });
        run(enableLua(name, "none"));
    }

    // Never turns off the last screen that is on
    function disable(name) {
        const m = find(name);
        if (!m || m.disabled || activeCount <= 1) return;
        patch(name, { disabled: true });
        run(disableLua(name));
    }

    function toggle(name) {
        const m = find(name);
        if (!m) return;
        if (m.disabled) enable(name);
        else disable(name);
    }

    // Only `name` stays on
    function only(name) {
        const m = find(name);
        if (!m) return;
        const lines = [];
        if (m.disabled || m.mirrorName !== "") lines.push(enableLua(name, "none"));
        for (const o of monitors) {
            if (o.name !== name && !o.disabled) {
                lines.push(disableLua(o.name));
                patch(o.name, { disabled: true });
            }
        }
        patch(name, { disabled: false, mirrorName: "" });
        run(lines.join("; "));
    }

    // Show `name` as a copy of `target`
    function mirror(name, target) {
        patch(name, { disabled: false, mirrorName: target });
        run(enableLua(name, target, "auto"));
    }

    function unmirror(name) {
        patch(name, { mirrorName: "" });
        run(enableLua(name, "none"));
    }

    // Back to hyprland.lua
    function restore() {
        Quickshell.execDetached(["sh", "-c", "hyprctl reload >/dev/null"]);
        settle.restart();
    }

    Timer {
        id: settle
        interval: 700
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name.startsWith("monitor") || event.name === "configreloaded") root.refresh();
        }
    }

    Process {
        id: read
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(this.text);
                    const list = all.map(m => ({
                        id: m.id,
                        name: m.name,
                        description: m.description || m.name,
                        width: m.width,
                        height: m.height,
                        refreshRate: m.refreshRate,
                        x: m.x,
                        y: m.y,
                        scale: m.scale,
                        disabled: m.disabled,
                        mirrorName: all.find(o => String(o.id) === String(m.mirrorOf))?.name ?? "",
                    }));
                    const specs = Object.assign({}, root.specs);
                    for (const m of list) {
                        if (m.disabled || m.mirrorName !== "") continue;
                        specs[m.name] = {
                            mode: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`,
                            position: `${m.x}x${m.y}`,
                            scale: m.scale,
                        };
                    }
                    root.specs = specs;
                    root.monitors = list;
                } catch (e) {
                    console.warn("Screens: could not read monitors:", e);
                }
            }
        }
    }

    Component.onCompleted: refresh()
}
