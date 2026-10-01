//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Dynamic island: one per screen. Control it with `qs ipc call island <fn>`.
ShellRoot {
    Variants {
        id: islands
        model: Quickshell.screens

        Island {}
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
