import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Panels

// CPU use + temperature, memory, and GPU temperature/use; click opens btop in the default terminal.
// CPU and memory are read from /proc here (no process per poll). The GPU
// source is found once by Services/sysmon.sh: a sysfs busy-percent file is
// read directly too; only an NVIDIA card needs the script per poll, and it
// leaves a sleeping laptop dGPU alone (the GPU half then hides).
Pill {
    id: sm
    property int cpu: 0
    property int mem: 0
    property int gpu: -1
    property int cpuTemp: -1           // °C of the CPU package
    property int gpuTemp: -1           // °C of the NVIDIA card while it is awake
    property string cpuTempSource: ""  // hwmon temp file, found once by sysmon.sh
    property var last: null
    property string gpuSource: ""      // "", "nvidia" or a sysfs file
    onClicked: Panels.toggle("system", sm)

    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: cpuTempFile; path: sm.cpuTempSource; blockLoading: true }
    FileView { id: gpuFile; path: sm.gpuSource.startsWith("/") ? sm.gpuSource : ""; blockLoading: true }
    function sample() {
        stat.reload()
        const f = stat.text().split("\n", 1)[0].trim().split(/\s+/).slice(1).map(Number)   // user nice system idle iowait irq softirq steal
        const idle = f[3] + f[4], total = f.slice(0, 8).reduce((a, b) => a + b, 0)
        if (last && total > last.total) cpu = Math.round(100 * (1 - (idle - last.idle) / (total - last.total)))
        last = { idle: idle, total: total }
        meminfo.reload()
        const m = meminfo.text(), kb = k => { const x = m.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")); return x ? +x[1] : 0 }
        const tot = kb("MemTotal")
        if (tot > 0) mem = Math.round(100 - 100 * kb("MemAvailable") / tot)
        if (cpuTempSource) { cpuTempFile.reload(); const t = parseInt(cpuTempFile.text()); cpuTemp = isNaN(t) ? -1 : Math.round(t / 1000) }
        if (gpuSource.startsWith("/")) { gpuFile.reload(); const g = parseInt(gpuFile.text()); gpu = isNaN(g) ? -1 : g }
        else if (gpuSource === "nvidia" && !nv.running && nvTick++ % 3 === 0) nv.running = true   // nvidia-smi costs a fork + ~20 ms: every 9 s
    }
    property int nvTick: 0
    Process {   // once: where the GPU load comes from
        command: ["bash", Quickshell.shellPath("Services/sysmon.sh"), "gpu-source"]
        running: true
        stdout: StdioCollector { onStreamFinished: sm.gpuSource = text.trim() === "none" ? "" : text.trim() }
    }
    Process {   // once: where the CPU temperature comes from
        command: ["bash", Quickshell.shellPath("Services/sysmon.sh"), "cpu-temp-source"]
        running: true
        stdout: StdioCollector { onStreamFinished: sm.cpuTempSource = text.trim() === "none" ? "" : text.trim() }
    }
    Process {
        id: nv
        command: ["bash", Quickshell.shellPath("Services/sysmon.sh"), "gpu"]
        stdout: StdioCollector { onStreamFinished: {
            const f = text.trim().split(/\s+/).map(Number)       // "<busy> <temp>", empty while asleep
            sm.gpu = f.length > 0 && !isNaN(f[0]) && text.trim() !== "" ? f[0] : -1
            sm.gpuTemp = f.length > 1 && !isNaN(f[1]) ? f[1] : -1
        } }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: sm.sample() }
    readonly property color hot: Theme.hued ? Theme.c.warning : Theme.c.accentBright
    // each icon sits with its number; the pill's gap separates the pairs
    gap: pillMode ? 13 : 7
    // each reading keeps the width of "88%" (Reading.qml), so 5% → 12% doesn't
    // push the bar; in a side bar they stack, number under icon
    // CPU and GPU: the ring is the load, the number the temperature; hovering
    // the widget swaps the numbers for the load in percent. Memory is a ring
    // too, with its percent. Each number keeps the width of "88%" (FixedLabel).
    Gauge {
        icon: "speed"
        load: sm.cpu
        text: sm.hovered || sm.cpuTemp < 0 ? sm.cpu + "%" : sm.cpuTemp + "°"
        widest: "88%"
        hot: sm.cpu > 85 || sm.cpuTemp >= 85
    }
    Gauge { icon: "sd_card"; load: sm.mem; text: sm.mem + "%"; widest: "88%"; hot: sm.mem > 85 }
    Gauge {
        visible: sm.gpu >= 0
        icon: "videogame_asset"
        load: sm.gpu
        text: sm.hovered || sm.gpuTemp < 0 ? sm.gpu + "%" : sm.gpuTemp + "°"
        widest: "88%"
        hot: sm.gpu > 85 || sm.gpuTemp >= 80
    }
    SystemPanel { anchorItem: sm; mon: sm }
}
