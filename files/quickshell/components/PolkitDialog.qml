import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import qs

// Polkit authentication dialog drawn by Quickshell itself (replaces hyprpolkitagent's window).
// Shows only a title and a password box. Enter = submit, Escape = cancel.
Scope {
    id: root

    PolkitAgent { id: agent }

    PanelWindow {
        id: win

        visible: agent.isActive
        color: Qt.rgba(0, 0, 0, 0.5)
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "snow-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property var flow: agent.flow

        onFlowChanged: {
            pw.text = ""
            if (flow) pw.forceActiveFocus()
        }
        onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus() }

        function submit() {
            if (win.flow && pw.text !== "") {
                win.flow.submit(pw.text)
                pw.text = ""
            }
        }
        function cancel() {
            if (win.flow) win.flow.cancelAuthenticationRequest()
        }

        Rectangle {
            id: card
            width: 380
            height: col.height + 48
            anchors.centerIn: parent
            radius: 18
            color: Theme.bg
            border.width: 1
            border.color: Qt.alpha(Theme.tint, 0.12)

            Column {
                id: col
                x: 24
                y: 24
                width: parent.width - 48
                spacing: 16

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Authentication"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    color: Theme.text
                }

                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 12
                    color: Theme.surface
                    border.width: 1
                    border.color: pw.activeFocus ? Theme.accent : Qt.alpha(Theme.tint, 0.14)

                    TextInput {
                        id: pw
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 16
                        color: Theme.text
                        clip: true
                        echoMode: (win.flow && win.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        enabled: win.flow ? win.flow.isResponseRequired : false

                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.submit(); e.accepted = true }
                            else if (e.key === Qt.Key_Escape) { win.cancel(); e.accepted = true }
                        }

                        Text {
                            visible: pw.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password"
                            font.pixelSize: 16
                            color: Theme.muted
                        }
                    }
                }

                Text {
                    visible: win.flow ? (win.flow.failed || win.flow.supplementaryIsError) : false
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: (win.flow && win.flow.supplementaryIsError && win.flow.supplementaryMessage !== "")
                          ? win.flow.supplementaryMessage : "Wrong password, try again."
                    font.pixelSize: 12
                    color: Theme.danger
                }
            }
        }
    }
}
