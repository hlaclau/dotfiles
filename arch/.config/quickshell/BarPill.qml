import QtQuick
import QtQuick.Layouts

// A group of bar segments, flat on the bar like macOS menu bar items. Fades and shrinks away
// when `shown` turns false instead of popping out.
Rectangle {
    id: pill

    property bool shown: true
    property int padding: 3
    default property alias content: row.data

    Layout.preferredWidth: shown ? row.implicitWidth + 2 * padding : 0
    Layout.maximumWidth: Layout.preferredWidth
    Layout.fillHeight: true
    Layout.topMargin: 3
    Layout.bottomMargin: 3

    visible: Layout.preferredWidth > 0.5
    opacity: shown ? 1 : 0
    clip: true
    radius: 7
    color: "transparent"

    Behavior on Layout.preferredWidth { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: pill.padding
        spacing: 0
    }
}
