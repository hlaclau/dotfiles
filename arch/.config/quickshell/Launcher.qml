import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Full-screen app grid with search, on the focused screen. Type to filter,
// arrows to move, Enter to launch, Escape to clear the search or close.
PanelWindow {
    id: launcher

    required property var modelData
    required property bool open
    signal closeRequested

    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property bool shown: open && focusedScreen
    readonly property var results: Apps.search(search.text)

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
    WlrLayershell.namespace: "launcher"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            search.text = "";
            grid.currentIndex = 0;
            grid.positionViewAtBeginning();
            search.forceActiveFocus();
        }
    }

    function launch(app) {
        if (!app) return;
        Apps.launch(app);
        closeRequested();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.closeRequested()
        }
    }

    // ---- Search ----
    Rectangle {
        id: searchBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.14
        width: 480
        height: 52
        radius: 16
        color: Theme.base
        border.width: 1
        border.color: search.activeFocus ? Theme.accent : Theme.surface1

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.search
            color: Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 15
        }

        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: 14
            anchors.right: count.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            selectionColor: Theme.surface2
            font.family: Theme.font
            font.pixelSize: 16
            clip: true

            onTextChanged: grid.currentIndex = 0

            Keys.onEscapePressed: {
                if (text) text = "";
                else launcher.closeRequested();
            }
            Keys.onReturnPressed: launcher.launch(launcher.results[grid.currentIndex])
            Keys.onEnterPressed: launcher.launch(launcher.results[grid.currentIndex])
            Keys.onLeftPressed: grid.moveCurrentIndexLeft()
            Keys.onRightPressed: grid.moveCurrentIndexRight()
            Keys.onUpPressed: grid.moveCurrentIndexUp()
            Keys.onDownPressed: grid.moveCurrentIndexDown()
            Keys.onTabPressed: grid.moveCurrentIndexRight()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !search.text
                text: "Search apps"
                color: Theme.overlay0
                font: search.font
            }
        }

        Text {
            id: count
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.results.length
            color: Theme.overlay0
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // ---- Grid ----
    GridView {
        id: grid

        readonly property int columns: Math.max(3, Math.floor(launcher.width * 0.78 / cellWidth))

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: searchBox.bottom
        anchors.topMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        width: columns * cellWidth
        cellWidth: 180
        cellHeight: 170
        clip: true
        model: launcher.results
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        keyNavigationWraps: false

        delegate: Item {
            id: cell

            required property var modelData
            required property int index
            readonly property bool current: GridView.isCurrentItem

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 8
                radius: 18
                color: cell.current ? Theme.surface0 : "transparent"
                border.width: cell.current ? 1 : 0
                border.color: Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            IconImage {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 30
                implicitSize: 64
                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                asynchronous: true
            }

            Text {
                anchors.top: icon.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 28
                horizontalAlignment: Text.AlignHCenter
                text: cell.modelData.name
                color: cell.current ? Theme.text : Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.currentIndex = cell.index
                onClicked: launcher.launch(cell.modelData)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: searchBox.bottom
        anchors.topMargin: 80
        visible: launcher.results.length === 0
        text: "No apps match \"" + search.text + "\""
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 14
    }
}
