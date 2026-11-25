import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// pill:    the classic look — numbered buttons in a pill, active one inverted
// minimal: Omarchy — plain numbers 1..5 (always) + any others, active shown as 󱓻
Pill {
    id: ws
    padH: pillMode ? 3 : 4
    gap: pillMode ? 4 : 4
    padV: 0
    interactive: false
    // Hyprland with a Lua config takes Lua dispatchers, not the classic syntax.
    function go(target) {
        if (Hyprland.usingLua !== false)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + (typeof target === "number" ? target : '"' + target + '"') + " })")
        else
            Hyprland.dispatch("workspace " + target)
    }
    onScrolled: (d) => go(d > 0 ? "e-1" : "e+1")

    readonly property var live: Hyprland.workspaces.values
    property var entries: []
    function rebuild() {
        const byId = {}
        for (const w of live) if (w.id > 0) byId[w.id] = w
        const ids = Object.keys(byId).map(Number)
        if (!pillMode) for (let i = 1; i <= 5; i++) if (!byId[i]) ids.push(i)
        ids.sort((a, b) => a - b)
        entries = ids.map(i => ({ id: i, ws: byId[i] || null }))
    }
    onLiveChanged: rebuild()
    onPillModeChanged: rebuild()
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { ws.rebuild() }
    }
    Component.onCompleted: rebuild()

    Repeater {
        model: ws.entries
        Rectangle {
            id: btn
            required property var modelData
            readonly property bool active: Hyprland.focusedWorkspace && modelData.ws
                                           && Hyprland.focusedWorkspace.id === modelData.id
            readonly property bool urgent: modelData.ws ? modelData.ws.urgent : false
            readonly property bool exists: modelData.ws !== null
            readonly property bool hov: m.containsMouse

            implicitWidth: ws.vertical ? (ws.pillMode ? 26 : 20) : ws.pillMode ? Math.max(active ? 38 : 34, t.implicitWidth + 14) : Math.max(active ? 36 : 28, t.implicitWidth + 16)
            implicitHeight: ws.vertical ? (ws.pillMode ? (active ? 32 : 26) : 20) : ws.pillMode ? 23 : 28
            radius: Theme.radiusSm
            color: ws.pillMode
                   ? (active ? Theme.c.fg : hov ? Theme.c.bg4 : urgent ? Theme.c.grey2 : Theme.c.bg2)
                   : (hov ? Theme.c.bg2 : "transparent")
            opacity: ws.pillMode && !active && !hov ? 0.7 : 1
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Label {
                id: t
                anchors.centerIn: parent
                text: String(btn.modelData.id)
                font.weight: btn.active ? Font.Bold : Font.Medium
                color: ws.pillMode
                       ? (btn.active || btn.urgent ? Theme.c.bg0 : hov ? Theme.c.fg : Theme.c.grey1)
                       : (btn.active ? Theme.c.accentBright : btn.exists ? Theme.c.fg : Theme.c.accentMid)
            }
            Rectangle {             // minimal skin: a workspace with windows
                visible: !ws.pillMode && !ws.vertical && btn.exists && !btn.active
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                width: 4; height: 2; radius: 1
                color: btn.urgent ? Theme.c.critical : Theme.c.accentBright
            }
            MouseArea {
                id: m
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ws.go(btn.modelData.id)
                onWheel: (w) => ws.go(w.angleDelta.y > 0 ? "e-1" : "e+1")
            }
        }
    }
}
