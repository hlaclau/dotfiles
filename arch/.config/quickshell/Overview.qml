import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Workspace overview for one screen: this monitor's workspaces with live
// window previews. Click a workspace or window to go there, drag a window onto
// another workspace to move it, 1-9 to jump, Escape to close.
PanelWindow {
    id: overview

    required property var modelData
    required property bool open
    signal closeRequested

    screen: modelData

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor?.name === modelData.name)
        .sort((a, b) => a.id - b.id)
    // First workspace id nobody uses, for the "new workspace" card
    readonly property int freeId: {
        const used = Hyprland.workspaces.values.map(w => w.id);
        let id = 1;
        while (used.includes(id)) id++;
        return id;
    }

    // Card size: a row of workspaces scaled down from the monitor
    readonly property real monitorWidth: monitor?.width ?? modelData.width
    readonly property real monitorHeight: monitor?.height ?? modelData.height
    readonly property real cardWidth: Math.min(modelData.width * 0.24,
        (modelData.width * 0.9 - 24 * workspaces.length) / (workspaces.length + 1))
    readonly property real cardScale: cardWidth / monitorWidth

    visible: open
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "overview"
    WlrLayershell.keyboardFocus: open && focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function dispatch(lua) {
        Quickshell.execDetached(["hyprctl", "dispatch", lua]);
    }
    function goToWorkspace(id) {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`);
        closeRequested();
    }
    function address(toplevel) {
        const a = toplevel.lastIpcObject?.address ?? toplevel.address;
        return a.startsWith("0x") ? a : "0x" + a;
    }

    // Window positions and sizes come from hyprctl, refresh them on open
    onOpenChanged: {
        if (open) {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.75)

        MouseArea {
            anchors.fill: parent
            onClicked: overview.closeRequested()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: overview.open
        Keys.onEscapePressed: overview.closeRequested()
        Keys.onPressed: event => {
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) overview.goToWorkspace(event.key - Qt.Key_0);
        }
    }

    // Drag state: the window being dragged, the workspace under the pointer,
    // and a ghost that follows the pointer
    property var dragging: null
    property int dropId: -1

    function cardIdAt(item, x, y) {
        const p = item.mapToItem(cards, x, y);
        const target = cards.childAt(p.x, p.y);
        return target?.dropId ?? target?.modelData?.id ?? -1;
    }

    Rectangle {
        id: ghost
        z: 10
        visible: overview.dragging !== null
        width: 140
        height: 90
        radius: 10
        color: Qt.alpha(Theme.accent, 0.25)
        border.width: 2
        border.color: Theme.accent

        Text {
            anchors.fill: parent
            anchors.margins: 8
            text: overview.dragging?.title ?? ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Row {
        id: cards
        anchors.centerIn: parent
        spacing: 24

        Repeater {
            model: overview.workspaces

            Rectangle {
                id: card

                required property var modelData
                readonly property bool active: overview.monitor?.activeWorkspace === modelData
                readonly property bool dropTarget: overview.dragging !== null && overview.dropId === modelData.id

                width: overview.cardWidth
                height: overview.monitorHeight * overview.cardScale
                radius: 14
                color: Theme.base
                border.width: active || dropTarget ? 2 : 1
                border.color: dropTarget ? Theme.green : (active ? Theme.accent : Theme.surface1)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: overview.goToWorkspace(card.modelData.id)
                }

                // Live previews, laid out like on the monitor
                Item {
                    anchors.fill: parent
                    clip: true

                    Repeater {
                        model: card.modelData.toplevels

                        ClippingRectangle {
                            id: win

                            required property var modelData
                            readonly property var ipc: modelData.lastIpcObject
                            readonly property bool known: ipc?.at !== undefined

                            visible: known
                            x: known ? (ipc.at[0] - (overview.monitor?.x ?? 0)) * overview.cardScale : 0
                            y: known ? (ipc.at[1] - (overview.monitor?.y ?? 0)) * overview.cardScale : 0
                            width: known ? ipc.size[0] * overview.cardScale : 0
                            height: known ? ipc.size[1] * overview.cardScale : 0
                            radius: 6
                            color: Theme.surface0
                            border.width: winMouse.containsMouse ? 2 : 0
                            border.color: Theme.lavender
                            opacity: overview.dragging === modelData ? 0.4 : 1

                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: overview.open ? win.modelData.wayland : null
                                live: true
                            }

                            MouseArea {
                                id: winMouse

                                property point pressPos
                                property bool moved: false

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onPressed: e => {
                                    pressPos = Qt.point(e.x, e.y);
                                    moved = false;
                                }
                                onPositionChanged: e => {
                                    if (!pressed) return;
                                    if (!moved && Math.hypot(e.x - pressPos.x, e.y - pressPos.y) > 8) {
                                        moved = true;
                                        overview.dragging = win.modelData;
                                    }
                                    if (moved) {
                                        const p = mapToItem(null, e.x, e.y);
                                        ghost.x = p.x - ghost.width / 2;
                                        ghost.y = p.y - ghost.height / 2;
                                        overview.dropId = overview.cardIdAt(this, e.x, e.y);
                                    }
                                }
                                onReleased: e => {
                                    if (!moved) {
                                        overview.dispatch(`hl.dsp.focus({ window = "address:${overview.address(win.modelData)}" })`);
                                        overview.closeRequested();
                                        return;
                                    }
                                    // Drop onto the card under the pointer
                                    const id = overview.cardIdAt(this, e.x, e.y);
                                    if (id > 0 && id !== card.modelData.id) {
                                        overview.dispatch(`hl.dsp.window.move({ window = "address:${overview.address(win.modelData)}", workspace = ${id}, follow = false })`);
                                        refreshAfterMove.restart();
                                    }
                                    overview.dragging = null;
                                    overview.dropId = -1;
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 8
                    text: card.modelData.id
                    color: card.active ? Theme.accent : Theme.subtext0
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        // Empty card to open a new workspace (or drop a window there)
        Rectangle {
            id: newCard

            readonly property int dropId: overview.freeId
            readonly property bool dropTarget: overview.dragging !== null && overview.dropId === dropId

            width: overview.cardWidth
            height: overview.monitorHeight * overview.cardScale
            radius: 14
            color: newMouse.containsMouse || dropTarget ? Theme.surface0 : "transparent"
            border.width: dropTarget ? 2 : 1
            border.color: dropTarget ? Theme.green : Theme.surface1

            Text {
                anchors.centerIn: parent
                text: "+"
                color: Theme.overlay1
                font.family: Theme.font
                font.pixelSize: 32
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                text: overview.freeId
                color: Theme.overlay0
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
            }

            MouseArea {
                id: newMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: overview.goToWorkspace(overview.freeId)
            }
        }
    }

    Timer {
        id: refreshAfterMove
        interval: 150
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }
}
