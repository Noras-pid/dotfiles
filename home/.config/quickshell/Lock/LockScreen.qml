import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Services

WlSessionLock {
    locked: Lock.locked
    WlSessionLockSurface {
        color: Theme.c.bg0
        LockView { anchors.fill: parent }
    }
}
