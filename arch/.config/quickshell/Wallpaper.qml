pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers: the local collection, applying one to some or all screens
// through hyprpaper, and searching / downloading from wallhaven.cc (SFW only,
// no API key). The choice per screen is saved and kept applied: hyprpaper.conf
// only holds the default, so whenever hyprpaper (re)starts showing something
// else, the saved wallpaper is put back.
//
// The picker's grids read `localModel` and `onlineModel`. Both are updated in
// place (rows appended, thumbnails filled in as they arrive) so the grid never
// rebuilds or jumps while scrolling. Thumbnails are small cached JPEGs: made
// with vipsthumbnail for local files, downloaded with curl for wallhaven.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // The dotfiles collection, plus downloads (kept out of the repo)
    readonly property string downloadDir: home + "/Pictures/Wallpapers"
    readonly property var dirs: [home + "/dotfiles/wallpapers", downloadDir]
    readonly property string thumbDir: Quickshell.cachePath("wallpaper-thumbs")

    // Absolute paths of every local wallpaper, sorted by name
    property var local: []
    // Monitor name -> path currently shown
    property var active: ({})

    // Grid rows, the same roles for both:
    //   key, title, subtitle, thumb (file path, "" until ready),
    //   path (local file) or wid + url (wallhaven)
    ListModel { id: localRows }
    ListModel { id: onlineRows }
    readonly property alias localModel: localRows
    readonly property alias onlineModel: onlineRows

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

    // Check what hyprpaper shows now and then, and put the saved choice back
    // when it differs: hyprpaper may start after quickshell, or restart
    function restore() {
        activeReader.running = true;
    }
    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.restore()
    }

    function enforceSaved() {
        const saved = Settings.values.wallpapers;
        for (const m of Object.keys(saved)) {
            // Only screens hyprpaper reports, i.e. it's running and the screen exists
            if (active[m] && active[m] !== saved[m]) {
                Quickshell.execDetached(["sh", "-c", '[ -f "$2" ] && hyprctl hyprpaper wallpaper "$1,$2,cover"', "sh", m, saved[m]]);
            }
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
                // Only on change: everything showing "current" rebinds on it
                if (JSON.stringify(map) !== JSON.stringify(root.active)) root.active = map;
                root.enforceSaved();
            }
        }
    }

    // ---- Local ----

    property string localFilter: ""
    // Path -> thumbnail file, once made
    property var localThumbs: ({})

    function filterLocal(text) {
        localFilter = text.trim().toLowerCase();
        localRows.clear();
        for (const p of local) {
            if (localFilter && !name(p).toLowerCase().includes(localFilter)) continue;
            localRows.append({
                key: p, title: name(p),
                subtitle: p.startsWith(downloadDir) ? "downloaded" : "",
                thumb: localThumbs[p] ?? "", path: p, wid: "", url: ""
            });
        }
    }

    Process {
        id: lister
        command: ["sh", "-c", `find "$@" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null`, "sh", ...root.dirs]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = this.text.split("\n").filter(p => p)
                    .sort((a, b) => root.name(a).localeCompare(root.name(b)));
                if (JSON.stringify(list) === JSON.stringify(root.local)) return;
                root.local = list;
                root.filterLocal(root.localFilter);
                localThumbnailer.make(list.filter(p => !root.localThumbs[p]));
            }
        }
    }

    // Small JPEG per wallpaper (named by a hash of its path, redone when the
    // file is newer), all in parallel; prints "path<TAB>thumb" as each is ready
    Process {
        id: localThumbnailer

        property var pending: []

        function make(paths) {
            pending = pending.concat(paths);
            if (!running) next();
        }
        function next() {
            if (!pending.length) return;
            command = ["sh", "-c", `
                dir="$1"; shift
                mkdir -p "$dir"
                for f in "$@"; do
                    {
                        t="$dir/$(printf %s "$f" | md5sum | cut -c1-32).jpg"
                        [ "$t" -nt "$f" ] || vipsthumbnail "$f" -s 480x -o "$t[Q=82]" 2>/dev/null
                        if [ -s "$t" ]; then printf '%s\\t%s\\n' "$f" "$t"; else printf '%s\\t%s\\n' "$f" "$f"; fi
                    } &
                done
                wait`, "sh", root.thumbDir, ...pending];
            pending = [];
            running = true;
        }

        stdout: SplitParser {
            onRead: line => {
                const [path, thumb] = line.split("\t");
                root.localThumbs[path] = thumb;
                for (let i = 0; i < localRows.count; i++) {
                    if (localRows.get(i).path === path) {
                        localRows.setProperty(i, "thumb", thumb);
                        break;
                    }
                }
            }
        }
        onExited: next()
    }

    // Move a local wallpaper to the trash (recoverable), and its thumbnail out
    // of the cache. A screen still showing it keeps it until changed.
    function trash(path) {
        trasher.target = path;
        trasher.command = ["sh", "-c", 'gio trash -- "$1" && rm -f -- "$2"', "sh", path, localThumbs[path] ?? ""];
        trasher.running = true;
    }

    Process {
        id: trasher
        property string target: ""
        onExited: code => {
            if (code !== 0) return;
            const path = target;
            root.local = root.local.filter(p => p !== path);
            delete root.localThumbs[path];
            for (let i = 0; i < localRows.count; i++) {
                if (localRows.get(i).path === path) {
                    localRows.remove(i);
                    break;
                }
            }
        }
    }

    // ---- Online: wallhaven.cc ----

    property bool searching: false
    property string error: ""
    property string query: ""
    // Only images wide enough for the ultrawide (21:9)
    property bool ultrawide: false
    property int page: 1
    property int lastPage: 1
    readonly property bool hasMore: page < lastPage
    // Wallhaven id -> row, to fill in thumbnails
    property var onlineIndex: ({})

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
                let j;
                try {
                    j = JSON.parse(this.text);
                } catch (e) {
                    return;
                }
                if (!searcher.more) {
                    onlineRows.clear();
                    root.onlineIndex = {};
                }
                const fetch = [];
                for (const d of j.data) {
                    // Pages can overlap when the ranking shifts between requests
                    if (root.onlineIndex[d.id] !== undefined) continue;
                    root.onlineIndex[d.id] = onlineRows.count;
                    onlineRows.append({
                        key: d.id, title: d.resolution,
                        subtitle: (d.file_size / 1e6).toFixed(1) + " MB",
                        thumb: "", path: "", wid: d.id, url: d.path
                    });
                    fetch.push(d.id, d.thumbs.large);
                }
                root.lastPage = j.meta.last_page;
                thumbFetcher.fetch(fetch);
            }
        }
        onExited: code => {
            root.searching = false;
            if (code !== 0) root.error = "Couldn't reach wallhaven.cc";
        }
    }

    // Wallhaven thumbnails are fetched with curl into the cache (Qt's own
    // HTTPS can't be relied on here) and shown once they're on disk
    Process {
        id: thumbFetcher

        // Flat [id, url, id, url, ...]
        property var pending: []

        function fetch(pairs) {
            pending = pending.concat(pairs);
            if (!running) next();
        }
        // Everything queued so far in parallel, printing each id when done
        function next() {
            if (!pending.length) return;
            command = ["sh", "-c", `
                dir="$1"; shift
                mkdir -p "$dir"
                while [ $# -ge 2 ]; do
                    id="$1" url="$2"; shift 2
                    { [ -s "$dir/wh-$id.jpg" ] || curl -sf -m 20 -o "$dir/wh-$id.jpg" "$url"; } && echo "$id" &
                done
                wait`, "sh", root.thumbDir, ...pending];
            pending = [];
            running = true;
        }

        stdout: SplitParser {
            onRead: id => {
                const i = root.onlineIndex[id];
                if (i !== undefined && i < onlineRows.count) onlineRows.setProperty(i, "thumb", `${root.thumbDir}/wh-${id}.jpg`);
            }
        }
        onExited: next()
    }

    // ---- Download one result (skipped if already there), then apply it ----

    property string downloading: ""
    property var downloadTargets: []

    function localPath(wid, url) {
        return `${downloadDir}/wallhaven-${wid}.${url.split(".").pop()}`;
    }

    function download(wid, url, monitors) {
        if (downloading) return;
        downloading = wid;
        downloadTargets = monitors ?? [];
        downloader.target = localPath(wid, url);
        downloader.command = ["sh", "-c", `
            [ -f "$2" ] && exit 0
            mkdir -p "$(dirname "$2")"
            curl -fsSL -m 120 -o "$2.part" "$1" && mv "$2.part" "$2"`, "sh", url, downloader.target];
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
