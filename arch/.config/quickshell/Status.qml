pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Shared state: audio, media and the quick toggles
Singleton {
    id: root

    // ---- Audio ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    function setVolume(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Volume OSD: true for a moment after the volume or mute state changes
    property bool osd: false

    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osd = false
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.showOsd(); }
        function onMutedChanged() { root.showOsd(); }
    }

    function showOsd() {
        // Ignore the burst of changes while PipeWire binds the node at startup
        if (!osdArmed.armed) return;
        osd = true;
        osdTimer.restart();
    }

    Timer {
        id: osdArmed
        property bool armed: false
        interval: 2000
        running: true
        onTriggered: armed = true
    }

    // ---- Media ----
    // Prefer a playing player, else the first one
    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }

    // ---- Toggles ----
    // Caffeine: block idle (hypridle honours systemd inhibitor locks)
    property bool caffeine: false

    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=island", "--why=Caffeine", "sleep", "infinity"]
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
}
