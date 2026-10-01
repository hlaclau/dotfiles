import QtQuick
import QtQuick.Shapes

// Island silhouette hanging from the top screen edge: rounded bottom corners
// plus two inverted "wing" corners that blend it into the edge.
//
//   ╮                  ╭   <- wings (radius `wing`)
//    │                │
//    ╰────────────────╯    <- body corners (radius `radius`)
Shape {
    id: shape

    property real wing: 14
    property real radius: 14
    property color color: Theme.crust

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        id: path

        readonly property real w: shape.width
        readonly property real h: shape.height
        readonly property real g: Math.max(0, Math.min(shape.wing, h / 2, w / 6))
        readonly property real r: Math.max(0, Math.min(shape.radius, h - g, (w - 2 * g) / 2))

        fillColor: shape.color
        strokeWidth: -1

        startX: 0
        startY: 0

        // Left wing
        PathArc {
            x: path.g; y: path.g
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
        PathLine { x: path.w - path.g; y: path.g }

        // Right wing
        PathArc {
            x: path.w; y: 0
            radiusX: path.g; radiusY: path.g
            direction: PathArc.Clockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
