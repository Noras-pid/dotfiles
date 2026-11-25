import QtQuick
import qs.Commons
import qs.Services
import qs.Panels

// Updates remain accessible before the first check and when up to date. The icon takes the
// warning colour when a kernel, driver or the compositor is among them.
Pill {
    id: w
    onClicked: Panels.toggle("updates", w)
    onRightClicked: Updates.check()
    readonly property color tone: Updates.importantCount > 0 && Theme.hued ? Theme.c.warning : Theme.c.accentLight
    Row {
        spacing: 4
        Icon { anchors.verticalCenter: parent.verticalCenter; icon: "deployed_code_update"; color: w.tone }
        FixedLabel {
            anchors.verticalCenter: parent.verticalCenter
            visible: !w.vertical
            text: Updates.checking ? "…" : Updates.checked.getTime() === 0 ? "—" : String(Updates.count)
            widest: "888"
            color: w.tone
        }
    }
    UpdatesPanel { anchorItem: w }
}
