import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// An image (or an animated gif / webp) floating above everything: a reference, a guide, a map. Paste one from the clipboard
// (an image, or a path / URL copied as text) or type a path or URL. Pin it and it stays on screen
// without its frame, letting clicks through; turn the mouse button on in its title bar to move it.
Item {
    id: tab

    readonly property string source: OverlayState.image.source
    readonly property bool remote: /^https?:\/\//i.test(source)
    // What the image items load: always a local file, because AnimatedImage crashes quickshell on URLs
    property string local: ""
    // Image only plays the first frame
    readonly property bool animated: /\.(gif|webp|apng)$/i.test(local)

    onSourceChanged: refresh()
    Component.onCompleted: refresh()

    function refresh() {
        if (!remote) {
            local = source;
            return;
        }
        local = "";
        fetcher.url = source;
        fetcher.running = true;
    }

    // A path, ~/ path, URL or file:// URL as something Image can load
    function resolve(text) {
        const t = text.trim();
        if (t === "") return "";
        if (t.startsWith("~/")) return "file://" + Quickshell.env("HOME") + t.slice(1);
        if (t.startsWith("/")) return "file://" + t;
        return t;
    }
    function setSource(text) {
        OverlayState.setImage(resolve(text));
        input.text = "";
    }

    Image {
        anchors.fill: parent
        visible: !tab.animated
        source: tab.animated ? "" : tab.local
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
    }
    AnimatedImage {
        anchors.fill: parent
        visible: tab.animated
        source: tab.animated ? tab.local : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
        playing: visible
    }

    Text {
        anchors.centerIn: parent
        visible: tab.source === "" && OverlayState.shown
        text: "Paste an image, a path or a URL"
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    // Remote images are downloaded once to the cache dir (named after the URL), the extension
    // coming from the content type so gifs and webps animate
    Process {
        id: fetcher

        property string url

        command: ["sh", "-c", `
            dir="$1"; url="$2"; mkdir -p "$dir"
            key=$(printf %s "$url" | md5sum | cut -c1-16)
            f=$(ls "$dir"/remote-$key.* 2>/dev/null | head -1)
            if [ -z "$f" ]; then
                tmp="$dir/remote-$key.part"
                type=$(curl -sfL -m 30 -o "$tmp" -w '%{content_type}' "$url") || { rm -f "$tmp"; exit 1; }
                case "$type" in image/gif) ext=.gif ;; image/webp) ext=.webp ;; image/png) ext=.png ;; image/jpeg) ext=.jpg ;; *) ext=.img ;; esac
                f="$dir/remote-$key$ext"
                mv "$tmp" "$f"
            fi
            echo "$f"`, "sh", Quickshell.cachePath("floating-image"), url]
        stdout: StdioCollector {
            onStreamFinished: {
                const file = this.text.trim();
                if (file && tab.remote && fetcher.url === tab.source) tab.local = "file://" + file;
            }
        }
    }

    // Image from the clipboard goes to the cache dir; anything else is taken as text
    Process {
        id: paster

        command: ["sh", "-c", `
            dir="$1"; mkdir -p "$dir"
            type=$(wl-paste -l 2>/dev/null | grep -m1 '^image/')
            if [ -n "$type" ]; then
                rm -f "$dir"/pasted-*
                # The extension tells the tab to animate it
                case "$type" in image/gif) ext=.gif ;; image/webp) ext=.webp ;; *) ext= ;; esac
                f="$dir/pasted-$(date +%s%N)$ext"
                wl-paste -t "$type" > "$f" && echo "$f"
            else
                wl-paste -n 2>/dev/null | head -c 2000
            fi`, "sh", Quickshell.cachePath("floating-image")]
        stdout: StdioCollector {
            onStreamFinished: tab.setSource(this.text)
        }
    }

    // Controls, only while the overlay is open
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: 38
        radius: 12
        color: Theme.surface0
        opacity: OverlayState.shown ? 0.95 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 6
            spacing: 8

            TextInput {
                id: input
                Layout.fillWidth: true
                color: Theme.text
                selectionColor: Theme.surface2
                font.family: Theme.font
                font.pixelSize: 12
                clip: true
                onAccepted: tab.setSource(text)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !input.text
                    text: "Path or URL"
                    color: Theme.overlay0
                    font: input.font
                }
            }
            IconButton {
                size: 28
                icon: Icons.clipboard
                iconColor: Theme.accent
                onClicked: paster.running = true
            }
            IconButton {
                size: 28
                icon: Icons.trash
                iconColor: Theme.red
                visible: tab.source !== ""
                onClicked: OverlayState.setImage("")
            }
        }
    }
}
