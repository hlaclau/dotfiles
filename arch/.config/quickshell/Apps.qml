pragma Singleton

import QtQuick
import Quickshell

// Installed apps for the launcher, ranked by search match then by how often
// they've been launched
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(app => !app.noDisplay)

    function launches(app) {
        return Settings.values.launches[app.id] ?? 0;
    }

    // 0 = no match. Name matches beat other fields, and earlier/denser matches beat later ones.
    function score(app, query) {
        const name = app.name.toLowerCase();
        if (name === query) return 100;
        if (name.startsWith(query)) return 90;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(query))) return 80;
        if (name.includes(query)) return 70;

        const other = [app.genericName, app.keywords, app.categories, app.comment].join(" ").toLowerCase();
        if (other.includes(query)) return 50;

        // Letters in order, e.g. "vsc" -> "Visual Studio Code"
        let i = 0;
        for (const c of name) {
            if (c === query[i]) i++;
            if (i === query.length) return 30;
        }
        return 0;
    }

    // Qt's Array.sort isn't stable, so every comparison ends on the name
    function byUse(a, b) {
        return (launches(b) - launches(a)) || a.name.localeCompare(b.name);
    }

    function search(text) {
        const query = text.trim().toLowerCase();
        if (!query) return [...all].sort(byUse);
        return all
            .map(app => ({ app, score: score(app, query) }))
            .filter(r => r.score > 0)
            .sort((a, b) => (b.score - a.score) || byUse(a.app, b.app))
            .map(r => r.app);
    }

    function launch(app) {
        const counts = Object.assign({}, Settings.values.launches);
        counts[app.id] = (counts[app.id] ?? 0) + 1;
        Settings.values.launches = counts;

        // `uwsm app` gives each app its own systemd scope, so it outlives the
        // quickshell service (restarting or crashing it would kill its children)
        if (app.runInTerminal) {
            // Drop desktop-entry field codes like %U
            const cmd = app.execString.replace(/%[a-zA-Z]/g, "").trim();
            Quickshell.execDetached(["sh", "-c", `uwsm app -- \${TERMINAL:-ghostty} -e ${cmd}`]);
        } else {
            Quickshell.execDetached(["uwsm", "app", "--", app.id + ".desktop"]);
        }
    }
}
