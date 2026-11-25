import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Bar
import qs.Services

// Control centre: who and how long, six quick toggles (Wi-Fi, Bluetooth,
// night light, do not disturb, caffeine, game mode), volume, microphone and
// brightness. The arrows on Wi-Fi / Bluetooth and the speaker icon open the
// detailed panels under the same bar widget.
Panel {
    id: p
    name: "control"
    panelWidth: 352
    spacing: 14

    // ---- state -----------------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [p.sink, p.source] }

    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wiredDev: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) || null
    function wifiName() {
        if (p.wiredDev) return "Ethernet"
        if (!Networking.wifiEnabled) return "Off"
        if (p.wifiDev) for (const n of p.wifiDev.networks.values) if (n.connected) return n.name
        return "Not connected"
    }

    property bool gamemode: false
    property real uptime: 0
    property real bright: 0
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    Process {
        id: poll
        command: ["sh", "-c", "test -e \"$XDG_RUNTIME_DIR/orrery-gamemode\" && echo g=1 || echo g=0; "
                            + "cut -d' ' -f1 /proc/uptime | sed 's/^/u=/'; "
                            + "d=$(brightnessctl -l -m -c backlight | grep -vi nvidia | head -n1 | cut -d, -f1); "
                            + "brightnessctl -m -d \"$d\" | cut -d, -f4 | tr -d % | sed 's/^/b=/'"]
        stdout: SplitParser {
            onRead: (l) => {
                if (l.startsWith("g=")) p.gamemode = l === "g=1"
                else if (l.startsWith("u=")) p.uptime = parseFloat(l.slice(2))
                else if (l.startsWith("b=") && !brightSlider.dragging) p.bright = parseFloat(l.slice(2)) / 100
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: p.open; triggeredOnStart: true; onTriggered: poll.running = true }
    Process { id: run }
    function exec(cmd) { run.command = cmd; run.running = true }
    function setBright(v) {
        p.bright = v
        exec(["sh", "-c", "d=$(brightnessctl -l -m -c backlight | grep -vi nvidia | head -n1 | cut -d, -f1); brightnessctl -q -d \"$d\" set " + Math.max(5, Math.round(v * 100)) + "%"])
    }
    function upText(s) {
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
        return "up " + (h > 0 ? h + "h " : "") + m + "m"
    }

    // ---- who, and the power buttons ---------------------------------------------------
    Item {
        width: parent.width; height: 40
        Rectangle {
            id: avatar
            width: 36; height: 36; radius: 18
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.alpha(Theme.c.accentBright, 0.16)
            border.width: 1; border.color: Theme.alpha(Theme.c.accentBright, 0.35)
            Label {
                anchors.centerIn: parent
                text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                font.pixelSize: Theme.fs(15); font.weight: Font.DemiBold; color: Theme.c.accentBright
            }
        }
        Column {
            anchors.left: avatar.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Label { text: Quickshell.env("USER") || ""; font.pixelSize: Theme.fs(13); font.weight: Font.DemiBold }
            Label { text: p.upText(p.uptime); font.pixelSize: Theme.fs(10.5); color: Theme.c.accentMid }
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            IconButton { icon: "lock"; onClicked: { Panels.close(); Lock.lock() } }
            IconButton { icon: "power_settings_new"; danger: true
                         onClicked: { Panels.close(); p.exec(["qs", "ipc", "call", "powermenu", "toggle"]) } }
        }
    }

    // ---- quick toggles ---------------------------------------------------------------
    Grid {
        id: grid
        width: parent.width
        columns: 2; columnSpacing: 8; rowSpacing: 8
        Repeater {
            model: [
                { id: "wifi", icon: p.wiredDev ? "lan" : Networking.wifiEnabled ? "wifi" : "wifi_off", title: p.wiredDev ? "Network" : "Wi-Fi", sub: p.wifiName(),
                  on: !!p.wiredDev || Networking.wifiEnabled, more: "network" },
                { id: "bt", icon: Bt.on ? "bluetooth" : "bluetooth_disabled", title: "Bluetooth", sub: !Bt.adapter ? "No adapter" : Bt.on ? "On" : "Off",
                  on: Bt.on, more: "bluetooth" },
                { id: "night", icon: "bedtime", title: "Night light", sub: Night.on ? Night.temp + "K" : "Off", on: Night.on, more: "" },
                { id: "dnd", icon: Notifs.dnd ? "notifications_off" : "notifications", title: "Do not disturb", sub: Notifs.dnd ? "On" : "Off", on: Notifs.dnd, more: "" },
                { id: "caffeine", icon: "coffee", title: "Caffeine", sub: Caffeine.on ? "Awake" : "Off", on: Caffeine.on, more: "" },
                { id: "game", icon: "sports_esports", title: "Game mode", sub: p.gamemode ? "Turbo on" : "Off", on: p.gamemode, more: "" }
            ]
            Rectangle {
                id: tile
                required property var modelData
                width: (grid.width - grid.columnSpacing) / 2; height: 56
                radius: Theme.radius
                color: modelData.on ? Theme.alpha(Theme.c.accentBright, tileMa.containsMouse ? 0.24 : 0.17)
                                    : tileMa.containsMouse ? Theme.c.bg2 : Theme.c.bg1
                border.width: 1
                border.color: modelData.on ? Theme.alpha(Theme.c.accentBright, 0.35) : Theme.c.border
                Behavior on color { ColorAnimation { duration: Motion.fadeMs } }
                scale: tileMa.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }

                Rectangle {
                    id: bubble
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32; radius: 16
                    color: tile.modelData.on ? Theme.c.accentBright : Theme.c.bg3
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }
                    Icon { anchors.centerIn: parent; icon: tile.modelData.icon; size: Theme.fs(16)
                           color: tile.modelData.on ? Theme.c.bg0 : Theme.c.accentLight }
                }
                Column {
                    anchors.left: bubble.right; anchors.leftMargin: 9
                    anchors.right: more.visible ? more.left : parent.right; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Label { width: parent.width; elide: Text.ElideRight; text: tile.modelData.title
                            font.pixelSize: Theme.fs(12); font.weight: Font.DemiBold }
                    Label { width: parent.width; elide: Text.ElideRight; text: tile.modelData.sub
                            font.pixelSize: Theme.fs(10.5); color: tile.modelData.on ? Theme.c.accentLight : Theme.c.accentMid }
                }
                MouseArea {
                    id: tileMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switch (tile.modelData.id) {
                        case "wifi": Networking.wifiEnabled = !Networking.wifiEnabled; break
                        case "bt": Bt.toggle(); break
                        case "night": Night.toggle(); break
                        case "dnd": Notifs.toggleDnd(); break
                        case "caffeine": Caffeine.toggle(); break
                        case "game": p.gamemode = !p.gamemode; p.exec([Quickshell.env("HOME") + "/.local/bin/orrery-gamemode"]); break
                        }
                    }
                }
                // the detailed panel (networks, devices)
                Rectangle {
                    id: more
                    visible: tile.modelData.more !== ""
                    anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: 26
                    color: moreMa.containsMouse ? Theme.alpha(Theme.c.fg, 0.06) : "transparent"
                    radius: Theme.radius
                    Icon { anchors.centerIn: parent; icon: "chevron_right"; size: Theme.fs(15); color: Theme.c.accentMid }
                    MouseArea { id: moreMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Panels.toggle(tile.modelData.more, p.anchorItem) }
                }
            }
        }
    }

    // ---- sliders ------------------------------------------------------------------------
    Column {
        width: parent.width; spacing: 10
        Repeater {
            model: [
                { id: "vol", icon: !p.sink || !p.sink.audio || p.sink.audio.muted ? "volume_off" : p.sink.audio.volume < 0.5 ? "volume_down" : "volume_up",
                  value: p.sink && p.sink.audio ? p.sink.audio.volume : 0, max: 1.5, dim: !!(p.sink && p.sink.audio && p.sink.audio.muted) },
                { id: "mic", icon: p.source && p.source.audio && p.source.audio.muted ? "mic_off" : "mic",
                  value: p.source && p.source.audio ? p.source.audio.volume : 0, max: 1, dim: !!(p.source && p.source.audio && p.source.audio.muted) },
                { id: "bright", icon: "light_mode", value: p.bright, max: 1, dim: false }
            ]
            Row {
                id: srow
                required property var modelData
                width: parent.width; spacing: 10
                Rectangle {
                    width: 30; height: 30; radius: Theme.radius
                    anchors.verticalCenter: parent.verticalCenter
                    color: icMa.containsMouse ? Theme.c.bg2 : "transparent"
                    Icon { anchors.centerIn: parent; icon: srow.modelData.icon; size: Theme.fs(16)
                           color: srow.modelData.dim ? Theme.c.accentDim : Theme.c.accentLight }
                    MouseArea {
                        id: icMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (srow.modelData.id === "vol" && p.sink && p.sink.audio) p.sink.audio.muted = !p.sink.audio.muted
                            else if (srow.modelData.id === "mic" && p.source && p.source.audio) p.source.audio.muted = !p.source.audio.muted
                        }
                    }
                }
                Slider {
                    id: sl
                    readonly property bool dragging: hot
                    width: srow.width - 30 - 44 - 2 * srow.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    value: srow.modelData.value
                    maxValue: srow.modelData.max
                    dimmed: srow.modelData.dim
                    onMoved: (v) => {
                        if (srow.modelData.id === "vol" && p.sink && p.sink.audio) p.sink.audio.volume = v
                        else if (srow.modelData.id === "mic" && p.source && p.source.audio) p.source.audio.volume = v
                        else if (srow.modelData.id === "bright") p.setBright(v)
                    }
                    Component.onCompleted: if (srow.modelData.id === "bright") brightSlider.target = sl
                }
                Label {
                    width: 44; horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(srow.modelData.value * 100) + "%"
                    font.pixelSize: Theme.fs(11.5); color: srow.modelData.dim ? Theme.c.accentDim : Theme.c.fg
                }
            }
        }
    }
    QtObject { id: brightSlider; property Item target: null; readonly property bool dragging: target ? target.hot : false }

    // ---- more ----------------------------------------------------------------------------
    Row {
        width: parent.width; spacing: 8
        Repeater {
            model: [
                { icon: "tune", text: "Sound", run: () => Panels.toggle("audio", p.anchorItem) },
                { icon: "palette", text: "Theme", run: () => { Panels.close(); p.exec(["orrery-theme-menu", "theme"]) } },
                { icon: "wallpaper", text: "Wallpaper", run: () => { Panels.close(); p.exec(["orrery-theme-menu", "wallpaper"]) } }
            ]
            Rectangle {
                required property var modelData
                width: (parent.width - 16) / 3; height: 32
                radius: Theme.radius
                color: bMa.containsMouse ? Theme.c.bg2 : "transparent"
                border.width: 1; border.color: Theme.c.border
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icon { anchors.verticalCenter: parent.verticalCenter; icon: modelData.icon; size: Theme.fs(14); color: Theme.c.accentLight }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: modelData.text; font.pixelSize: Theme.fs(11.5) }
                }
                MouseArea { id: bMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.run() }
            }
        }
    }
}
