pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio visualizer: cava bar levels (0-1) while music is playing. `spectrum` is the full
// resolution (music panel), `bars` the same folded into `count` groups (island).
Singleton {
    id: root

    readonly property int count: 6
    readonly property int spectrumCount: 32
    property var bars: []
    property var spectrum: []

    readonly property bool active: Status.player?.isPlaying ?? false
    onActiveChanged: if (!active) { bars = []; spectrum = []; }

    Process {
        running: root.active
        command: ["sh", "-c", `
            cfg="\${XDG_RUNTIME_DIR:-/tmp}/island-cava.conf"
            cat > "$cfg" <<EOF
[general]
bars = ${root.spectrumCount}
framerate = 30
[input]
method = pipewire
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
EOF
            exec cava -p "$cfg"
        `]
        stdout: SplitParser {
            onRead: line => {
                const levels = line.split(";").filter(v => v !== "").map(v => Number(v) / 100);
                root.spectrum = levels;
                const n = levels.length;
                root.bars = Array.from({ length: root.count }, (_, i) =>
                    Math.max(0, ...levels.slice(Math.floor(i * n / root.count), Math.floor((i + 1) * n / root.count))));
            }
        }
    }
}
