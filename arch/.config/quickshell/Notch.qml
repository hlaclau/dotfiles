import QtQuick
import QtQuick.Shapes

// Island silhouette hanging from the top screen edge: rounded bottom corners
// plus two inverted "wing" corners that blend it into the edge.
//
//   ╮                  ╭   <- wings (radius `wing`), `wingTop` px down
//    │                │
//    ╰────────────────╯    <- body corners (radius `radius`)
//
// With the bar drawn as a solid strip, `wingTop` puts the wings on the bar's
// bottom edge so the island grows out of the bar rather than the screen edge.
Shape {
    id: shape

    property real wing: 14
    property real radius: 14
    property real wingTop: 0
    property color color: Theme.crust

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        id: path

        readonly property real w: shape.width
        readonly property real h: shape.height
        readonly property real t: Math.max(0, Math.min(shape.wingTop, h))
        readonly property real g: Math.max(0, Math.min(shape.wing, (h - t) / 2, w / 6))
        readonly property real r: Math.max(0, Math.min(shape.radius, h - t - g, (w - 2 * g) / 2))

        fillColor: shape.color
        strokeWidth: -1

        startX: 0
        startY: path.t

        // Left wing
        PathArc {
            x: path.g; y: path.t + path.g
            radiusX: path.g; radiusY: path.g
            direction: PathArc.Clockwise
        }
        PathLine { x: path.g; y: path.h - path.r }

        // Bottom-left corner
        PathArc {
            x: path.g + path.r; y: path.h
            radiusX: path.r; radiusY: path.r
            direction: PathArc.Counterclockwise
        }
        PathLine { x: path.w - path.g - path.r; y: path.h }

        // Bottom-right corner
        PathArc {
            x: path.w - path.g; y: path.h - path.r
            radiusX: path.r; radiusY: path.r
            direction: PathArc.Counterclockwise
        }
        PathLine { x: path.w - path.g; y: path.t + path.g }

        // Right wing
        PathArc {
            x: path.w; y: path.t
            radiusX: path.g; radiusY: path.g
            direction: PathArc.Clockwise
        }
        // Up and across the part hidden in the bar
        PathLine { x: path.w; y: 0 }
        PathLine { x: 0; y: 0 }
        PathLine { x: 0; y: path.t }
    }
}
