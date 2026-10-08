import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Wallpaper picker on the focused screen. Local: your collection, filtered by
// name. Online: wallhaven.cc search (empty search = this month's top), more
// results load as you scroll; picking one downloads it to ~/Pictures/Wallpapers.
// Choose which screen to apply to up top. Arrows move, Enter applies, Tab
// switches Local / Online, Escape clears the search or closes.
PanelWindow {
    id: picker

    required property var modelData
    required property bool open
    // Open on the Online tab, showing the results already searched
    property bool startOnline: false
    signal closeRequested

    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property bool shown: open && focusedScreen

    property bool online: false
    // Screen to apply to; "" for all of them
    property string target: ""
    readonly property var targets: target ? [target] : []

    // What the current target shows, to mark it in the grid
    readonly property string current: Wallpaper.active[target || modelData.name] ?? ""

    readonly property var items: {
        if (online) {
            return Wallpaper.results.map(r => ({
                key: r.id, source: Wallpaper.thumbsReady[r.id] ? "file://" + Wallpaper.thumbPath(r) : "",
                title: r.resolution,
                subtitle: (r.size / 1e6).toFixed(1) + " MB", item: r,
                isCurrent: current === Wallpaper.localPath(r)
            }));
        }
        const q = search.text.trim().toLowerCase();
        return Wallpaper.local
            .filter(p => !q || Wallpaper.name(p).toLowerCase().includes(q))
            .map(p => ({
                key: p, source: "file://" + p, title: Wallpaper.name(p),
                subtitle: p.startsWith(Wallpaper.downloadDir) ? "downloaded" : "", path: p,
                isCurrent: current === p
            }));
    }

    function pick(entry) {
        if (!entry) return;
        if (entry.item) Wallpaper.download(entry.item, targets);
        else Wallpaper.apply(entry.path, targets);
    }

    function setOnline(on) {
        if (online === on) return;
        online = on;
        search.text = on ? Wallpaper.query : "";
        grid.currentIndex = 0;
        if (on && Wallpaper.results.length === 0) Wallpaper.search(search.text, false);
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
    WlrLayershell.namespace: "wallpaper"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // `wallpaper search` while already open: jump to the results
    onStartOnlineChanged: {
        if (startOnline) {
            online = true;
            search.text = Wallpaper.query;
            grid.currentIndex = 0;
        }
    }

    onShownChanged: {
        if (shown) {
            if (startOnline) online = true;
            Wallpaper.refresh();
            search.text = online ? Wallpaper.query : "";
            grid.currentIndex = Math.max(0, items.findIndex(i => i.isCurrent));
            grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
            search.forceActiveFocus();
        }
    }

    // Online: search a moment after typing stops (wallhaven allows 45 requests a minute)
    Timer {
        id: debounce
        interval: 500
        onTriggered: Wallpaper.search(search.text, false)
    }

    // Rounded pill for tabs and options
    component Chip: Rectangle {
        id: chip

        property string label
        property string icon
        property bool selected: false
        signal clicked

        implicitWidth: row.implicitWidth + 24
        implicitHeight: 34
        radius: 17
        color: selected ? Theme.accent : (chipMouse.containsMouse ? Theme.surface1 : Theme.surface0)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Text {
                visible: chip.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                color: chip.selected ? Theme.crust : Theme.subtext1
                font.family: Theme.iconFont
                font.pixelSize: 13
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.selected ? Theme.crust : Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: chip.selected
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
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
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.barHeight + 48
        anchors.bottomMargin: 40
        width: Math.min(parent.width * 0.86, 1500)
        spacing: 16

        // ---- Search + tabs ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

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
                        text: picker.online ? Icons.globe : Icons.search
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

                        onTextChanged: {
                            grid.currentIndex = 0;
                            if (picker.online && activeFocus) debounce.restart();
                        }

                        Keys.onEscapePressed: {
                            if (text) text = "";
                            else picker.closeRequested();
                        }
                        Keys.onReturnPressed: picker.pick(picker.items[grid.currentIndex])
                        Keys.onEnterPressed: picker.pick(picker.items[grid.currentIndex])
                        Keys.onTabPressed: picker.setOnline(!picker.online)
                        Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                        Keys.onRightPressed: grid.moveCurrentIndexRight()
                        Keys.onUpPressed: grid.moveCurrentIndexUp()
                        Keys.onDownPressed: grid.moveCurrentIndexDown()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text
                            text: picker.online ? "Search wallhaven (empty: this month's top)" : "Filter wallpapers"
                            color: Theme.overlay0
                            font: search.font
                        }
                    }
                    Text {
                        text: picker.online && Wallpaper.searching ? "searching…" : picker.items.length
                        color: Theme.overlay0
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }

            Chip {
                label: "Local"
                icon: Icons.image
                selected: !picker.online
                onClicked: picker.setOnline(false)
            }
            Chip {
                label: "Online"
                icon: Icons.globe
                selected: picker.online
                onClicked: picker.setOnline(true)
            }
        }

        // ---- Options ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Apply to"
                color: Theme.overlay1
                font.family: Theme.font
                font.pixelSize: 12
                Layout.rightMargin: 4
            }
            Chip {
                label: "All screens"
                selected: picker.target === ""
                onClicked: picker.target = ""
            }
            Repeater {
                model: Quickshell.screens

                Chip {
                    required property var modelData
                    label: `${modelData.name} · ${modelData.width}×${modelData.height}`
                    selected: picker.target === modelData.name
                    onClicked: picker.target = modelData.name
                }
            }

            Item { Layout.fillWidth: true }

            Chip {
                visible: picker.online
                label: "21:9 only"
                selected: Wallpaper.ultrawide
                onClicked: Wallpaper.ultrawide = !Wallpaper.ultrawide
            }
            Chip {
                visible: !picker.online
                label: "Random"
                icon: Icons.shuffle
                onClicked: Wallpaper.random(picker.targets)
            }
        }

        // ---- Suggestions for online search ----
        RowLayout {
            Layout.fillWidth: true
            visible: picker.online
            spacing: 8

            Repeater {
                model: ["catppuccin", "anime", "frieren", "nature", "minimalist", "pixel art", "space", "city"]

                Chip {
                    required property string modelData
                    implicitHeight: 28
                    label: modelData
                    selected: Wallpaper.query === modelData
                    onClicked: {
                        search.text = modelData;
                        Wallpaper.search(modelData, false);
                        search.forceActiveFocus();
                    }
                }
            }
        }

        // ---- Grid ----
        GridView {
            id: grid

            readonly property int columns: Math.max(2, Math.floor(content.width / 340))

            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: Math.floor(width / columns)
            cellHeight: Math.round(cellWidth * 0.62)
            clip: true
            model: picker.items
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            // Infinite scroll for online results
            onAtYEndChanged: if (atYEnd && picker.online && count > 0) Wallpaper.search("", true)

            delegate: Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool selected: GridView.isCurrentItem
                readonly property bool busy: Wallpaper.downloading !== "" && Wallpaper.downloading === modelData.item?.id

                width: grid.cellWidth
                height: grid.cellHeight

                ClippingRectangle {
                    id: card

                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 14
                    color: Theme.mantle
                    border.width: cell.modelData.isCurrent ? 3 : (cell.selected ? 2 : 0)
                    border.color: cell.modelData.isCurrent ? Theme.accent : Theme.lavender
                    scale: cellMouse.containsMouse || cell.selected ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: cell.modelData.source
                        sourceSize.width: 480
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }

                    // Loading shimmer
                    Text {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready
                        text: Icons.image
                        color: Theme.surface1
                        font.family: Theme.iconFont
                        font.pixelSize: 28
                    }

                    // Caption on a fade at the bottom
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 44
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Qt.alpha(Theme.crust, 0.9) }
                        }
                        opacity: cellMouse.containsMouse || cell.selected || cell.modelData.isCurrent ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: cell.modelData.title
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: cell.modelData.subtitle
                                color: Theme.subtext0
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Current badge
                    Rectangle {
                        visible: cell.modelData.isCurrent
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 24
                        height: 24
                        radius: 12
                        color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: Icons.check
                            color: Theme.crust
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }
                    }

                    // Downloading
                    Rectangle {
                        anchors.fill: parent
                        visible: cell.busy
                        color: Qt.alpha(Theme.crust, 0.6)

                        Text {
                            anchors.centerIn: parent
                            text: Icons.download
                            color: Theme.accent
                            font.family: Theme.iconFont
                            font.pixelSize: 24

                            SequentialAnimation on opacity {
                                running: cell.busy
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                    }
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: grid.currentIndex = cell.index
                    onClicked: picker.pick(cell.modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: picker.online
                    ? (Wallpaper.searching ? "Searching…" : (Wallpaper.error || "No results"))
                    : (Wallpaper.local.length ? `No wallpapers match "${search.text}"` : "No wallpapers in ~/dotfiles/wallpapers or ~/Pictures/Wallpapers")
                color: Wallpaper.error && picker.online ? Theme.red : Theme.overlay0
                font.family: Theme.font
                font.pixelSize: 14
            }
        }
    }
}
