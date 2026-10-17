import QtQuick
import QtQuick.Layouts
import Quickshell

// Searchable emoji list: click one to copy it (the panel stays open to pick more)
ColumnLayout {
    id: tab

    property string copied: ""

    spacing: 10

    readonly property var matches: Emoji.search(search.text)

    Component.onCompleted: {
        Emoji.wanted = true;
        search.forceActiveFocus();
    }

    function copy(char) {
        Quickshell.execDetached(["wl-copy", char]);
        copied = char;
        clearCopied.restart();
    }

    Timer {
        id: clearCopied
        interval: 1500
        onTriggered: tab.copied = ""
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 10
        color: Theme.surface0
        border.width: search.activeFocus ? 1 : 0
        border.color: Theme.accent

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: Icons.search
                color: Theme.overlay1
                font.family: Theme.iconFont
                font.pixelSize: 12
            }

            TextInput {
                id: search
                Layout.fillWidth: true
                color: Theme.text
                selectionColor: Theme.surface2
                font.family: Theme.font
                font.pixelSize: 12
                clip: true

                // Enter copies the first match
                onAccepted: {
                    if (tab.matches.length > 0) tab.copy(tab.matches[0].char);
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: "Search emoji"
                    color: Theme.overlay0
                    font: search.font
                }
            }

            Text {
                visible: tab.copied !== ""
                text: "Copied " + tab.copied
                color: Theme.green
                font.family: "Noto Color Emoji"
                font.pixelSize: 12
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: tab.matches.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: Emoji.missing ? "Install the unicode-emoji package" : (Emoji.all.length === 0 ? "Loading…" : "No match")
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    Flow {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: tab.matches

            Rectangle {
                id: cell

                required property var modelData

                width: 40
                height: 40
                radius: 10
                color: cellMouse.containsMouse ? Theme.surface1 : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.char
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 22
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.copy(cell.modelData.char)
                }
            }
        }
    }
}
