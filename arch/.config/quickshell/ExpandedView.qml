import QtQuick
import QtQuick.Layouts

// Control center shown when the island is expanded: header, tab bar, then the
// current tab (Home, Audio, Clipboard, Hyprland)
ColumnLayout {
    id: view

    required property var island
    required property var clock

    spacing: 14

    // Reboot / power off need a second click within 3s
    property string armed: ""

    Timer {
        id: disarm
        interval: 3000
        onTriggered: view.armed = ""
    }

    function confirm(action, cmd) {
        if (armed === action) {
            armed = "";
            Status.run(cmd);
        } else {
            armed = action;
            disarm.restart();
        }
    }

    // ---- Header: date, time and session buttons ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            spacing: 0

            Text {
                text: Qt.formatDateTime(view.clock.date, "HH:mm")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 30
                font.bold: true
            }
            Text {
                text: Qt.formatDateTime(view.clock.date, "dddd d MMMM")
                color: Theme.subtext0
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        Item { Layout.fillWidth: true }

        IconButton {
            icon: Icons.lock
            onClicked: view.island.runAndClose("loginctl lock-session")
        }
        IconButton {
            icon: Icons.moon
            onClicked: view.island.runAndClose("systemctl suspend")
        }
        IconButton {
            icon: Icons.reboot
            danger: view.armed === "reboot"
            onClicked: view.confirm("reboot", "systemctl reboot")
        }
        IconButton {
            icon: Icons.power
            iconColor: Theme.red
            danger: view.armed === "poweroff"
            onClicked: view.confirm("poweroff", "systemctl poweroff")
        }
    }

    // ---- Tabs ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 12
        color: Theme.surface0

        RowLayout {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 3

            Repeater {
                model: [
                    { icon: Icons.home, label: "Home" },
                    { icon: Icons.speaker, label: "Audio" },
                    { icon: Icons.clipboard, label: "Clipboard" },
                    { icon: Icons.sliders, label: "Hyprland" },
                ]

                Rectangle {
                    id: tabButton
                    required property var modelData
                    required property int index
                    readonly property bool current: view.island.tab === index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 9
                    color: current ? Theme.accent : (tabMouse.containsMouse ? Theme.surface1 : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 7

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabButton.modelData.icon
                            color: tabButton.current ? Theme.crust : Theme.subtext1
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabButton.modelData.label
                            color: tabButton.current ? Theme.crust : Theme.subtext1
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: tabButton.current
                        }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.island.tab = tabButton.index
                    }
                }
            }
        }
    }

    HomeTab {
        Layout.fillWidth: true
        visible: view.island.tab === 0
        island: view.island
    }
    AudioTab {
        Layout.fillWidth: true
        visible: view.island.tab === 1
    }
    ClipboardTab {
        Layout.fillWidth: true
        visible: view.island.tab === 2
        island: view.island
    }
    HyprTab {
        Layout.fillWidth: true
        visible: view.island.tab === 3
    }
}
