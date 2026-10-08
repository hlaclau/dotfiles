pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Resource usage for the bar: CPU, memory, disk, temperatures and the NVIDIA
// GPU, with a short history for the sparklines
Singleton {
    id: root

    // Samples kept for the graphs (one every `interval` ms)
    readonly property int historyLength: 40
    readonly property int interval: 2000

    // ---- CPU ----
    property real cpu: 0
    property var cpuHistory: []
    property real cpuTemp: 0
    property var lastCpu: null

    // ---- Memory (GiB) ----
    property real memUsed: 0
    property real memTotal: 0
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
    property var memHistory: []

    // ---- Disk (/home, GB) ----
    property real diskUsed: 0
    property real diskTotal: 0
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0

    // ---- GPU (nvidia-smi; absent when there's no NVIDIA card) ----
    property bool hasGpu: false
    property real gpu: 0
    property real gpuTemp: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property var gpuHistory: []

    property real uptime: 0

    function push(history, value) {
        const h = history.concat([value]);
        return h.length > historyLength ? h.slice(h.length - historyLength) : h;
    }

    Timer {
        interval: root.interval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            uptimeFile.reload();
            if (tempFile.path) tempFile.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // cpu  user nice system idle iowait irq softirq steal
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.slice(0, 8).reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpu = dt > 0 ? 1 - (idle - root.lastCpu.idle) / dt : 0;
                root.cpuHistory = root.push(root.cpuHistory, root.cpu);
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))?.[1] ?? 0);
            const gib = 1024 * 1024;
            root.memTotal = kb("MemTotal") / gib;
            root.memUsed = (kb("MemTotal") - kb("MemAvailable")) / gib;
            root.memHistory = root.push(root.memHistory, root.mem);
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0])
    }

    // CPU package temperature from the coretemp / k10temp hwmon
    FileView {
        id: tempFile
        path: ""
        onLoaded: root.cpuTemp = Number(text().trim()) / 1000
    }

    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name")" in coretemp|k10temp|zenpower) echo "$h/temp1_input"; break ;; esac
            done`]
        stdout: StdioCollector {
            onStreamFinished: tempFile.path = this.text.trim()
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/home"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [used, size] = this.text.trim().split("\n")[1].trim().split(/\s+/).map(Number);
                root.diskUsed = used / 1e9;
                root.diskTotal = size / 1e9;
            }
        }
    }
    Timer {
        interval: 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    // One long-lived nvidia-smi printing a line every 2s
    Process {
        running: true
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null && exec nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits -l 2"]
        stdout: SplitParser {
            onRead: line => {
                const [util, temp, used, total] = line.split(",").map(s => Number(s.trim()));
                if (isNaN(util)) return;
                root.hasGpu = true;
                root.gpu = util / 100;
                root.gpuTemp = temp;
                root.vramUsed = used / 1024;
                root.vramTotal = total / 1024;
                root.gpuHistory = root.push(root.gpuHistory, root.gpu);
            }
        }
    }
}
