pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Weather from Open-Meteo (no API key). Location: shell.json › weather.location
// as a city name or "lat,lon"; empty means "where the IP is" (ipinfo.io).
// Refreshes every 30 min, and on demand from the panel.
Singleton {
    id: root
    property string city: ""
    property real lat: NaN
    property real lon: NaN
    property var current: null     // { temp, feels, humidity, wind, windDir, pressure, code, day }
    property var hourly: []        // next 12 hours: { time: Date, temp, code, day, rain }
    property var daily: []         // { date: Date, min, max, code, sunrise: Date, sunset: Date, rain, uv }
    property bool loading: false
    property string error: ""
    property date updated: new Date(0)
    readonly property bool ready: current !== null
    readonly property string location: (Config.data.weather && Config.data.weather.location) ? String(Config.data.weather.location) : ""
    // optional display name for a "lat,lon" location (shell.json › weather.name)
    readonly property string placeName: (Config.data.weather && Config.data.weather.name) ? String(Config.data.weather.name) : ""
    onLocationChanged: { lat = NaN; lon = NaN; city = ""; refresh() }
    onPlaceNameChanged: if (placeName) city = placeName

    function get(url, ok) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) { try { ok(JSON.parse(x.responseText)); return } catch (e) { fail("bad reply") ; return } }
            fail(x.status ? "HTTP " + x.status : "offline")
        }
        x.open("GET", url)
        x.send()
    }
    function fail(msg) { error = msg; loading = false }

    function refresh() {
        loading = true; error = ""
        if (!isNaN(lat)) return fetch()
        const loc = location.trim()
        const m = loc.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/)
        if (m) { lat = +m[1]; lon = +m[2]; city = placeName || loc; return fetch() }
        if (loc) {
            get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=" + encodeURIComponent(loc), j => {
                if (!j.results || !j.results.length) return fail("city not found")
                lat = j.results[0].latitude; lon = j.results[0].longitude; city = j.results[0].name
                fetch()
            })
            return
        }
        get("https://ipinfo.io/json", j => {
            const p = String(j.loc || "").split(",")
            if (p.length !== 2) return fail("could not find your location")
            lat = +p[0]; lon = +p[1]
                        get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=" + encodeURIComponent(j.city || ""), g => {
                city = g.results && g.results.length ? g.results[0].name : (j.city || "")
            })
            fetch()
        })
    }

    function fetch() {
        const q = [
            "latitude=" + lat, "longitude=" + lon, "timezone=auto", "forecast_days=7", "wind_speed_unit=ms",
            "current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,pressure_msl,weather_code,is_day",
            "hourly=temperature_2m,weather_code,is_day,precipitation_probability",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,uv_index_max"
        ].join("&")
        get("https://api.open-meteo.com/v1/forecast?" + q, j => {
            const c = j.current
            current = { temp: Math.round(c.temperature_2m), feels: Math.round(c.apparent_temperature),
                        humidity: c.relative_humidity_2m, wind: c.wind_speed_10m, windDir: c.wind_direction_10m,
                        pressure: Math.round(c.pressure_msl), code: c.weather_code, day: c.is_day === 1 }
            // Open-Meteo times are local wall-clock strings ("2026-10-08T14:00")
            const now = new Date(), h = j.hourly, out = []
            for (let i = 0; i < h.time.length && out.length < 12; i++) {
                const t = new Date(h.time[i])
                if (t.getTime() + 3600e3 <= now.getTime()) continue
                out.push({ time: t, temp: Math.round(h.temperature_2m[i]), code: h.weather_code[i], day: h.is_day[i] === 1,
                           rain: h.precipitation_probability ? h.precipitation_probability[i] : null })
            }
            hourly = out
            const d = j.daily, days = []
            for (let i = 0; i < d.time.length; i++)
                days.push({ date: new Date(d.time[i] + "T12:00"), min: Math.round(d.temperature_2m_min[i]), max: Math.round(d.temperature_2m_max[i]),
                            code: d.weather_code[i], sunrise: new Date(d.sunrise[i]), sunset: new Date(d.sunset[i]),
                            rain: d.precipitation_probability_max ? d.precipitation_probability_max[i] : null,
                            uv: d.uv_index_max ? d.uv_index_max[i] : null })
            daily = days
            updated = new Date()
            loading = false
        })
    }

    // WMO weather codes → Material Symbols name and a description
    function icon(code, day) {
        if (code <= 1) return day === false ? "clear_night" : "sunny"
        if (code === 2) return day === false ? "partly_cloudy_night" : "partly_cloudy_day"
        if (code === 3) return "cloud"
        if (code === 45 || code === 48) return "foggy"
        if (code >= 51 && code <= 57) return "rainy_light"
        if (code === 61 || code === 63 || code === 80 || code === 81) return "rainy"
        if (code === 65 || code === 66 || code === 67 || code === 82) return "rainy_heavy"
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "weather_snowy"
        if (code >= 95) return "thunderstorm"
        return "cloud"
    }
    function describe(code) {
        const t = { 0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast",
                    45: "Fog", 48: "Rime fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
                    56: "Freezing drizzle", 57: "Freezing drizzle", 61: "Light rain", 63: "Rain", 65: "Heavy rain",
                    66: "Freezing rain", 67: "Freezing rain", 71: "Light snow", 73: "Snow", 75: "Heavy snow",
                    77: "Snow grains", 80: "Rain showers", 81: "Heavy showers", 82: "Violent showers",
                    85: "Snow showers", 86: "Heavy snow showers", 95: "Thunderstorm", 96: "Thunderstorm, hail", 99: "Thunderstorm, hail" }
        return t[code] || "—"
    }
    // a hued theme colours the weather the way a stock widget does
    function tint(code, day) {
        if (!Theme.hued) return Theme.c.accentBright
        if (code <= 2) return day === false ? Theme.c.accentLight : Theme.c.warning
        if (code >= 95) return Theme.c.critical
        return code >= 51 ? Theme.c.accentBright : Theme.c.accentLight
    }

    Timer { interval: 30 * 60 * 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
