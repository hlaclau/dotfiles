pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history from cliphist (fed by `wl-paste --watch cliphist store`,
// started in hyprland.lua)
Singleton {
    id: root

    // Raw cliphist lines: "<id>\t<preview>"
    property var entries: []

    function preview(line) {
        return line.slice(line.indexOf("\t") + 1);
    }

    function refresh() {
        list.running = true;
    }

    // Lines are passed as arguments, never pasted into the shell command
    function copy(line) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", line]);
    }
    function remove(line) {
        entries = entries.filter(e => e !== line);
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", line]);
    }
    function wipe() {
        entries = [];
        Quickshell.execDetached(["cliphist", "wipe"]);
    }

    Process {
        id: list
        command: ["sh", "-c", "cliphist list | head -n 100"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = this.text.split("\n").filter(l => l.includes("\t"))
        }
    }
}
