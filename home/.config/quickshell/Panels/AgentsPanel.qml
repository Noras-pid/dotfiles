import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Bar
import qs.Services

// Coding agents: limits of the default agent's account as rings (the bar's
// sysmon language, grown up), a week of token use as columns with the
// models behind it, and the launch button. Data: Services/Agents.qml.
Panel {
    id: p
    name: "agents"
    panelWidth: 360
    spacing: 14
    readonly property var account: Agents.primary
    readonly property var limits: account ? account.limits || [] : []
    readonly property bool claudeSelected: Agents.defaultAgent.startsWith("claude")
    property int tick: 0
    Timer { interval: 30000; running: p.open; repeat: true; onTriggered: p.tick++ }
    onOpenChanged: if (open && Date.now() / 1000 - Agents.updated > 120) Agents.refresh()

    // token history of the selected agent (Claude Code / Codex local logs)
    readonly property var days: (Agents.agentTokens.days || []).slice(-7)
    readonly property var models: (Agents.agentTokens.models || []).slice().sort((a, b) => b.total - a.total).slice(0, 3)
    readonly property real dayMax: days.reduce((m, d) => Math.max(m, d.total), 0)
    readonly property real modelSum: models.reduce((s, m) => s + m.total, 0)
    readonly property bool hasActivity: dayMax > 0
    property int hoverDay: -1

    function shortName(name) {
        if (/5\s*час|session/i.test(name)) return "Session · 5h"
        if (/недел|week/i.test(name)) return "Week"
        return name.replace(/^За\s+/, "")
    }
    function resetsIn(iso) {
        void tick
        if (!iso) return "reset time unknown"
        const ms = new Date(iso).getTime() - Date.now()
        if (isNaN(ms)) return ""
        if (ms <= 0) return "due now"
        const m = Math.round(ms / 60000), h = Math.floor(m / 60), d = Math.floor(h / 24)
        if (d >= 1) return "resets in " + d + "d " + (h % 24) + "h"
        if (h >= 1) return "resets in " + h + "h " + (m % 60) + "m"
        return "resets in " + m + "m"
    }
    function updatedText() {
        void tick
        if (Agents.busy) return "Refreshing…"
        const u = p.account ? p.account.updated || 0 : 0
        if (!u) return "Never refreshed"
        const m = Math.round((Date.now() / 1000 - u) / 60)
        return m < 1 ? "Updated just now" : m < 60 ? "Updated " + m + "m ago" : "Updated at " + Qt.formatTime(new Date(u * 1000), "HH:mm")
    }
    function dayDate(s) { const f = s.split("-").map(Number); return new Date(f[0], f[1] - 1, f[2]) }
    function modelName(m) {   // "opus-4-7" → "Opus 4.7", "gpt-6.1-sol" → "GPT-6.1 Sol"
        const f = m.split("-")
        if (f[0] === "gpt" && f.length > 1)
            return "GPT-" + f[1] + f.slice(2).map(w => " " + w.charAt(0).toUpperCase() + w.slice(1)).join("")
        return f[0].charAt(0).toUpperCase() + f[0].slice(1) + (f.length > 1 ? " " + f.slice(1).join(".") : "")
    }

    // one limit: a ring that fills up when the panel opens, the percent in
    // the middle, what it is and when it resets underneath
    component LimitCard: Rectangle {
        id: card
        required property var limit
        readonly property real pct: Math.max(0, Math.min(100, limit.percent))
        readonly property string tint: pct >= 90 ? Theme.c.critical
                                      : Theme.hued && pct >= 75 ? Theme.c.warning : Theme.c.accentBright
        readonly property real d: 78
        readonly property real stroke: 6
        property real shown: p.open ? pct : 0
        Behavior on shown { NumberAnimation { duration: Motion.growMs + 200; easing.type: Easing.OutCubic } }
        height: body.implicitHeight + 24
        radius: Theme.radius
        color: Theme.c.bg1
        border.width: 1; border.color: Theme.c.border

        Column {
            id: body
            anchors.centerIn: parent
            width: parent.width - 20
            spacing: 8
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.d; height: card.d
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.c.bg3; strokeWidth: card.stroke; fillColor: "transparent"
                        PathAngleArc { centerX: card.d / 2; centerY: card.d / 2; radiusX: (card.d - card.stroke) / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: card.tint; strokeWidth: card.shown >= 0.5 ? card.stroke : 0; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: card.d / 2; centerY: card.d / 2; radiusX: (card.d - card.stroke) / 2; radiusY: radiusX; startAngle: -90; sweepAngle: 3.6 * card.shown }
                    }
                }
                Row {
                    anchors.centerIn: parent
                    Label { text: Math.round(card.shown); font.pixelSize: Theme.fs(22); font.weight: Font.DemiBold; color: Theme.c.fg }
                    Label { text: "%"; anchors.baseline: parent.children[0].baseline; font.pixelSize: Theme.fs(11); color: Theme.c.accentMid }
                }
            }
            Label {
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: p.shortName(card.limit.name); elide: Text.ElideRight
                font.pixelSize: Theme.fs(12); font.weight: Font.DemiBold; color: Theme.c.fg
            }
            Label {
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: p.resetsIn(card.limit.resets_at); wrapMode: Text.Wrap
                font.pixelSize: Theme.fs(10); color: Theme.c.accentMid
            }
        }
    }

    PanelHeader {
        title: "AI agents"
        detail: p.account && p.account.plan ? p.account.plan : ""
        actions: [IconButton { icon: "refresh"; enabled: !Agents.busy; opacity: enabled ? 1 : 0.4; onClicked: Agents.refresh() }]
    }

    Segmented {
        options: [{ label: "Claude", icon: "auto_awesome", value: "claude-desktop" },
                  { label: "Codex", icon: "code", value: "codex" }]
        current: p.claudeSelected ? "claude-desktop" : "codex"
        onPicked: value => Agents.setDefault(value)
    }

    Label {
        visible: !!(p.account && p.account.stale)
        width: parent.width; wrapMode: Text.Wrap
        text: "Showing the last saved data. " + (p.account ? p.account.error : "")
        color: Theme.hued ? Theme.c.warning : Theme.c.accentMid; font.pixelSize: Theme.fs(10.5)
    }

    Row {
        visible: p.limits.length > 0
        width: parent.width; spacing: 10
        Repeater {
            model: p.limits
            LimitCard {
                required property var modelData
                limit: modelData
                width: (parent.width - (p.limits.length - 1) * 10) / Math.max(1, p.limits.length)
            }
        }
    }
    EmptyState {
        visible: p.limits.length === 0
        icon: Agents.busy ? "refresh" : "auto_awesome"
        text: Agents.busy ? "Loading limits…" : "No limit data"
        hint: p.account && p.account.error ? p.account.error : "Press ↻ above to refresh"
    }

    // a week of tokens: columns scaled to the busiest day, today in the
    // accent; hovering a column puts its number in the section header
    PanelSection {
        visible: p.hasActivity
        text: "Activity"
        detail: {
            const i = p.hoverDay >= 0 ? p.hoverDay : p.days.length - 1
            const d = p.days[i]
            if (!d) return ""
            return Agents.fmtTokens(d.total) + " tok · " + (i === p.days.length - 1 ? "today" : Qt.locale("en_US").toString(p.dayDate(d.date), "ddd, d MMM"))
        }
    }
    Row {
        id: chart
        visible: p.hasActivity
        width: parent.width; height: 64
        spacing: 6
        readonly property real colW: (width - (p.days.length - 1) * spacing) / Math.max(1, p.days.length)
        Repeater {
            model: p.days
            Item {
                id: col
                required property var modelData
                required property int index
                readonly property bool today: index === p.days.length - 1
                readonly property bool lit: today || p.hoverDay === index
                width: chart.colW; height: chart.height
                Rectangle {   // the column, at least a 3px stub so empty days still read as days
                    anchors.bottom: dayLabel.top; anchors.bottomMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 6
                    readonly property real full: col.height - dayLabel.height - 5
                    height: p.open ? Math.max(3, full * Math.sqrt(col.modelData.total / p.dayMax)) : 3
                    Behavior on height { NumberAnimation { duration: Motion.growMs; easing.type: Easing.OutCubic } }
                    radius: Theme.radiusSm
                    color: col.lit ? Theme.c.accentBright : col.modelData.total > 0 ? Theme.alpha(Theme.c.accentLight, 0.45) : Theme.c.bg3
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Label {
                    id: dayLabel
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.locale("en_US").toString(p.dayDate(col.modelData.date), "ddd")
                    font.pixelSize: Theme.fs(10); font.weight: col.today ? Font.DemiBold : Font.Normal
                    color: col.lit ? Theme.c.fg : Theme.c.accentMid
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: p.hoverDay = col.index
                    onExited: if (p.hoverDay === col.index) p.hoverDay = -1
                }
            }
        }
    }

    // the models behind those tokens, as shares of the week
    Column {
        visible: p.hasActivity && p.models.length > 0
        width: parent.width; spacing: 7
        Repeater {
            model: p.models
            Item {
                id: mrow
                required property var modelData
                required property int index
                readonly property real share: p.modelSum > 0 ? modelData.total / p.modelSum : 0
                width: parent.width; height: 16
                Label {
                    id: mname
                    width: 92; anchors.verticalCenter: parent.verticalCenter
                    text: p.modelName(mrow.modelData.model); elide: Text.ElideRight
                    font.pixelSize: Theme.fs(11); color: mrow.index === 0 ? Theme.c.fg : Theme.c.accentLight
                }
                Rectangle {
                    anchors.left: mname.right; anchors.right: mpct.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4; radius: 2; color: Theme.c.bg3
                    Rectangle {
                        height: parent.height; radius: 2
                        width: p.open ? parent.width * mrow.share : 0
                        Behavior on width { NumberAnimation { duration: Motion.growMs; easing.type: Easing.OutCubic } }
                        color: mrow.index === 0 ? Theme.c.accentBright : Theme.alpha(Theme.c.accentLight, 0.55)
                    }
                }
                Label {
                    id: mpct
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 34; horizontalAlignment: Text.AlignRight
                    text: Math.round(mrow.share * 100) + "%"
                    font.pixelSize: Theme.fs(11); color: Theme.c.accentMid
                }
            }
        }
    }

    PanelDivider {}
    Item {
        width: parent.width; height: launch.height
        Label {
            anchors.left: parent.left; anchors.right: launch.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: p.updatedText(); elide: Text.ElideRight
            font.pixelSize: Theme.fs(10.5); color: Theme.c.accentMid
        }
        PanelButton {
            id: launch
            anchors.right: parent.right
            primary: true
            icon: "terminal"
            text: "Open " + Agents.defaultName
            onClicked: { Agents.launch(""); Panels.close() }
        }
    }
}
