import QtQuick
import QtQuick.Layouts

// CPU, memory, GPU and disk: a ring each, graphs of the recent past and the temperatures
ColumnLayout {
    id: tab

    spacing: 12

    function level(v) {
        return v > 0.9 ? Theme.red : (v > 0.7 ? Theme.peach : Theme.accent);
    }
    function percent(v) {
        return Math.round(v * 100) + "%";
    }
    readonly property var rings: [
        { icon: Icons.cpu, name: "CPU", value: SysInfo.cpu, show: true },
        { icon: Icons.memory, name: "RAM", value: SysInfo.mem, show: true },
        { icon: Icons.gpu, name: "GPU", value: SysInfo.gpu, show: SysInfo.hasGpu },
        { icon: Icons.disk, name: "Disk", value: SysInfo.disk, show: true }
    ]
    readonly property var graphs: [
        { name: "CPU", value: SysInfo.cpu, history: SysInfo.cpuHistory, show: true,
          detail: Math.round(SysInfo.cpuTemp) + "°C" },
        { name: "Memory", value: SysInfo.mem, history: SysInfo.memHistory, show: true,
          detail: SysInfo.memUsed.toFixed(1) + " / " + SysInfo.memTotal.toFixed(0) + " GiB" },
        { name: "GPU", value: SysInfo.gpu, history: SysInfo.gpuHistory, show: SysInfo.hasGpu,
          detail: Math.round(SysInfo.gpuTemp) + "°C · " + SysInfo.vramUsed.toFixed(1) + " / " + SysInfo.vramTotal.toFixed(0) + " GiB" }
    ]

    // ---- Rings ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: tab.rings

            ColumnLayout {
                id: gauge

                required property var modelData

                visible: modelData.show
                Layout.fillWidth: true
                spacing: 6

                Ring {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 64
                    implicitHeight: 64
                    thickness: 5
                    icon: gauge.modelData.icon
                    value: gauge.modelData.value
                    color: tab.level(gauge.modelData.value)
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: tab.percent(gauge.modelData.value)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -4
                    text: gauge.modelData.name
                    color: Theme.subtext0
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }
        }
    }

    // ---- Graphs ----
    Repeater {
        model: tab.graphs

        ColumnLayout {
            id: graph

            required property var modelData

            visible: modelData.show
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: graph.modelData.name
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: graph.modelData.detail
                    color: Theme.subtext0
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                Text {
                    text: tab.percent(graph.modelData.value)
                    color: tab.level(graph.modelData.value)
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 10
                color: Theme.surface0
                clip: true

                Sparkline {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    values: graph.modelData.history
                    capacity: SysInfo.historyLength
                    color: tab.level(graph.modelData.value)
                    lineWidth: 1.6
                }
            }
        }
    }

    // ---- Disk and uptime ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Disk /home"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: SysInfo.diskUsed.toFixed(0) + " / " + SysInfo.diskTotal.toFixed(0) + " GB"
                color: Theme.subtext0
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.surface0

            Rectangle {
                width: parent.width * SysInfo.disk
                height: parent.height
                radius: 3
                color: tab.level(SysInfo.disk)
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: {
            const h = Math.floor(SysInfo.uptime / 3600), m = Math.floor(SysInfo.uptime % 3600 / 60);
            return "up " + (h > 0 ? h + "h " : "") + m + "m";
        }
        color: Theme.overlay1
        font.family: Theme.font
        font.pixelSize: 11
    }
}
