import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Bar
import qs.Services

// Under sysmon: CPU, memory, swap, disk and GPU as meters, uptime, and the
// processes using the most CPU. `mon` is the bar's SysMon (its live numbers);
// everything else is read only while the panel is open.
Panel {
    id: p
    name: "system"
    panelWidth: 372
    required property var mon
    property string cpuName: ""
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real diskTotal: 0
    property real diskUsed: 0
    property real uptime: 0
    property var procs: []

    function gib(b) { return (b / 1073741824).toFixed(1) }
    function upText(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m"
    }
    function level(v, warn, crit) {     // hued themes colour a meter the way btop does
        if (!Theme.hued) return Theme.c.accentBright
        return v >= crit ? Theme.c.critical : v >= warn ? Theme.c.warning : Theme.c.good
    }

    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: up; path: "/proc/uptime"; blockLoading: true }
    FileView { id: cpuinfo; path: "/proc/cpuinfo"; blockLoading: true }
    function sample() {
        meminfo.reload()
        const m = meminfo.text(), kb = k => { const x = m.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")); return x ? +x[1] * 1024 : 0 }
        memTotal = kb("MemTotal"); memUsed = memTotal - kb("MemAvailable")
        swapTotal = kb("SwapTotal"); swapUsed = swapTotal - kb("SwapFree")
        up.reload(); uptime = parseFloat(up.text()) || 0
        if (!ps.running) ps.running = true
    }
    Process {
        id: df
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector { onStreamFinished: {
            const f = text.trim().split("\n").pop().trim().split(/\s+/).map(Number)
            if (f.length === 2) { p.diskTotal = f[0]; p.diskUsed = f[1] }
        } }
    }
    Process {
        id: ps
        command: ["sh", "-c", "ps -eo pcpu,rss,comm --sort=-pcpu --no-headers | grep -v -e ' ps$' -e ' sh$' | head -n 5"]
        stdout: StdioCollector { onStreamFinished: {
            p.procs = text.trim().split("\n").slice(0, 5).map(l => {
                const f = l.trim().split(/\s+/)
                return { cpu: parseFloat(f[0]) || 0, mem: (+f[1] || 0) * 1024, name: f.slice(2).join(" ") }
            })
        } }
    }
    Timer { interval: 3000; running: p.open; repeat: true; triggeredOnStart: true; onTriggered: p.sample() }
    onOpenChanged: if (open) {
        df.running = true
        if (!cpuName) { cpuinfo.reload(); const x = cpuinfo.text().match(/^model name\s*:\s*(.+)$/m); cpuName = x ? x[1].replace(/\(R\)|\(TM\)|CPU|@.*$/g, "").replace(/\s+/g, " ").trim() : "" }
    }

    component Meter: Column {
        id: mt
        property string icon
        property string title
        property string value
        property real frac: 0
        property color tone: Theme.c.accentBright
        width: parent.width; spacing: 6
        Item {
            width: parent.width; height: 18
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                Icon { anchors.verticalCenter: parent.verticalCenter; icon: mt.icon; size: Theme.fs(15); color: Theme.c.accentLight }
                Label { anchors.verticalCenter: parent.verticalCenter; text: mt.title; font.pixelSize: Theme.fs(12); color: Theme.c.fg }
            }
            Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: mt.value
                    font.pixelSize: Theme.fs(11.5); color: Theme.c.accentMid }
        }
        Rectangle {
            width: parent.width; height: 5; radius: 2.5; color: Theme.c.bg2
            Rectangle {
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, mt.frac))); height: parent.height; radius: 2.5
                color: mt.tone
                Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Easing.OutCubic } }
            }
        }
    }

    PanelHeader { title: "System"; detail: p.uptime > 0 ? "up " + p.upText(p.uptime) : "" }

    Meter {
        icon: "developer_board"
        title: p.cpuName || "Processor"
        value: p.mon.cpu + "%" + (p.mon.cpuTemp >= 0 ? " · " + p.mon.cpuTemp + "°" : "")
        frac: p.mon.cpu / 100
        tone: p.level(Math.max(p.mon.cpu, p.mon.cpuTemp), 70, 85)
    }
    Meter {
        icon: "memory_alt"
        title: "Memory"
        value: p.gib(p.memUsed) + " / " + p.gib(p.memTotal) + " GiB"
        frac: p.memTotal ? p.memUsed / p.memTotal : 0
        tone: p.level(p.memTotal ? 100 * p.memUsed / p.memTotal : 0, 75, 90)
    }
    Meter {
        visible: p.swapTotal > 0
        icon: "memory"
        title: "Swap (zram)"
        value: p.gib(p.swapUsed) + " / " + p.gib(p.swapTotal) + " GiB"
        frac: p.swapTotal ? p.swapUsed / p.swapTotal : 0
        tone: p.level(p.swapTotal ? 100 * p.swapUsed / p.swapTotal : 0, 60, 85)
    }
    Meter {
        visible: p.diskTotal > 0
        icon: "hard_drive"
        title: "Disk /"
        value: p.gib(p.diskUsed) + " / " + p.gib(p.diskTotal) + " GiB"
        frac: p.diskTotal ? p.diskUsed / p.diskTotal : 0
        tone: p.level(p.diskTotal ? 100 * p.diskUsed / p.diskTotal : 0, 80, 92)
    }
    Meter {
        visible: p.mon.gpu >= 0
        icon: "videogame_asset"
        title: "GTX 1050"
        value: p.mon.gpu + "%" + (p.mon.gpuTemp >= 0 ? " · " + p.mon.gpuTemp + "°" : "")
        frac: p.mon.gpu / 100
        tone: p.level(Math.max(p.mon.gpu, p.mon.gpuTemp), 70, 85)
    }

    PanelSection { text: "Top processes"; detail: "CPU" }
    Column {
        width: parent.width; spacing: 0
        Repeater {
            model: p.procs
            Item {
                required property var modelData
                width: parent.width; height: 26
                Label { anchors.left: parent.left; anchors.leftMargin: 4; anchors.right: mem.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        text: modelData.name; font.pixelSize: Theme.fs(12); color: Theme.c.fg }
                Label { id: mem; anchors.right: cpu.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 64; horizontalAlignment: Text.AlignRight
                        text: modelData.mem >= 1073741824 ? p.gib(modelData.mem) + " GiB" : Math.round(modelData.mem / 1048576) + " MiB"
                        font.pixelSize: Theme.fs(11.5); color: Theme.c.accentMid }
                Label { id: cpu; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                        width: 48; horizontalAlignment: Text.AlignRight
                        text: modelData.cpu.toFixed(1) + "%"; font.pixelSize: Theme.fs(12); font.weight: Font.DemiBold
                        color: modelData.cpu >= 50 && Theme.hued ? Theme.c.warning : Theme.c.accentLight }
            }
        }
    }

    PanelButton {
        width: parent.width
        icon: "speed"
        text: "Open btop"
        onClicked: { Panels.close(); Quickshell.execDetached(["sh", "-c", 'exec "${TERMINAL:-$(cat "$HOME/.config/orrery/defaults/terminal" 2>/dev/null || echo kitty)}" -e btop']) }
    }
}
