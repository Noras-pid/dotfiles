import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Commons
import qs.Bar
import qs.Services

// One notification: icon, app + time, summary, body, action buttons.
Rectangle {
    id: card
    required property var entry
    property bool compact: false
    property bool showApp: true       // the centre groups by app, so its cards leave the name out
    property real progress: -1        // popup: time left 1 → 0, drawn as a line along the bottom
    readonly property bool hovered: hover.hovered
    readonly property var n: entry.n || ({ summary: "", body: "", appName: "", appIcon: "", image: "", actions: [], urgency: 1 })
    readonly property bool critical: n.urgency === NotificationUrgency.Critical
    // actions worth a button: apps also send a hidden "default" one (a click on
    // the card runs it) and some send none with a label, which drew empty buttons
    // apps that send no icon (notify-send, Firefox) usually have one under their own name
    readonly property string iconSrc: n.image !== "" ? n.image
        : n.appIcon !== "" && Quickshell.iconPath(n.appIcon, true) !== "" ? Quickshell.iconPath(n.appIcon, true)
        : n.appName !== "" ? Quickshell.iconPath(n.appName.toLowerCase().replace(/\s+/g, "-"), true) : ""
    readonly property string appLabel: n.appName ? n.appName.charAt(0).toUpperCase() + n.appName.slice(1) : ""
    readonly property var buttons: (n.actions || []).filter(a => a && a.text && a.text.trim() !== "" && a.identifier !== "default")

    width: parent.width
    implicitHeight: col.implicitHeight + 24
    radius: Theme.radius
    color: Theme.c.bg1
    border.width: 1
    border.color: critical ? (Theme.hued ? Theme.alpha(Theme.c.critical, 0.67) : Theme.c.borderStrong) : Theme.c.border
    Behavior on color { ColorAnimation { duration: 150 } }

    HoverHandler { id: hover }

    function ago() {
        void Notifs.tick
        const s = Math.round((Date.now() - entry.time.getTime()) / 1000)
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + " min" : s < 86400 ? Math.floor(s / 3600) + " h" : Math.floor(s / 86400) + " d"
    }

    Row {
        id: col
        x: 12; y: 12
        width: parent.width - 24
        spacing: 10

        // icon: the notification's image, else the app icon, else a glyph
        Item {
            width: 32; height: 32
            IconImage {
                anchors.fill: parent
                visible: card.iconSrc !== ""
                source: card.iconSrc
                implicitSize: 32
            }
            Icon { anchors.centerIn: parent; visible: card.iconSrc === ""
                   icon: card.critical ? "error" : "notifications"; size: Theme.fs(22)
                   color: card.critical && Theme.hued ? Theme.c.critical : Theme.c.accentMid }
        }

        Column {
            width: parent.width - 42
            spacing: 3
            Row {
                visible: card.showApp
                width: parent.width
                Label { text: card.appLabel; font.pixelSize: Theme.fs(11); color: Theme.c.accentMid; width: parent.width - 60; elide: Text.ElideRight }
                Label { text: card.ago(); font.pixelSize: Theme.fs(11); color: Theme.c.accentDim; width: 60; rightPadding: 16; horizontalAlignment: Text.AlignRight }
            }
            // without the app line the time rides on the title's line
            Item {
                width: parent.width
                height: sum.implicitHeight
                Label { id: sum; width: parent.width - (card.showApp ? 0 : 64); text: card.n.summary; font.pixelSize: Theme.fs(13); font.weight: Font.Bold
                        color: card.critical && Theme.hued ? Theme.c.critical : Theme.c.accentBright; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                Label { visible: !card.showApp; anchors.right: parent.right; anchors.rightMargin: 16; y: 1
                        text: card.ago(); font.pixelSize: Theme.fs(11); color: Theme.c.accentDim }
            }
            Label { visible: card.n.body !== ""; width: parent.width; text: card.n.body; textFormat: Text.StyledText
                    font.pixelSize: Theme.fs(12); color: Theme.c.fg; wrapMode: Text.WordWrap; maximumLineCount: card.compact ? 3 : 6; elide: Text.ElideRight }
            Row {
                visible: card.buttons.length > 0
                spacing: 6
                topPadding: 4
                Repeater {
                    model: card.buttons
                    Rectangle {
                        required property var modelData
                        implicitWidth: al.implicitWidth + 20; implicitHeight: 24; radius: Theme.radius
                        color: am.containsMouse ? Theme.c.bg3 : Theme.c.bg2
                        border.width: 1; border.color: Theme.c.border
                        Label { id: al; anchors.centerIn: parent; text: modelData.text; font.pixelSize: Theme.fs(11) }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { modelData.invoke(); Notifs.dismiss(card.entry) } }
                    }
                }
            }
        }
    }

    // critical: a bar down the left edge, in the critical colour
    Rectangle {
        visible: card.critical
        x: 1; y: 1; width: 3; height: parent.height - 2
        topLeftRadius: Math.max(0, card.radius - 1); bottomLeftRadius: Math.max(0, card.radius - 1)
        color: Theme.hued ? Theme.c.critical : Theme.c.accentBright
    }
    // popup countdown; it stops while the pointer is on the card
    Rectangle {
        visible: card.progress >= 0
        anchors.bottom: parent.bottom; anchors.bottomMargin: 1
        x: 1; height: 2
        width: Math.max(0, (parent.width - 2) * card.progress)
        color: card.critical && Theme.hued ? Theme.c.critical : Theme.c.accentBright
        opacity: card.hovered ? 0.35 : 0.8
        Behavior on opacity { NumberAnimation { duration: Motion.fadeMs } }
        Behavior on width { NumberAnimation { duration: 100 } }
    }

    // close
    Icon {
        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
        icon: "close"; size: Theme.fs(15); color: cm.containsMouse ? Theme.c.accentBright : Theme.c.accentDim
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.dismiss(card.entry) }
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (e) => e.button === Qt.MiddleButton ? Notifs.dismiss(card.entry) : Notifs.invokeDefault(card.entry)
    }
}
