pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Pending package updates: repo packages from checkupdates (pacman-contrib,
// a private copy of the sync db, so pacman's own is never touched) and AUR
// packages from yay -Qua. Checked a minute after login, then every two hours.
Singleton {
    id: root
    property var items: []            // { name, from, to, aur, important }
    property bool checking: false
    property date checked: new Date(0)
    readonly property int count: items.length
    readonly property int importantCount: items.filter(i => i.important).length
    // packages whose update usually wants a reboot or a re-login
    readonly property var importantRe: /^(linux(-cachyos)?(-lts)?(-headers)?|nvidia.*|lib32-nvidia.*|mesa|lib32-mesa|hyprland|aquamarine|hyprutils|quickshell.*|systemd|glibc|xdg-desktop-portal.*|pipewire|wireplumber|grub|mkinitcpio)$/

    function check() {
        if (proc.running) return
        checking = true
        proc.running = true
    }
    // a full upgrade in the floating terminal; the password is typed there
    function update() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/orrery-float", "yay -Syu"])
        recheck.restart()
    }

    Process {
        id: proc
        command: ["sh", "-c", "checkupdates 2>/dev/null; echo '--aur--'; command -v yay >/dev/null && yay -Qua 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            const out = []
            let aur = false
            for (const line of text.split("\n")) {
                if (line === "--aur--") { aur = true; continue }
                const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                if (m) out.push({ name: m[1], from: m[2], to: m[3], aur: aur, important: root.importantRe.test(m[1]) })
            }
            out.sort((a, b) => (b.important - a.important) || a.name.localeCompare(b.name))
            root.items = out
            root.checked = new Date()
            root.checking = false
        } }
        onExited: (code) => { if (root.checking) root.checking = false }
    }
    Timer { interval: 60 * 1000; running: true; onTriggered: root.check() }                       // network up first
    Timer { interval: 2 * 3600 * 1000; running: true; repeat: true; onTriggered: root.check() }
    // after an upgrade started from the panel: look again once it is likely done
    Timer { id: recheck; interval: 5 * 60 * 1000; onTriggered: root.check() }

    IpcHandler {
        target: "updates"
        function check(): void { root.check() }
        function count(): int { return root.count }
    }
}
