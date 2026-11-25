pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Application launcher state: the desktop entries, a fuzzy filter, category
// chips, a launch history so what you use floats up (like rofi's drun
// sorting), and two extra rows: a calculator answer and a web search.
Singleton {
    id: root
    property bool open: false
    property string query: ""
    property string category: "all"
    property var history: ({})          // desktop id -> launch count
    readonly property string histFile: Quickshell.env("HOME") + "/.local/state/orrery/launcher.json"

    // freedesktop main categories → chips; a chip shows only when it has apps
    readonly property var categoryDefs: [
        { id: "all",      label: "All",        icon: "apps",           cats: [] },
        { id: "games",    label: "Games",       icon: "sports_esports", cats: ["Game"] },
        { id: "net",      label: "Web",   icon: "language",       cats: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
        { id: "media",    label: "Media",      icon: "movie",          cats: ["AudioVideo", "Audio", "Video", "Player"] },
        { id: "graphics", label: "Graphics",    icon: "palette",        cats: ["Graphics"] },
        { id: "dev",      label: "Dev", icon: "code",           cats: ["Development", "IDE", "TextEditor"] },
        { id: "office",   label: "Office",       icon: "work",           cats: ["Office"] },
        { id: "system",   label: "System",    icon: "settings",       cats: ["System", "Settings", "Utility", "TerminalEmulator", "FileManager"] }
    ]
    function inCategory(e, id) {
        if (id === "all") return true
        const d = categoryDefs.find(c => c.id === id)
        const cs = e.categories || []
        return !!d && cs.some(c => d.cats.indexOf(c) !== -1)
    }

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property var categories: categoryDefs.filter(d => d.id === "all" || all.some(e => inCategory(e, d.id)))
    function cycleCategory(step) {
        const ids = categories.map(c => c.id)
        const i = Math.max(0, ids.indexOf(category))
        category = ids[(i + step + ids.length) % ids.length]
    }

    // the most launched apps, for the "frequent" strip
    readonly property var frequent: all.filter(e => (history[e.id] || 0) > 0)
                                       .sort((a, b) => (history[b.id] || 0) - (history[a.id] || 0))
                                       .slice(0, 7)

    // "2+2*3", "(1.5+2)^2", "15%" → its value; anything else → ""
    readonly property string calc: {
        const q = query.trim()
        if (!/^[0-9+\-*/().,%^\s]+$/.test(q) || !/[0-9]/.test(q) || !/[+\-*/%^]/.test(q.replace(/^-/, ""))) return ""
        try {
            const v = Function('"use strict"; return (' + q.replace(/,/g, ".").replace(/\^/g, "**").replace(/(\d+(?:\.\d+)?)%/g, "($1/100)") + ")")()
            if (typeof v !== "number" || !isFinite(v)) return ""
            return String(Math.round(v * 1e10) / 1e10)
        } catch (e) { return "" }
    }

    readonly property var apps: {
        const q = query.trim().toLowerCase()
        const score = (e) => {
            const n = (e.name || "").toLowerCase(), g = (e.genericName || "").toLowerCase(), c = (e.comment || "").toLowerCase()
            const k = (e.keywords || []).join(" ").toLowerCase()
            if (q === "") return 1
            if (n.startsWith(q)) return 100
            if (n.indexOf(q) !== -1) return 60
            if (n.split(/\s+/).some(w => w.startsWith(q))) return 50
            if (g.indexOf(q) !== -1 || k.indexOf(q) !== -1) return 30
            if (c.indexOf(q) !== -1) return 20
            // subsequence match
            let i = 0; for (const ch of n) if (ch === q[i]) i++
            return i === q.length ? 10 : 0
        }
        return all.filter(e => inCategory(e, category))
                  .map(e => ({ e: e, s: score(e), h: history[e.id] || 0 }))
                  .filter(x => x.s > 0)
                  .sort((a, b) => (b.s - a.s) || (b.h - a.h) || a.e.name.localeCompare(b.e.name))
                  .map(x => x.e)
    }
    // what the list shows: the calculator answer first, the apps, and a web
    // search when nothing matched. Specials carry `special` and a Material icon.
    readonly property var results: {
        const r = []
        if (calc !== "") r.push({ special: "calc", name: "= " + calc, comment: "Enter to copy", symbol: "calculate" })
        for (const e of apps) r.push(e)
        if (query.trim() !== "" && apps.length === 0 && calc === "")
            r.push({ special: "web", name: "Search the web for “" + query.trim() + "”", comment: "Opens in your browser", symbol: "travel_explore" })
        return r
    }

    function launch(entry) {
        if (!entry) return
        if (entry.special === "calc") {
            Quickshell.execDetached(["wl-copy", calc])
        } else if (entry.special === "web") {
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(query.trim())])
        } else {
            history[entry.id] = (history[entry.id] || 0) + 1
            history = Object.assign({}, history)
            hist.setText(JSON.stringify(history))
            // own scope per app, so an OOM kill takes the app and not the session
            Quickshell.execDetached(["uwsm", "app", "--", entry.id + ".desktop"])
        }
        open = false
    }
    function reset() { query = ""; category = "all" }
    function toggle() { reset(); open = !open }

    function seedFromRofi() {
        // first run: start from rofi's drun history so the order carries over
        let t = ""
        try { t = rofiCache.text() } catch (e) { return }
        const h = {}
        for (const line of t.split("\n")) {
            const m = line.match(/^(\d+)\s+(.+)\.desktop$/)
            if (m) h[m[2]] = parseInt(m[1])
        }
        if (Object.keys(h).length === 0) return
        history = h
        hist.setText(JSON.stringify(h))
    }
    FileView {
        id: hist
        path: root.histFile
        onLoaded: { try { root.history = JSON.parse(text()) } catch (e) {} }
        onLoadFailed: seed.start()
    }
    FileView { id: rofiCache; path: Quickshell.env("HOME") + "/.cache/rofi3.druncache"; onLoadFailed: {} }
    Timer { id: seed; interval: 500; onTriggered: root.seedFromRofi() }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.reset(); root.open = true }
        function close(): void { root.open = false }
    }
}
