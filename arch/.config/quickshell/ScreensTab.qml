import QtQuick
import QtQuick.Layouts

// Switch screens on and off, keep only one, or mirror one on another
ColumnLayout {
    id: tab

    spacing: 10

    onVisibleChanged: if (visible) Screens.refresh()

    // Small pill button
    component Chip: Rectangle {
        id: chip

        property string label
        property bool selected: false
        signal clicked

        implicitWidth: chipText.implicitWidth + 20
        implicitHeight: 26
        radius: 13
        color: selected ? Theme.accent : (chipMouse.containsMouse ? Theme.surface2 : Theme.surface1)
        Behavior on color { ColorAnimation { duration: 120 } }

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

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "Screens"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Icons.refresh + "  Restore"
            color: restoreMouse.containsMouse ? Theme.accent : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 12

            MouseArea {
                id: restoreMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Screens.restore()
            }
        }
    }

    Repeater {
        model: Screens.monitors

        Rectangle {
            id: card

            required property var modelData

            readonly property bool on: !modelData.disabled
            readonly property bool mirrored: modelData.mirrorName !== ""
            // The other screens that are on and show their own picture
            readonly property var targets: Screens.monitors.filter(o => o.name !== modelData.name && !o.disabled && o.mirrorName === "")

            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + 24
            radius: 12
            color: Theme.surface0
            opacity: on ? 1 : 0.7

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: Icons.desktop
                        color: card.on ? Theme.accent : Theme.overlay0
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.description
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: !card.on ? card.modelData.name + " · off"
                                : card.modelData.name + " · " + Screens.modeText(card.modelData) + " · " + card.modelData.scale + "x"
                                    + (card.mirrored ? " · mirrors " + card.modelData.mirrorName : "")
                            color: Theme.subtext0
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                    Toggle {
                        checked: card.on
                        onToggled: Screens.toggle(card.modelData.name)
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Chip {
                        visible: Screens.monitors.length > 1
                        label: "Only this one"
                        onClicked: Screens.only(card.modelData.name)
                    }
                    Chip {
                        visible: card.mirrored
                        selected: true
                        label: "Mirroring " + card.modelData.mirrorName + "  ✕"
                        onClicked: Screens.unmirror(card.modelData.name)
                    }
                    Repeater {
                        model: card.mirrored ? [] : card.targets

                        Chip {
                            required property var modelData
                            label: "Mirror " + modelData.name
                            onClicked: Screens.mirror(card.modelData.name, modelData.name)
                        }
                    }
                }
            }
        }
    }
}
