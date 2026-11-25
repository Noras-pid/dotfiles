import QtQuick
import qs.Commons

// Bar text: the rice font, medium weight, themed colour.
Text {
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: Font.Medium
    color: Theme.c.fg
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    antialiasing: true
    font.hintingPreference: Font.PreferVerticalHinting
    Behavior on color { ColorAnimation { duration: 150 } }
}
