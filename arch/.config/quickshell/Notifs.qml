pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon (replaces dunst). Every notification is kept in the
// island's history until dismissed; the newest one also pops up in the island
// unless Do Not Disturb is on or its app is muted (critical ones always pop up).
Singleton {
    id: root

    property bool dnd: false

    // Notification currently shown as a popup, or null
    property var popup: null

    readonly property var list: [...server.trackedNotifications.values].reverse()
    readonly property int count: server.trackedNotifications.values.length

    readonly property var mutedApps: Settings.values.mutedApps

    function isMuted(app) {
        return mutedApps.includes(app);
    }
    function toggleMute(app) {
        if (!app) return;
        Settings.values.mutedApps = isMuted(app) ? mutedApps.filter(a => a !== app) : [...mutedApps, app];
    }

    function clearAll() {
        for (const n of [...server.trackedNotifications.values]) n.dismiss();
        popup = null;
    }

    function hidePopup() {
        const n = popup;
        popup = null;
        // Transient notifications don't belong in the history
        if (n && n.transient) n.expire();
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            if ((root.dnd || root.isMuted(n.appName)) && n.urgency !== NotificationUrgency.Critical) {
                if (n.transient) n.expire();
                return;
            }
            root.popup = n;
            popupTimer.interval = n.urgency === NotificationUrgency.Critical ? 10000
                : (n.expireTimeout > 0 ? Math.min(n.expireTimeout, 10000) : 5000);
            popupTimer.restart();
        }
    }

    Timer {
        id: popupTimer
        onTriggered: root.hidePopup()
    }

    Connections {
        target: root.popup
        // The app closed it, or it was dismissed from the history
        function onClosed() {
            root.popup = null;
        }
    }
}
