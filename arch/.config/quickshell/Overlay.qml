import QtQuick
import Quickshell
import Quickshell.Wayland

// The control center overlay for one screen: a dimmed backdrop, a dock at the top and the
// panels (Home, Audio, Network, Clipboard, Hyprland, Screens, Resources, Calendar, Emoji, Music,
// Floating image, Crosshair) as windows you can drag, resize and pin. Pinned panels stay on screen, clickable, after the backdrop is gone.
// Open it with SUPER + I, the island or the bar (`qs ipc call island toggle`).
PanelWindow {
    id: overlay

    required property var modelData
    screen: modelData

    readonly property bool mine: OverlayState.screenName === modelData.name

    visible: mine && !OverlayState.capturing
        && (OverlayState.shown || OverlayState.hasPinned || backdrop.opacity > 0 || OverlayState.crosshair.enabled)
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "overlay"
    WlrLayershell.keyboardFocus: OverlayState.shown ? WlrKeyboardFocus.Exclusive
        : (OverlayState.hasPinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

    // Everything while shown, otherwise only the pinned panels that are not click-through
    mask: Region {
        item: OverlayState.shown ? backdrop : null

        PinnedRegion { panels: panelRepeater; slot: 0 }
        PinnedRegion { panels: panelRepeater; slot: 1 }
        PinnedRegion { panels: panelRepeater; slot: 2 }
        PinnedRegion { panels: panelRepeater; slot: 3 }
        PinnedRegion { panels: panelRepeater; slot: 4 }
        PinnedRegion { panels: panelRepeater; slot: 5 }
        PinnedRegion { panels: panelRepeater; slot: 6 }
        PinnedRegion { panels: panelRepeater; slot: 7 }
        PinnedRegion { panels: panelRepeater; slot: 8 }
        PinnedRegion { panels: panelRepeater; slot: 9 }
        PinnedRegion { panels: panelRepeater; slot: 10 }
        PinnedRegion { panels: panelRepeater; slot: 11 }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    FocusScope {
        anchors.fill: parent
        focus: OverlayState.shown
        Keys.onEscapePressed: OverlayState.hide()

        // Dim the screen; a click on it closes the overlay
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: OverlayState.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                enabled: OverlayState.shown
                onClicked: OverlayState.hide()
            }
        }

        // Never takes input: it is not in the mask
        CrosshairView {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: OverlayState.crosshair.dx
            anchors.verticalCenterOffset: OverlayState.crosshair.dy
            visible: OverlayState.crosshair.enabled
            z: 200
        }

        OverlayDock {
            clock: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.barHeight + 14
            z: 100
        }

        // One window per panel, always created so the mask can follow the pinned ones
        Item {
            id: canvas
            anchors.fill: parent

            Repeater {
                id: panelRepeater
                model: OverlayState.panels

                OverlayPanel {
                    id: panel
                    required property var modelData
                    required property int index

                    panelId: modelData.id
                    title: modelData.title
                    icon: modelData.icon
                    defaultWidth: modelData.width
                    defaultHeight: modelData.height ?? 0
                    bare: modelData.bare ?? false
                    fill: modelData.fill ?? false
                    defaultClickthrough: modelData.clickthrough ?? false
                    cascade: index

                    // Only built while the panel is on screen
                    Loader {
                        width: parent.width
                        height: panel.fill ? parent.height : (item ? item.implicitHeight : 0)
                        active: panel.visible && overlay.mine
                        sourceComponent: {
                            switch (panel.panelId) {
                            case "home": return homeTab;
                            case "audio": return audioTab;
                            case "network": return networkTab;
                            case "clipboard": return clipboardTab;
                            case "hyprland": return hyprlandTab;
                            case "resources": return resourcesTab;
                            case "calendar": return calendarTab;
                            case "emoji": return emojiTab;
                            case "music": return musicTab;
                            case "image": return imageTab;
                            case "crosshair": return crosshairTab;
                            default: return screensTab;
                            }
                        }
                    }
                }
            }
        }
    }

    Component { id: homeTab; HomeTab { island: OverlayState } }
    Component { id: audioTab; AudioTab {} }
    Component { id: networkTab; NetworkTab {} }
    Component { id: clipboardTab; ClipboardTab { island: OverlayState } }
    Component { id: hyprlandTab; HyprTab {} }
    Component { id: screensTab; ScreensTab {} }
    Component { id: resourcesTab; ResourcesTab {} }
    Component { id: calendarTab; CalendarTab {} }
    Component { id: emojiTab; EmojiTab {} }
    Component { id: musicTab; MusicTab {} }
    Component { id: imageTab; ImageTab {} }
    Component { id: crosshairTab; CrosshairTab {} }
}
