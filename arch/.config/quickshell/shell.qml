//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Dynamic island, workspace overview, app launcher, keybind cheatsheet and AI
// chat, one of each per screen. Control them with `qs ipc call island <fn>`,
// `qs ipc call ai <toggle|ask TEXT|newChat>` and
// `qs ipc call <overview|launcher|keybinds> toggle`.
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

    property bool launcherOpen: false

    Variants {
        model: Quickshell.screens

        Launcher {
            open: launcherOpen
            onCloseRequested: launcherOpen = false
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcherOpen = !launcherOpen;
        }
    }

    property bool keybindsOpen: false

    Variants {
        model: Quickshell.screens

        Keybinds {
            open: keybindsOpen
            onCloseRequested: keybindsOpen = false
        }
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            keybindsOpen = !keybindsOpen;
        }
    }

    property bool aiOpen: false

    Variants {
        model: Quickshell.screens

        AiPanel {
            open: aiOpen
            onCloseRequested: aiOpen = false
        }
    }

    IpcHandler {
        target: "ai"

        function toggle(): void {
            aiOpen = !aiOpen;
        }
        // Open the panel and send `text` to the current chat
        function ask(text: string): void {
            aiOpen = true;
            Ai.send(text);
        }
        function newChat(): void {
            Ai.newChat();
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
