import QtQuick
import QtQuick.Shapes
import qs.Commons

// A load ring around an icon, with a number beside it (sysmon's CPU and GPU):
// the ring fills clockwise from the top with `load` (0..100), the number is
// whatever reads better as a figure (a temperature). Side by side in a
// horizontal bar, stacked in a side bar like Reading.qml.
Grid {
    id: g
    property string icon
    property real load: 0              // 0..100, drawn as the ring
    property string text
    property string widest: "88°"
    property bool hot: false           // ring, icon and number take the warning colour
    readonly property string tint: hot ? (Theme.hued ? Theme.c.warning : Theme.c.accentBright) : Theme.c.accentLight
    readonly property bool vertical: Config.vertical
    columns: vertical ? 1 : 2
    columnSpacing: 4
    rowSpacing: 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Item {
        id: dial
        readonly property real d: g.vertical ? Theme.fs(17) : Theme.fs(20)
        readonly property real stroke: 2
        readonly property real r: d / 2 - stroke / 2 - 0.5
        width: d; height: d
        property real shown: Math.max(0, Math.min(100, g.load))
        Behavior on shown { NumberAnimation { duration: Motion.moveMs; easing.type: Easing.OutCubic } }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {                 // the track
                strokeColor: Theme.alpha(g.tint, 0.2)
                strokeWidth: dial.stroke
                fillColor: "transparent"
                PathAngleArc { centerX: dial.d / 2; centerY: dial.d / 2; radiusX: dial.r; radiusY: dial.r; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {                 // the load
                strokeColor: g.tint
                strokeWidth: dial.shown >= 1 ? dial.stroke : 0
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: dial.d / 2; centerY: dial.d / 2; radiusX: dial.r; radiusY: dial.r; startAngle: -90; sweepAngle: 3.6 * dial.shown }
            }
        }
        Icon { anchors.centerIn: parent; icon: g.icon; color: g.tint; size: Math.round(dial.d * 0.56) }
    }
    FixedLabel {
        text: g.text
        widest: g.widest
        color: g.hot ? g.tint : Theme.c.accentLight
        font.pixelSize: g.vertical ? Theme.fs(9) : Theme.fontSize
    }
}
