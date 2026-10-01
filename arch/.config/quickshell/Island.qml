import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The dynamic island for one screen.
//
// States, highest priority first:
//   expanded      control center (hover, click, or SUPER + I)
//   notification  newest notification pops up for a few seconds
//   osd           volume changed
//   collapsed     clock, now playing and status indicators
PanelWindow {
    id: island

    required property var modelData
    screen: modelData

    // Opened on purpose (click / keybind) rather than by hovering:
    // it then stays open until Escape, a click outside, or SUPER + I.
    property bool expanded: false
    property bool pinned: false

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property bool showNotification: !expanded && Notifs.popup !== null && focusedScreen
    readonly property bool showOsd: !expanded && !showNotification && Status.osd && focusedScreen
    readonly property bool fullscreen: Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false

    function open(pin) {
        expanded = true;
        pinned = pin;
    }
    function close() {
        expanded = false;
        pinned = false;
    }
    function toggle() {
        if (expanded) close();
        else open(true);
    }
    // Close first so screenshots and pickers don't capture the island
    function runAndClose(cmd) {
        close();
        Status.run("sleep 0.3; " + cmd);
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
    WlrLayershell.keyboardFocus: expanded && pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only the notch takes input, except while expanded where a click anywhere closes it
    mask: Region {
        item: island.expanded ? backdrop : notch
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Dim the screen and close on click outside while expanded
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25)
        opacity: island.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            enabled: island.expanded
            onClicked: island.close()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: island.expanded
        Keys.onEscapePressed: island.close()
    }

    Timer {
        id: hoverOpen
        interval: 200
        onTriggered: if (!island.expanded && !island.showNotification) island.open(false)
    }
    Timer {
        id: hoverClose
        interval: 400
        onTriggered: if (island.expanded && !island.pinned) island.close()
    }

    Item {
        id: notch

        readonly property int wing: 14
        readonly property int pad: 18

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: {
            if (island.expanded) return 560;
            if (island.showNotification) return 460;
            if (island.showOsd) return 340;
            return collapsed.implicitWidth + 2 * (wing + pad);
        }
        height: {
            if (island.expanded) return Math.min(controlCenter.implicitHeight + 2 * pad, island.height * 0.85);
            if (island.showNotification) return popup.implicitHeight + 2 * pad - 4;
            if (island.showOsd) return Theme.barHeight + 8;
            return Theme.barHeight;
        }

        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    hoverClose.stop();
                    hoverOpen.restart();
                } else {
                    hoverOpen.stop();
                    if (island.expanded && !island.pinned) hoverClose.restart();
                }
            }
        }

        // Any click inside keeps it open after the pointer leaves
        TapHandler {
            onTapped: {
                hoverOpen.stop();
                if (island.expanded) island.pinned = true;
                else island.open(true);
            }
        }

        Notch {
            anchors.fill: parent
            wing: notch.wing
            radius: island.expanded ? 28 : (island.showNotification ? 22 : 16)
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
                opacity: !island.expanded && !island.showNotification && !island.showOsd ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                RowLayout {
                    spacing: 6
                    visible: Status.player?.isPlaying ?? false

                    Text {
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
                    visible: Notifs.dnd || Status.caffeine || Status.micMuted || Notifs.count > 0

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
                        visible: Status.micMuted
                        text: Icons.micSlash
                        color: Theme.red
                        font.family: Theme.iconFont
                        font.pixelSize: 12
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

            // ---- Expanded control center ----
            ExpandedView {
                id: controlCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: notch.pad
                island: island
                clock: clock
                opacity: island.expanded ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }
    }
}
