import QtQuick
import Quickshell

// Input region for one panel of the overlay that stays on screen, clickable, once the overlay
// closes: not while the backdrop covers everything, and not for click-through panels
Region {
    id: region

    required property var panels
    required property int slot

    readonly property Item panel: panels.itemAt(slot)

    item: !OverlayState.shown && panel && panel.visible && !panel.clickthrough ? panel : null
}
