import QtQuick

// Quick toggle / action tile
Rectangle {
    id: tile

    property string icon
    property string label
    property bool active: false
    signal clicked

    implicitHeight: 64
    radius: 16
    color: active ? Theme.accent : (mouse.containsMouse ? Theme.surface1 : Theme.surface0)

    Behavior on color { ColorAnimation { duration: 120 } }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.icon
            color: tile.active ? Theme.crust : Theme.text
            font.family: Theme.iconFont
            font.pixelSize: 16
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            color: tile.active ? Theme.crust : Theme.subtext1
            font.family: Theme.font
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
