import QtQuick
import QtQuick.Layouts

// Media, volume, quick toggles and notifications
ColumnLayout {
    id: tab

    required property var island

    spacing: 14

    MediaCard {
        Layout.fillWidth: true
        visible: Status.player !== null
    }

    // ---- Volume ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        IconButton {
            size: 30
            icon: Status.muted ? Icons.volumeMute : (Status.volume < 0.4 ? Icons.volumeLow : Icons.volumeHigh)
            iconColor: Status.muted ? Theme.overlay1 : Theme.accent
            onClicked: Status.toggleMute()
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

    // ---- Quick toggles ----
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 8
        rowSpacing: 8

        Tile {
            Layout.fillWidth: true
            icon: Notifs.dnd ? Icons.bellSlash : Icons.bell
            label: "Silent"
            active: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        Tile {
            Layout.fillWidth: true
            icon: Icons.coffee
            label: "Awake"
            active: Status.caffeine
            onClicked: Status.caffeine = !Status.caffeine
        }
        Tile {
            Layout.fillWidth: true
            icon: Status.micMuted ? Icons.micSlash : Icons.mic
            label: "Mic"
            active: !Status.micMuted
            onClicked: Status.toggleMic()
        }
        Tile {
            Layout.fillWidth: true
            icon: Status.nightLight ? Icons.moon : Icons.sun
            label: "Night"
            active: Status.nightLight
            onClicked: Status.nightLight = !Status.nightLight
        }
        Tile {
            Layout.fillWidth: true
            icon: Status.recording ? Icons.stop : Icons.record
            label: Status.recording ? Status.recordTime : "Record"
            active: Status.recording
            onClicked: {
                if (!Status.recording) tab.island.close();
                Status.toggleRecording();
            }
        }
        Tile {
            Layout.fillWidth: true
            icon: Icons.camera
            label: "Capture"
            onClicked: tab.island.runAndClose("hyprshot -m region")
        }
        Tile {
            Layout.fillWidth: true
            icon: Icons.eyedropper
            label: "Picker"
            onClicked: tab.island.runAndClose("hyprpicker -a")
        }
        Tile {
            Layout.fillWidth: true
            icon: Icons.terminal
            label: "Scratch"
            onClicked: tab.island.runAndClose("hyprctl dispatch 'hl.dsp.workspace.toggle_special(\"scratch\")'")
        }
    }

    // ---- Notifications ----
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        Text {
            text: "Notifications"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }
        Text {
            text: Notifs.count > 0 ? Notifs.count : ""
            color: Theme.overlay1
            font.family: Theme.font
            font.pixelSize: 12
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: Notifs.count > 0
            text: Icons.trash + "  Clear"
            color: clearMouse.containsMouse ? Theme.red : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 12

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearAll()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        visible: Notifs.count === 0
        horizontalAlignment: Text.AlignHCenter
        text: "All caught up"
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(notifList.implicitHeight, 320)
        visible: Notifs.count > 0
        contentHeight: notifList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: notifList
            width: parent.width
            spacing: 8

            Repeater {
                model: Notifs.list

                NotificationCard {
                    required property var modelData
                    Layout.fillWidth: true
                    notification: modelData
                }
            }
        }
    }
}
