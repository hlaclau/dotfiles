import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Volume mixer per app, then output / input device selection
ColumnLayout {
    spacing: 8

    component SectionTitle: Text {
        Layout.topMargin: 4
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 13
        font.bold: true
    }

    // A device row: click to make it the default
    component Device: Rectangle {
        id: device

        required property var node
        property bool current: false
        signal picked

        Layout.fillWidth: true
        implicitHeight: 36
        radius: 10
        color: current ? Qt.alpha(Theme.accent, 0.18) : (deviceMouse.containsMouse ? Theme.surface0 : "transparent")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: device.current ? Theme.accent : Theme.surface2
            }
            Text {
                Layout.fillWidth: true
                text: device.node.description || device.node.nickname || device.node.name
                color: device.current ? Theme.text : Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: deviceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: device.picked()
        }
    }

    // ---- Apps ----
    SectionTitle { text: "Apps" }

    AppMixer {
        Layout.fillWidth: true
        Layout.leftMargin: 4
    }

    // ---- Outputs ----
    SectionTitle { text: "Output"; Layout.topMargin: 10 }

    Repeater {
        model: Status.outputs

        Device {
            required property var modelData
            node: modelData
            current: modelData === Status.sink
            onPicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    // ---- Inputs ----
    SectionTitle {
        text: "Input"
        visible: Status.inputs.length > 0
    }

    Repeater {
        model: Status.inputs

        Device {
            required property var modelData
            node: modelData
            current: modelData === Status.source
            onPicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 4
        spacing: 10

        Text {
            text: Icons.mic
            color: Status.noiseSuppression ? Theme.accent : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 12
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: "Noise suppression"
                color: Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 12
            }
            Text {
                text: "Filters background noise from your mic (RNNoise)"
                color: Theme.overlay0
                font.family: Theme.font
                font.pixelSize: 10
            }
        }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: Status.noiseSuppression
            onToggled: Status.toggleNoiseSuppression()
        }
    }
}
