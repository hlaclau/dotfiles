//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Top bar, bottom dock, dynamic island with its control center overlay, workspace overview, app launcher, keybind cheatsheet,
// and wallpaper picker, one of each per screen. Control them with `qs ipc call island <fn>`,
// `qs ipc call wallpaper <toggle|random|set PATH|search QUERY>`,
// `qs ipc call themes <toggle|set ID>` and
// `qs ipc call <overview|launcher|keybinds> toggle`.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            onIslandTab: index => islandFor(modelData).open(true, index)
            onToggleLauncher: launcherOpen = !launcherOpen
            onToggleOverview: overviewOpen = !overviewOpen
        }
    }

    Variants {
        id: islands
        model: Quickshell.screens

        Island {}
    }

    // Control center: panels (home, audio, network, ...) over a dimmed screen. Declared after the
    // islands so it stacks above them.
    Variants {
        model: Quickshell.screens

        Overlay {}
    }

    Variants {
        model: Quickshell.screens

        Dock {}
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

    property bool themesOpen: false

    Variants {
        model: Quickshell.screens

        ThemePicker {
            open: themesOpen
            onCloseRequested: themesOpen = false
        }
    }

    IpcHandler {
        target: "themes"

        function toggle(): void {
            themesOpen = !themesOpen;
        }
        // Apply a theme by id (see `scripts/theme.sh list`)
        function set(id: string): void {
            Themes.apply(id);
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
        // Open the control center on a panel: 0 Home, 1 Audio, 2 Network, 3 Clipboard, 4 Hyprland, 5 Screens
        function openTab(index: int): void {
            focusedIsland().open(true, index);
        }
        // Open or close a panel by id (home, audio, network, clipboard, hyprland, screens,
        // resources, calendar, emoji, music, image, crosshair)
        function panel(id: string): void {
            const screen = Hyprland.focusedMonitor?.name;
            OverlayState.togglePanelOnScreen(id, screen);
        }
        function clipboard(): void {
            focusedIsland().toggleTab(3);
        }
        function record(): void {
            Status.toggleRecording();
        }
        // Show or hide the crosshair at the middle of the screen
        function toggleCrosshair(): void {
            OverlayState.setCrosshair({ enabled: !OverlayState.crosshair.enabled });
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
