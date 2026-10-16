import QtQuick
import qs

// Quick Settings slider row (design v8): small label above, a 40 px pill track with the
// round icon button inside on the left and the percent inside on the right, gear button outside.
Item {
    id: root

    property string glyph: ""
    property string label: ""
    property real value: 0
    property bool dimmed: false
    signal moved(real v)
    signal iconClicked()
    property bool gear: false           // small settings button at the right end
    property bool gearActive: false
    signal gearClicked()

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : value
    readonly property int percent: Math.round(root.shown * 100)

    implicitHeight: 19 + 40

    // mouse wheel: hover over the whole row and scroll
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            var d = e.angleDelta.y > 0 ? 0.05 : -0.05
            root.moved(Math.max(0, Math.min(1, root.value + d)))
        }
    }

    Text {
        x: 4
        text: root.label
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Theme.muted
    }

    Rectangle {
        id: track
        y: 19
        width: parent.width - (root.gear ? 34 : 0)
        height: 40
        radius: 20
        color: Theme.surfaceHi
        clip: true

        // fill
        Rectangle {
            width: track.width * Math.min(1, root.shown)
            height: parent.height
            radius: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.dimmed ? Theme.muted : Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.accent, 0.5)) }
                GradientStop { position: 1.0; color: root.dimmed ? Theme.muted : Theme.accent }
            }
            Behavior on width { enabled: !root.dragging; NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }

        // drag area (under the icon button)
        MouseArea {
            anchors.fill: parent
            function update(mx) {
                var v = Math.max(0, Math.min(1, mx / width))
                root.dragValue = v
                root.moved(v)
            }
            onPressed: (m) => { root.dragging = true; update(m.x) }
            onPositionChanged: (m) => { if (pressed) update(m.x) }
            onReleased: root.dragging = false
        }

        // round icon button (mute / sun)
        Rectangle {
            x: 4
            y: 4
            width: 32
            height: 32
            radius: 16
            color: Theme.surface
            Text {
                anchors.centerIn: parent
                text: root.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: root.dimmed ? Theme.danger : Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        // percent
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "%"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.family: "JetBrains Mono"
            color: (root.percent > 88 && !root.dimmed) ? "#ffffff" : Theme.text
        }
    }

    // gear button (outside the track, right)
    Rectangle {
        visible: root.gear
        x: parent.width - width
        y: 19 + 6
        width: 28
        height: 28
        radius: 14
        color: root.gearActive ? Qt.alpha(Theme.accent, 0.25) : (gma.containsMouse ? Qt.alpha(Theme.tint, 0.08) : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "\ue8b8"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
            color: root.gearActive ? Theme.accent : Theme.muted
        }
        MouseArea {
            id: gma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.gearClicked()
        }
    }
}
