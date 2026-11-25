import QtQuick
import qs.Commons
import qs.Bar
import qs.Services

// Under the weather widget. A sky card tinted by the weather (rain, snow or
// stars drift in it while the panel is open) with the day's details, the
// next 8 hours as a temperature curve, and seven days whose bars are
// coloured by the actual temperature.
// Mono themes keep every colour in the theme's greys.
Panel {
    id: p
    name: "weather"
    panelWidth: 360
    spacing: 10
    readonly property var cur: Weather.current
    readonly property var today: Weather.daily.length ? Weather.daily[0] : null
    readonly property int weekMin: Weather.daily.length ? Math.min.apply(null, Weather.daily.map(d => d.min)) : 0
    readonly property int weekMax: Weather.daily.length ? Math.max.apply(null, Weather.daily.map(d => d.max)) : 1
    readonly property int code: cur ? cur.code : 3
    readonly property bool isDay: cur ? cur.day : true
    // what drifts through the sky card
    readonly property string fx: code >= 95 || (code >= 51 && code <= 67) || (code >= 80 && code <= 82) ? "rain"
                               : (code >= 71 && code <= 77) || code === 85 || code === 86 ? "snow"
                               : !isDay && code <= 1 ? "stars"
                               : code >= 2 ? "clouds" : ""
    // the sky's light: sun, moon, cloud, rain, snow, storm
    readonly property color glow: !Theme.hued ? Theme.c.accentBright
                                : code >= 95 ? Theme.c.critical
                                : fx === "snow" ? Theme.c.fg
                                : fx === "rain" ? Theme.c.accentBright
                                : code <= 2 ? (isDay ? Theme.c.warning : Theme.c.accentLight)
                                : Theme.c.accentMid
    readonly property real glowA: Theme.hued ? 0.30 : 0.10

    function hm(d) { return Qt.formatTime(d, "HH:mm") }
    function dayName(d, i) {
        if (i === 0) return "Today"
        if (i === 1) return "Tomorrow"
        return Qt.locale("en_US").toString(d, "ddd")
    }
    function compass(deg) { return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(((deg % 360) + 360) % 360 / 45) % 8] }
        // a temperature's colour: icy → blue → green → yellow → red (mono: the accent)
    function tempColor(t) {
        if (!Theme.hued) return Theme.c.accentBright
        const stops = [[-10, Theme.c.accentLight], [2, Theme.c.accentBright], [12, Theme.c.good], [22, Theme.c.warning], [32, Theme.c.critical]]
        if (t <= stops[0][0]) return stops[0][1]
        for (let i = 1; i < stops.length; i++) {
            if (t > stops[i][0]) continue
            const a = Qt.color(stops[i - 1][1]), b = Qt.color(stops[i][1])
            const k = (t - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0])
            return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1)
        }
        return stops[stops.length - 1][1]
    }
    onOpenChanged: if (open && (Date.now() - Weather.updated.getTime()) > 10 * 60 * 1000) Weather.refresh()

    EmptyState {
        visible: !Weather.ready
        icon: Weather.error ? "cloud" : "refresh"
        text: Weather.error ? "Weather unavailable" : "Loading the forecast…"
        hint: Weather.error
    }

    // sky card ----------------------------------------------------------------
    Rectangle {
        id: sky
        visible: Weather.ready
        width: parent.width; height: 186
        radius: Theme.radius
        clip: true
        border.width: 1; border.color: Theme.alpha(p.glow, Theme.hued ? 0.30 : 0.18)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.tint(Theme.c.bg2, Theme.alpha(p.glow, p.glowA)) }
            GradientStop { position: 1; color: Theme.c.bg1 }
        }

        // the sun / moon's halo behind the big icon
        Rectangle {
            width: 220; height: 220; radius: 110
            x: parent.width - 168; y: -62
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(p.glow, Theme.hued ? 0.22 : 0.08) }
                GradientStop { position: 0.6; color: Theme.alpha(p.glow, 0) }
            }
            rotation: 0
        }

        // slow cloud puffs for cloudy, foggy and wet skies
        Repeater {
            model: p.fx === "stars" || p.fx === "" ? 0 : 3
            Rectangle {
                id: puff
                required property int index
                readonly property real w: [210, 160, 240][index]
                width: w; height: w * 0.42; radius: height / 2
                y: [92, 118, 132][index]
                color: Theme.alpha(Theme.c.fg, Theme.light ? 0.05 : 0.035)
                x: [-40, 180, 60][index]
                NumberAnimation on x {
                    running: p.open
                    loops: Animation.Infinite
                    from: -puff.w; to: sky.width
                    duration: [52000, 38000, 64000][puff.index]
                }
            }
        }

        // rain streaks, snowflakes or stars; only animated while the panel is open
        Repeater {
            model: p.fx === "" || p.fx === "clouds" ? 0 : (p.fx === "stars" ? 22 : 26)
            Rectangle {
                id: drop
                required property int index
                readonly property real seed: (index * 0.6180339 + 0.137) % 1
                readonly property real seed2: (index * 0.4142135 + 0.71) % 1
                x: seed * sky.width
                width: p.fx === "rain" ? 1.2 : p.fx === "snow" ? 2 + seed2 * 2.5 : 1.5 + seed2 * 1.5
                height: p.fx === "rain" ? 9 + seed2 * 7 : width
                radius: p.fx === "rain" ? 1 : width / 2
                rotation: p.fx === "rain" ? 12 : 0
                color: p.fx === "rain" ? Theme.c.accentBright : Theme.c.fg
                opacity: p.fx === "stars" ? 0.25 + 0.5 * seed2 : p.fx === "rain" ? 0.28 : 0.55
                y: p.fx === "stars" ? 8 + seed2 * (sky.height * 0.55) : -height
                NumberAnimation on y {
                    running: p.open && p.fx !== "stars"
                    loops: Animation.Infinite
                    from: -drop.height - drop.seed2 * sky.height; to: sky.height + 4
                    duration: (p.fx === "rain" ? 900 : 5200) * (0.75 + drop.seed2 * 0.5)
                }
                NumberAnimation on x {
                    running: p.open && p.fx === "snow"
                    loops: Animation.Infinite
                    from: drop.seed * sky.width; to: drop.seed * sky.width - 24
                    duration: 5200 * (0.75 + drop.seed2 * 0.5)
                }
                SequentialAnimation on opacity {
                    running: p.open && p.fx === "stars"
                    loops: Animation.Infinite
                    PauseAnimation { duration: drop.seed * 2400 }
                    NumberAnimation { to: 0.15; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.85; duration: 1400; easing.type: Easing.InOutSine }
                }
            }
        }

        // place + refresh
        Row {
            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 14
            spacing: 5
            Icon { anchors.verticalCenter: parent.verticalCenter; icon: "location_on"; size: Theme.fs(14); color: Theme.c.accentLight }
            Label { anchors.verticalCenter: parent.verticalCenter; text: Weather.city; font.pixelSize: Theme.fs(12.5); font.weight: Font.DemiBold; color: Theme.c.fg }
        }
        IconButton {
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
            icon: "refresh"; iconSize: Theme.fs(14)
            onClicked: Weather.refresh()
            opacity: Weather.loading ? 0.4 : 0.85
        }

        // temperature
        Text {
            id: bigT
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.top: parent.top; anchors.topMargin: 34
            text: p.cur ? p.cur.temp + "°" : ""
            font.family: Theme.font; font.pixelSize: Theme.fs(62); font.weight: Font.ExtraLight
            color: Theme.c.accentBright
            renderType: Text.QtRendering
        }
        Icon {
            anchors.right: parent.right; anchors.rightMargin: 22; anchors.verticalCenter: bigT.verticalCenter; anchors.verticalCenterOffset: 6
            icon: p.cur ? Weather.icon(p.cur.code, p.cur.day) : "cloud"
            size: 68
            color: p.cur ? Weather.tint(p.cur.code, p.cur.day) : Theme.c.accentBright
        }
        Column {
            anchors.left: parent.left; anchors.leftMargin: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            spacing: 3
            Label { text: p.cur ? Weather.describe(p.cur.code) : ""; font.pixelSize: Theme.fs(13.5); font.weight: Font.DemiBold; color: Theme.c.fg }
            Label {
                text: p.cur && p.today ? "Feels like " + p.cur.feels + "°   ·   ↑ " + p.today.max + "°  ↓ " + p.today.min + "°" : ""
                font.pixelSize: Theme.fs(11.5); color: Theme.c.accentMid
            }
            Row {
                topPadding: 4; spacing: 14
                Repeater {
                    model: p.cur && p.today ? [
                        { icon: "water_drop", text: p.cur.humidity + "%" },
                        { icon: "air", text: p.cur.wind.toFixed(1) + " m/s " + p.compass(p.cur.windDir) },
                        { icon: "wb_twilight", text: p.hm(p.today.sunrise) + " – " + p.hm(p.today.sunset) }
                    ] : []
                    Row {
                        required property var modelData
                        spacing: 4
                        Icon { anchors.verticalCenter: parent.verticalCenter; icon: modelData.icon; size: Theme.fs(12); color: Theme.c.accentLight }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: modelData.text; font.pixelSize: Theme.fs(11); color: Theme.c.fg }
                    }
                }
            }
        }
    }

    // next 12 hours: a temperature curve -----------------------------------------
    Rectangle {
        id: hoursCard
        visible: Weather.ready && Weather.hourly.length > 1
        width: parent.width; height: 132
        radius: Theme.radius
        color: Theme.c.bg1; border.width: 1; border.color: Theme.c.border
        readonly property var hrs: Weather.hourly.slice(0, 8)
        readonly property int n: hrs.length
        readonly property real colW: (width - 16) / Math.max(1, n)
        readonly property real tMin: n ? Math.min.apply(null, hrs.map(h => h.temp)) : 0
        readonly property real tMax: n ? Math.max.apply(null, hrs.map(h => h.temp)) : 1
        // the curve lives between curveTop and curveBot
        readonly property real curveTop: 50
        readonly property real curveBot: 86
        function px(i) { return 8 + colW * (i + 0.5) }
        function py(t) { return tMax === tMin ? (curveTop + curveBot) / 2 : curveBot - (t - tMin) / (tMax - tMin) * (curveBot - curveTop) }

        Canvas {
            id: curve
            anchors.fill: parent
            property var hours: hoursCard.hrs
            onHoursChanged: requestPaint()
            onWidthChanged: requestPaint()
            Connections { target: Theme; function onCChanged() { curve.requestPaint() } }
            onPaint: {
                const ctx = getContext("2d"), h = hoursCard, n = h.n
                ctx.reset()
                if (n < 2) return
                const pts = []
                for (let i = 0; i < n; i++) pts.push([h.px(i), h.py(h.hrs[i].temp)])
                const path = () => {
                    ctx.moveTo(pts[0][0], pts[0][1])
                    for (let i = 0; i < n - 1; i++) {
                        const mx = (pts[i][0] + pts[i + 1][0]) / 2
                        ctx.bezierCurveTo(mx, pts[i][1], mx, pts[i + 1][1], pts[i + 1][0], pts[i + 1][1])
                    }
                }
                // soft fill under the line
                const fill = ctx.createLinearGradient(0, h.curveTop - 6, 0, h.height - 10)
                fill.addColorStop(0, Theme.alpha(Theme.c.accentBright, Theme.hued ? 0.22 : 0.14))
                fill.addColorStop(1, Theme.alpha(Theme.c.accentBright, 0))
                ctx.beginPath(); path()
                ctx.lineTo(pts[n - 1][0], h.height - 10); ctx.lineTo(pts[0][0], h.height - 10); ctx.closePath()
                ctx.fillStyle = fill; ctx.fill()
                // the line, coloured by temperature along the way
                const stroke = ctx.createLinearGradient(pts[0][0], 0, pts[n - 1][0], 0)
                for (let i = 0; i < n; i++) stroke.addColorStop(i / (n - 1), String(p.tempColor(h.hrs[i].temp)))
                ctx.beginPath(); path()
                ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.strokeStyle = stroke; ctx.stroke()
                // "now"
                ctx.beginPath(); ctx.arc(pts[0][0], pts[0][1], 3.5, 0, Math.PI * 2)
                ctx.fillStyle = String(Theme.c.bg1); ctx.fill()
                ctx.lineWidth = 2; ctx.strokeStyle = String(p.tempColor(h.hrs[0].temp)); ctx.stroke()
            }
        }

        Repeater {
            model: hoursCard.hrs
            Item {
                required property var modelData
                required property int index
                x: hoursCard.px(index) - width / 2; width: hoursCard.colW; height: hoursCard.height
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 9
                    text: index === 0 ? "Now" : Qt.formatTime(modelData.time, "HH")
                    font.pixelSize: Theme.fs(10.5); font.weight: index === 0 ? Font.DemiBold : Font.Medium
                    color: index === 0 ? Theme.c.accentBright : Theme.c.accentMid
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 26
                    icon: Weather.icon(modelData.code, modelData.day); size: Theme.fs(16)
                    color: Weather.tint(modelData.code, modelData.day)
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: hoursCard.py(modelData.temp) + 7
                    text: modelData.temp + "°"
                    font.pixelSize: Theme.fs(11); font.weight: Font.DemiBold; color: Theme.c.fg
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                    text: modelData.rain !== null && modelData.rain >= 20 ? modelData.rain + "%" : "·"
                    font.pixelSize: Theme.fs(9.5); font.weight: Font.DemiBold
                    color: modelData.rain !== null && modelData.rain >= 20 ? Theme.c.accentBright : Theme.c.grey0
                }
            }
        }
    }

    // seven days ------------------------------------------------------------------
    Rectangle {
        visible: Weather.ready && Weather.daily.length > 0
        width: parent.width; height: days.implicitHeight + 12
        radius: Theme.radius
        color: Theme.c.bg1; border.width: 1; border.color: Theme.c.border
        Column {
            id: days
            x: 0; y: 6; width: parent.width
            Repeater {
                model: Weather.daily
                Item {
                    id: dayRow
                    required property var modelData
                    required property int index
                    width: days.width; height: 34
                    Rectangle {     // hairline between days
                        visible: index > 0
                        x: 12; width: parent.width - 24; height: 1; color: Theme.alpha(Theme.c.fg, 0.05)
                    }
                    Label { id: dn; x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 70; text: p.dayName(modelData.date, index); font.pixelSize: Theme.fs(12)
                            font.weight: index === 0 ? Font.DemiBold : Font.Medium; color: index === 0 ? Theme.c.accentBright : Theme.c.fg }
                    Icon { id: di; anchors.left: dn.right; anchors.verticalCenter: parent.verticalCenter
                           icon: Weather.icon(modelData.code, true); size: Theme.fs(17); color: Weather.tint(modelData.code, true) }
                    Label { id: rain; anchors.left: di.right; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 32; text: modelData.rain !== null && modelData.rain >= 20 ? modelData.rain + "%" : ""
                            font.pixelSize: Theme.fs(10.5); font.weight: Font.DemiBold; color: Theme.c.accentBright }
                    Label { id: lo; anchors.left: rain.right; anchors.verticalCenter: parent.verticalCenter
                            width: 30; horizontalAlignment: Text.AlignRight; text: modelData.min + "°"; font.pixelSize: Theme.fs(12); color: Theme.c.accentMid }
                    Label { id: hi; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 30; horizontalAlignment: Text.AlignRight; text: modelData.max + "°"; font.pixelSize: Theme.fs(12); font.weight: Font.DemiBold; color: Theme.c.fg }
                    Rectangle {     // the week's range; this day's part coloured by its temperatures
                        id: track
                        anchors.left: lo.right; anchors.leftMargin: 10; anchors.right: hi.left; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5; radius: 2.5; color: Theme.c.bg3
                        readonly property real span: Math.max(1, p.weekMax - p.weekMin)
                        Rectangle {
                            x: track.width * (dayRow.modelData.min - p.weekMin) / track.span
                            width: Math.max(5, track.width * (dayRow.modelData.max - dayRow.modelData.min) / track.span)
                            height: parent.height; radius: 2.5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: p.tempColor(dayRow.modelData.min) }
                                GradientStop { position: 1; color: p.tempColor(dayRow.modelData.max) }
                            }
                        }
                        Rectangle {     // today: where it is now
                            visible: dayRow.index === 0 && p.cur !== null
                            width: 9; height: 9; radius: 4.5
                            anchors.verticalCenter: parent.verticalCenter
                            x: p.cur ? track.width * (Math.max(p.weekMin, Math.min(p.weekMax, p.cur.temp)) - p.weekMin) / track.span - width / 2 : 0
                            color: Theme.c.fg; border.width: 2; border.color: Theme.c.bg1
                        }
                    }
                }
            }
        }
    }
}
