pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Shared state: audio, media, recorder, privacy and the quick toggles
Singleton {
    id: root

    // ---- Audio ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    // App streams: playing (output) and recording (input). Their properties
    // only fill in once tracked below.
    // (quickshell reports playback streams as sinks: they feed an output device)
    readonly property var apps: nodes.filter(n => n.isStream && n.isSink)
    readonly property var recorders: nodes.filter(n => n.isStream && !n.isSink)

    function setVolume(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }
    function nodeName(node) {
        return node?.properties["application.name"] || node?.nickname || node?.description || node?.name || "";
    }

    // Volume and mute only update for tracked nodes
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.outputs, ...root.inputs, ...root.apps, ...root.recorders]
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

    // ---- Privacy: mic / camera in use ----
    // Ignore level meters (pavucontrol, etc.), which record monitor streams
    readonly property bool micInUse: recorders.some(n => n.properties["stream.monitor"] !== "true")
    property bool camInUse: false

    Process {
        id: camCheck
        command: ["sh", "-c", "fuser /dev/video* 2>/dev/null | grep -q . && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.camInUse = this.text.trim() === "1"
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: camCheck.running = true
    }

    // ---- Screen recorder ----
    // Select a region, record it with desktop audio to ~/Videos/Recordings
    readonly property bool recording: recorder.running && recordStart > 0
    property real recordStart: 0
    property int recordSeconds: 0
    readonly property string recordTime: {
        const m = Math.floor(recordSeconds / 60), s = recordSeconds % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function toggleRecording() {
        if (recorder.running) recorder.signal(15); // SIGTERM: wf-recorder finalizes the file
        else recorder.running = true;
    }

    Process {
        id: recorder
        command: ["sh", "-c", `
            sleep 0.3 # let the island close before selecting
            region=$(slurp) || exit 1
            dir="$HOME/Videos/Recordings"
            mkdir -p "$dir"
            file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
            wf-recorder -g "$region" --audio="$(pactl get-default-sink).monitor" -f "$file" >/dev/null 2>&1 &
            pid=$!
            trap 'kill -TERM $pid' INT TERM
            echo started
            wait $pid; wait $pid 2>/dev/null
            notify-send -a Recorder -i video-x-generic "Recording saved" "$file"
        `]
        stdout: SplitParser {
            onRead: line => {
                if (line === "started") {
                    root.recordStart = Date.now();
                    root.recordSeconds = 0;
                }
            }
        }
        onExited: root.recordStart = 0
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.recordSeconds = Math.round((Date.now() - root.recordStart) / 1000)
    }

    // ---- Toggles ----
    // Caffeine: block idle (hypridle honours systemd inhibitor locks)
    property bool caffeine: false

    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=island", "--why=Caffeine", "sleep", "infinity"]
    }

    // Night light through the hyprsunset daemon (started by hyprland.lua)
    property bool nightLight: false
    property int nightTemperature: 4500

    function applyNightLight() {
        run(nightLight ? "hyprctl hyprsunset temperature " + nightTemperature : "hyprctl hyprsunset identity");
    }
    onNightLightChanged: applyNightLight()
    onNightTemperatureChanged: if (nightLight) applyNightLight()

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
}
