pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji list for the launcher's `:` mode, read from the unicode-emoji
// package the first time it's searched
Singleton {
    id: root

    // Set by the launcher when emoji mode is first used, so startup skips the file
    property bool wanted: false
    property bool missing: false
    // [{ char, name, group }]
    property var all: []

    function search(text) {
        const query = text.trim().toLowerCase();
        if (!query) return all.slice(0, 60);
        const score = e => {
            const name = e.name.toLowerCase();
            if (name === query) return 4;
            if (name.startsWith(query)) return 3;
            if (name.split(" ").some(w => w.startsWith(query))) return 2;
            if (name.includes(query) || e.group.toLowerCase().includes(query)) return 1;
            return 0;
        };
        return all
            .map((e, i) => ({ e, i, score: score(e) }))
            .filter(r => r.score > 0)
            .sort((a, b) => (b.score - a.score) || (a.i - b.i))
            .slice(0, 60)
            .map(r => r.e);
    }

    FileView {
        path: root.wanted ? "/usr/share/unicode/emoji/emoji-test.txt" : ""
        printErrors: false
        onLoadFailed: root.missing = true
        onLoaded: {
            // Lines look like:
            //   # group: Smileys & Emotion
            //   1F600 ; fully-qualified # 😀 E1.0 grinning face
            const list = [];
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("# group: ")) {
                    group = line.slice(9).trim();
                    continue;
                }
                const m = line.match(/;\s*fully-qualified\s*#\s*(\S+)\s+E[\d.]+\s+(.+)$/);
                if (m && group !== "Component") list.push({ char: m[1], name: m[2], group });
            }
            root.all = list;
            root.missing = false;
        }
    }
}
