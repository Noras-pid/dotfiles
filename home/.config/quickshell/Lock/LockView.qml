import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Bar
import qs.Services

Item {
    id: view
    property bool preview: false
    readonly property bool compact: width < 900 || height < 700
    readonly property real inset: Math.max(28, Math.min(160, width * 0.085))
    readonly property real clockTop: compact ? 44 : height * 0.14
    readonly property color accent: Theme.c.accentBright
    function submit() {
        if (!preview && !Lock.busy && password.text.length > 0) Lock.tryPassword(password.text)
    }
    function focusInput() { password.forceActiveFocus() }

    Image {
        anchors.fill: parent
        source: "file://" + Wallpaper.path + "?g=" + Wallpaper.generation
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(view.width, view.height)
        cache: false
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.c.bg0, 0.12)
    }
    Rectangle {
        anchors.left: parent.left
        height: parent.height
        width: Math.min(parent.width, 820)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.alpha(Theme.c.bg0, 0.88) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    Column {
        id: clockBlock
        x: view.inset; y: view.clockTop
        spacing: 4
        Label {
            text: Qt.formatTime(clock.date, "HH:mm")
            font.pixelSize: view.compact ? 72 : 104
            font.weight: Font.Light
            font.letterSpacing: -3
            color: Theme.c.accentLight
        }
        Label {
            text: Qt.locale("en_US").toString(clock.date, "dddd, d MMMM")
            font.pixelSize: 18
            font.weight: Font.Normal
            color: Theme.c.accentMid
        }
    }

    Rectangle {
        id: card
        x: view.inset
        y: Math.min(parent.height - height - 104, Math.max(clockBlock.y + clockBlock.height + 44, parent.height * 0.43))
        width: Math.min(400, parent.width - view.inset * 2)
        height: 190
        radius: 10
        color: Theme.alpha(Theme.c.bg1, 0.94)
        border.width: 1
        border.color: Theme.alpha(view.accent, 0.24)

        Label {
            x: 24; y: 23
            text: Quickshell.env("USER")
            font.pixelSize: 24
            font.weight: Font.DemiBold
            color: Theme.c.fg
        }
        Rectangle {
            id: field
            x: 24; y: 70
            width: parent.width - 48; height: 50
            radius: 6
            color: Theme.c.bg0
            border.width: 1
            border.color: Lock.error !== "" ? Theme.c.critical : password.activeFocus ? view.accent : Theme.c.bg3
            opacity: Lock.busy ? 0.6 : 1
            TextInput {
                id: password
                anchors.left: parent.left; anchors.leftMargin: 15
                anchors.right: enterButton.left; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font; font.pixelSize: 17
                color: Theme.c.accentLight
                selectionColor: Theme.c.bg3
                selectedTextColor: Theme.c.fg
                echoMode: TextInput.Password
                passwordCharacter: "●"
                cursorVisible: activeFocus
                enabled: !Lock.busy
                focus: true
                clip: true
                onAccepted: view.submit()
                Keys.onEscapePressed: clear()
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"
                    visible: password.text.length === 0
                    color: Theme.c.accentMid
                    font.pixelSize: 15
                    font.weight: Font.Normal
                }
            }
            Rectangle {
                id: enterButton
                anchors.right: parent.right; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 5
                color: click.containsMouse ? Theme.c.accentLight : view.accent
                Label {
                    anchors.centerIn: parent
                    text: "→"
                    font.pixelSize: 22
                    color: Theme.c.bg0
                }
                MouseArea {
                    id: click
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Lock.busy
                    onClicked: view.submit()
                }
            }
        }
        Label {
            x: 24; y: 137
            width: parent.width - 48
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            font.weight: Font.Normal
            color: Lock.error !== "" ? Theme.c.critical : Theme.c.accentMid
            text: Lock.busy ? "Checking…"
                  : Lock.error === "Wrong password" ? "Wrong password. Try again."
                  : Lock.error === "Too many attempts" ? "Too many attempts. Wait a moment."
                  : Lock.error !== "" ? "Could not check the password."
                  : "Enter to unlock"
        }
    }

    Label {
        x: view.inset
        anchors.bottom: parent.bottom; anchors.bottomMargin: 32
        text: "Alt+Shift to switch layout"
        font.pixelSize: 12
        font.weight: Font.Normal
        color: Theme.c.accentMid
    }
    readonly property var player: Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Playing) || null
    Label {
        anchors.right: parent.right; anchors.rightMargin: view.inset
        anchors.bottom: parent.bottom; anchors.bottomMargin: 32
        width: Math.min(parent.width * 0.4, 440)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        visible: view.player !== null
        text: view.player ? (view.player.trackTitle || "") + (view.player.trackArtist ? " / " + view.player.trackArtist : "") : ""
        font.pixelSize: 12
        color: Theme.c.accentMid
    }
    Connections {
        target: Lock
        function onErrorChanged() { if (Lock.error !== "") { password.clear(); password.forceActiveFocus() } }
        function onLockedChanged() { password.clear(); if (Lock.locked) Qt.callLater(view.focusInput) }
    }
    Component.onCompleted: Qt.callLater(view.focusInput)
}
