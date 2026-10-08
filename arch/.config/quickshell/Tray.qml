import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray as Sni

// System tray icons. Left click activates (or opens the menu for menu-only
// items), right click opens the menu, middle click is the secondary action.
// Passive items stay hidden; ones asking for attention pulse.
RowLayout {
    id: tray

    required property var barWindow

    readonly property var items: Sni.SystemTray.items.values.filter(i => i.status !== Sni.Status.Passive)

    spacing: 0

    function openMenu(item, anchor) {
        const p = anchor.mapToItem(null, 0, anchor.height + 8);
        item.display(barWindow, p.x, p.y);
    }

    Repeater {
        model: tray.items

        BarItem {
            id: entry

            required property var modelData

            padding: 7

            onClicked: button => {
                if (button === Qt.RightButton || (button === Qt.LeftButton && modelData.onlyMenu)) {
                    if (modelData.hasMenu) tray.openMenu(modelData, entry);
                } else if (button === Qt.LeftButton) {
                    modelData.activate();
                } else {
                    modelData.secondaryActivate();
                }
            }
            onScrolled: steps => modelData.scroll(steps * 120, false)

            IconImage {
                id: icon
                implicitSize: 18
                source: entry.modelData.icon
                asynchronous: true

                SequentialAnimation on opacity {
                    running: entry.modelData.status === Sni.Status.NeedsAttention
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) icon.opacity = 1
                    NumberAnimation { to: 0.35; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }

            BarPopup {
                owner: entry
                ownerHovered: entry.hovered
                padding: 10

                Text {
                    text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }
}
