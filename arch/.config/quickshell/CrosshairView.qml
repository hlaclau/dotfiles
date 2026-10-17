import QtQuick

// The crosshair drawn at the middle of the screen from OverlayState.crosshair (set in the
// Crosshair panel). It only draws; clicks pass through it.
Canvas {
    id: view

    readonly property var s: OverlayState.crosshair
    readonly property color color: Theme[s.color] ?? Theme.accent
    readonly property real extent: s.size + s.gap + s.thickness + 4

    width: extent * 2
    height: extent * 2

    onSChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2, cy = height / 2;
        const arm = s.size, gap = s.gap, t = s.thickness;
        const style = s.style;

        // One pass per color: the dark outline first (slightly thicker), then the crosshair
        const draw = (c, grow) => {
            ctx.strokeStyle = c;
            ctx.fillStyle = c;
            ctx.lineCap = "butt";
            ctx.lineWidth = t + grow * 2;

            if (style === "cross" || style === "crossdot") {
                ctx.beginPath();
                ctx.moveTo(cx - gap - arm - grow, cy); ctx.lineTo(cx - gap + grow, cy);
                ctx.moveTo(cx + gap - grow, cy); ctx.lineTo(cx + gap + arm + grow, cy);
                ctx.moveTo(cx, cy - gap - arm - grow); ctx.lineTo(cx, cy - gap + grow);
                ctx.moveTo(cx, cy + gap - grow); ctx.lineTo(cx, cy + gap + arm + grow);
                ctx.stroke();
            }
            if (style === "dot" || style === "crossdot") {
                ctx.beginPath();
                ctx.arc(cx, cy, Math.max(1, t) + grow, 0, Math.PI * 2);
                ctx.fill();
            }
            if (style === "circle") {
                ctx.beginPath();
                ctx.arc(cx, cy, arm / 2 + gap, 0, Math.PI * 2);
                ctx.stroke();
            }
        };

        if (s.outline) draw(Qt.rgba(0, 0, 0, 0.8), 1);
        draw(color, 0);
    }
}
