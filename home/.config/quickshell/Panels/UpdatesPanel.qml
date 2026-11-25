import QtQuick
import qs.Commons
import qs.Bar
import qs.Services

// Under the updates widget: the important packages first (kernel, drivers,
// compositor: they want a reboot), then the rest folded after a dozen, and
// one button that runs the full upgrade in a floating terminal.
Panel {
    id: p
    name: "updates"
    panelWidth: 392
    property bool expanded: false
    readonly property int shown: expanded ? Updates.count : Math.min(Updates.count, 12)
    function ago() {
        const m = Math.round((Date.now() - Updates.checked.getTime()) / 60000)
        return Updates.checking ? "checking…" : m < 1 ? "checked just now" : m < 60 ? "checked " + m + "m ago" : "checked at " + Qt.formatTime(Updates.checked, "HH:mm")
    }
    onOpenChanged: if (open) { expanded = false; if (Date.now() - Updates.checked.getTime() > 15 * 60 * 1000) Updates.check() }

    PanelHeader {
        title: "Updates"
        detail: Updates.count > 0 ? String(Updates.count) : ""
        actions: [ IconButton { icon: "refresh"; opacity: Updates.checking ? 0.4 : 1; onClicked: Updates.check() } ]
    }

    EmptyState {
        visible: Updates.count === 0
        icon: "deployed_code_update"
        text: Updates.checking ? "Checking for updates…" : "Everything is up to date"
        hint: p.ago()
    }

    Label {
        visible: Updates.importantCount > 0
        width: parent.width; wrapMode: Text.WordWrap
        text: Updates.importantCount + (Updates.importantCount === 1 ? " package needs" : " packages need") + " a reboot after updating (kernel, drivers or the compositor)"
        font.pixelSize: Theme.fs(11); color: Theme.hued ? Theme.c.warning : Theme.c.accentMid
    }

    Flickable {
        visible: Updates.count > 0
        width: parent.width
        height: Math.min(list.implicitHeight, 420)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: list
            width: parent.width
            Repeater {
                model: Updates.items.slice(0, p.shown)
                Item {
                    required property var modelData
                    width: list.width; height: 26
                    Rectangle {
                        visible: modelData.important
                        x: 0; anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 14; radius: 1.5
                        color: Theme.hued ? Theme.c.warning : Theme.c.accentBright
                    }
                    Label {
                        anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.42; elide: Text.ElideRight
                        text: modelData.name + (modelData.aur ? "  ·  AUR" : "")
                        font.pixelSize: Theme.fs(12); font.weight: modelData.important ? Font.DemiBold : Font.Normal
                        color: modelData.important ? Theme.c.accentBright : Theme.c.fg
                    }
                    Label {
                        anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.55; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                        text: modelData.from + "  →  " + modelData.to
                        font.pixelSize: Theme.fs(11); color: Theme.c.accentMid
                    }
                }
            }
        }
    }
    PanelButton {
        visible: !p.expanded && Updates.count > p.shown
        width: parent.width
        text: (Updates.count - p.shown) + " more"
        onClicked: p.expanded = true
    }

    Item {
        visible: Updates.count > 0
        width: parent.width; height: 32
        Label { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: p.ago(); font.pixelSize: Theme.fs(10.5); color: Theme.c.accentDim }
        PanelButton {
            anchors.right: parent.right
            primary: true
            icon: "upgrade"
            text: "Update now"
            onClicked: { Panels.close(); Updates.update() }
        }
    }
}
