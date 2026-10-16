pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The palette of the current theme (scripts/theme.sh writes ~/.config/theme/palette.json and the
// shell follows changes live). The defaults are Catppuccin Mocha: https://catppuccin.com/palette
Singleton {
    id: root

    FileView {
        path: Quickshell.env("HOME") + "/.config/theme/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        adapter: pal
    }

    JsonAdapter {
        id: pal
        property string rosewater: "#f5e0dc"
        property string flamingo: "#f2cdcd"
        property string pink: "#f5c2e7"
        property string mauve: "#cba6f7"
        property string red: "#f38ba8"
        property string maroon: "#eba0ac"
        property string peach: "#fab387"
        property string yellow: "#f9e2af"
        property string green: "#a6e3a1"
        property string teal: "#94e2d5"
        property string sky: "#89dceb"
        property string sapphire: "#74c7ec"
        property string blue: "#89b4fa"
        property string lavender: "#b4befe"
        property string text: "#cdd6f4"
        property string subtext1: "#bac2de"
        property string subtext0: "#a6adc8"
        property string overlay2: "#9399b2"
        property string overlay1: "#7f849c"
        property string overlay0: "#6c7086"
        property string surface2: "#585b70"
        property string surface1: "#45475a"
        property string surface0: "#313244"
        property string base: "#1e1e2e"
        property string mantle: "#181825"
        property string crust: "#11111b"
        property string accent: "#cba6f7"
    }

    readonly property color rosewater: pal.rosewater
    readonly property color flamingo: pal.flamingo
    readonly property color pink: pal.pink
    readonly property color mauve: pal.mauve
    readonly property color red: pal.red
    readonly property color maroon: pal.maroon
    readonly property color peach: pal.peach
    readonly property color yellow: pal.yellow
    readonly property color green: pal.green
    readonly property color teal: pal.teal
    readonly property color sky: pal.sky
    readonly property color sapphire: pal.sapphire
    readonly property color blue: pal.blue
    readonly property color lavender: pal.lavender
    readonly property color text: pal.text
    readonly property color subtext1: pal.subtext1
    readonly property color subtext0: pal.subtext0
    readonly property color overlay2: pal.overlay2
    readonly property color overlay1: pal.overlay1
    readonly property color overlay0: pal.overlay0
    readonly property color surface2: pal.surface2
    readonly property color surface1: pal.surface1
    readonly property color surface0: pal.surface0
    readonly property color base: pal.base
    readonly property color mantle: pal.mantle
    readonly property color crust: pal.crust

    readonly property color accent: pal.accent

    readonly property string font: "SFMono Nerd Font Mono"
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    // Height of the bar and of the collapsed island, so the notch lines up with it
    readonly property int barHeight: 44
}
