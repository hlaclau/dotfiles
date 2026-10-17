import QtQuick
import QtQuick.Layouts

// A window of the control center overlay: title bar to drag it, pin to keep it after the
// overlay closes, close, and grips on the right and bottom edges to resize it. Put the content
// inside (a tab); it is as wide as the panel and scrolls when taller.
Rectangle {
    id: panel

    required property string panelId
    property string title
    property string icon
    property int defaultWidth: 460
    property int defaultHeight: 0
    // Fade the frame and title bar out once the overlay closes, leaving just the content
    property bool bare: false
    // The content fills the panel instead of scrolling inside it
    property bool fill: false
    property bool defaultClickthrough: false
    // Offsets the first position so panels opened for the first time do not stack exactly
    property int cascade: 0
    default property alias content: holder.data

    readonly property var info: OverlayState.info(panelId)
    readonly property bool wanted: info.open && (OverlayState.shown || info.pinned)
    readonly property bool bareNow: bare && !OverlayState.shown
    // Pinned panels that let clicks through are left out of the window's input region
    readonly property bool clickthrough: info.clickthrough ?? defaultClickthrough

    readonly property real minWidth: 320
    readonly property real minHeight: 160
    readonly property real pad: 10
    readonly property real maxHeight: (parent?.height ?? 800) * 0.85

    readonly property real wantW: info.w > 0 ? info.w : defaultWidth
    readonly property real wantH: info.h > 0 ? info.h
        : (defaultHeight > 0 ? defaultHeight : Math.min(header.height + holder.height + 2 * pad, maxHeight))
    readonly property real wantX: info.x !== undefined ? info.x : ((parent?.width ?? 0) - wantW) / 2 + cascade * 36
    readonly property real wantY: info.y !== undefined ? info.y : (Theme.barHeight + 90) + cascade * 36

    // While dragging or resizing the panel follows the pointer; the state is written on release
    property bool interacting: false
    property real liveX
    property real liveY
    property real liveW
    property real liveH

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(v, Math.max(lo, hi)));
    }
    function begin() {
        liveX = x;
        liveY = y;
        liveW = width;
        liveH = height;
        interacting = true;
        OverlayState.raise(panelId);
    }
    function commit() {
        OverlayState.setGeometry(panelId, { x: Math.round(liveX), y: Math.round(liveY), w: Math.round(liveW), h: Math.round(liveH) });
        interacting = false;
    }

    width: interacting ? liveW : wantW
    height: interacting ? liveH : wantH
    x: clamp(interacting ? liveX : wantX, 0, (parent?.width ?? 0) - width)
    y: clamp(interacting ? liveY : wantY, 0, (parent?.height ?? 0) - height)
    z: OverlayState.indexOf(panelId)

    radius: 22
    color: bareNow ? "transparent" : Theme.crust
    border.width: 1
    border.color: bareNow ? "transparent" : Theme.surface0
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    opacity: wanted ? 1 : 0
    visible: opacity > 0
    scale: wanted ? 1 : 0.96
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Clicking anywhere in the panel brings it to the front
    TapHandler {
        onPressedChanged: if (pressed) OverlayState.raise(panel.panelId)
    }

    // ---- Title bar ----
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 42
        // Keeps its room when hidden so the content does not jump
        opacity: panel.bareNow ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }

        MouseArea {
            anchors.fill: parent
            enabled: !panel.bareNow
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real grabX
            property real grabY

            onPressed: mouse => {
                panel.begin();
                const p = mapToItem(panel.parent, mouse.x, mouse.y);
                grabX = p.x - panel.x;
                grabY = p.y - panel.y;
            }
            onPositionChanged: mouse => {
                if (!pressed) return;
                const p = mapToItem(panel.parent, mouse.x, mouse.y);
                panel.liveX = panel.clamp(p.x - grabX, 0, panel.parent.width - panel.width);
                panel.liveY = panel.clamp(p.y - grabY, 0, panel.parent.height - panel.height);
            }
            onReleased: panel.commit()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 10
            spacing: 8

            Text {
                text: panel.icon
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 14
            }
            Text {
                Layout.fillWidth: true
                text: panel.title
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

            IconButton {
                size: 26
                visible: panel.info.pinned
                icon: Icons.mouse
                iconColor: Theme.subtext1
                active: !panel.clickthrough
                onClicked: OverlayState.patch(panel.panelId, { clickthrough: !panel.clickthrough })
            }
            IconButton {
                size: 26
                icon: ""
                iconColor: Theme.subtext1
                active: panel.info.pinned
                onClicked: OverlayState.setPinned(panel.panelId, !panel.info.pinned)
            }
            IconButton {
                size: 26
                icon: Icons.close
                iconColor: Theme.subtext1
                onClicked: OverlayState.closePanel(panel.panelId)
            }
        }
    }

    // ---- Content ----
    Flickable {
        id: flick
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: panel.pad
        anchors.rightMargin: panel.pad
        anchors.bottomMargin: panel.pad
        clip: true
        contentWidth: width
        contentHeight: holder.height
        interactive: !panel.fill
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: holder
            width: flick.width
            height: panel.fill ? flick.height : childrenRect.height
        }
    }

    // ---- Resize grips ----
    component Grip: MouseArea {
        id: grip

        property bool horizontal: false
        property bool vertical: false
        property real startW
        property real startH
        property real startX
        property real startY

        enabled: !panel.bareNow
        hoverEnabled: true
        cursorShape: horizontal && vertical ? Qt.SizeFDiagCursor : (horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor)

        onPressed: mouse => {
            panel.begin();
            const p = mapToItem(panel.parent, mouse.x, mouse.y);
            startX = p.x;
            startY = p.y;
            startW = panel.width;
            startH = panel.height;
        }
        onPositionChanged: mouse => {
            if (!pressed) return;
            const p = mapToItem(panel.parent, mouse.x, mouse.y);
            if (horizontal) panel.liveW = panel.clamp(startW + p.x - startX, panel.minWidth, panel.parent.width - panel.x);
            if (vertical) panel.liveH = panel.clamp(startH + p.y - startY, panel.minHeight, panel.parent.height - panel.y);
        }
        onReleased: panel.commit()
    }

    Grip {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: header.height
        anchors.bottomMargin: 18
        width: 8
        horizontal: true
    }
    Grip {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18
        height: 8
        vertical: true
    }
    Grip {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 18
        height: 18
        horizontal: true
        vertical: true
    }
}
