import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

// Volume mixer with a row per app playing sound: icon, name, what it's playing,
// a slider with a live level meter under it, and mute. An app with several
// streams (a browser with two tabs playing) gets one row that drives them all.
// Used by the island (Home and Audio tabs) and the bar's volume card.
ColumnLayout {
    id: mixer

    // Hide the "Nothing is playing" line when there are no apps
    property bool hideWhenEmpty: false

    visible: !hideWhenEmpty || Status.apps.length > 0
    spacing: 10

    // Stream titles that say nothing about what's playing
    readonly property var genericTitles: ["playback", "audio stream", "audiostream", "output", "sound", "simple dsp", "audio"]

    // Streams grouped by app, in order of appearance: [{ key, nodes }]
    readonly property var groups: {
        const out = [];
        for (const node of Status.apps) {
            const key = node.properties["application.name"] || node.properties["application.process.binary"] || node.name;
            const group = out.find(g => g.key === key);
            if (group) group.nodes.push(node);
            else out.push({ key, nodes: [node] });
        }
        return out;
    }

    Text {
        Layout.fillWidth: true
        visible: Status.apps.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing is playing"
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    Repeater {
        model: mixer.groups

        RowLayout {
            id: app

            required property var modelData
            readonly property var nodes: modelData.nodes
            readonly property var props: nodes[0].properties
            // The first stream stands for the group; changes go to all of them
            readonly property var audio: nodes[0].audio
            readonly property bool muted: audio?.muted ?? false
            // Desktop entry from the binary or app name, for a real icon and name
            // (a binary replaced by an update shows up as "chrome (deleted)")
            readonly property string binary: (props["application.process.binary"] ?? "").replace(/ \(deleted\)$/, "")
            readonly property var entry: (binary ? DesktopEntries.heuristicLookup(binary) : null)
                ?? DesktopEntries.heuristicLookup(props["application.name"] || "")
            readonly property string icon: props["application.icon-name"] || entry?.icon || ""
            readonly property string name: entry?.name || Status.nodeName(nodes[0])
            readonly property string title: {
                const titles = nodes.map(n => (n.properties["media.name"] ?? "").trim())
                    .filter(t => t && t !== name && !mixer.genericTitles.includes(t.toLowerCase()));
                return [...new Set(titles)].join(" · ");
            }
            readonly property real peak: {
                let max = 0;
                for (let i = 0; i < monitors.count; i++) max = Math.max(max, monitors.objectAt(i)?.peak ?? 0);
                return max;
            }

            function setVolume(v) {
                for (const n of nodes) if (n.audio) n.audio.volume = v;
            }
            function toggleMute() {
                const mute = !muted;
                for (const n of nodes) if (n.audio) n.audio.muted = mute;
            }

            Layout.fillWidth: true
            spacing: 12

            Instantiator {
                id: monitors
                model: app.nodes

                // Quickshell's monitor captures in stereo and can't read mono streams
                PwNodePeakMonitor {
                    required property var modelData
                    node: modelData
                    enabled: mixer.visible && !app.muted && (modelData.audio?.channels.length ?? 0) >= 2
                }
            }

            // Icon, with the music note when the app has none
            Item {
                implicitWidth: 28
                implicitHeight: 28
                opacity: app.muted ? 0.4 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }

                IconImage {
                    id: appIcon
                    anchors.fill: parent
                    source: app.icon ? Quickshell.iconPath(app.icon, true) : ""
                    visible: status === Image.Ready
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: Icons.music
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: app.name
                        color: app.muted ? Theme.overlay1 : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        visible: app.nodes.length > 1
                        text: "×" + app.nodes.length
                        color: Theme.overlay0
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: app.title !== ""
                        text: app.title
                        color: Theme.overlay1
                        font.family: Theme.font
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                LevelSlider {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    value: app.audio?.volume ?? 0
                    dimmed: app.muted
                    onMoved: v => app.setVolume(v)
                }

                // Live level: how loud the app is right now, after its volume
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 3
                    radius: 1.5
                    color: Theme.surface0

                    Rectangle {
                        width: parent.width * Math.min(1, app.peak)
                        height: parent.height
                        radius: 1.5
                        color: app.peak > 0.95 ? Theme.red : Theme.green
                        opacity: 0.8
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: app.muted ? "off" : Math.round((app.audio?.volume ?? 0) * 100) + "%"
                color: app.muted ? Theme.overlay0 : Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 12
            }
            IconButton {
                size: 28
                icon: app.muted ? Icons.volumeMute : Icons.volumeHigh
                iconColor: app.muted ? Theme.red : Theme.text
                onClicked: app.toggleMute()
            }
        }
    }
}
