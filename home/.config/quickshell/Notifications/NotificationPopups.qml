import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// Popup stack, top-right, under the bar: newest on top, at most four at a
// time (the rest wait their turn). Each counts down along its bottom edge
// and stops counting while the pointer is on it.
PanelWindow {
    id: win
    // out of the way while a bar panel is open (they sat over its top corner)
    visible: Notifs.popups.length > 0 && Panels.open === ""
    // the bar's own geometry (Bar.qml): 12px from the screen edge, 37/40px thick
    readonly property int barGap: Theme.barStyle === "minimal" ? 0 : 12
    readonly property int barThick: Theme.barStyle === "pill" ? 37 : 40
    anchors { top: true; right: true }
    margins {
        top: Config.position === "top" ? barGap + barThick + 8 : 12
        right: Config.position === "right" ? barGap + barThick + 8 : 12
    }
    implicitWidth: 380
    implicitHeight: Math.min(stack.implicitHeight, screen.height - 100)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "orrery-notifications"

    Column {
        id: stack
        width: parent.width
        spacing: 8
        move: Transition { NumberAnimation { properties: "y"; duration: Motion.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.moveCurve } }
        Repeater {
            model: Notifs.popups
            NotificationCard {
                id: card
                required property var modelData
                required property int index
                entry: modelData
                compact: true
                visible: index < 4
                progress: Notifs.left(modelData)
                Timer {
                    interval: 100; repeat: true
                    running: card.visible && !card.hovered
                    onTriggered: Notifs.spend(card.modelData, interval)
                }
                // only a card that just arrived slides in; the others were
                // rebuilt by the list change and stay where they are
                readonly property bool fresh: Date.now() - modelData.time.getTime() < 400
                opacity: fresh ? 0 : 1
                transform: Translate { id: shift; x: card.fresh ? 40 : 0 }
                Component.onCompleted: if (fresh) arrive.start()
                ParallelAnimation {
                    id: arrive
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: Motion.inMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.inCurve }
                    NumberAnimation { target: shift; property: "x"; to: 0; duration: Motion.growMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.growCurve }
                }
            }
        }
    }
}
