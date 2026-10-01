//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Dynamic island and workspace overview, one of each per screen.
// Control them with `qs ipc call island <fn>` and `qs ipc call overview toggle`.
ShellRoot {
    Variants {
        id: islands
        model: Quickshell.screens

        Island {}
    }

    property bool overviewOpen: false

    Variants {
        model: Quickshell.screens

        Overview {
            open: overviewOpen
            onCloseRequested: overviewOpen = false
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            overviewOpen = !overviewOpen;
        }
    }

    function focusedIsland() {
        const name = Hyprland.focusedMonitor?.name;
        return islands.instances.find(i => i.modelData.name === name) ?? islands.instances[0];
    }

    IpcHandler {
        target: "island"

        function toggle(): void {
            focusedIsland().toggle();
        }
        // 0 Home, 1 Audio, 2 Network, 3 Clipboard, 4 Hyprland
        function openTab(index: int): void {
            focusedIsland().open(true, index);
        }
        function clipboard(): void {
            focusedIsland().toggleTab(3);
        }
        function record(): void {
            Status.toggleRecording();
        }
        function toggleDnd(): void {
            Notifs.dnd = !Notifs.dnd;
        }
        function setDnd(enabled: bool): void {
            Notifs.dnd = enabled;
        }
        function clearNotifications(): void {
            Notifs.clearAll();
        }
    }
}
