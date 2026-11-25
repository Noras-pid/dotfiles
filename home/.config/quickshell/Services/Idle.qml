pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Services

// Idle timers (replaces hypridle's listeners): keyboard backlight, lock,
// screen off, suspend.
// Caffeine pauses all of them; a wayland idle inhibitor (video playing)
// does too. hypridle itself stays only as the logind bridge: it turns
// `loginctl lock-session` and the pre-sleep hook into 'qs ipc call lock lock'.
Singleton {
    id: root

    // 0 disables that timer. Only the keyboard backlight is on a timer here;
    // lock, screen off and suspend are manual (keybind, lid, Lock service).
    property int kbdAfter:     250
    property int lockAfter:    0
    property int screenAfter:  0
    property int suspendAfter: 0
    property bool hasKeyboardBacklight: false
    Process {
        running: true
        command: ["sh", "-c", "brightnessctl -l -m -c leds | grep -q kbd_backlight"]
        onExited: (code) => root.hasKeyboardBacklight = code === 0
    }
    readonly property bool paused: Caffeine.on

    function sh(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }

    IdleMonitor {
        enabled: root.hasKeyboardBacklight && !root.paused && root.kbdAfter > 0; respectInhibitors: true; timeout: root.kbdAfter
        onIsIdleChanged: root.sh(isIdle ? "~/.config/hypr/scripts/brightness.sh kbd-off" : "~/.config/hypr/scripts/brightness.sh kbd-restore")
    }
    IdleMonitor {
        enabled: !root.paused && root.lockAfter > 0; respectInhibitors: true; timeout: root.lockAfter
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    IdleMonitor {
        enabled: !root.paused && root.screenAfter > 0; respectInhibitors: true; timeout: root.screenAfter
        onIsIdleChanged: {
            // explicit action: dpms("on") without a table toggles instead
            Quickshell.execDetached(["hyprctl", "dispatch", isIdle ? 'hl.dsp.dpms({action = "off"})' : 'hl.dsp.dpms({action = "on"})'])
            if (!isIdle) root.sh("brightnessctl -r")
        }
    }
    IdleMonitor {
        enabled: !root.paused && root.suspendAfter > 0; respectInhibitors: true; timeout: root.suspendAfter
        onIsIdleChanged: if (isIdle) root.sh("systemctl suspend")
    }
}
