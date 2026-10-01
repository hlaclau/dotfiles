import QtQuick
import QtQuick.Layouts

// Searchable clipboard history: click an entry to copy it and close the island
ColumnLayout {
    id: tab

    required property var island

    spacing: 8

    readonly property var matches: {
        const q = search.text.toLowerCase();
        const list = q ? Clipboard.entries.filter(e => Clipboard.preview(e).toLowerCase().includes(q)) : Clipboard.entries;
        return list.slice(0, 50);
    }

    onVisibleChanged: {
        if (visible) {
            search.text = "";
            Clipboard.refresh();
            search.forceActiveFocus();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

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
                        if (tab.matches.length > 0) tab.pick(tab.matches[0]);
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search clipboard"
                        color: Theme.overlay0
                        font: search.font
                    }
                }
            }
        }

        IconButton {
            size: 34
            icon: Icons.trash
            iconColor: Theme.red
            visible: Clipboard.entries.length > 0
            onClicked: Clipboard.wipe()
        }
    }

    function pick(line) {
        Clipboard.copy(line);
        island.close();
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: tab.matches.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: Clipboard.entries.length === 0 ? "Clipboard is empty" : "No matches"
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(entryList.implicitHeight, 380)
        visible: tab.matches.length > 0
        contentHeight: entryList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: entryList
            width: parent.width
            spacing: 4

            Repeater {
                model: tab.matches

                Rectangle {
                    id: entry

                    required property string modelData
                    readonly property string preview: Clipboard.preview(modelData)
                    readonly property bool binary: preview.startsWith("[[ binary data")

                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 10
                    color: entryMouse.containsMouse ? Theme.surface0 : "transparent"

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.pick(entry.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: entry.preview.replace(/\s+/g, " ")
                            color: entry.binary ? Theme.overlay1 : Theme.subtext1
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.italic: entry.binary
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: entryMouse.containsMouse || removeMouse.containsMouse
                            text: Icons.close
                            color: removeMouse.containsMouse ? Theme.red : Theme.overlay1
                            font.family: Theme.iconFont
                            font.pixelSize: 12

                            MouseArea {
                                id: removeMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Clipboard.remove(entry.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
