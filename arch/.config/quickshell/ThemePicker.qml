import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Theme picker on the focused screen: each card shows the palette of a theme from
// scripts/theme.sh. Type to filter, arrows move, Enter or a click applies it, Escape
// clears the filter or closes.
PanelWindow {
    id: picker

    required property var modelData
    required property bool open
    signal closeRequested

    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property bool shown: open && focusedScreen

    readonly property var filtered: {
        const q = search.text.trim().toLowerCase();
        return Themes.list.filter(t => !q || t.name.toLowerCase().includes(q) || t.variant.includes(q));
    }

    function pick(index) {
        if (index < 0 || index >= filtered.length) return;
        Themes.apply(filtered[index].id);
        closeRequested();
    }

    visible: shown
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "themes"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            Themes.refresh();
            search.text = "";
            const i = Themes.list.findIndex(t => t.id === Themes.current);
            grid.currentIndex = Math.max(i, 0);
            grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
            search.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.75)

        MouseArea {
            anchors.fill: parent
            onClicked: picker.closeRequested()
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.barHeight + 48
        anchors.bottomMargin: 40
        width: Math.min(parent.width * 0.7, 1100)
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 16
            color: Theme.base
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.surface1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                Text {
                    text: Icons.search
                    color: Theme.overlay1
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.surface2
                    font.family: Theme.font
                    font.pixelSize: 15
                    clip: true

                    onTextChanged: grid.currentIndex = 0

                    Keys.onEscapePressed: {
                        if (text) text = "";
                        else picker.closeRequested();
                    }
                    Keys.onReturnPressed: picker.pick(grid.currentIndex)
                    Keys.onEnterPressed: picker.pick(grid.currentIndex)
                    Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                    Keys.onRightPressed: grid.moveCurrentIndexRight()
                    Keys.onUpPressed: grid.moveCurrentIndexUp()
                    Keys.onDownPressed: grid.moveCurrentIndexDown()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: Themes.applying ? "Applying…" : "Filter themes (dark, light, nord, …)"
                        color: Theme.overlay0
                        font: search.font
                    }
                }
                Text {
                    text: picker.filtered.length
                    color: Theme.overlay0
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }

        GridView {
            id: grid

            readonly property int columns: Math.max(2, Math.floor(width / 260))

            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: Math.floor(width / columns)
            cellHeight: 120
            clip: true
            model: picker.filtered
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: Item {
                id: cell

                required property int index
                required property var modelData

                readonly property bool selected: GridView.isCurrentItem
                readonly property bool isCurrent: modelData.id === Themes.current

                width: grid.cellWidth
                height: grid.cellHeight

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        grid.currentIndex = cell.index;
                        picker.pick(cell.index);
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 14
                    color: cell.modelData.base
                    border.width: cell.isCurrent ? 3 : (cell.selected ? 2 : 1)
                    border.color: cell.isCurrent ? cell.modelData.accent : (cell.selected ? Theme.lavender : cell.modelData.surface1)
                    scale: cellMouse.containsMouse || cell.selected ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: cell.modelData.name
                                color: cell.modelData.text
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.bold: true
                            }
                            Text {
                                visible: cell.isCurrent
                                text: "current"
                                color: cell.modelData.accent
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            text: cell.modelData.variant
                            color: cell.modelData.subtext0
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Item { Layout.fillHeight: true }

                        Row {
                            spacing: 6

                            Repeater {
                                model: ["red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink"]

                                Rectangle {
                                    required property string modelData
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: cell.modelData[modelData]
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
