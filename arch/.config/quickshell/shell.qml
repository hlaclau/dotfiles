//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Top bar, dynamic island, workspace overview, app launcher, keybind cheatsheet,
// AI chat and wallpaper picker, one of each per screen. Control them with `qs ipc call island <fn>`,
// `qs ipc call ai <toggle|ask TEXT|newChat>`,
// `qs ipc call wallpaper <toggle|random|set PATH|search QUERY>` and
// `qs ipc call <overview|launcher|keybinds> toggle`.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            onIslandTab: index => islandFor(modelData).open(true, index)
            onToggleLauncher: launcherOpen = !launcherOpen
            onToggleOverview: overviewOpen = !overviewOpen
            onToggleAi: aiOpen = !aiOpen
        }
    }

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

    property bool wallpaperOpen: false
    // Open on the Online tab (set by `wallpaper search`)
    property bool wallpaperSearch: false

    Variants {
        model: Quickshell.screens

        WallpaperPicker {
            open: wallpaperOpen
            startOnline: wallpaperSearch
            onCloseRequested: {
                wallpaperOpen = false;
                wallpaperSearch = false;
            }
        }
    }

    // Put back the wallpapers picked last time (hyprpaper.conf only has the default)
    Component.onCompleted: Wallpaper.restore()

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            wallpaperOpen = !wallpaperOpen;
        }
        // Random local wallpaper on every screen
        function random(): void {
            Wallpaper.random([]);
        }
        function set(path: string): void {
            Wallpaper.apply(path, []);
        }
        // Open the picker on wallhaven results for `query`
        function search(query: string): void {
            Wallpaper.search(query, false);
            wallpaperSearch = true;
            wallpaperOpen = true;
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            overviewOpen = !overviewOpen;
        }
    }

    function islandFor(screen) {
        return islands.instances.find(i => i.modelData.name === screen?.name) ?? islands.instances[0];
    }
    function focusedIsland() {
        return islandFor(Hyprland.focusedMonitor);
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
