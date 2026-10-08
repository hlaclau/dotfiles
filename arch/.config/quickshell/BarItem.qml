import QtQuick
import QtQuick.Layouts

// Clickable segment inside a BarPill: highlights on hover and reports clicks
// (with the button) and wheel steps (+1 up, -1 down)
Item {
    id: item

    property int padding: 10
    property bool active: false
    readonly property bool hovered: mouse.containsMouse
    default property alias content: row.data

    signal clicked(int button)
    signal scrolled(int steps)

    Layout.fillHeight: true
    implicitWidth: row.implicitWidth + 2 * padding

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: item.active ? Qt.alpha(Theme.accent, 0.18) : Theme.surface0
        opacity: item.active || mouse.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7
    }

    MouseArea {
        id: mouse

        property real wheel: 0

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => item.clicked(e.button)
        // Touchpads send small deltas: add them up into whole notches
        onWheel: e => {
            wheel += e.angleDelta.y;
            const steps = Math.trunc(wheel / 120);
            if (steps !== 0) {
                wheel -= steps * 120;
                item.scrolled(steps);
            }
        }
    }
}
