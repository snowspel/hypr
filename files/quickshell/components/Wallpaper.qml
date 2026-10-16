import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    property string path: ""
    property string stamp: ""

    Process {
        id: finder
        command: ["bash", "-c", "shopt -s nullglob nocaseglob; f=$(ls -t \"$HOME\"/.config/hypr/wallpaper/*.{jpg,jpeg,png,webp} 2>/dev/null | head -1); [ -n \"$f\" ] && echo \"$(stat -c %Y \"$f\")|$f\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t === "") return
                var i = t.indexOf("|")
                var s = t.slice(0, i)
                var p = t.slice(i + 1)
                if (s !== root.stamp || p !== root.path) {
                    root.stamp = s
                    root.path = p
                }
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!finder.running) finder.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wp
            required property var modelData
            screen: modelData

            color: "#000000"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "snow-wallpaper"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Image {
                id: img
                anchors.fill: parent
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(wp.width, wp.height)
                source: root.path !== "" ? "file://" + root.path + "?v=" + root.stamp : ""
            }
        }
    }
}
