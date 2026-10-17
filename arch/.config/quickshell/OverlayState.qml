pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// State of the control center overlay: whether it is shown (and on which screen), which panels
// are open, pinned and where they sit. Open panels, pins and geometry survive restarts, saved as
// JSON in quickshell's state dir. Unpinned panels hide with the overlay, pinned ones stay.
Singleton {
    id: root

    // The panels, in dock order. Island tab indexes (Bar, `qs ipc call island openTab`) follow it.
    readonly property var panels: [
        { id: "home", title: "Home", icon: Icons.home, width: 480 },
        { id: "audio", title: "Audio", icon: Icons.speaker, width: 440 },
        { id: "network", title: "Network", icon: Icons.wifi, width: 480 },
        { id: "clipboard", title: "Clipboard", icon: Icons.clipboard, width: 420 },
        { id: "hyprland", title: "Hyprland", icon: Icons.sliders, width: 440 },
        { id: "screens", title: "Screens", icon: Icons.desktop, width: 440 },
        { id: "resources", title: "Resources", icon: Icons.cpu, width: 420 },
        { id: "calendar", title: "Calendar", icon: Icons.calendar, width: 360 },
        { id: "emoji", title: "Emoji", icon: "\uf118", width: 400 },
        { id: "music", title: "Music", icon: Icons.music, width: 460 },
        // bare: only the content stays when the overlay closes; fill: the content takes the whole
        // panel instead of scrolling; clickthrough: pinned, it lets clicks pass through
        { id: "image", title: "Floating image", icon: Icons.image, width: 420, height: 300, bare: true, fill: true, clickthrough: true },
        { id: "crosshair", title: "Crosshair", icon: "\uf05b", width: 360 }
    ]

    property bool shown: false
    // Screen the overlay (and the pinned panels) live on
    property string screenName: ""
    // Everything hides briefly so screenshots and pickers don't capture it
    property bool capturing: false
    // Panel ids, last one on top
    property var stack: panels.map(p => p.id)

    // Crosshair drawn at the center of the screen (see CrosshairView.qml), and the floating image
    readonly property var crosshair: saved.crosshair
    readonly property var image: saved.image

    readonly property bool hasPinned: panels.some(p => info(p.id).open && info(p.id).pinned)

    FileView {
        id: fileView
        path: Quickshell.statePath("overlay.json")
        blockLoading: true
        // Sliders change values continuously; write once they settle
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: saved

            // id -> { open, pinned, x, y, w, h }; no x/y/w/h until moved or resized
            property var panels: ({})

            // style: cross | dot | circle | crossdot; color: a Theme color name
            property var crosshair: ({ enabled: false, style: "cross", color: "accent", size: 14, thickness: 2, gap: 4, outline: true, dx: 0, dy: 0 })
            // What the floating image shows: a path, a URL or a file:// URL
            property var image: ({ source: "" })
        }
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: fileView.writeAdapter()
    }

    Timer {
        id: captureTimer
        interval: 1500
        onTriggered: root.capturing = false
    }

    function info(id) {
        return saved.panels[id] ?? { open: false, pinned: false };
    }
    function patch(id, changes) {
        const next = Object.assign({}, saved.panels);
        next[id] = Object.assign({}, info(id), changes);
        saved.panels = next;
    }

    function setCrosshair(changes) {
        saved.crosshair = Object.assign({}, saved.crosshair, changes);
    }
    function setImage(source) {
        saved.image = { source: source };
    }

    function isOpen(id) {
        return info(id).open;
    }
    function indexOf(id) {
        return stack.indexOf(id);
    }
    function panelAt(index) {
        return panels[Math.max(0, Math.min(index, panels.length - 1))].id;
    }

    function raise(id) {
        if (stack[stack.length - 1] === id) return;
        stack = [...stack.filter(s => s !== id), id];
    }
    function setPinned(id, pinned) {
        patch(id, { pinned: pinned });
    }
    function setGeometry(id, g) {
        patch(id, g);
    }

    function openPanel(id) {
        patch(id, { open: true });
        raise(id);
    }
    function closePanel(id) {
        patch(id, { open: false });
    }
    function togglePanel(id) {
        if (isOpen(id)) closePanel(id);
        else openPanel(id);
    }

    function show(screen) {
        if (screen) screenName = screen;
        if (!panels.some(p => isOpen(p.id))) openPanel("home");
        shown = true;
    }
    function hide() {
        shown = false;
    }
    function toggle(screen) {
        if (shown && (!screen || screenName === screen)) hide();
        else show(screen);
    }
    // Show the overlay with this panel open and on top
    function showPanel(id, screen) {
        if (screen) screenName = screen;
        openPanel(id);
        shown = true;
    }
    // Same key again closes the panel (and the overlay once it is empty)
    function togglePanelOnScreen(id, screen) {
        if (shown && isOpen(id) && (!screen || screenName === screen)) {
            closePanel(id);
            if (!panels.some(p => isOpen(p.id))) hide();
        } else {
            showPanel(id, screen);
        }
    }

    // What the tabs call to get out of the way
    function close() {
        hide();
    }
    function runAndClose(cmd) {
        hide();
        capturing = true;
        captureTimer.restart();
        Status.run("sleep 0.3; " + cmd);
    }
}
