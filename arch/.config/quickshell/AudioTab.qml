import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

// Output / input device selection and a volume mixer per app
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

    // ---- Outputs ----
    SectionTitle { text: "Output" }

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

    // ---- Apps ----
    SectionTitle { text: "Apps" }

    Text {
        Layout.fillWidth: true
        visible: Status.apps.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing is playing"
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    Repeater {
        model: Status.apps

        RowLayout {
            id: app

            required property var modelData
            readonly property string iconName: modelData.properties["application.icon-name"] ?? ""

            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 12

            Item {
                implicitWidth: 26
                implicitHeight: 26

                IconImage {
                    anchors.fill: parent
                    source: app.iconName ? Quickshell.iconPath(app.iconName, true) : ""
                    visible: source != ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: !app.iconName
                    text: Icons.music
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: Status.nodeName(app.modelData)
                    color: Theme.subtext1
                    font.family: Theme.font
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                VolumeSlider {
                    Layout.fillWidth: true
                    audio: app.modelData.audio
                }
            }

            Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round((app.modelData.audio?.volume ?? 0) * 100) + "%"
                color: Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 12
            }
            IconButton {
                size: 28
                icon: app.modelData.audio?.muted ? Icons.volumeMute : Icons.volumeHigh
                iconColor: app.modelData.audio?.muted ? Theme.overlay1 : Theme.text
                onClicked: app.modelData.audio.muted = !app.modelData.audio.muted
            }
        }
    }
}
