import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Wallpaper picker on the focused screen. Local: your collection, filtered by
// name. Online: wallhaven.cc search (empty search = this month's top), more
// results load ahead as you scroll; picking one downloads it to ~/Pictures/Wallpapers.
// Choose which screen to apply to up top. Arrows move, Enter applies, Tab
// switches Local / Online, Escape clears the search or closes. Local ones can
// be moved to the trash: the bin on hover or Delete, twice to confirm.
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

    readonly property var model: online ? Wallpaper.onlineModel : Wallpaper.localModel

    // Path a row's wallpaper has (or will have, once downloaded) on disk
    function pathOf(row) {
        return row.wid ? Wallpaper.localPath(row.wid, row.url) : row.path;
    }

    // Path armed for deletion: a second click / Delete within 3s trashes it
    property string armed: ""
    Timer {
        id: disarm
        interval: 3000
        onTriggered: picker.armed = ""
    }

    function remove(index) {
        if (online || index < 0 || index >= model.count) return;
        const path = model.get(index).path;
        if (armed === path) {
            armed = "";
            Wallpaper.trash(path);
        } else {
            armed = path;
            disarm.restart();
        }
    }

    function pick(index) {
        if (index < 0 || index >= model.count) return;
        const row = model.get(index);
        if (row.wid) Wallpaper.download(row.wid, row.url, targets);
        else Wallpaper.apply(row.path, targets);
    }

    function setOnline(on) {
        if (online === on) return;
        online = on;
        search.text = on ? Wallpaper.query : "";
        grid.currentIndex = 0;
        if (on && Wallpaper.onlineModel.count === 0) Wallpaper.search(search.text, false);
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
            if (!online) Wallpaper.filterLocal("");
            // Start on the wallpaper shown now
            let i = 0;
            for (let r = 0; r < model.count; r++) {
                if (pathOf(model.get(r)) === current) {
                    i = r;
                    break;
                }
            }
            grid.currentIndex = i;
            grid.positionViewAtIndex(i, GridView.Center);
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
                            if (!picker.online) Wallpaper.filterLocal(text);
                            else if (activeFocus) debounce.restart();
                        }

                        Keys.onEscapePressed: {
                            if (text) text = "";
                            else picker.closeRequested();
                        }
                        Keys.onReturnPressed: picker.pick(grid.currentIndex)
                        Keys.onEnterPressed: picker.pick(grid.currentIndex)
                        Keys.onTabPressed: picker.setOnline(!picker.online)
                        Keys.onDeletePressed: picker.remove(grid.currentIndex)
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
                        text: picker.online && Wallpaper.searching ? "searching…" : picker.model.count
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
            model: picker.model
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            // Keep a couple of rows ready above and below the view
            cacheBuffer: cellHeight * 2

            // Infinite scroll: fetch the next page two rows before the end,
            // new rows are appended so the view stays where it is
            onContentYChanged: {
                if (picker.online && count > 0 && Wallpaper.hasMore
                    && contentY + height > contentHeight - cellHeight * 2) Wallpaper.search("", true);
            }

            delegate: Item {
                id: cell

                required property int index
                required property string title
                required property string subtitle
                required property string thumb
                required property string path
                required property string wid
                required property string url

                readonly property bool selected: GridView.isCurrentItem
                readonly property bool isCurrent: picker.current !== "" && picker.pathOf(cell) === picker.current
                readonly property bool busy: wid !== "" && Wallpaper.downloading === wid

                width: grid.cellWidth
                height: grid.cellHeight

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Below the card so the card's own buttons (bin) get clicks first.
                    // Hover doesn't move the keyboard selection: that would
                    // scroll the view under the pointer
                    onClicked: {
                        grid.currentIndex = cell.index;
                        picker.pick(cell.index);
                    }
                }

                ClippingRectangle {
                    id: card

                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 14
                    color: Theme.mantle
                    border.width: cell.isCurrent ? 3 : (cell.selected ? 2 : 0)
                    border.color: cell.isCurrent ? Theme.accent : Theme.lavender
                    scale: cellMouse.containsMouse || cell.selected ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: cell.thumb ? "file://" + cell.thumb : ""
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
                        opacity: cellMouse.containsMouse || cell.selected || cell.isCurrent ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: cell.title
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: cell.subtitle
                                color: Theme.subtext0
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Trash (local only): first click arms it, second deletes
                    Rectangle {
                        id: bin

                        readonly property bool armed: picker.armed !== "" && picker.armed === cell.path

                        visible: !picker.online && (cellMouse.containsMouse || binMouse.containsMouse || armed)
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 10
                        width: armed ? binLabel.implicitWidth + 40 : 28
                        height: 28
                        radius: 14
                        color: armed ? Theme.red : (binMouse.containsMouse ? Theme.surface1 : Qt.alpha(Theme.crust, 0.8))
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.trash
                                color: bin.armed ? Theme.crust : Theme.text
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                            }
                            Text {
                                id: binLabel
                                visible: bin.armed
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Delete?"
                                color: Theme.crust
                                font.family: Theme.font
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: binMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: picker.remove(cell.index)
                        }
                    }

                    // Current badge
                    Rectangle {
                        visible: cell.isCurrent
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
