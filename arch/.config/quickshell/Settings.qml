pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Preferences that survive restarts, saved as JSON in quickshell's state dir.
// Change them through `Settings.values.<name> = ...`; they're written back automatically.
Singleton {
    readonly property alias values: adapter

    FileView {
        path: Quickshell.statePath("settings.json")
        // Load before anything reads the values, so startup sees the saved ones
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property int nightTemperature: 4500
            // Turn night light on/off automatically between these times (HH:MM)
            property bool nightSchedule: false
            property string nightStart: "20:00"
            property string nightEnd: "07:00"

            property bool noiseSuppression: false
            // Hardware mic the noise filter reads from
            property string noiseMic: ""

            // Launcher: how often each app was opened (desktop entry id -> count)
            property var launches: ({})

            // Apps whose notifications don't pop up (still kept in the history)
            property var mutedApps: []
        }
    }
}
