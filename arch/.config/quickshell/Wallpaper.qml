pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers: the local collection, applying one to some or all screens
// through hyprpaper, and searching / downloading from wallhaven.cc (SFW only,
// no API key). The choice per screen is saved and re-applied at startup, since
// hyprpaper.conf only holds the default.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // The dotfiles collection, plus downloads (kept out of the repo)
    readonly property string downloadDir: home + "/Pictures/Wallpapers"
    readonly property var dirs: [home + "/dotfiles/wallpapers", downloadDir]

    // Absolute paths of every local wallpaper, sorted by name
    property var local: []
    // Monitor name -> path currently shown
    property var active: ({})

    function name(path) {
        return path.split("/").pop().replace(/\.[^.]+$/, "");
    }

    function refresh() {
        lister.running = true;
        activeReader.running = true;
    }

    // `monitors`: names to apply to; empty for every screen
    function apply(path, monitors) {
        const targets = monitors?.length ? monitors : Quickshell.screens.map(s => s.name);
        const saved = Object.assign({}, Settings.values.wallpapers);
        const shown = Object.assign({}, active);
        for (const m of targets) {
            Quickshell.execDetached(["hyprctl", "hyprpaper", "wallpaper", `${m},${path},cover`]);
            saved[m] = path;
            shown[m] = path;
        }
        Settings.values.wallpapers = saved;
        active = shown;
    }

    function random(monitors) {
        const current = Object.values(active);
        const pool = local.filter(p => !current.includes(p));
        const list = pool.length ? pool : local;
        if (list.length) apply(list[Math.floor(Math.random() * list.length)], monitors);
    }

    // Put back the saved choice once hyprpaper is up (it starts with Hyprland)
    function restore() {
        restoreTimer.restart();
    }
    Timer {
        id: restoreTimer
        interval: 1500
        onTriggered: {
            const saved = Settings.values.wallpapers;
            for (const m of Object.keys(saved)) {
                if (root.active[m] !== saved[m]) Quickshell.execDetached(["hyprctl", "hyprpaper", "wallpaper", `${m},${saved[m]},cover`]);
            }
            root.refresh();
        }
    }

    Process {
        id: lister
        command: ["sh", "-c", `find "$@" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null`, "sh", ...root.dirs]
        stdout: StdioCollector {
            onStreamFinished: root.local = this.text.split("\n").filter(p => p)
                .sort((a, b) => root.name(a).localeCompare(root.name(b)))
        }
    }

    // "DP-1: /path/to/file"
    Process {
        id: activeReader
        command: ["hyprctl", "hyprpaper", "listactive"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of this.text.split("\n")) {
                    const i = line.indexOf(": ");
                    if (i > 0) map[line.slice(0, i)] = line.slice(i + 2);
                }
                root.active = map;
            }
        }
    }

    // ---- Online: wallhaven.cc ----

    // [{ id, thumb, url, resolution, size, fileType }]
    property var results: []
    property bool searching: false
    property string error: ""
    property string query: ""
    // Only images wide enough for the ultrawide (21:9)
    property bool ultrawide: false
    property int page: 1
    property int lastPage: 1

    function search(text, more) {
        if (searching) return;
        if (!more) {
            query = text.trim();
            page = 1;
        } else if (page >= lastPage) {
            return;
        } else {
            page++;
        }
        const params = [
            "categories=110", "purity=100", `page=${page}`,
            ultrawide ? "ratios=21x9" : "atleast=1920x1080"
        ];
        // No query: this month's most popular
        params.push(query ? "sorting=relevance&q=" + encodeURIComponent(query) : "sorting=toplist&topRange=1M");
        searcher.more = !!more;
        searcher.command = ["curl", "-sf", "-m", "15", "https://wallhaven.cc/api/v1/search?" + params.join("&")];
        searching = true;
        error = "";
        searcher.running = true;
    }

    onUltrawideChanged: search(query, false)

    Process {
        id: searcher
        property bool more: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const items = j.data.map(d => ({
                        id: d.id,
                        thumb: d.thumbs.large,
                        url: d.path,
                        resolution: d.resolution,
                        size: d.file_size,
                        fileType: d.file_type
                    }));
                    root.results = searcher.more ? [...root.results, ...items] : items;
                    root.lastPage = j.meta.last_page;
                    root.fetchThumbs(items);
                } catch (e) {
                    if (!searcher.more) root.results = [];
                }
            }
        }
        onExited: code => {
            root.searching = false;
            if (code !== 0) root.error = "Couldn't reach wallhaven.cc";
        }
    }

    // Thumbnails are fetched with curl into a cache (Qt's own HTTPS can't be
    // relied on here) and shown once they're on disk: id -> true
    readonly property string thumbDir: Quickshell.cachePath("wallhaven")
    property var thumbsReady: ({})

    function thumbPath(item) {
        return `${thumbDir}/${item.id}.jpg`;
    }

    function fetchThumbs(items) {
        const args = items.reduce((a, i) => a.concat([i.id, i.thumb]), []);
        thumbFetcher.queue = thumbFetcher.queue.concat(args);
        if (!thumbFetcher.running) thumbFetcher.next();
    }

    Process {
        id: thumbFetcher

        property var queue: []

        // Fetch everything queued so far in parallel, printing each id when done
        function next() {
            if (!queue.length) return;
            command = ["sh", "-c", `
                dir="$1"; shift
                mkdir -p "$dir"
                while [ $# -ge 2 ]; do
                    id="$1" url="$2"; shift 2
                    { [ -s "$dir/$id.jpg" ] || curl -sf -m 20 -o "$dir/$id.jpg" "$url"; } && echo "$id" &
                done
                wait`, "sh", root.thumbDir, ...queue];
            queue = [];
            running = true;
        }

        stdout: SplitParser {
            onRead: id => {
                const ready = Object.assign({}, root.thumbsReady);
                ready[id] = true;
                root.thumbsReady = ready;
            }
        }
        onExited: next()
    }

    // Download one result (skipped if already there), then apply it
    property string downloading: ""
    property var downloadTargets: []

    function localPath(item) {
        return `${downloadDir}/wallhaven-${item.id}.${item.url.split(".").pop()}`;
    }

    function download(item, monitors) {
        if (downloading) return;
        downloading = item.id;
        downloadTargets = monitors ?? [];
        downloader.target = localPath(item);
        downloader.command = ["sh", "-c", `
            [ -f "$2" ] && exit 0
            mkdir -p "$(dirname "$2")"
            curl -fsSL -m 120 -o "$2.part" "$1" && mv "$2.part" "$2"`, "sh", item.url, downloader.target];
        downloader.running = true;
    }

    Process {
        id: downloader
        property string target: ""
        onExited: code => {
            if (code === 0) {
                root.apply(target, root.downloadTargets);
                lister.running = true;
            } else {
                root.error = "Download failed";
            }
            root.downloading = "";
        }
    }
}
