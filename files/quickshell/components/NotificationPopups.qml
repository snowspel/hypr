import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import qs

PanelWindow {
    id: win

    visible: server.trackedNotifications.values.length > 0
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: 16; right: 16 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: stack.height

    mask: Region {}

    WlrLayershell.namespace: "snow-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        onNotification: (n) => { n.tracked = true }
    }

    Column {
        id: stack
        width: parent.width
        spacing: 10

        Repeater {
            model: server.trackedNotifications

            delegate: Rectangle {
                id: card
                required property var modelData

                width: stack.width
                height: body.height + 28
                radius: 16
                color: Theme.bg
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                Timer {
                    running: true
                    interval: 5000
                    onTriggered: card.modelData.expire()
                }

                Row {
                    id: body
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 12
                        color: Theme.surfaceHi
                        Image {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            sourceSize: Qt.size(52, 52)
                            source: card.modelData.image !== "" ? card.modelData.image
                                  : Quickshell.iconPath(card.modelData.appIcon, "dialog-information")
                        }
                    }

                    Column {
                        width: parent.width - 52
                        spacing: 3
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: card.modelData.summary
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            visible: text !== ""
                            width: parent.width
                            text: card.modelData.body
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: Theme.muted
                        }
                        Text {
                            text: card.modelData.appName
                            font.pixelSize: 10
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }
}
