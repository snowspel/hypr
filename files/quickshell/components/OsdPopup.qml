import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs

PanelWindow {
    id: win

    property string kind: "vol"
    property real level: 0
    property bool muted: false
    property bool active: false
    property bool ready: false
    property bool forceShow: false

    visible: card.opacity > 0
    color: "transparent"
    anchors { bottom: true }
    margins { bottom: 90 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: 64

    mask: Region {}

    WlrLayershell.namespace: "snow-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function pop() {
        win.active = true
        hideTimer.restart()
    }

    // read the volume, show only if it changed
    Process {
        id: volGet
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/([0-9]+\.[0-9]+)/)
                if (!m) return
                var v = parseFloat(m[1])
                var mu = text.indexOf("MUTED") !== -1
                var changed = (v !== win.level || mu !== win.muted || win.kind !== "vol")
                var first = !win.ready
                win.ready = true
                if (win.kind !== "vol" && !changed) return
                win.kind = "vol"
                win.level = v
                win.muted = mu
                if ((changed && !first) || win.forceShow) win.pop()
                win.forceShow = false
            }
        }
    }

    // listens for system volume changes (pactl = libpulse package)
    Process {
        id: watcher
        running: true
        command: ["sh", "-c", "pactl subscribe | grep --line-buffered \"'change' on sink #\""]
        stdout: SplitParser {
            onRead: data => debounce.restart()
        }
        onRunningChanged: if (!running) restartTimer.start()
    }
    Timer { id: restartTimer; interval: 2000; onTriggered: watcher.running = true }
    Timer { id: debounce; interval: 30; onTriggered: if (!volGet.running) volGet.running = true }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: win.active = false
    }

    Component.onCompleted: volGet.running = true

    IpcHandler {
        target: "osd"
        function trigger(): void { win.forceShow = true; if (!volGet.running) volGet.running = true }
        function brightness(v: real): void {
            win.kind = "bright"
            win.level = v
            win.muted = false
            win.pop()
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 32
        color: Theme.bg
        border.width: 1
        border.color: Qt.alpha(Theme.tint, 0.08)
        opacity: win.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 20
            width: parent.width - 40
            spacing: 14

            Text {
                width: 24
                anchors.verticalCenter: parent.verticalCenter
                text: win.kind === "bright" ? "\ue1ac"
                    : (win.muted || win.level === 0 ? "\ue04f" : (win.level < 0.34 ? "\ue04e" : (win.level < 0.67 ? "\ue04d" : "\ue050")))
                font.family: "Material Symbols Rounded"
                font.pixelSize: 24
                color: Theme.text
            }

            Item {
                width: parent.width - 24 - 44 - 28
                height: 6
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Theme.surfaceHi
                }
                Rectangle {
                    width: parent.width * Math.min(1, win.level)
                    height: parent.height
                    radius: 3
                    color: win.muted ? Theme.muted : Theme.accent
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            Text {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round(win.level * 100) + "%"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: win.muted ? Theme.muted : Theme.text
            }
        }
    }
}
