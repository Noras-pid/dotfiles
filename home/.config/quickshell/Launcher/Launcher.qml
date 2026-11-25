import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Bar
import qs.Services

// App launcher, minimal: a search line and one column of single-line rows
// (icon, name, what it is dimmed on the right). Type to filter; ↑↓ / Tab
// move, Enter launches, Escape closes. A sum ("2+2*3") shows its answer
// first (Enter copies it); a search with no app offers the web. The card
// keeps one size whatever it shows.
Variants {
    model: Apps.open ? Quickshell.screens : []
    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: Apps.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Apps.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "orrery-launcher"
        color: "transparent"

        property int selected: 0
        readonly property int rowH: 38
        readonly property int rowsShown: 9
        onVisibleChanged: if (visible) { selected = 0; input.text = ""; input.forceActiveFocus() }
        Component.onCompleted: if (visible) visibleChanged()
        Connections { target: Apps; function onResultsChanged() { win.selected = 0 } }

        MouseArea { anchors.fill: parent; onClicked: Apps.open = false }

        Arrive { target: card; when: win.visible; from: 0.98; growMs: 160; fadeMs: 80 }

        Rectangle {
            id: card
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -40
            width: 540
            height: 10 + 40 + 6 + win.rowsShown * win.rowH + 10
            radius: Theme.radius
            // blur is off on this iGPU, so the card is solid to stay readable
            color: Theme.c.bg0
            border.width: 1; border.color: Theme.c.borderStrong
            MouseArea { anchors.fill: parent }   // clicks on the card don't close it

            // search line
            Item {
                id: bar
                x: 10; y: 10; width: parent.width - 20; height: 40
                Icon { id: lens; x: 8; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: Theme.fs(17); color: Theme.c.accentMid }
                TextInput {
                    id: input
                    anchors.left: lens.right; anchors.leftMargin: 10
                    anchors.right: count.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font; font.pixelSize: Theme.fs(14)
                    color: Theme.c.fg
                    selectionColor: Theme.alpha(Theme.c.accentBright, 0.35)
                    clip: true
                    focus: true
                    onTextChanged: Apps.query = text
                    Label { visible: !input.text; anchors.verticalCenter: parent.verticalCenter
                            text: "Search"; font.pixelSize: Theme.fs(14); color: Theme.c.accentDim }
                    Keys.onPressed: (e) => {
                        const n = Apps.results.length
                        if (e.key === Qt.Key_Escape) { Apps.open = false; e.accepted = true; return }
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { Apps.launch(Apps.results[win.selected]); e.accepted = true; return }
                        if (n === 0) return
                        if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) win.selected = (win.selected + 1) % n
                        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) win.selected = (win.selected + n - 1) % n
                        else return
                        e.accepted = true
                    }
                }
                Label {
                    id: count
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Apps.query !== ""
                    text: Apps.apps.length
                    font.pixelSize: Theme.fs(11); color: Theme.c.accentDim
                }
            }
            Rectangle { x: 10; y: bar.y + bar.height; width: parent.width - 20; height: 1; color: Theme.c.bg3 }

            ListView {
                id: list
                x: 10; y: bar.y + bar.height + 6
                width: parent.width - 20
                height: win.rowsShown * win.rowH
                clip: true
                model: Apps.results
                currentIndex: win.selected
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.selected
                    readonly property bool special: !!modelData.special
                    readonly property string sub: special ? modelData.comment : (modelData.genericName || "")
                    width: list.width; height: win.rowH
                    radius: Theme.radiusSm
                    color: sel ? Theme.c.bg2 : rowMouse.containsMouse ? Theme.alpha(Theme.c.bg2, 0.5) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    // the selected row's accent bar, as in the menu and clipboard
                    Rectangle { visible: row.sel; width: 3; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter
                                radius: 1.5; color: Theme.c.accentBright }
                    Item {
                        id: ico
                        x: 12; width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter
                        IconImage {
                            anchors.centerIn: parent
                            visible: !row.special
                            implicitSize: 22
                            source: !row.special && row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: row.special || !row.modelData.icon
                            icon: row.special ? row.modelData.symbol : "apps"
                            size: Theme.fs(17)
                            color: row.special || row.sel ? Theme.c.accentBright : Theme.c.accentMid
                        }
                    }
                    Label {
                        id: name
                        anchors.left: ico.right; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - 70)
                        elide: Text.ElideRight
                        text: row.modelData.name; font.pixelSize: Theme.fs(12.5)
                        font.weight: row.special ? Font.DemiBold : Font.Normal
                        color: row.sel ? Theme.c.accentBright : Theme.c.fg
                    }
                    Label {
                        anchors.left: name.right; anchors.leftMargin: 10
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: row.sub; font.pixelSize: Theme.fs(10.5); color: Theme.c.accentDim
                    }
                    // click only: hovering never moves the selection
                    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Apps.launch(row.modelData) }
                }
                Label { visible: Apps.results.length === 0; anchors.centerIn: parent
                        text: "Nothing found"; font.pixelSize: Theme.fs(12); color: Theme.c.accentDim }
            }
        }
    }
}
