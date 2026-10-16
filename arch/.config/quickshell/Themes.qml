pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The themes of scripts/theme.sh: the list (with palettes) for the picker and switching to one.
// Applying rewrites ~/.config/theme, which Theme.qml follows live.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/dotfiles/scripts/theme.sh"

    property var list: []
    property string current: ""
    property bool applying: false

    function refresh() {
        if (!listProc.running) listProc.running = true;
    }

    function apply(id) {
        if (applying || id === current) return;
        applying = true;
        applyProc.command = ["sh", script, id];
        applyProc.running = true;
    }

    Process {
        id: listProc
        command: ["sh", root.script, "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.list = data.themes;
                    root.current = data.current;
                } catch (e) {
                    console.warn("theme list: " + e);
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            root.applying = false;
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
