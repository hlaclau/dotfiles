import QtQuick
import QtQuick.Layouts

// Now playing with a full spectrum of the music (cava), meant to be pinned
ColumnLayout {
    id: tab

    spacing: 12

    MediaCard {
        Layout.fillWidth: true
        visible: Status.player !== null
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: Status.player === null
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing playing"
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    Rectangle {
        id: stage

        readonly property int count: Cava.spectrumCount

        Layout.fillWidth: true
        Layout.preferredHeight: 130
        radius: 16
        color: Theme.surface0
        clip: true

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 3

            Repeater {
                model: stage.count

                Item {
                    id: slot

                    required property int index

                    width: (parent.width - (stage.count - 1) * parent.spacing) / stage.count
                    height: parent.height

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(3, parent.height * (Cava.spectrum[slot.index] ?? 0))
                        radius: Math.min(width / 2, 3)
                        // Lows in the accent color, highs shading towards the secondary one
                        color: Qt.tint(Theme.accent, Qt.alpha(Theme.sapphire, slot.index / stage.count))
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }
        }
    }
}
