import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Now playing: cover, title, artist, controls and progress
Rectangle {
    id: card

    readonly property var player: Status.player

    implicitHeight: 96
    radius: 16
    color: Theme.surface0

    // MPRIS doesn't push position updates, so poll while visible and playing
    Timer {
        interval: 1000
        repeat: true
        running: card.visible && (card.player?.isPlaying ?? false)
        onTriggered: card.player.positionChanged()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        ClippingRectangle {
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
            radius: 12
            color: Theme.surface1

            Image {
                anchors.fill: parent
                source: card.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: Icons.music
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 24
                visible: !card.player?.trackArtUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: card.player?.trackTitle || card.player?.identity || ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: card.player?.trackArtist ?? ""
                color: Theme.subtext0
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Theme.surface1
                    visible: card.player?.lengthSupported ?? false

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        width: card.player && card.player.length > 0
                            ? parent.width * Math.min(1, card.player.position / card.player.length) : 0
                    }
                }

                Item { Layout.fillWidth: true; visible: !(card.player?.lengthSupported ?? false) }

                IconButton {
                    size: 28
                    icon: Icons.previous
                    visible: card.player?.canGoPrevious ?? false
                    onClicked: card.player.previous()
                }
                IconButton {
                    size: 32
                    icon: card.player?.isPlaying ? Icons.pause : Icons.play
                    iconColor: Theme.accent
                    onClicked: card.player.togglePlaying()
                }
                IconButton {
                    size: 28
                    icon: Icons.next
                    visible: card.player?.canGoNext ?? false
                    onClicked: card.player.next()
                }
            }
        }
    }
}
