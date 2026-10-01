pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pending package updates: pacman (checkupdates) and AUR (yay), checked hourly
Singleton {
    id: root

    // Package names
    property var repo: []
    property var aur: []
    readonly property int count: repo.length + aur.length
    readonly property bool checking: checker.running
    readonly property bool updating: updater.running

    function check() {
        if (!checker.running && !updater.running) checker.running = true;
    }

    // Runs yay in a terminal (in its own scope, so restarting the island can't
    // kill an update), then checks again once it's closed
    function update() {
        if (!updater.running) updater.running = true;
    }

    Process {
        id: checker
        command: ["sh", "-c", "checkupdates 2>/dev/null; echo --aur--; yay -Qua 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [repoPart, aurPart] = this.text.split("--aur--");
                const names = part => (part ?? "").split("\n").map(l => l.split(" ")[0]).filter(n => n);
                root.repo = names(repoPart);
                root.aur = names(aurPart);
            }
        }
    }

    Process {
        id: updater
        command: ["sh", "-c", `uwsm app -- \${TERMINAL:-ghostty} -e sh -c 'yay; printf "\\nDone. Press Enter to close."; read _'`]
        onExited: root.check()
    }

    // First check a minute after login (network up), then every hour
    Timer {
        interval: 60 * 1000
        running: true
        onTriggered: root.check()
    }
    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.check()
    }
}
