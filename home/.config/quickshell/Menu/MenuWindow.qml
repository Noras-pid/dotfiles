import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Bar
import qs.Services

// The menu overlay, kept minimal: one search line (a "‹ Section" chip in
// front of it inside a section, four small quick toggles at its end on the
// root page), compact single-line rows, nothing else. ↑↓ / Tab move, Enter
// opens or runs, → opens, Backspace/← on an empty box goes up, Esc closes.
// Searching lists every leaf; the section a result belongs to is shown
// dimly on the right.
//
// Motion: the card rises and scales in, its rows follow one after another
// (also on every page change, from the side you went); the selection is
// one highlight that glides between rows; closing shrinks and fades the
// card before the window goes.
Variants {
    id: menuWindows
    // held from open until the closing animation has played, then unloaded
    property bool held: false
    model: Menu.open || held ? Quickshell.screens : []
    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        // stays mapped until the closing animation has played
        property bool shown: false
        visible: shown
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "orrery-menu"
        color: "transparent"

        readonly property int rowH: 34
        readonly property int rowsMax: 10
        readonly property var rows: Menu.rows
        readonly property int rowsShown: Math.max(2, Math.min(rowsMax, rows.length))
        // quick toggles at the end of the search line (root page only)
        readonly property var quickIds: ["toggle.caffeine", "toggle.dnd", "toggle.nightlight", "toggle.gamemode"]
        readonly property var quick: Menu.path === "" && Menu.query === "" && !Menu.inputRow
                                     ? Menu.childrenOf("toggle").filter(r => quickIds.indexOf(r.id) !== -1)
                                                                .sort((a, b) => quickIds.indexOf(a.id) - quickIds.indexOf(b.id))
                                     : []
        // bumped on open and on every page change: the rows replay their entrance
        property int wave: 0
        property int waveDir: 1
        // rows created during an entrance join it; rows created by typing just appear
        property bool entering: false
        onWaveChanged: { entering = true; enterWindow.restart() }
        Timer { id: enterWindow; interval: 420; onTriggered: win.entering = false }

        Component.onCompleted: if (Menu.open) { menuOpen.onOpenChanged(); if (Menu.query) menuOpen.onQueryChanged() }
        Connections {
            id: menuOpen
            target: Menu
            function onOpenChanged() {
                if (Menu.open) {
                    closing.stop(); win.shown = true; menuWindows.held = true
                    input.text = ""; input.forceActiveFocus()
                    win.waveDir = 1; win.wave++
                    card.y0 = 10; card.opacity = 0; card.scale = 0.96; opening.restart()
                } else if (win.shown) {
                    opening.stop(); closing.restart()
                }
            }
            function onPathChanged() { input.text = "" }
            function onInputRowChanged() { input.text = "" }
            function onQueryChanged() { if (input.text !== Menu.query) input.text = Menu.query }
        }

        ParallelAnimation {
            id: opening
            NumberAnimation { target: card; property: "scale"; to: 1; duration: Motion.growMs
                              easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.growCurve }
            NumberAnimation { target: card; property: "y0"; to: 0; duration: Motion.inMs
                              easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.inCurve }
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: Motion.effectsMs
                              easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeCurve }
        }
        SequentialAnimation {
            id: closing
            ParallelAnimation {
                NumberAnimation { target: card; property: "scale"; to: 0.97; duration: Motion.outMs
                                  easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.outCurve }
                NumberAnimation { target: card; property: "y0"; to: 6; duration: Motion.outMs
                                  easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.outCurve }
                NumberAnimation { target: card; property: "opacity"; to: 0; duration: Motion.outMs
                                  easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.outCurve }
            }
            ScriptAction { script: { win.shown = false; menuWindows.held = false } }
        }

        MouseArea { anchors.fill: parent; onClicked: Menu.close() }

        Rectangle {
            id: card
            property real y0: 0          // the rise on open, the dip on close
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2 - 40 + y0
            width: 500
            height: 8 + 38 + 6 + win.rowsShown * win.rowH + 8
            // grows and shrinks with the list, in the shell's own motion
            Behavior on height { NumberAnimation { duration: Motion.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.moveCurve } }
            radius: Theme.radius
            // solid: blur is off on this iGPU, and a game behind it made the rows unreadable
            color: Theme.c.bg0
            border.width: 1; border.color: Theme.c.borderStrong
            MouseArea { anchors.fill: parent }   // clicks on the card don't close the menu

            // search line: [‹ section] input [quick toggles]
            Item {
                id: bar
                x: 8; y: 8; width: parent.width - 16; height: 38
                Icon {
                    id: lens
                    visible: !crumb.visible
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    icon: "search"; size: Theme.fs(16); color: Theme.c.accentMid
                }
                // inside a section: "‹ Appearance" — a chip that goes back up
                Rectangle {
                    id: crumb
                    visible: Menu.crumb !== "Menu"
                    x: 2; anchors.verticalCenter: parent.verticalCenter
                    width: crumbRow.implicitWidth + 12; height: 24
                    radius: Theme.radiusSm
                    color: crumbMouse.containsMouse ? Theme.c.bg3 : Theme.c.bg2
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }
                    Row {
                        id: crumbRow
                        anchors.centerIn: parent
                        spacing: 2
                        Icon { anchors.verticalCenter: parent.verticalCenter; icon: "chevron_left"; size: Theme.fs(14); color: Theme.c.accentLight }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: Menu.crumb; font.pixelSize: Theme.fs(11.5); color: Theme.c.fg }
                    }
                    MouseArea { id: crumbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Menu.up() }
                }
                TextInput {
                    id: input
                    anchors.left: crumb.visible ? crumb.right : lens.right
                    anchors.leftMargin: crumb.visible ? 10 : 8
                    anchors.right: quickRow.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font; font.pixelSize: Theme.fs(13); color: Theme.c.fg
                    selectionColor: Theme.alpha(Theme.c.accentBright, 0.35)
                    clip: true
                    focus: true
                    onTextChanged: { if (!Menu.inputRow) { Menu.query = text; Menu.selected = 0 } }
                    Label { visible: !input.text; anchors.verticalCenter: parent.verticalCenter
                            text: Menu.inputRow ? Menu.placeholder : "Search"; font.pixelSize: Theme.fs(13); color: Theme.c.accentDim }
                    Keys.onPressed: (e) => {
                        const n = win.rows.length
                        if (e.key === Qt.Key_Escape) { if (Menu.inputRow || input.text !== "") Menu.up(); else Menu.close(); e.accepted = true; return }
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (Menu.inputRow) Menu.submitInput(input.text); else if (n) list.activate(Menu.selected)
                            e.accepted = true; return
                        }
                        if ((e.key === Qt.Key_Backspace || e.key === Qt.Key_Left) && input.text === "") { Menu.up(); e.accepted = true; return }
                        if (e.key === Qt.Key_Right && !Menu.inputRow && n && win.rows[Menu.selected].sub) { Menu.activate(win.rows[Menu.selected]); e.accepted = true; return }
                        if (n === 0 || Menu.inputRow) return
                        if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { Menu.selected = (Menu.selected + 1) % n; e.accepted = true }
                        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { Menu.selected = (Menu.selected + n - 1) % n; e.accepted = true }
                    }
                }
                // quick toggles: small icons, filled while on; they fade out
                // when you start typing or go into a section
                Row {
                    id: quickRow
                    anchors.right: parent.right; anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    opacity: win.quick.length ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs } }
                    Repeater {
                        model: win.quick
                        Rectangle {
                            id: qtile
                            required property var modelData
                            readonly property bool on: modelData.checked === true
                            width: 28; height: 28
                            radius: Theme.radiusSm
                            color: on ? Theme.c.accentBright : qtileMouse.containsMouse ? Theme.c.bg2 : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fadeMs } }
                            scale: qtileMouse.pressed ? 0.88 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                            Icon { anchors.centerIn: parent; icon: qtile.modelData.icon; size: Theme.fs(15)
                                   color: qtile.on ? Theme.c.bg0 : Theme.c.accentMid }
                            MouseArea { id: qtileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { Menu.activate(qtile.modelData); input.forceActiveFocus() } }
                        }
                    }
                }
            }
            Rectangle { x: 8; y: bar.y + bar.height; width: parent.width - 16; height: 1; color: Theme.c.bg3 }

            // a page change: the rows come in one after another from the side
            // you went (deeper from the right, back from the left)
            property string lastPath: Menu.path
            Connections {
                target: Menu
                function onPathChanged() {
                    win.waveDir = Menu.path.length >= card.lastPath.length ? 1 : -1
                    card.lastPath = Menu.path
                    win.wave++
                }
            }
            ListView {
                id: list
                x: 8; y: bar.y + bar.height + 6
                width: parent.width - 16
                height: win.rowsShown * win.rowH
                clip: true; spacing: 0
                // the model is the row count, and each row reads win.rows[index]:
                // a toggle re-reads the rows, and a new array as the model reset
                // the view to the top every time; same count, nothing resets
                model: win.rows.length
                currentIndex: Menu.selected
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                // one highlight that glides to the selected row
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 160
                highlightMoveVelocity: -1
                highlightResizeDuration: 0
                highlight: Rectangle {
                    width: list.width; height: win.rowH
                    radius: Theme.radiusSm
                    color: Theme.c.bg2
                    Rectangle { width: 3; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter
                                radius: 1.5; color: Theme.c.accentBright }
                }
                // another page or another search: start at the top
                Connections {
                    target: Menu
                    function onPathChanged() { list.positionViewAtBeginning() }
                    function onQueryChanged() { list.positionViewAtBeginning() }
                }
                function activate(i) {
                    const r = win.rows[i]
                    if (!r) return
                    Menu.selected = i
                    Menu.activate(r)
                }
                delegate: Item {
                    id: row
                    required property int index
                    readonly property var modelData: win.rows[index] || ({ icon: "", label: "", crumb: "", value: "" })
                    readonly property bool sel: index === Menu.selected
                    width: list.width; height: win.rowH

                    // the entrance: fade and slide in, a little later for each row
                    Item {
                        id: content
                        width: parent.width; height: parent.height
                        Component.onCompleted: if (win.entering) row.enter()
                        Icon {
                            id: ic
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: 18
                            icon: row.modelData.icon; size: material ? Theme.fs(17) : Theme.fs(13)
                            color: row.sel ? Theme.c.accentBright : Theme.c.accentMid
                        }
                        Label {
                            anchors.left: ic.right; anchors.leftMargin: 10
                            anchors.right: right.left; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.modelData.label; font.pixelSize: Theme.fs(12)
                            color: row.sel ? Theme.c.accentBright : Theme.c.fg
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Row {
                            id: right
                            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Label { visible: Menu.query !== "" && row.modelData.crumb !== ""; text: row.modelData.crumb; font.pixelSize: Theme.fs(11); color: Theme.c.accentDim
                                    // cut from the left: the end of the path ("Dock › Position") is what
                                    // tells two "Top" rows apart
                                    elide: Text.ElideLeft; width: Math.min(implicitWidth, 190) }
                            Label { visible: row.modelData.value !== ""; text: row.modelData.value; font.pixelSize: Theme.fs(11); color: Theme.c.accentMid
                                    elide: Text.ElideRight; width: Math.min(implicitWidth, 170) }
                            Icon { visible: row.modelData.checked === true; icon: "check"; size: Theme.fs(16); color: Theme.c.accentBright }
                            Icon { visible: row.modelData.sub; icon: "chevron_right"; size: Theme.fs(16); color: row.sel ? Theme.c.accentLight : Theme.c.accentDim }
                        }
                    }
                    function enter() {
                        entry.stop()
                        content.opacity = 0; content.x = 10 * win.waveDir
                        delay.duration = Math.min(row.index, 9) * 22
                        entry.start()
                    }
                    Connections { target: win; function onWaveChanged() { row.enter() } }
                    SequentialAnimation {
                        id: entry
                        PauseAnimation { id: delay; duration: 0 }
                        ParallelAnimation {
                            NumberAnimation { target: content; property: "opacity"; to: 1; duration: 180
                                              easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.fadeCurve }
                            NumberAnimation { target: content; property: "x"; to: 0; duration: Motion.moveMs
                                              easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.moveCurve }
                        }
                    }
                    // click only: hovering never moves the selection
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: list.activate(row.index) }
                }
                Label { visible: win.rows.length === 0 && !Menu.inputRow; anchors.centerIn: parent; text: "Nothing found"; font.pixelSize: Theme.fs(12); color: Theme.c.accentDim }
            }
        }
    }
}
