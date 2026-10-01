import QtQuick

// Round icon button. `danger` turns it red (used to confirm reboot/power off).
Rectangle {
    id: button

    property string icon
    property int size: 32
    property color iconColor: Theme.text
    property bool danger: false
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: danger ? Theme.red : (mouse.containsMouse ? Theme.surface1 : Theme.surface0)

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: button.icon
        color: button.danger ? Theme.crust : button.iconColor
        font.family: Theme.iconFont
        font.pixelSize: button.size * 0.42
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
