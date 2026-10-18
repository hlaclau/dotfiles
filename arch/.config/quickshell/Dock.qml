import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// macOS-style dock with every open window, across all workspaces, ordered by workspace. It slides
// up over the windows when the pointer touches the bottom edge and away when it leaves. Icons swell
// near the pointer. Click one to jump to its workspace and focus it, middle click closes it.
// Hidden while a window is fullscreen or nothing is open.
PanelWindow {
    id: dock

    required property var modelData
    screen: modelData

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: monitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property var windows: Hyprland.toplevels.values
        .filter(t => t.workspace && t.address)
        .sort((a, b) => a.workspace.id - b.workspace.id)
    readonly property int margin: 10
    readonly property int iconSize: 56
    readonly property int pillHeight: 82
    // Pointer over the trigger strip or the dock itself, held a moment so it doesn't flicker
    property bool hovered: false
    readonly property bool revealed: hovered || hold.running

    Timer {
        id: hold
        interval: 350
    }

    function appId(t) {
        return t.wayland?.appId || t.lastIpcObject?.class || "";
    }
    function address(t) {
        const a = t.lastIpcObject?.address ?? t.address;
        return a.startsWith("0x") ? a : "0x" + a;
    }
    function dispatch(lua) {
        Quickshell.execDetached(["hyprctl", "dispatch", lua]);
    }

    visible: !fullscreen && windows.length > 0
    color: "transparent"
    implicitHeight: pillHeight + margin + 80
    exclusiveZone: 0
    mask: Region {
        item: pill
        Region { item: trigger }
    }

    anchors {
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dock"

    // Invisible strip along the bottom edge that reveals the dock
    Item {
        id: trigger
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 4

        HoverHandler {
            onHoveredChanged: {
                dock.hovered = hovered || pillHover.hovered;
                if (!hovered) hold.restart();
            }
        }
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.revealed ? dock.margin : -(height + 4)
        implicitWidth: row.implicitWidth + 28
        height: dock.pillHeight
        radius: 28
        color: Qt.alpha(Theme.crust, 0.7)
        border.width: 1
        border.color: Theme.surface0

        Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: pillHover
            onHoveredChanged: {
                dock.hovered = hovered;
                if (!hovered) hold.restart();
            }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 9

            Repeater {
                model: dock.windows

                Item {
                    id: entry

                    required property var modelData
                    readonly property bool active: Hyprland.activeToplevel?.address === modelData.address
                    readonly property string app: dock.appId(modelData)

                    // Swell towards the pointer
                    readonly property real centerX: x + width / 2 + row.x
                    readonly property real swell: pillHover.hovered
                        ? 1 + 0.55 * Math.exp(-Math.pow((pillHover.point.position.x - centerX) / 66, 2)) : 1

                    Layout.preferredWidth: dock.iconSize
                    Layout.preferredHeight: dock.iconSize

                    Item {
                        id: body
                        anchors.fill: parent
                        transformOrigin: Item.Bottom
                        scale: entry.swell * (mouse.pressed ? 0.92 : 1)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 15
                            color: entry.active ? Qt.alpha(Theme.accent, 0.2) : Theme.surface0
                            border.width: entry.active ? 1 : 0
                            border.color: Qt.alpha(Theme.accent, 0.45)
                            opacity: entry.active || mouse.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 44
                            source: Quickshell.iconPath(DesktopEntries.heuristicLookup(entry.app)?.icon ?? entry.app.toLowerCase(), "application-x-executable")
                            asynchronous: true
                        }

                        // Workspace badge
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 1
                            width: badge.implicitWidth + 6
                            height: 14
                            radius: 7
                            color: Theme.crust
                            border.width: 1
                            border.color: Theme.surface1

                            Text {
                                id: badge
                                anchors.centerIn: parent
                                text: entry.modelData.workspace.id > 0 ? entry.modelData.workspace.id : "S"
                                color: entry.active ? Theme.accent : Theme.subtext0
                                font.family: Theme.font
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        // Active marker
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.accent
                            visible: entry.active
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: e => {
                            const addr = `address:${dock.address(entry.modelData)}`;
                            if (e.button === Qt.MiddleButton)
                                dock.dispatch(`hl.dsp.window.close({ window = "${addr}" })`);
                            else
                                dock.dispatch(`hl.dsp.focus({ window = "${addr}" })`);
                        }
                    }

                    // Title on hover
                    Rectangle {
                        visible: mouse.containsMouse
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8 + (entry.swell - 1) * dock.iconSize
                        width: Math.min(tip.implicitWidth, 320) + 16
                        height: tip.implicitHeight + 8
                        radius: 8
                        color: Theme.crust
                        border.width: 1
                        border.color: Theme.surface0

                        Text {
                            id: tip
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, 320)
                            text: entry.modelData.title || entry.app
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
