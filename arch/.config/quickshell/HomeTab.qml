import QtQuick
import QtQuick.Layouts

// Media, per-app volume, quick actions, package updates and notifications. Volume, mic and
// do-not-disturb are in the bar (click, scroll, right click).
ColumnLayout {
    id: tab

    required property var island

    spacing: 12

    MediaCard {
        Layout.fillWidth: true
        visible: Status.player !== null
    }

    // ---- Per-app volume, only while something plays ----
    AppMixer {
        Layout.fillWidth: true
        Layout.leftMargin: 2
        hideWhenEmpty: true
    }

    // ---- Quick toggles ----
    GridLayout {
        Layout.fillWidth: true
        columns: 6
        columnSpacing: 8
        rowSpacing: 8

        Tile {
            Layout.fillWidth: true
            icon: Icons.coffee
            label: Status.caffeine && Status.caffeineEnd > 0 ? Status.formatLeft(Status.caffeineLeft) : "Awake"
            active: Status.caffeine
            onClicked: {
                if (Status.caffeine) Status.stopCaffeine();
                else Status.startCaffeine(Settings.values.caffeineMinutes);
            }
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

    // ---- Awake timer: how long the Awake tile keeps the PC from idling ----
    RowLayout {
        id: awake
        Layout.fillWidth: true
        Layout.leftMargin: 2
        spacing: 10

        readonly property var steps: [30, 60, 120, 240, 360, 480, 600, 720, 1440, 0]
        readonly property int index: Math.max(0, steps.indexOf(Settings.values.caffeineMinutes))

        function label(min) {
            if (min === 0) return "No limit";
            return min < 60 ? min + " min" : (min / 60) + " h";
        }
        // Changing it while Awake is on restarts the countdown
        function set(i) {
            const min = steps[Math.max(0, Math.min(steps.length - 1, i))];
            Settings.values.caffeineMinutes = min;
            if (Status.caffeine) Status.startCaffeine(min);
        }

        Text {
            text: Icons.coffee + "  Awake for"
            color: Theme.subtext0
            font.family: Theme.iconFont
            font.pixelSize: 12
        }
        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: minusMouse.containsMouse ? Theme.surface1 : Theme.surface0
            Text {
                anchors.centerIn: parent
                text: "−"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
            }
            MouseArea {
                id: minusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: awake.set(awake.index - 1)
            }
        }
        Text {
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignHCenter
            text: awake.label(Settings.values.caffeineMinutes)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }
        Rectangle {
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: plusMouse.containsMouse ? Theme.surface1 : Theme.surface0
            Text {
                anchors.centerIn: parent
                text: "+"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
            }
            MouseArea {
                id: plusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: awake.set(awake.index + 1)
            }
        }
    }

    // ---- Package updates ----
    Rectangle {
        Layout.fillWidth: true
        visible: Updates.count > 0 || Updates.updating
        implicitHeight: 56
        radius: 16
        color: Theme.surface0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 12

            Text {
                text: Icons.download
                color: Theme.peach
                font.family: Theme.iconFont
                font.pixelSize: 16
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: Updates.updating ? "Updating…"
                        : Updates.count + (Updates.count === 1 ? " update" : " updates")
                        + (Updates.aur.length > 0 ? "  ·  " + Updates.aur.length + " from AUR" : "")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: {
                        const all = [...Updates.repo, ...Updates.aur];
                        return all.slice(0, 4).join(", ") + (all.length > 4 ? " +" + (all.length - 4) : "");
                    }
                    color: Theme.subtext0
                    font.family: Theme.font
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: !Updates.updating
                implicitWidth: updateText.implicitWidth + 24
                implicitHeight: 30
                radius: 15
                color: updateMouse.containsMouse ? Theme.peach : Theme.surface1

                Text {
                    id: updateText
                    anchors.centerIn: parent
                    text: "Update"
                    color: updateMouse.containsMouse ? Theme.crust : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    id: updateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tab.island.close();
                        Updates.update();
                    }
                }
            }
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

    // Muted apps: click one to unmute it
    Flow {
        Layout.fillWidth: true
        visible: Notifs.mutedApps.length > 0
        spacing: 6

        Text {
            height: 24
            verticalAlignment: Text.AlignVCenter
            text: Icons.bellSlash + "  Muted"
            color: Theme.peach
            font.family: Theme.iconFont
            font.pixelSize: 11
        }

        Repeater {
            model: Notifs.mutedApps

            Rectangle {
                id: chip
                required property string modelData
                implicitWidth: chipText.implicitWidth + 22
                implicitHeight: 24
                radius: 12
                color: chipMouse.containsMouse ? Theme.surface1 : Theme.surface0

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData + (chipMouse.containsMouse ? "  " + Icons.close : "")
                    color: Theme.subtext1
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.toggleMute(chip.modelData)
                }
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
