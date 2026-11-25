import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Panels

Pill {
    id: clk
    gap: 12
    SystemClock { id: clock; precision: SystemClock.Minutes }
    onClicked: Panels.toggle("calendar", clk)
    Label {
        visible: !clk.vertical && !clk.pillMode
        text: Qt.locale("en_US").toString(clock.date, "ddd, MMM d")
        color: Theme.c.accentMid
        font.pixelSize: Theme.fs(12)
    }
    Label {
        text: clk.vertical ? Qt.formatTime(clock.date, "HH\nmm") : Qt.formatTime(clock.date, "HH:mm")
        horizontalAlignment: Text.AlignHCenter
        color: Theme.c.fg
        font.pixelSize: Theme.fs(14)
        font.weight: Font.Bold
    }
    CalendarPanel { anchorItem: clk }
}
