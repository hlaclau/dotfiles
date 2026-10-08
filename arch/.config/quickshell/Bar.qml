import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import Quickshell.Widgets

// Top bar for one screen: a solid strip the island grows out of, with rounded
// corners curving down into the screen. Chips on both sides, the center left
// free for the island.
//
//   left   launcher · workspaces · focused window
//   right  updates · weather · CPU/RAM/GPU · tray · network/audio/notifications/AI · date
//
// Hover a chip for details (the volume card has sliders, the date a calendar),
// click / right click / scroll it to act. On narrow screens (`compact`) the
// secondary labels go and only the active workspace shows app icons.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    signal islandTab(int index)
    signal toggleLauncher
    signal toggleOverview
    signal toggleAi

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: monitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property bool compact: width < 2400
    // Room each side gets: half the screen minus the expanded island (560) and a gap
    readonly property real sideWidth: width / 2 - 280 - 24
    readonly property int corner: 18

    visible: !fullscreen
    color: "transparent"
    // The corners hang below the strip; only the strip reserves space
    implicitHeight: Theme.barHeight + corner
    exclusiveZone: Theme.barHeight
    mask: Region { item: strip }

    anchors {
        top: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "bar"

    function levelColor(v) {
        return v > 0.9 ? Theme.red : (v > 0.7 ? Theme.peach : Theme.accent);
    }
    function percent(v) {
        return Math.round(v * 100) + "%";
    }
    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Glyph: Text {
        color: Theme.accent
        font.family: Theme.iconFont
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    component Label: Text {
        color: Theme.subtext1
        font.family: Theme.font
        font.pixelSize: 13
        font.bold: true
    }
    // Small caption above or beside a main label
    component Caption: Text {
        color: Theme.overlay1
        font.family: Theme.font
        font.pixelSize: 10
    }
    // Two lines: small caption over a bold value
    component Stack: ColumnLayout {
        property alias caption: cap.text
        property alias value: val.text
        property alias valueColor: val.color

        spacing: -1

        Caption { id: cap }
        Label { id: val; color: Theme.text }
    }
    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
        color: Theme.surface0
    }
    // Popup row: label on the left, value on the right
    component Stat: RowLayout {
        property string label
        property string value
        property color valueColor: Theme.text

        Layout.fillWidth: true
        spacing: 16

        Text {
            Layout.fillWidth: true
            text: parent.label
            color: Theme.overlay1
            font.family: Theme.font
            font.pixelSize: 12
        }
        Text {
            text: parent.value
            color: parent.valueColor
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
        }
    }
    component Heading: Text {
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 13
        font.bold: true
    }
    component Hint: Text {
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 11
    }
    // Inverted corner under the strip: filled outside a quarter circle
    component Corner: Shape {
        property bool mirrored: false

        width: bar.corner
        height: bar.corner
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: parent.mirrored ? -1 : 1; origin.x: bar.corner / 2 }

        ShapePath {
            fillColor: Theme.crust
            strokeWidth: -1
            startX: 0; startY: 0
            PathLine { x: bar.corner; y: 0 }
            PathArc {
                x: 0; y: bar.corner
                radiusX: bar.corner; radiusY: bar.corner
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }
    }

    Rectangle {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.barHeight
        color: Theme.crust
    }
    Corner {
        anchors.left: parent.left
        anchors.top: strip.bottom
    }
    Corner {
        anchors.right: parent.right
        anchors.top: strip.bottom
        mirrored: true
    }

    // =========================== Left ===========================
    RowLayout {
        id: left

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: strip.top
        anchors.bottom: strip.bottom
        width: Math.min(implicitWidth, bar.sideWidth)
        spacing: 8

        // ---- Launcher: click for apps, right click for the overview ----
        BarPill {
            color: launcherItem.hovered ? Theme.accent : Qt.alpha(Theme.accent, 0.16)
            Behavior on color { ColorAnimation { duration: 150 } }

            BarItem {
                id: launcherItem
                padding: 9
                onClicked: button => button === Qt.RightButton ? bar.toggleOverview() : bar.toggleLauncher()

                Glyph {
                    text: Icons.arch
                    font.pixelSize: 17
                    color: launcherItem.hovered ? Theme.crust : Theme.accent
                }
            }
        }

        BarPill {
            Workspaces {
                monitor: bar.monitor
                showAllIcons: !bar.compact
            }
        }

        // ---- Focused window (or this screen's window when focus is elsewhere) ----
        Item {
            id: windowBox

            readonly property var toplevel: {
                const active = Hyprland.activeToplevel;
                if (active && active.monitor?.name === bar.monitor?.name) return active;
                return bar.monitor?.activeWorkspace?.toplevels.values[0] ?? null;
            }
            readonly property string appId: toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || ""
            readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null
            readonly property string appName: entry?.name ?? appId
            readonly property bool focused: toplevel !== null && toplevel === Hyprland.activeToplevel
            // The app name is already shown: drop a trailing " - Google Chrome"
            readonly property string title: {
                const t = toplevel?.title ?? "";
                const m = t.match(/^(.*\S)\s+[-—–|]\s+([^-—–|]+)$/);
                return m && m[2].toLowerCase().includes(appName.toLowerCase()) ? m[1] : t;
            }

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 4
            implicitWidth: windowRow.implicitWidth
            opacity: toplevel ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Slide the new window in when focus changes
            onToplevelChanged: if (toplevel) swap.restart()
            ParallelAnimation {
                id: swap
                NumberAnimation { target: windowRow; property: "anchors.verticalCenterOffset"; from: 10; to: 0; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: windowRow; property: "scale"; from: 0.96; to: 1; duration: 260; easing.type: Easing.OutCubic }
            }

            RowLayout {
                id: windowRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                opacity: windowBox.focused ? 1 : 0.5
                Behavior on opacity { NumberAnimation { duration: 200 } }

                IconImage {
                    implicitSize: 24
                    source: Quickshell.iconPath(windowBox.entry?.icon ?? windowBox.appId.toLowerCase(), "application-x-executable")
                    asynchronous: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: bar.compact ? 300 : 520
                    spacing: -1

                    Caption {
                        Layout.fillWidth: true
                        text: windowBox.appName.toUpperCase()
                        color: Theme.accent
                        font.bold: true
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.fillWidth: true
                        text: windowBox.title || windowBox.appName
                        color: Theme.text
                        font.bold: false
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // =========================== Right ===========================
    // Laid out right to left: the first chip sits at the screen edge
    RowLayout {
        id: right

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: strip.top
        anchors.bottom: strip.bottom
        layoutDirection: Qt.RightToLeft
        spacing: 8

        // ---- Date, with a calendar on hover ----
        BarPill {
            id: datePill

            BarItem {
                id: dateItem
                padding: 12
                onClicked: bar.islandTab(0)

                Glyph {
                    text: Icons.calendar
                    font.pixelSize: 14
                }
                Stack {
                    caption: Qt.formatDate(clock.date, "dddd")
                    value: Qt.formatDate(clock.date, "d MMMM")
                }
            }

            BarPopup {
                owner: datePill
                ownerHovered: dateItem.hovered
                padding: 14

                Calendar {
                    today: clock.date
                }
            }
        }

        // ---- Status: network · volume · mic · notifications · AI ----
        BarPill {
            BarItem {
                id: netItem

                readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
                readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
                readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null
                readonly property bool online: wired !== null || wifi !== null

                padding: 9
                onClicked: bar.islandTab(2)

                Glyph {
                    text: netItem.wired ? Icons.ethernet : (netItem.wifi ? Icons.wifi : Icons.wifiOff)
                    color: netItem.online ? Theme.accent : Theme.red
                }

                BarPopup {
                    owner: netItem
                    ownerHovered: netItem.hovered

                    ColumnLayout {
                        width: 230
                        spacing: 6

                        Heading { text: netItem.online ? "Connected" : "Offline"; Layout.bottomMargin: 2 }
                        Stat {
                            label: "Ethernet"
                            value: netItem.wired ? "connected" : "—"
                            valueColor: netItem.wired ? Theme.green : Theme.overlay0
                        }
                        Stat {
                            label: "Wi-Fi"
                            value: netItem.wifiNetwork?.name ?? (Networking.wifiEnabled ? "not connected" : "off")
                            valueColor: netItem.wifi ? Theme.green : Theme.overlay0
                        }
                        Hint { text: "Click for networks and Bluetooth"; Layout.topMargin: 4 }
                    }
                }
            }

            BarItem {
                id: volumeItem
                padding: 9
                onClicked: button => button === Qt.RightButton ? bar.islandTab(1) : Status.toggleMute()
                onScrolled: steps => Status.setVolume(Status.volume + steps * 0.05)

                Glyph {
                    text: Status.muted ? Icons.volumeMute : (Status.volume < 0.4 ? Icons.volumeLow : Icons.volumeHigh)
                    color: Status.muted ? Theme.overlay0 : Theme.accent
                }
                Label {
                    visible: !bar.compact
                    Layout.preferredWidth: 36
                    text: Status.muted ? "off" : bar.percent(Status.volume)
                    color: Status.muted ? Theme.overlay0 : Theme.subtext1
                }
            }

            BarItem {
                id: micItem
                padding: 9
                onClicked: button => button === Qt.RightButton ? bar.islandTab(1) : Status.toggleMic()
                onScrolled: steps => {
                    const a = Status.source?.audio;
                    if (a) a.volume = Math.max(0, Math.min(1, a.volume + steps * 0.05));
                }

                Glyph {
                    text: Status.micMuted ? Icons.micSlash : Icons.mic
                    color: Status.micMuted ? Theme.red : (Status.micInUse ? Theme.peach : Theme.accent)
                }
            }

            // Sliders for output, mic and each app, shared by both audio buttons
            BarPopup {
                owner: volumeItem
                ownerHovered: volumeItem.hovered || micItem.hovered
                padding: 16

                ColumnLayout {
                    width: 360
                    spacing: 10

                    Repeater {
                        model: [
                            { name: Status.nodeName(Status.sink) || "Output", node: Status.sink, mic: false },
                            { name: Status.nodeName(Status.source) || "Input", node: Status.source, mic: true }
                        ]

                        ColumnLayout {
                            id: channel

                            required property var modelData
                            readonly property var audio: modelData.node?.audio ?? null

                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Glyph {
                                    text: channel.modelData.mic
                                        ? (channel.audio?.muted ? Icons.micSlash : Icons.mic)
                                        : (channel.audio?.muted ? Icons.volumeMute : Icons.volumeHigh)
                                    color: channel.audio?.muted ? Theme.overlay0 : Theme.accent

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (channel.audio) channel.audio.muted = !channel.audio.muted
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: channel.modelData.name
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: channel.audio?.muted ? "muted" : bar.percent(channel.audio?.volume ?? 0)
                                    color: Theme.subtext0
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            VolumeSlider {
                                Layout.fillWidth: true
                                audio: channel.audio
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        implicitHeight: 1
                        color: Theme.surface0
                    }
                    Heading { text: "Apps" }
                    AppMixer {
                        Layout.fillWidth: true
                    }

                    Hint { text: "Click an icon to mute · right click for devices"; Layout.topMargin: 2 }
                }
            }

            Divider {}

            BarItem {
                id: notifItem
                padding: 9
                onClicked: button => {
                    if (button === Qt.RightButton) Notifs.dnd = !Notifs.dnd;
                    else if (button === Qt.MiddleButton) Notifs.clearAll();
                    else bar.islandTab(0);
                }

                Item {
                    implicitWidth: bell.implicitWidth
                    implicitHeight: bell.implicitHeight

                    Glyph {
                        id: bell
                        text: Notifs.dnd ? Icons.bellSlash : Icons.bell
                        color: Notifs.dnd ? Theme.peach : (Notifs.count > 0 ? Theme.text : Theme.overlay1)
                    }
                    // Count badge
                    Rectangle {
                        visible: Notifs.count > 0 && !Notifs.dnd
                        x: bell.width - 5
                        y: -5
                        width: Math.max(14, badge.implicitWidth + 6)
                        height: 14
                        radius: 7
                        color: Theme.accent
                        scale: visible ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                        Text {
                            id: badge
                            anchors.centerIn: parent
                            text: Notifs.count > 9 ? "9+" : Notifs.count
                            color: Theme.crust
                            font.family: Theme.font
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                BarPopup {
                    owner: notifItem
                    ownerHovered: notifItem.hovered

                    ColumnLayout {
                        spacing: 4
                        Heading {
                            text: Notifs.count ? Notifs.count + " notification" + (Notifs.count > 1 ? "s" : "") : "No notifications"
                        }
                        Caption { visible: Notifs.dnd; text: "Do not disturb is on"; color: Theme.peach }
                        Hint { text: "Click to open · right click DND · middle click clear"; Layout.topMargin: 4 }
                    }
                }
            }

            BarItem {
                id: aiItem
                padding: 9
                active: Ai.busy
                onClicked: bar.toggleAi()

                Glyph {
                    id: robot
                    text: Icons.robot
                    font.pixelSize: 16
                    color: Ai.busy || aiItem.hovered ? Theme.accent : Theme.overlay1

                    SequentialAnimation on opacity {
                        running: Ai.busy
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) robot.opacity = 1
                        NumberAnimation { to: 0.4; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }
        }

        BarPill {
            shown: tray.items.length > 0
            Tray {
                id: tray
                barWindow: bar
            }
        }

        // ---- System: CPU · RAM · GPU rings, graphs on hover, btop on click ----
        BarPill {
            id: system

            BarItem {
                id: systemItem
                padding: 10
                // Own class so hyprland.lua floats it at a size btop fits in
                onClicked: bar.run("uwsm app -- ghostty --class=ghostty.btop -e btop")

                Repeater {
                    model: [
                        { icon: Icons.cpu, value: SysInfo.cpu, show: true },
                        { icon: Icons.memory, value: SysInfo.mem, show: true },
                        { icon: Icons.gpu, value: SysInfo.gpu, show: SysInfo.hasGpu }
                    ]

                    RowLayout {
                        id: meter

                        required property var modelData
                        required property int index

                        visible: modelData.show
                        spacing: 5
                        Layout.leftMargin: index > 0 ? 4 : 0

                        Ring {
                            value: meter.modelData.value
                            icon: meter.modelData.icon
                            color: bar.levelColor(meter.modelData.value)
                        }
                        Label {
                            visible: !bar.compact
                            Layout.preferredWidth: 34
                            text: bar.percent(meter.modelData.value)
                            color: meter.modelData.value > 0.7 ? bar.levelColor(meter.modelData.value) : Theme.subtext1
                        }
                    }
                }
            }

            BarPopup {
                owner: system
                ownerHovered: systemItem.hovered

                ColumnLayout {
                    width: 300
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Heading { Layout.fillWidth: true; text: "System" }
                        Hint {
                            text: {
                                const h = Math.floor(SysInfo.uptime / 3600), m = Math.floor(SysInfo.uptime % 3600 / 60);
                                return "up " + (h > 0 ? h + "h " : "") + m + "m";
                            }
                        }
                    }

                    Repeater {
                        model: [
                            { name: "CPU", value: SysInfo.cpu, history: SysInfo.cpuHistory, show: true,
                              detail: Math.round(SysInfo.cpuTemp) + "°C" },
                            { name: "Memory", value: SysInfo.mem, history: SysInfo.memHistory, show: true,
                              detail: SysInfo.memUsed.toFixed(1) + " / " + SysInfo.memTotal.toFixed(0) + " GiB" },
                            { name: "GPU", value: SysInfo.gpu, history: SysInfo.gpuHistory, show: SysInfo.hasGpu,
                              detail: Math.round(SysInfo.gpuTemp) + "°C · " + SysInfo.vramUsed.toFixed(1) + " / " + SysInfo.vramTotal.toFixed(0) + " GiB" }
                        ]

                        ColumnLayout {
                            id: graph

                            required property var modelData

                            visible: modelData.show
                            Layout.fillWidth: true
                            spacing: 4

                            Stat {
                                label: graph.modelData.name + "  " + graph.modelData.detail
                                value: bar.percent(graph.modelData.value)
                                valueColor: bar.levelColor(graph.modelData.value)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 8
                                color: Theme.mantle
                                clip: true

                                Sparkline {
                                    anchors.fill: parent
                                    anchors.topMargin: 4
                                    values: graph.modelData.history
                                    capacity: SysInfo.historyLength
                                    color: bar.levelColor(graph.modelData.value)
                                    lineWidth: 1.6
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Stat {
                            label: "Disk /home"
                            value: SysInfo.diskUsed.toFixed(0) + " / " + SysInfo.diskTotal.toFixed(0) + " GB"
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6
                            radius: 3
                            color: Theme.surface0

                            Rectangle {
                                width: parent.width * SysInfo.disk
                                height: parent.height
                                radius: 3
                                color: bar.levelColor(SysInfo.disk)
                            }
                        }
                    }

                    Hint { Layout.alignment: Qt.AlignHCenter; text: "Click for btop" }
                }
            }
        }

        // ---- Weather ----
        BarPill {
            id: weatherPill
            shown: Weather.ready

            BarItem {
                id: weatherItem
                padding: 12
                onClicked: Weather.refresh()

                Glyph {
                    text: Weather.icon
                    font.pixelSize: 17
                    color: Theme.yellow
                }
                Stack {
                    visible: !bar.compact
                    caption: Weather.description
                    value: Weather.temp + "°C"
                }
                Label {
                    visible: bar.compact
                    text: Weather.temp + "°"
                    color: Theme.text
                }
            }

            BarPopup {
                owner: weatherPill
                ownerHovered: weatherItem.hovered
                padding: 16

                ColumnLayout {
                    width: 260
                    spacing: 12

                    RowLayout {
                        spacing: 14

                        Text {
                            text: Weather.icon
                            color: Theme.yellow
                            font.family: Theme.iconFont
                            font.pixelSize: 36
                        }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Weather.temp + "°C"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 24
                                font.bold: true
                            }
                            Caption { text: Weather.description + (Weather.area ? " · " + Weather.area : "") }
                        }
                    }

                    RowLayout {
                        spacing: 16
                        Caption { text: "Feels like " + Weather.feelsLike + "°" }
                        Caption { text: "Humidity " + Weather.humidity + "%" }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.surface0
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            model: Weather.days

                            ColumnLayout {
                                id: day

                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                spacing: 4

                                Caption {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: day.index === 0 ? "Today" : Qt.formatDate(new Date(day.modelData.date + "T12:00"), "ddd")
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Weather.iconFor(day.modelData.code, false)
                                    color: Theme.yellow
                                    font.family: Theme.iconFont
                                    font.pixelSize: 20
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: day.modelData.max + "° <font color='" + Theme.overlay1 + "'>" + day.modelData.min + "°</font>"
                                    textFormat: Text.StyledText
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- Package updates (only when there are some) ----
        BarPill {
            shown: Updates.count > 0 || Updates.updating

            BarItem {
                id: updatesItem
                onClicked: if (!Updates.updating) Updates.update()

                Glyph {
                    id: updatesGlyph
                    text: Updates.updating ? Icons.refresh : Icons.download
                    color: Theme.peach

                    RotationAnimation on rotation {
                        running: Updates.updating
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1200
                        onRunningChanged: if (!running) updatesGlyph.rotation = 0
                    }
                }
                Label {
                    text: Updates.count
                    color: Theme.peach
                }

                BarPopup {
                    owner: updatesItem
                    ownerHovered: updatesItem.hovered

                    ColumnLayout {
                        width: 220
                        spacing: 4

                        Heading {
                            text: Updates.count + " update" + (Updates.count === 1 ? "" : "s")
                            Layout.bottomMargin: 4
                        }
                        Repeater {
                            model: [...Updates.repo, ...Updates.aur.map(n => n + "  (aur)")].slice(0, 12)

                            Text {
                                required property string modelData
                                text: modelData
                                color: Theme.subtext1
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                        Hint { visible: Updates.count > 12; text: "and " + (Updates.count - 12) + " more" }
                        Hint { text: "Click to update"; Layout.topMargin: 4 }
                    }
                }
            }
        }
    }
}
