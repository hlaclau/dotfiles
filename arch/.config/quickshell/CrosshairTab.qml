import QtQuick
import QtQuick.Layouts

// Settings for the crosshair drawn in the middle of the screen (over games too)
ColumnLayout {
    id: tab

    readonly property var s: OverlayState.crosshair

    spacing: 12

    component Section: Text {
        color: Theme.subtext0
        font.family: Theme.font
        font.pixelSize: 11
    }

    component Chip: Rectangle {
        id: chip

        property string label
        property bool selected: false
        signal clicked

        implicitWidth: chipText.implicitWidth + 22
        implicitHeight: 26
        radius: 13
        color: selected ? Theme.accent : (chipMouse.containsMouse ? Theme.surface1 : Theme.surface0)

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? Theme.crust : Theme.subtext1
            font.family: Theme.font
            font.pixelSize: 11
            font.bold: chip.selected
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component Setting: RowLayout {
        id: row

        property string label
        property real from
        property real to
        property string key
        property string unit: "px"

        Layout.fillWidth: true
        spacing: 10

        Section {
            Layout.preferredWidth: 70
            text: row.label
        }
        LevelSlider {
            Layout.fillWidth: true
            from: row.from
            to: row.to
            step: 1
            value: tab.s[row.key]
            onMoved: v => OverlayState.setCrosshair({ [row.key]: Math.round(v) })
        }
        Section {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: tab.s[row.key] + row.unit
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "Show crosshair"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }
        Toggle {
            checked: tab.s.enabled
            onToggled: OverlayState.setCrosshair({ enabled: !tab.s.enabled })
        }
    }

    Section { text: "Style" }
    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { id: "cross", label: "Cross" },
                { id: "crossdot", label: "Cross + dot" },
                { id: "dot", label: "Dot" },
                { id: "circle", label: "Circle" }
            ]

            Chip {
                required property var modelData
                label: modelData.label
                selected: tab.s.style === modelData.id
                onClicked: OverlayState.setCrosshair({ style: modelData.id })
            }
        }
    }

    Section { text: "Color" }
    Row {
        spacing: 8

        Repeater {
            model: ["accent", "red", "green", "yellow", "sky", "pink", "text"]

            Rectangle {
                id: swatch

                required property string modelData

                width: 26
                height: 26
                radius: 13
                color: Theme[modelData]
                border.width: tab.s.color === modelData ? 2 : 0
                border.color: Theme.text

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: OverlayState.setCrosshair({ color: swatch.modelData })
                }
            }
        }
    }

    Setting { label: "Size"; key: "size"; from: 2; to: 60 }
    Setting { label: "Thickness"; key: "thickness"; from: 1; to: 10 }
    Setting { label: "Gap"; key: "gap"; from: 0; to: 30 }
    Setting { label: "Offset X"; key: "dx"; from: -300; to: 300 }
    Setting { label: "Offset Y"; key: "dy"; from: -300; to: 300 }

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "Dark outline"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }
        Toggle {
            checked: tab.s.outline
            onToggled: OverlayState.setCrosshair({ outline: !tab.s.outline })
        }
    }
}
