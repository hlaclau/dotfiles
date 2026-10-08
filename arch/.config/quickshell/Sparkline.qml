import QtQuick

// Line graph of values in 0..1, newest on the right, with a soft fill under it
Canvas {
    id: graph

    property var values: []
    // Samples the width is split into, so the line scrolls instead of stretching
    property int capacity: 40
    property color color: Theme.accent
    property real lineWidth: 1.5
    property bool fill: true

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (values.length < 2) return;

        const step = width / Math.max(1, capacity - 1);
        const x0 = width - (values.length - 1) * step;
        const pad = lineWidth;
        const y = v => pad + (1 - Math.max(0, Math.min(1, v))) * (height - 2 * pad);

        ctx.beginPath();
        ctx.moveTo(x0, y(values[0]));
        for (let i = 1; i < values.length; i++) ctx.lineTo(x0 + i * step, y(values[i]));

        if (fill) {
            ctx.save();
            ctx.lineTo(width, height);
            ctx.lineTo(x0, height);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.alpha(color, 0.35));
            g.addColorStop(1, Qt.alpha(color, 0));
            ctx.fillStyle = g;
            ctx.fill();
            ctx.restore();

            // Redraw the line on its own, without the fill's closing edges
            ctx.beginPath();
            ctx.moveTo(x0, y(values[0]));
            for (let i = 1; i < values.length; i++) ctx.lineTo(x0 + i * step, y(values[i]));
        }

        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.strokeStyle = color;
        ctx.stroke();
    }
}
