pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio visualizer: cava bar levels (0-1) while music is playing
Singleton {
    id: root

    readonly property int count: 6
    property var bars: []

    readonly property bool active: Status.player?.isPlaying ?? false
    onActiveChanged: if (!active) bars = []

    Process {
        running: root.active
        command: ["sh", "-c", `
            cfg="\${XDG_RUNTIME_DIR:-/tmp}/island-cava.conf"
            cat > "$cfg" <<EOF
[general]
bars = ${root.count}
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
            onRead: line => root.bars = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        }
    }
}
