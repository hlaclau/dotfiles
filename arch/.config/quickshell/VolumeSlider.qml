import QtQuick

// Thin slider bound to the default sink; drag, click or scroll to change it
Item {
    id: slider

    property real value: Status.volume
    property color fill: Status.muted ? Theme.overlay0 : Theme.accent

    implicitHeight: 20

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Theme.surface0

        Rectangle {
            width: Math.max(height, track.width * Math.min(1, slider.value))
            height: parent.height
            radius: parent.radius
            color: slider.fill
            Behavior on width { NumberAnimation { duration: 80 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function set(x) { Status.setVolume(x / width); }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x); }
        onWheel: e => Status.setVolume(Status.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
