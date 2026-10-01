import QtQuick

// Thin volume slider for a PipeWire node (the default output unless `audio` is set);
// drag, click or scroll to change it
LevelSlider {
    property var audio: Status.sink?.audio ?? null

    value: audio?.volume ?? 0
    dimmed: audio?.muted ?? false
    onMoved: v => {
        if (audio) audio.volume = v;
    }
}
