import QtQuick
import QtQuick.Shapes

// Circular gauge for a value in 0..1, drawn clockwise from the top, with a
// glyph in the middle
Item {
    id: ring

    property real value: 0
    property color color: Theme.accent
    property string icon
    property real thickness: 3

    implicitWidth: 28
    implicitHeight: 28

    property real shown: value
    Behavior on shown { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.surface0
            strokeWidth: ring.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness; radiusY: radiusX
                startAngle: -90
                sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.color
            strokeWidth: ring.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness; radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * Math.max(0.01, Math.min(1, ring.shown))
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: ring.icon
        color: ring.color
        font.family: Theme.iconFont
        font.pixelSize: ring.width * 0.36
    }
}
