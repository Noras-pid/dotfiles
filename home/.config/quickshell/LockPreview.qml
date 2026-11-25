import QtQuick
import QtQuick.Window
import Quickshell
import qs.Lock
ShellRoot {
    Window {
        visible: true
        width: 1280; height: 720
        title: "Rei — lock screen preview"
        LockView { anchors.fill: parent; preview: true }
    }
}
