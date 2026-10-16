import QtQuick 2.15

// One dial. Ticks/numerals live on a circle around (0,0); the container is rotated
// so that `pos` sits at 3 o'clock (values grow clockwise).
Item {
    id: ring
    required property int count
    property real pos: 0
    property real radius: 100
    property real majorLen: 20
    property real minorLen: 8
    property real majorWidth: 3
    property real minorWidth: 1.5
    property int majorEvery: 5
    property int labelEvery: 5
    property real labelRadius: 60
    property real labelSize: 20
    property real labelAlpha: 0.9
    property real hideBand: 0.5
    property real minorAlpha: 0.55
    property bool twelveHour: false     // numbers 12, 01, 02 ... 11 instead of 00, 01 ... 
    property color ink: "white"
    property string fontFamily: "Montserrat"
    width: 0; height: 0

    Item {
        width: 0; height: 0
        rotation: -(((ring.pos % ring.count) + ring.count) % ring.count) * 360 / ring.count
        Repeater {
            model: ring.count
            delegate: Item {
                id: slot
                required property int index
                readonly property bool major: index % ring.majorEvery === 0
                rotation: index * 360 / ring.count
                Rectangle {
                    x: ring.radius - width
                    y: -height / 2
                    width: slot.major ? ring.majorLen : ring.minorLen
                    height: slot.major ? ring.majorWidth : ring.minorWidth
                    color: ring.ink
                    opacity: slot.major ? 0.92 : ring.minorAlpha
                    antialiasing: true
                }
                Text {
                    readonly property real p: ((ring.pos % ring.count) + ring.count) % ring.count
                    readonly property real dist: ((slot.index - p + 1.5 * ring.count) % ring.count) - ring.count / 2
                    visible: slot.index % ring.labelEvery === 0
                    text: { var n = (ring.twelveHour && slot.index === 0) ? 12 : slot.index; return (n < 10 ? "0" : "") + n }
                    x: ring.labelRadius - width / 2
                    y: -height / 2
                    color: ring.ink
                    opacity: ring.labelAlpha * Math.max(0, Math.min(1, (Math.abs(dist) - ring.hideBand) / 0.5))
                    font.family: ring.fontFamily
                    font.pixelSize: ring.labelSize
                    font.weight: Font.Bold
                }
            }
        }
    }
}
