pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wireless mouse battery (razer-battery script), polled every 2 minutes.
// A level of -1 means the mouse is unavailable (off or not detected).
Singleton {
    id: root

    property int mouse: -1
    property bool mouseCharging: false
    readonly property bool mouseShown: mouse >= 0

    function refresh() {
        if (!probe.running) probe.running = true;
    }

    Process {
        id: probe
        command: ["razer-battery"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(this.text);
                    root.mouse = r.mouse;
                    root.mouseCharging = r.charging;
                } catch (e) {
                    root.mouse = -1;
                    root.mouseCharging = false;
                }
            }
        }
    }

    Timer {
        interval: 2 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
