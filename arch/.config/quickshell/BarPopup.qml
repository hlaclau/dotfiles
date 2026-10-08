import QtQuick
import Quickshell

// Card that drops down under a bar item while the pointer rests on it (or on
// the card itself). Set `owner` to the item and `ownerHovered` to its hover state.
PopupWindow {
    id: popup

    required property Item owner
    property bool ownerHovered: false
    property int padding: 14
    default property alias content: body.data

    readonly property bool wanted: ownerHovered || cardHover.hovered
    property bool shown: false

    onWantedChanged: {
        if (wanted) {
            closeTimer.stop();
            openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }

    Timer {
        id: openTimer
        interval: 350
        onTriggered: popup.shown = true
    }
    Timer {
        id: closeTimer
        interval: 200
        onTriggered: popup.shown = false
    }

    anchor.item: owner
    anchor.rect.width: owner.width
    anchor.rect.height: owner.height + 10
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: body.implicitWidth + 2 * padding
    implicitHeight: body.implicitHeight + 2 * padding + 8
    visible: shown || card.opacity > 0
    color: "transparent"

    Rectangle {
        id: card

        width: parent.width
        height: parent.height - 8
        y: popup.shown ? 0 : -8
        opacity: popup.shown ? 1 : 0
        radius: 14
        color: Theme.crust
        border.width: 1
        border.color: Theme.surface0

        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        HoverHandler {
            id: cardHover
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: popup.padding
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
