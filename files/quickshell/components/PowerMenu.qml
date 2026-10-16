import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs

// Power menu (Super+Escape): one card at the top center with 3 big square tiles (no hint text).
// Order: Log Out, Shut Down, Restart.  Shut Down is focused on open, so Super+Escape then Enter = shut down.
// The focused tile uses the theme accent (so it changes with the theme); Shut Down is a FIXED red (not a theme color) when focused or hovered.
PanelWindow {
    id: win

    property bool dryRun: false
    property int sel: 1                 // Shut Down

    visible: false
    color: Qt.rgba(0, 0, 0, 0.45)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "snow-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int defaultSel: 1
    readonly property var items: [
        { label: "Log Out",   glyph: "", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { label: "Shut Down", glyph: "", cmd: ["systemctl", "poweroff"] },
        { label: "Restart",   glyph: "", cmd: ["systemctl", "reboot"] }
    ]

    function run(cmd) {
        win.visible = false
        if (dryRun)
            Quickshell.execDetached(["notify-send", "snow (dry run)", cmd.join(" ")])
        else
            Quickshell.execDetached(cmd)
    }

    onVisibleChanged: {
        if (visible) {
            sel = defaultSel
            keys.forceActiveFocus()
            enter.restart()
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { win.visible = !win.visible }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: win.visible = false
        Keys.onLeftPressed:  win.sel = (win.sel + win.items.length - 1) % win.items.length
        Keys.onRightPressed: win.sel = (win.sel + 1) % win.items.length
        Keys.onReturnPressed: win.run(win.items[win.sel].cmd)
        Keys.onEnterPressed:  win.run(win.items[win.sel].cmd)

        MouseArea {
            anchors.fill: parent
            onClicked: win.visible = false
        }

        // soft slide-down + fade when it opens
        ParallelAnimation {
            id: enter
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { target: card; property: "y"; from: 44; to: 72; duration: 240; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: 72
            width: tiles.width + 32
            height: 16 + tiles.height + 16
            radius: 28
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.24)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(Theme.bg, Qt.alpha(Theme.accent, 0.07)) }
                GradientStop { position: 1.0; color: Theme.bg }
            }

            MouseArea { anchors.fill: parent }

            Row {
                id: tiles
                x: 16
                y: 16
                spacing: 10

                Repeater {
                    model: win.items

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool cur: win.sel === index
                        readonly property bool danger: modelData.label === "Shut Down"
                        readonly property color hot: danger ? Qt.rgba(0.937, 0.267, 0.267, 1) : Theme.accent     // focus color: a FIXED red for Shut Down (same in every theme), theme accent for the others

                        width: 124
                        height: 124
                        radius: 24

                        property color c0: cur ? Qt.tint(tile.hot, Qt.rgba(1, 1, 1, 0.2)) : Theme.surfaceHi
                        property color c1: cur ? tile.hot : Theme.surfaceHi
                        Behavior on c0 { ColorAnimation { duration: 150 } }
                        Behavior on c1 { ColorAnimation { duration: 150 } }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: tile.c0 }
                            GradientStop { position: 1.0; color: tile.c1 }
                        }
                        scale: tma.pressed ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        // soft ring on the focused tile
                        Rectangle {
                            z: -1
                            visible: tile.cur
                            x: -3
                            y: -3
                            width: parent.width + 6
                            height: parent.height + 6
                            radius: 27
                            color: Qt.alpha(tile.hot, 0.24)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 60
                                height: 60
                                radius: 30
                                color: tile.cur ? Qt.rgba(0, 0, 0, 0.34) : Qt.alpha(Theme.accent, 0.14)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: tile.modelData.glyph
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 32
                                    color: tile.cur ? "#ffffff" : Theme.accent
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: tile.cur ? "#ffffff" : Theme.text
                            }
                        }

                        MouseArea {
                            id: tma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: win.sel = tile.index      // real mouse movement only, so the opening focus is not stolen
                            onClicked: win.run(tile.modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
