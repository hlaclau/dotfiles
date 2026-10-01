import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification. Clicking it runs the default action; the x dismisses it.
// `flat` drops the card background (used for the popup inside the island).
Rectangle {
    id: card

    required property var notification
    property bool flat: false

    readonly property var defaultAction: notification?.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notification?.actions.filter(a => a.identifier !== "default") ?? []
    readonly property string iconSource: {
        if (!notification) return "";
        if (notification.image) return notification.image;
        if (notification.appIcon) return Quickshell.iconPath(notification.appIcon, true);
        return "";
    }

    implicitHeight: layout.implicitHeight + (flat ? 0 : 24)
    radius: 14
    color: flat ? "transparent" : (mouse.containsMouse ? Theme.surface1 : Theme.surface0)
    border.width: !flat && notification?.urgency === NotificationUrgency.Critical ? 1 : 0
    border.color: Theme.red

    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (card.defaultAction) {
                card.defaultAction.invoke();
                if (!card.notification.resident) card.notification.dismiss();
            }
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: card.flat ? 0 : 12
        spacing: 12

        Item {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignTop

            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.surface1
                visible: card.iconSource !== ""

                IconImage {
                    anchors.fill: parent
                    source: card.iconSource
                }
            }

            Text {
                anchors.centerIn: parent
                visible: card.iconSource === ""
                text: Icons.bell
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 18
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: card.notification?.appName ?? ""
                visible: text !== ""
                color: Theme.overlay1
                font.family: Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: card.notification?.summary ?? ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: card.notification?.body ?? ""
                visible: text !== ""
                color: Theme.subtext0
                font.family: Theme.font
                font.pixelSize: 12
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.flat ? 2 : 4
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 6
                visible: card.buttons.length > 0

                Repeater {
                    model: card.buttons

                    Rectangle {
                        required property var modelData
                        implicitWidth: actionText.implicitWidth + 20
                        implicitHeight: 26
                        radius: 13
                        color: actionMouse.containsMouse ? Theme.surface2 : Theme.surface1

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }

        // Mute this app's popups; stays visible (peach) once muted
        Text {
            readonly property bool muted: Notifs.isMuted(card.notification?.appName ?? "")

            Layout.alignment: Qt.AlignTop
            visible: !card.flat && (card.notification?.appName ?? "") !== ""
                && (muted || mouse.containsMouse || muteMouse.containsMouse || closeMouse.containsMouse)
            text: Icons.bellSlash
            color: muted || muteMouse.containsMouse ? Theme.peach : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 12

            MouseArea {
                id: muteMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.toggleMute(card.notification.appName)
            }
        }

        Text {
            Layout.alignment: Qt.AlignTop
            text: Icons.close
            color: closeMouse.containsMouse ? Theme.red : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 13

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.notification.dismiss()
            }
        }
    }
}
