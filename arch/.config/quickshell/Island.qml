import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The dynamic island for one screen.
//
// States, highest priority first:
//   notification  newest notification pops up for a few seconds
//   osd           volume changed
//   collapsed     clock, now playing and status indicators
// Clicking it (or SUPER + I) opens the control center overlay (Overlay.qml).
PanelWindow {
    id: island

    required property var modelData
    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property bool showNotification: Notifs.popup !== null && focusedScreen
    readonly property bool showOsd: !showNotification && Status.osd && focusedScreen
    readonly property bool fullscreen: Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false

    // The control center lives in the overlay; tabIndex follows OverlayState.panels
    function open(pin, tabIndex) {
        OverlayState.showPanel(OverlayState.panelAt(tabIndex ?? 0), modelData.name);
    }
    function close() {
        OverlayState.hide();
    }
    function toggle() {
        OverlayState.toggle(modelData.name);
    }
    function toggleTab(tabIndex) {
        OverlayState.togglePanelOnScreen(OverlayState.panelAt(tabIndex), modelData.name);
    }

    visible: !fullscreen
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the notch takes input
    mask: Region {
        item: notch
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Item {
        id: notch

        readonly property int wing: 14
        readonly property int pad: 18

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: {
            if (island.showNotification) return 460;
            if (island.showOsd) return 340;
            return collapsed.implicitWidth + 2 * (wing + pad);
        }
        height: {
            if (island.showNotification) return popup.implicitHeight + 2 * pad - 4;
            if (island.showOsd) return Theme.barHeight + 8;
            return Theme.barHeight;
        }

        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

        // Click to open the control center
        TapHandler {
            onTapped: island.toggle()
        }

        Notch {
            anchors.fill: parent
            wing: notch.wing
            // Wings on the bar's bottom edge once the island reaches below it
            wingTop: Math.max(0, Math.min(Theme.barHeight, notch.height - Theme.barHeight))
            radius: island.showNotification ? 22 : 16
            Behavior on radius { NumberAnimation { duration: 200 } }
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.leftMargin: notch.wing
            anchors.rightMargin: notch.wing
            clip: true

            // ---- Collapsed: now playing · clock · indicators ----
            RowLayout {
                id: collapsed
                anchors.centerIn: parent
                spacing: 12
                opacity: !island.showNotification && !island.showOsd ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                RowLayout {
                    spacing: 6
                    visible: Status.recording

                    Rectangle {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: Theme.red

                        SequentialAnimation on opacity {
                            running: Status.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 700 }
                            NumberAnimation { to: 1; duration: 700 }
                        }
                    }
                    Text {
                        text: "REC " + Status.recordTime
                        color: Theme.red
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                RowLayout {
                    spacing: 6
                    visible: !Status.recording && (Status.player?.isPlaying ?? false)

                    // Bars dance with the music; the note shows until cava sends levels
                    Visualizer {
                        visible: Cava.bars.length > 0
                        maxHeight: 14
                    }
                    Text {
                        visible: Cava.bars.length === 0
                        text: Icons.music
                        color: Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.maximumWidth: 200
                        text: Status.player?.trackTitle ?? ""
                        color: Theme.subtext1
                        font.family: Theme.font
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.bold: true
                }

                RowLayout {
                    spacing: 8
                    visible: Notifs.dnd || Status.caffeine || Status.micMuted || Status.nightLight
                        || Notifs.count > 0 || Status.micInUse || Status.camInUse

                    Text {
                        visible: Notifs.dnd
                        text: Icons.bellSlash
                        color: Theme.peach
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }
                    Text {
                        visible: Status.caffeine
                        text: Icons.coffee
                        color: Theme.yellow
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }
                    Text {
                        visible: Status.caffeine && Status.caffeineEnd > 0
                        text: Status.formatLeft(Status.caffeineLeft)
                        color: Theme.yellow
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                    Text {
                        visible: Status.micMuted
                        text: Icons.micSlash
                        color: Theme.red
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }
                    Text {
                        visible: Status.nightLight
                        text: Icons.moon
                        color: Theme.peach
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }
                    // Privacy: orange = mic in use, green = camera in use
                    Rectangle {
                        visible: Status.micInUse
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 4
                        color: Theme.peach
                    }
                    Rectangle {
                        visible: Status.camInUse
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 4
                        color: Theme.green
                    }
                    Rectangle {
                        visible: Notifs.count > 0 && !Notifs.dnd
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 4
                        color: Theme.accent
                    }
                }
            }

            // ---- Volume OSD ----
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: notch.pad
                anchors.rightMargin: notch.pad
                spacing: 12
                opacity: island.showOsd ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    text: Status.muted ? Icons.volumeMute : (Status.volume < 0.4 ? Icons.volumeLow : Icons.volumeHigh)
                    color: Status.muted ? Theme.overlay1 : Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                }
                VolumeSlider {
                    Layout.fillWidth: true
                }
                Text {
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Status.volume * 100) + "%"
                    color: Theme.subtext1
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            // ---- Notification popup ----
            NotificationCard {
                id: popup
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: notch.pad
                anchors.topMargin: notch.pad - 4
                flat: true
                notification: Notifs.popup
                opacity: island.showNotification ? 1 : 0
                visible: opacity > 0 && notification !== null
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }
}
