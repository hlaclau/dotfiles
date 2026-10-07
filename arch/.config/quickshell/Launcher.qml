import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Full-screen app grid with search, on the focused screen. Type to filter,
// arrows to move, Enter to launch, Escape to clear the search or close.
// Typing a math expression (12*4.5, (3+4)^2) shows the result; Enter copies it.
//
// A prefix switches to a list of other results:
//   =  qalc (units, conversions, currency)   Enter copies
//   >  shell command                          Enter runs it, Shift+Enter in a terminal
//   ?  web search                             Enter opens the browser
//   !  ask the AI panel                       Enter sends the question
//   :  emoji                                  Enter copies
//   /  files under ~                          Enter opens, Shift+Enter opens the folder
//   @  open windows                           Enter focuses
PanelWindow {
    id: launcher

    required property var modelData
    required property bool open
    signal closeRequested

    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    readonly property bool shown: open && focusedScreen

    readonly property string searchUrl: "https://duckduckgo.com/?q=%s"
    readonly property string home: Quickshell.env("HOME")

    // Prefix character of the current mode, "" for apps
    readonly property string mode: {
        const c = search.text.charAt(0);
        return c && "=>?!:/@".includes(c) ? c : "";
    }
    readonly property string query: mode ? search.text.slice(1).trim() : search.text
    readonly property var modeNames: ({ "=": "calc", ">": "run", "?": "web", "!": "ask", ":": "emoji", "/": "files", "@": "windows" })

    readonly property var results: mode ? [] : Apps.search(search.text)

    // Result of the search text if it's arithmetic, else ""
    readonly property string calcResult: {
        if (mode) return "";
        const t = search.text.trim();
        // Only digits and operators reach the evaluator
        if (!/^[\d\s+\-*/().,%^]+$/.test(t) || !/\d/.test(t) || !/[+\-*/%^]/.test(t)) return "";
        try {
            const v = Function(`"use strict"; return (${t.replace(/,/g, ".").replace(/\^/g, "**")});`)();
            return Number.isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    // Output of the async modes, filled by the processes below
    property string qalcResult: ""
    property var files: []
    property bool searching: false

    // Rows for the list modes: { glyph | icon | emoji, title, subtitle, hint, act(shift) }
    readonly property var items: {
        const q = query;
        switch (mode) {
        case "=":
            return qalcResult ? [{ glyph: "=", title: qalcResult, subtitle: q, hint: "Enter to copy", act: () => copy(qalcResult) }] : [];
        case ">":
            return q ? [{ glyph: Icons.terminal, title: q, subtitle: "Run command", hint: "Enter run · Shift+Enter terminal", act: shift => runCommand(q, shift) }] : [];
        case "?":
            return q ? [{ glyph: Icons.search, title: q, subtitle: "Search the web", hint: "Enter to search", act: () => webSearch(q) }] : [];
        case "!":
            return q ? [{ glyph: "\u{F06A9}", title: q, subtitle: "Ask AI", hint: "Enter to ask", act: () => askAi(q) }] : [];
        case ":":
            return Emoji.search(q).map(e => ({ emoji: e.char, title: e.name, subtitle: e.group, hint: "Enter to copy", act: () => copy(e.char) }));
        case "/":
            return files.map(f => {
                const dir = f.endsWith("/");
                const path = dir ? f.slice(0, -1) : f;
                const slash = path.lastIndexOf("/");
                return {
                    glyph: dir ? "\uf07b" : "\uf15b",
                    title: path.slice(slash + 1),
                    subtitle: path.slice(0, slash).replace(home, "~") || "/",
                    hint: "Enter open · Shift+Enter folder",
                    act: shift => openPath(shift ? path.slice(0, slash) : path)
                };
            });
        case "@":
            return Hyprland.toplevels.values
                .map(t => ({ t, cls: t.lastIpcObject?.class ?? t.wayland?.appId ?? "" }))
                .filter(({ t, cls }) => (t.title + " " + cls).toLowerCase().includes(q.toLowerCase()))
                .map(({ t, cls }) => ({
                    icon: Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon ?? cls, "application-x-executable"),
                    title: t.title || cls,
                    subtitle: cls + (t.workspace ? "  ·  workspace " + t.workspace.name : ""),
                    hint: "Enter to focus",
                    act: () => focusWindow(t)
                }));
        }
        return [];
    }

    readonly property string emptyText: {
        switch (mode) {
        case "": return calcResult ? "" : "No apps match \"" + search.text + "\"";
        case "=": return query ? "No result" : "Type an expression, e.g. 5 usd to eur or 10 km to mi";
        case ">": return "Type a command";
        case "?": return "Type a web search";
        case "!": return "Type a question for the AI";
        case ":": return Emoji.missing ? "Install the unicode-emoji package for emoji search" : "No emoji match";
        case "/": return !query ? "Type to search files in ~" : searching ? "Searching…" : "No files match";
        case "@": return "No windows match";
        }
        return "";
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", text]);
        closeRequested();
    }

    function copyResult() {
        copy(calcResult);
    }

    function runCommand(cmd, inTerminal) {
        if (inTerminal)
            Quickshell.execDetached(["sh", "-c", `uwsm app -- \${TERMINAL:-ghostty} -e sh -c "$1; exec \\$SHELL"`, "sh", cmd]);
        else
            Quickshell.execDetached(["uwsm", "app", "--", "sh", "-c", cmd]);
        closeRequested();
    }

    function webSearch(q) {
        Quickshell.execDetached(["xdg-open", searchUrl.replace("%s", encodeURIComponent(q))]);
        closeRequested();
    }

    function askAi(q) {
        Quickshell.execDetached(["qs", "ipc", "call", "ai", "ask", q]);
        closeRequested();
    }

    function openPath(path) {
        Quickshell.execDetached(["xdg-open", path]);
        closeRequested();
    }

    function focusWindow(toplevel) {
        const a = toplevel.lastIpcObject?.address ?? toplevel.address;
        const address = a.startsWith("0x") ? a : "0x" + a;
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ window = "address:${address}" })`]);
        closeRequested();
    }

    function accept(shift) {
        if (mode) items[list.currentIndex]?.act(shift);
        else if (calcResult) copyResult();
        else launch(results[grid.currentIndex]);
    }

    function moveUp() {
        if (mode) list.decrementCurrentIndex();
        else grid.moveCurrentIndexUp();
    }
    function moveDown() {
        if (mode) list.incrementCurrentIndex();
        else grid.moveCurrentIndexDown();
    }

    onModeChanged: {
        qalcResult = "";
        files = [];
        if (mode === ":") Emoji.wanted = true;
        if (mode === "@") Hyprland.refreshToplevels();
    }
    // qalc and fd run a moment after typing stops
    onQueryChanged: {
        list.currentIndex = 0;
        if (mode === "=" || mode === "/") debounce.restart();
    }

    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            const q = launcher.query;
            if (launcher.mode === "=") {
                qalc.running = false;
                if (!q) return launcher.qalcResult = "";
                // qalc exits non-zero on input it can't parse, so only print on success
                qalc.command = ["sh", "-c", 'out=$(qalc -t -- "$1") && printf %s "$out"', "sh", q];
                qalc.running = true;
            } else if (launcher.mode === "/") {
                finder.running = false;
                if (!q) return launcher.files = [];
                // Hidden files are searched, minus caches, toolchains and other noise
                const noise = [".git", "node_modules", ".cache", ".local/state", ".local/share/Trash", ".cargo", ".rustup",
                    ".npm", ".bun", ".yarn", ".gradle", ".nuget", ".dotnet", ".java", ".nv", ".ollama", ".var",
                    ".vscode", ".cursor", ".minecraft", ".mozilla", "go/pkg"];
                finder.command = ["fd", "--hidden", "--fixed-strings", "--max-results", "200",
                    ...[].concat(...noise.map(n => ["--exclude", n])), "--", q, launcher.home];
                launcher.searching = true;
                finder.running = true;
            }
        }
    }

    Process {
        id: qalc
        stdout: StdioCollector {
            onStreamFinished: launcher.qalcResult = this.text.trim()
        }
    }

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                const q = launcher.query.toLowerCase();
                const name = p => p.replace(/\/$/, "").split("/").pop().toLowerCase();
                // Names starting with the query first, then shallower paths
                launcher.files = this.text.split("\n").filter(p => p)
                    .sort((a, b) => (name(b).startsWith(q) - name(a).startsWith(q))
                        || (a.split("/").length - b.split("/").length) || a.localeCompare(b))
                    .slice(0, 50);
                launcher.searching = false;
            }
        }
    }

    visible: shown
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "launcher"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            search.text = "";
            grid.currentIndex = 0;
            grid.positionViewAtBeginning();
            search.forceActiveFocus();
        }
    }

    function launch(app) {
        if (!app) return;
        Apps.launch(app);
        closeRequested();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.closeRequested()
        }
    }

    // ---- Search ----
    Rectangle {
        id: searchBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.14
        width: 480
        height: 52
        radius: 16
        color: Theme.base
        border.width: 1
        border.color: search.activeFocus ? Theme.accent : Theme.surface1

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.search
            color: Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 15
        }

        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: 14
            anchors.right: modeChip.visible ? modeChip.left : count.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            selectionColor: Theme.surface2
            font.family: Theme.font
            font.pixelSize: 16
            clip: true

            onTextChanged: grid.currentIndex = 0

            Keys.onEscapePressed: {
                if (text) text = "";
                else launcher.closeRequested();
            }
            Keys.onReturnPressed: event => launcher.accept(event.modifiers & Qt.ShiftModifier)
            Keys.onEnterPressed: event => launcher.accept(event.modifiers & Qt.ShiftModifier)
            Keys.onLeftPressed: event => {
                if (launcher.mode) event.accepted = false;
                else grid.moveCurrentIndexLeft();
            }
            Keys.onRightPressed: event => {
                if (launcher.mode) event.accepted = false;
                else grid.moveCurrentIndexRight();
            }
            Keys.onUpPressed: launcher.moveUp()
            Keys.onDownPressed: launcher.moveDown()
            Keys.onTabPressed: {
                if (launcher.mode) list.incrementCurrentIndex();
                else grid.moveCurrentIndexRight();
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !search.text
                text: "Search apps"
                color: Theme.overlay0
                font: search.font
            }
        }

        Rectangle {
            id: modeChip
            anchors.right: count.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: launcher.mode !== ""
            width: chipLabel.implicitWidth + 16
            height: 22
            radius: 11
            color: Theme.surface0

            Text {
                id: chipLabel
                anchors.centerIn: parent
                text: launcher.modeNames[launcher.mode] ?? ""
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: true
            }
        }

        Text {
            id: count
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.mode ? launcher.items.length : launcher.results.length
            color: Theme.overlay0
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // Prefix cheatsheet while the search is empty
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: searchBox.bottom
        anchors.topMargin: 14
        visible: !search.text
        text: "= calc   > run   ? web   ! ask   : emoji   / files   @ windows"
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    // ---- Calculator ----
    Rectangle {
        id: calcCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: searchBox.bottom
        anchors.topMargin: 16
        width: searchBox.width
        height: launcher.calcResult ? 72 : 0
        visible: launcher.calcResult !== ""
        radius: 16
        color: calcMouse.containsMouse ? Theme.surface0 : Theme.base
        border.width: 1
        border.color: Theme.surface1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            text: "= " + launcher.calcResult
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter to copy"
            color: Theme.overlay0
            font.family: Theme.font
            font.pixelSize: 12
        }

        MouseArea {
            id: calcMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: launcher.copyResult()
        }
    }

    // ---- Grid ----
    GridView {
        id: grid

        readonly property int columns: Math.max(3, Math.floor(launcher.width * 0.78 / cellWidth))

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: calcCard.visible ? calcCard.bottom : searchBox.bottom
        anchors.topMargin: calcCard.visible ? 24 : 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        width: columns * cellWidth
        visible: !launcher.mode
        cellWidth: 180
        cellHeight: 170
        clip: true
        model: launcher.results
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        keyNavigationWraps: false

        delegate: Item {
            id: cell

            required property var modelData
            required property int index
            readonly property bool current: GridView.isCurrentItem

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 8
                radius: 18
                color: cell.current ? Theme.surface0 : "transparent"
                border.width: cell.current ? 1 : 0
                border.color: Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            IconImage {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 30
                implicitSize: 64
                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                asynchronous: true
            }

            Text {
                anchors.top: icon.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 28
                horizontalAlignment: Text.AlignHCenter
                text: cell.modelData.name
                color: cell.current ? Theme.text : Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.currentIndex = cell.index
                onClicked: launcher.launch(cell.modelData)
            }
        }
    }

    // ---- Prefix mode results ----
    ListView {
        id: list

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: searchBox.bottom
        anchors.topMargin: 16
        width: searchBox.width
        height: Math.min(contentHeight, launcher.height - y - 48)
        visible: launcher.mode !== ""
        clip: true
        spacing: 4
        model: launcher.items
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        keyNavigationWraps: true

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem

            width: list.width
            height: 56
            radius: 14
            color: current ? Theme.surface0 : Theme.base
            border.width: 1
            border.color: current ? Theme.surface2 : Theme.surface1
            Behavior on color { ColorAnimation { duration: 100 } }

            Item {
                id: lead
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30

                IconImage {
                    anchors.centerIn: parent
                    visible: row.modelData.icon !== undefined
                    implicitSize: 28
                    source: row.modelData.icon ?? ""
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: row.modelData.icon === undefined
                    text: row.modelData.emoji ?? row.modelData.glyph ?? ""
                    color: Theme.accent
                    font.family: row.modelData.emoji ? "Noto Color Emoji" : Theme.iconFont
                    font.pixelSize: row.modelData.emoji ? 22 : 16
                    font.bold: true
                }
            }

            Column {
                anchors.left: lead.right
                anchors.leftMargin: 14
                anchors.right: hint.visible ? hint.left : parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: row.modelData.title
                    color: row.current ? Theme.text : Theme.subtext1
                    font.family: Theme.font
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData.subtitle ?? ""
                    color: Theme.overlay1
                    font.family: Theme.font
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
            }

            Text {
                id: hint
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: row.current
                text: row.modelData.hint ?? ""
                color: Theme.overlay0
                font.family: Theme.font
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onEntered: list.currentIndex = row.index
                onClicked: mouse => row.modelData.act(mouse.modifiers & Qt.ShiftModifier)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: searchBox.bottom
        anchors.topMargin: launcher.mode ? 40 : 80
        visible: launcher.emptyText !== "" && (launcher.mode ? launcher.items.length === 0 : launcher.results.length === 0)
        text: launcher.emptyText
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 14
    }
}
