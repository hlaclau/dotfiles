import QtQuick
import QtQuick.Layouts

// A group of bar segments on a raised rounded chip. Fades and shrinks away
// when `shown` turns false instead of popping out.
Rectangle {
    id: pill

    property bool shown: true
    property int padding: 3
    default property alias content: row.data

    Layout.preferredWidth: shown ? row.implicitWidth + 2 * padding : 0
    Layout.maximumWidth: Layout.preferredWidth
    Layout.fillHeight: true
    Layout.topMargin: 6
    Layout.bottomMargin: 6

    visible: Layout.preferredWidth > 0.5
    opacity: shown ? 1 : 0
    clip: true
    radius: 12
    color: Theme.base

    Behavior on Layout.preferredWidth { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: pill.padding
        spacing: 0
    }
}
