import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import qs.Panels

// Network, Bluetooth and volume in one widget; click opens the control centre,
// scroll changes the volume, right-click mutes. The detailed panels (sound,
// networks, Bluetooth) open from the centre under this same widget.
Pill {
    id: ctl
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink && sink.audio
    readonly property real vol: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    PwObjectTracker { objects: [ctl.sink] }

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) || null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) || null
    property real strength: 1
    function refresh() {
        let s = 1
        if (wifi) for (const n of wifi.networks.values) if (n.connected) { s = n.signalStrength; break }
        strength = s
    }
    onWifiChanged: refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: ctl.refresh() }

    readonly property string netIcon: wired ? "lan" : !wifi ? "wifi_off"
                                    : strength > 0.75 ? "signal_wifi_4_bar" : strength > 0.5 ? "network_wifi_3_bar"
                                    : strength > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
    readonly property string volIcon: muted ? "volume_off" : vol < 0.01 ? "volume_mute" : vol < 0.5 ? "volume_down" : "volume_up"

    onClicked: Panels.toggle("control", ctl)
    onRightClicked: if (ready) sink.audio.muted = !sink.audio.muted
    onScrolled: (d) => { if (ready) sink.audio.volume = Math.max(0, Math.min(1.5, vol + d * 0.05)) }

    Row {
        spacing: 9
        Icon { anchors.verticalCenter: parent.verticalCenter; icon: ctl.netIcon; color: ctl.wired || ctl.wifi ? Theme.c.accentLight : Theme.c.accentDim }
        Icon { anchors.verticalCenter: parent.verticalCenter; visible: Bt.on; icon: "bluetooth"; color: Theme.c.accentLight }
        Icon { anchors.verticalCenter: parent.verticalCenter; icon: ctl.volIcon; color: ctl.muted ? Theme.c.accentDim : Theme.c.accentLight }
    }

    ControlPanel { anchorItem: ctl }
    AudioPanel { anchorItem: ctl }
    NetworkPanel { anchorItem: ctl }
    BluetoothPanel { anchorItem: ctl }
}
