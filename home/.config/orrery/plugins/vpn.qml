import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Bar
import qs.Services
import qs.Panels

Pill {
    id: w

    readonly property var servers: [
        { id: "vpnmine-poland", name: "Poland", city: "VPNmine" }
    ]
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/vpn-last"
    property string active: ""
    property string last: "vpnmine-poland"
    property bool busy: false
    property string ip: ""
    property string city: ""
    property string cc: ""
    property bool geoFailed: false
    readonly property bool up: active !== ""
    readonly property string country: cc === "" ? "" : (Qt.locale("en_" + cc).nativeCountryName || cc)

    function unit(id) { return "wg-quick@" + id }
    function refresh() { if (!state.running) state.running = true }
    function loadGeo() { if (up && !geo.running) geo.running = true }
    function clearGeo() { ip = ""; city = ""; cc = ""; geoFailed = false }
    function connect(id) {
        if (busy || id === active) return
        busy = true
        last = id
        clearGeo()
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname '" + stateFile + "')\"; echo " + id + " > '" + stateFile + "'; sudo -n systemctl start " + unit(id)])
        settle.restart()
    }
    function disconnect() {
        if (busy || !up) return
        busy = true
        clearGeo()
        Quickshell.execDetached(["sudo", "-n", "systemctl", "stop", unit(active)])
        settle.restart()
    }
    function setUp(want) { want ? connect(last) : disconnect() }

    Process {
        running: true
        command: ["cat", w.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                const id = text.trim()
                if (w.servers.some(s => s.id === id)) w.last = id
            }
        }
    }

    Process {
        id: state
        command: ["systemctl", "is-active"].concat(w.servers.map(s => w.unit(s.id)))
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                let now = ""
                w.servers.forEach((s, i) => { if (lines[i] === "active") now = s.id })
                if (now !== w.active) {
                    w.clearGeo()
                    w.active = now
                    if (now !== "") geoDelay.restart()
                }
            }
        }
    }

    Process {
        id: geo
        command: ["curl", "-s", "-m", "10", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    w.ip = j.ip || ""
                    w.city = j.city || ""
                    w.cc = j.country || ""
                    w.geoFailed = w.ip === ""
                } catch (e) {
                    w.geoFailed = true
                }
            }
        }
    }

    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: w.refresh() }
    Timer { id: geoDelay; interval: 1500; onTriggered: w.loadGeo() }
    Timer { id: settle; interval: 2000; onTriggered: { w.busy = false; w.refresh() } }

    onClicked: Panels.toggle("vpn", w)
    onRightClicked: w.setUp(!w.up)

    Row {
        spacing: 3
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: "vpn_key"
            color: w.up ? Theme.c.accentBright : Theme.c.accentDim
            opacity: w.busy ? 0.5 : 1
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: w.pillMode && !w.vertical && w.up
            text: w.cc
            color: Theme.c.fg
        }
    }

    Panel {
        name: "vpn"
        anchorItem: w
        panelWidth: 320
        onOpenChanged: if (open) { w.refresh(); w.loadGeo() }

        PanelHeader {
            title: "VPN"
            detail: w.busy ? "…" : (w.up ? "on" : "off")
            showToggle: true
            toggle.on: w.up
            onToggled: (on) => w.setUp(on)
            actions: [
                IconButton {
                    visible: w.up
                    icon: "refresh"
                    onClicked: w.loadGeo()
                }
            ]
        }

        PanelSection { text: "Server" }

        Repeater {
            model: w.servers
            delegate: PanelRow {
                required property var modelData
                icon: "language"
                title: modelData.name
                subtitle: modelData.city
                active: w.active === modelData.id
                busy: w.busy && w.last === modelData.id
                trailing: w.active === modelData.id ? "connected" : ""
                onClicked: w.connect(modelData.id)
            }
        }

        PanelDivider { visible: w.up }

        PanelRow {
            visible: w.up
            icon: "lock"
            check: false
            title: w.ip !== "" ? w.ip : (w.geoFailed ? "Address unknown" : "Locating…")
            subtitle: w.country !== "" ? "Exit · " + w.country + (w.city !== "" ? ", " + w.city : "") : "Exit address"
        }
        PanelRow {
            visible: w.up
            icon: "vpn_key"
            check: false
            title: "WireGuard · VPNmine"
            subtitle: "All traffic via " + w.active
        }
    }
}
