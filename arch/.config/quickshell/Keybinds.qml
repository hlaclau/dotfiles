import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Searchable list of every Hyprland bind that has a description
// (bindings.lua gives them one), on the focused screen
PanelWindow {
    id: sheet

    required property var modelData
    required property bool open
    signal closeRequested

    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property bool shown: open && focusedScreen

    // [{ keys: ["SUPER", "SHIFT", "S"], description }]
    property var binds: []
    readonly property var matches: {
        const q = search.text.trim().toLowerCase();
        if (!q) return binds;
        return binds.filter(b => b.description.toLowerCase().includes(q) || b.keys.join(" ").toLowerCase().includes(q));
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
    WlrLayershell.namespace: "keybinds"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            search.text = "";
            reader.running = true;
            search.forceActiveFocus();
        }
    }

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mods = mask => [
                    [64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]
                ].filter(([bit]) => mask & bit).map(([, name]) => name);
                // Keys as Hyprland reports them, made readable
                const key = k => ({ grave: "`", slash: "/", mouse_down: "Scroll ↓", mouse_up: "Scroll ↑",
                    "mouse:272": "Left click", "mouse:273": "Right click", RETURN: "Enter", ESCAPE: "Esc" })[k]
                    ?? (k.length === 1 ? k.toUpperCase() : k);
                try {
                    sheet.binds = JSON.parse(this.text)
                        .filter(b => b.has_description)
                        .map(b => ({ keys: [...mods(b.modmask), key(b.key)], description: b.description }));
                } catch (e) {
                    console.warn("Keybinds: could not read binds:", e);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: sheet.closeRequested()
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 720
        height: Math.min(parent.height * 0.8, 120 + list.contentHeight)
        radius: 24
        color: Theme.base
        border.width: 1
        border.color: Theme.surface1

        // Swallow clicks so they don't close the sheet
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: Icons.keyboard
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.surface2
                    font.family: Theme.font
                    font.pixelSize: 16
                    clip: true

                    Keys.onEscapePressed: {
                        if (text) text = "";
                        else sheet.closeRequested();
                    }
                    Keys.onDownPressed: list.flick(0, -800)
                    Keys.onUpPressed: list.flick(0, 800)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search keybinds"
                        color: Theme.overlay0
                        font: search.font
                    }
                }
                Text {
                    text: sheet.matches.length
                    color: Theme.overlay0
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.surface0
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: sheet.matches

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: list.width
                    height: 36
                    radius: 10
                    color: rowHover.hovered ? Theme.surface0 : "transparent"

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 6

                        Repeater {
                            model: row.modelData.keys

                            Rectangle {
                                required property string modelData
                                implicitWidth: keyText.implicitWidth + 14
                                implicitHeight: 24
                                radius: 7
                                color: Theme.surface0
                                border.width: 1
                                border.color: Theme.surface1

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: Theme.accent
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: row.modelData.description
                            color: Theme.subtext1
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
