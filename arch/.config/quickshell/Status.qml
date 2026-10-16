pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Shared state: audio, media, recorder, privacy, night light and the quick toggles
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
    // (the noise filter's own capture stream isn't an app recording)
    readonly property var recorders: nodes.filter(n => n.isStream && !n.isSink && n.name !== "rnnoise_capture")

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
    // Ignore streams that record speaker output rather than a mic: level meters
    // (pavucontrol) and the visualizer (cava)
    readonly property bool micInUse: recorders.some(n =>
        n.properties["stream.monitor"] !== "true" && n.properties["stream.capture.sink"] !== "true")
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
    // hypr/record.sh selects a region and records it with desktop audio to ~/Videos/Recordings; it
    // runs from Hyprland (not from here) so slurp gets the pointer, and leaves its start time in
    // $XDG_RUNTIME_DIR/recording-start while it records
    readonly property bool recording: recordStart > 0
    property real recordStart: 0
    property int recordSeconds: 0
    readonly property string recordTime: {
        const m = Math.floor(recordSeconds / 60), s = recordSeconds % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function toggleRecording() {
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("$HOME/.config/hypr/record.sh")']);
    }

    Process {
        id: recordPoll
        command: ["sh", "-c", "cat \"${XDG_RUNTIME_DIR:-/tmp}/recording-start\" 2>/dev/null || echo 0"]
        stdout: SplitParser {
            onRead: line => {
                const start = parseInt(line) * 1000;
                root.recordStart = start;
                root.recordSeconds = start > 0 ? Math.max(0, Math.round((Date.now() - start) / 1000)) : 0;
            }
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: recordPoll.running = true
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
    readonly property int nightTemperature: Settings.values.nightTemperature

    function applyNightLight() {
        run(nightLight ? "hyprctl hyprsunset temperature " + nightTemperature : "hyprctl hyprsunset identity");
    }
    onNightLightChanged: applyNightLight()
    onNightTemperatureChanged: if (nightLight) applyNightLight()

    // Schedule: switch on entering the window and off leaving it, so a manual
    // toggle holds until the next edge
    function minutes(hhmm) {
        const [h, m] = hhmm.split(":").map(Number);
        return h * 60 + m;
    }
    function inNightWindow() {
        const now = new Date();
        const m = now.getHours() * 60 + now.getMinutes();
        const start = minutes(Settings.values.nightStart), end = minutes(Settings.values.nightEnd);
        return start <= end ? (m >= start && m < end) : (m >= start || m < end);
    }
    property var lastInWindow: undefined

    function checkSchedule() {
        if (!Settings.values.nightSchedule) {
            lastInWindow = undefined;
            return;
        }
        const inWindow = inNightWindow();
        if (inWindow !== lastInWindow) {
            lastInWindow = inWindow;
            nightLight = inWindow;
        }
    }

    Connections {
        target: Settings.values
        function onNightScheduleChanged() { root.checkSchedule(); }
        function onNightStartChanged() { root.lastInWindow = undefined; root.checkSchedule(); }
        function onNightEndChanged() { root.lastInWindow = undefined; root.checkSchedule(); }
    }
    Timer {
        interval: 30 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.checkSchedule()
    }

    // Mic noise suppression: a separate PipeWire filter (RNNoise) reads the
    // hardware mic and exposes "Noise suppressed mic", made the default input
    readonly property bool noiseSuppression: Settings.values.noiseSuppression
    readonly property var noiseSource: Pipewire.nodes.values.find(n => n.name === "rnnoise_source") ?? null

    function toggleNoiseSuppression() {
        if (!noiseSuppression) {
            // Remember the hardware mic the filter should read from
            const mic = source?.name ?? "";
            if (mic && mic !== "rnnoise_source") Settings.values.noiseMic = mic;
        }
        Settings.values.noiseSuppression = !noiseSuppression;
    }

    // Filtered mic appears: make it the default. Turned off: back to the hardware mic.
    onNoiseSourceChanged: if (noiseSource && noiseSuppression) Pipewire.preferredDefaultAudioSource = noiseSource
    onNoiseSuppressionChanged: {
        if (noiseSuppression) return;
        const mic = Pipewire.nodes.values.find(n => n.name === Settings.values.noiseMic);
        if (mic) Pipewire.preferredDefaultAudioSource = mic;
    }

    // Restart the session manager so it re-scans devices (headsets that were plugged in late)
    function refreshAudio() {
        audioRefresh.running = true;
    }

    Process {
        id: audioRefresh
        command: ["systemctl", "--user", "restart", "wireplumber"]
    }

    Process {
        running: root.noiseSuppression && Settings.values.noiseMic !== ""
        command: ["sh", "-c", `
            conf="\${XDG_RUNTIME_DIR:-/tmp}/island-rnnoise.conf"
            cat > "$conf" <<CONF
context.properties = { log.level = 0 }
context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}
context.modules = [
    { name = libpipewire-module-rt flags = [ ifexists nofail ] }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Noise suppressed mic"
            media.name       = "Noise suppressed mic"
            filter.graph = {
                nodes = [
                    {
                        type    = ladspa
                        name    = rnnoise
                        plugin  = "librnnoise_ladspa"
                        label   = noise_suppressor_mono
                        control = { "VAD Threshold (%)" 50.0 }
                    }
                ]
            }
            audio.position = [ MONO ]
            capture.props = {
                node.name           = "rnnoise_capture"
                node.passive        = true
                target.object       = "$1"
                node.dont-reconnect = true
            }
            playback.props = {
                node.name   = "rnnoise_source"
                media.class = Audio/Source
            }
        }
    }
]
CONF
            exec pipewire -c "$conf"
        `, "sh", Settings.values.noiseMic]
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
}
