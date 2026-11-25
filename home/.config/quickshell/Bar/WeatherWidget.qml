import QtQuick
import qs.Commons
import qs.Services
import qs.Panels

// Weather now: condition icon + temperature. Click for the forecast panel.
Pill {
    id: w
    visible: Weather.ready
    onClicked: Panels.toggle("weather", w)
    Row {
        spacing: 4
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"
            color: Weather.ready ? Weather.tint(Weather.current.code, Weather.current.day) : Theme.c.accentLight
        }
        FixedLabel {
            anchors.verticalCenter: parent.verticalCenter
            visible: !w.vertical
            text: Weather.ready ? Weather.current.temp + "°" : ""
            widest: "-88°"
            color: Theme.c.accentLight
        }
    }
    WeatherPanel { anchorItem: w }
}
