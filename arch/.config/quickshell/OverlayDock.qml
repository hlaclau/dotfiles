import QtQuick
import QtQuick.Layouts

// Dock at the top of the overlay: a button per panel, the clock and the session buttons
Rectangle {
    id: dock

    required property var clock

    // Reboot / power off need a second click within 3s
    property string armed: ""

    function confirm(action, cmd) {
        if (armed === action) {
            armed = "";
            OverlayState.runAndClose(cmd);
        } else {
            armed = action;
            disarm.restart();
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: dock.armed = ""
    }

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 52
    radius: 26
    color: Theme.crust
    border.width: 1
    border.color: Theme.surface0

    opacity: OverlayState.shown ? 1 : 0
    visible: opacity > 0
    transform: Translate { y: OverlayState.shown ? 0 : -12; Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: OverlayState.panels

            IconButton {
                required property var modelData
                size: 36
                icon: modelData.icon
                iconColor: Theme.subtext1
                active: OverlayState.isOpen(modelData.id)
                onClicked: OverlayState.togglePanel(modelData.id)
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            color: Theme.surface1
        }

        ColumnLayout {
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(dock.clock.date, "HH:mm")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 15
                font.bold: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(dock.clock.date, "ddd d MMM")
                color: Theme.subtext0
                font.family: Theme.font
                font.pixelSize: 10
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            color: Theme.surface1
        }

        IconButton {
            size: 30
            icon: Icons.lock
            onClicked: OverlayState.runAndClose("loginctl lock-session")
        }
        IconButton {
            size: 30
            icon: Icons.moon
            onClicked: OverlayState.runAndClose("systemctl suspend")
        }
        IconButton {
            size: 30
            icon: Icons.reboot
            danger: dock.armed === "reboot"
            onClicked: dock.confirm("reboot", "systemctl reboot")
        }
        IconButton {
            size: 30
            icon: Icons.power
            iconColor: Theme.red
            danger: dock.armed === "poweroff"
            onClicked: dock.confirm("poweroff", "systemctl poweroff")
        }
    }
}
