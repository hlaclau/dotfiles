import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// This monitor's workspaces: the usual ones always, plus any other in use.
// Occupied workspaces show their apps' icons; the highlight stretches from one
// workspace to the next like a drop of liquid. Click to go, scroll to cycle.
Item {
    id: root

    required property var monitor
    // Show icons on every occupied workspace, or only the active one
    property bool showAllIcons: true

    // Same split as the workspace rules: 1-5 on the ultrawide, 6-9 on the side screen
    readonly property var persistent: ({ "DP-2": [1, 2, 3, 4, 5], "DP-1": [6, 7, 8, 9] })

    readonly property var ids: {
        const name = monitor?.name ?? "";
        const all = Hyprland.workspaces.values.filter(w => w.id > 0);
        const used = all.filter(w => w.monitor?.name === name).map(w => w.id);
        // A usual workspace that was moved to the other screen shows there instead
        const elsewhere = all.filter(w => w.monitor?.name !== name).map(w => w.id);
        const usual = (persistent[name] ?? []).filter(id => !elsewhere.includes(id));
        return [...new Set([...usual, ...used])].sort((a, b) => a - b);
    }
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1

    function workspace(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }
    function appId(toplevel) {
        return toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "";
    }
    function dispatch(lua) {
        Quickshell.execDetached(["hyprctl", "dispatch", lua]);
    }

    Layout.fillHeight: true
    implicitWidth: row.implicitWidth

    // ---- Highlight under the active workspace ----
    // The edge moving towards the target leads and the other trails behind
    Rectangle {
        id: highlight

        // `count` makes this re-evaluate once the Repeater has created its buttons
        readonly property Item target: buttons.count > 0 ? buttons.itemAt(root.ids.indexOf(root.activeId)) : null
        property real leftEdge: target ? target.x : 0
        property real rightEdge: target ? target.x + target.width : 0
        readonly property bool forward: target ? target.x >= x : true

        x: leftEdge
        width: Math.max(0, rightEdge - leftEdge)
        height: parent.height
        visible: target !== null
        radius: 9
        color: Qt.alpha(Theme.accent, 0.2)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.45)

        Behavior on leftEdge { NumberAnimation { duration: highlight.forward ? 340 : 170; easing.type: Easing.OutCubic } }
        Behavior on rightEdge { NumberAnimation { duration: highlight.forward ? 170 : 340; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            id: buttons
            model: root.ids

            Item {
                id: button

                required property int modelData
                readonly property var ws: root.workspace(modelData)
                readonly property var windows: ws?.toplevels.values ?? []
                readonly property bool active: modelData === root.activeId
                readonly property bool occupied: windows.length > 0
                readonly property bool urgent: ws?.urgent ?? false
                readonly property bool iconsShown: occupied && (root.showAllIcons || active)
                // One icon per app, at most three
                readonly property var apps: [...new Set(windows.map(root.appId).filter(a => a))].slice(0, 3)

                Layout.fillHeight: true
                implicitWidth: content.implicitWidth + 22

                Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: button.urgent ? Qt.alpha(Theme.red, 0.25) : Theme.surface0
                    opacity: button.urgent || (mouse.containsMouse && !button.active) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    SequentialAnimation on opacity {
                        running: button.urgent
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: button.modelData
                        color: button.active ? Theme.accent : (button.urgent ? Theme.red
                            : (mouse.containsMouse ? Theme.text : (button.occupied ? Theme.subtext1 : Theme.overlay0)))
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: true
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Repeater {
                        model: button.iconsShown ? button.apps : []

                        IconImage {
                            required property string modelData
                            implicitSize: 18
                            source: Quickshell.iconPath(DesktopEntries.heuristicLookup(modelData)?.icon ?? modelData.toLowerCase(), "application-x-executable")
                            asynchronous: true
                            opacity: button.active || mouse.containsMouse ? 1 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }

                    // Occupied but icons hidden (compact): a dot instead
                    Rectangle {
                        visible: button.occupied && !button.iconsShown
                        implicitWidth: 5
                        implicitHeight: 5
                        radius: 2.5
                        color: Theme.subtext0
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dispatch(`hl.dsp.focus({ workspace = ${button.modelData} })`)
                }
            }
        }
    }

    // Scroll anywhere on the strip to cycle this monitor's workspaces
    WheelHandler {
        property real acc: 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            acc += e.angleDelta.y;
            if (Math.abs(acc) < 120) return;
            const i = root.ids.indexOf(root.activeId);
            const next = root.ids[Math.max(0, Math.min(root.ids.length - 1, i + (acc > 0 ? -1 : 1)))];
            acc = 0;
            if (next !== undefined && next !== root.activeId) root.dispatch(`hl.dsp.focus({ workspace = ${next} })`);
        }
    }
}
