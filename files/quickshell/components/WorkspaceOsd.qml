import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs

// Workspace pop-up: a small round DARK badge at the top-left that shows the workspace number for 1.5 seconds
// whenever the focused workspace changes. Dark glass circle, white number, a thin accent edge (the only theme color).
// Dark on purpose in every theme, so the white number is always readable. To make it bigger or smaller change `size` below.
// Loaded from shell.qml by code (like the polkit dialog), so a Quickshell build without the
// Hyprland module cannot break the whole shell.
PanelWindow {
    id: win

    readonly property int size: 40      // diameter of the round badge
    readonly property int ring: 3       // soft ring around it

    property bool active: false
    property bool ready: false          // false until the first workspace is known (no pop-up at start-up)

    readonly property var fw: Hyprland.focusedWorkspace
    readonly property int wsId: fw ? fw.id : 0

    visible: badge.opacity > 0
    color: "transparent"
    anchors { top: true; left: true }
    margins { top: 16 - ring; left: 16 - ring }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: size + 2 * ring
    implicitHeight: size + 2 * ring

    mask: Region {}                     // clicks go through

    WlrLayershell.namespace: "snow-workspace"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onWsIdChanged: {
        if (wsId <= 0) return           // none yet, or a special / named workspace
        if (!ready) { ready = true; return }
        active = true
        hideTimer.restart()
    }
    Component.onCompleted: ready = wsId > 0

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: win.active = false
    }

    Item {
        id: badge
        anchors.fill: parent
        opacity: win.active ? 1 : 0
        scale: win.active ? 1 : 0.85
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

        // soft ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.30)
        }
        // the round badge
        Rectangle {
            x: win.ring
            y: win.ring
            width: win.size
            height: win.size
            radius: width / 2
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.55)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.17, 0.17, 0.21, 0.96) }
                GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.06, 0.08, 0.96) }
            }
            Text {
                anchors.centerIn: parent
                text: win.wsId
                font.pixelSize: win.wsId >= 10 ? 15 : 18
                font.weight: Font.ExtraBold
                color: "#ffffff"
            }
        }
    }
}
