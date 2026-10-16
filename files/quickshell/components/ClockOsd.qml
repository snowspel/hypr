import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs

PanelWindow {
    id: win

    property bool shown: false

    visible: card.opacity > 0
    color: "transparent"
    anchors { bottom: true; right: true }
    margins { bottom: 16; right: 16 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: card.width
    implicitHeight: card.height

    mask: Region {}

    WlrLayershell.namespace: "snow-clock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // 12-hour: 15:20 -> "3:20" + "PM"
    readonly property int hh: clock.date.getHours()
    readonly property string timeText: (hh % 12 === 0 ? 12 : hh % 12) + ":" + ("0" + clock.date.getMinutes()).slice(-2)
    readonly property string ampmText: hh >= 12 ? "PM" : "AM"

    IpcHandler {
        target: "clock"
        function toggle(): void { win.shown = !win.shown }
    }

    Rectangle {
        id: card
        width: timeRow.width + 36
        height: col.height + 22
        radius: 16
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
        border.width: 1
        border.color: Qt.alpha(Theme.tint, 0.10)
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: 0

            // 12-hour format: 3:45 + small PM
            Item {
                id: timeRow
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeTxt.width + 5 + ampmTxt.width
                height: timeTxt.height

                Text {
                    id: timeTxt
                    text: win.timeText
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    color: Theme.text
                }
                Text {
                    id: ampmTxt
                    anchors.left: timeTxt.right
                    anchors.leftMargin: 5
                    anchors.baseline: timeTxt.baseline
                    text: win.ampmText
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.muted
                }
            }
            // date + day:  11 · SUNDAY   (date in the accent color, day in small spaced capitals)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "dd")
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.accent
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 3; radius: 1.5
                    color: Theme.muted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 1.6
                    color: Theme.muted
                }
            }
        }
    }
}
