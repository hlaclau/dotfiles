import QtQuick

// Small bars driven by cava, shown next to the playing track
Row {
    id: viz

    property real maxHeight: 14

    height: maxHeight
    spacing: 2

    Repeater {
        model: Cava.count

        Rectangle {
            required property int index
            y: viz.maxHeight - height
            width: 3
            height: Math.max(3, viz.maxHeight * (Cava.bars[index] ?? 0))
            radius: 1.5
            color: Theme.accent

            Behavior on height { NumberAnimation { duration: 60 } }
        }
    }
}
