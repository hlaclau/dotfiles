import QtQuick

// On/off switch
Rectangle {
    id: toggle

    property bool checked: false
    signal toggled

    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.accent : Theme.surface1

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        x: toggle.checked ? toggle.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: toggle.height - 6
        height: width
        radius: width / 2
        color: toggle.checked ? Theme.crust : Theme.subtext0

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
