import QtQuick

// Thin slider for a value in [from, to]; drag, click or scroll to change it.
// It doesn't move by itself: handle `moved` and update `value`.
Item {
    id: slider

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: (to - from) / 20
    property bool dimmed: false
    signal moved(real value)

    readonly property real fraction: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    implicitHeight: 20

    function emit(v) {
        moved(Math.max(from, Math.min(to, v)));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Theme.surface0

        Rectangle {
            width: Math.max(height, track.width * slider.fraction)
            height: parent.height
            radius: parent.radius
            color: slider.dimmed ? Theme.overlay0 : Theme.accent
            Behavior on width { NumberAnimation { duration: 80 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function set(x) { slider.emit(slider.from + Math.max(0, Math.min(1, x / width)) * (slider.to - slider.from)); }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x); }
        onWheel: e => slider.emit(slider.value + (e.angleDelta.y > 0 ? slider.step : -slider.step))
    }
}
