import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs

PanelWindow {
    id: win

    visible: false
    color: Qt.rgba(0, 0, 0, 0.45)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "snow-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string query: ""
    property bool listMode: false          // false = grid, true = list
    readonly property string viewFile: Quickshell.env("HOME") + "/.config/snow/launcher-view"

    Process {
        id: viewGet
        command: ["sh", "-c", "cat \"" + win.viewFile + "\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: win.listMode = text.trim() === "list" }
    }
    function setView(list) {
        win.listMode = list
        Quickshell.execDetached(["sh", "-c", "echo " + (list ? "list" : "grid") + " > \"" + win.viewFile + "\""])
        grid.currentIndex = 0
    }
    Component.onCompleted: viewGet.running = true

    readonly property var apps: {
        var q = win.query.toLowerCase().trim()
        var all = DesktopEntries.applications.values.filter(function(e) { return !e.noDisplay })
        if (q !== "") {
            all = all.filter(function(e) {
                return e.name.toLowerCase().indexOf(q) !== -1
                    || (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1)
                    || (e.comment && e.comment.toLowerCase().indexOf(q) !== -1)
            })
            // names that start with the query come first
            all.sort(function(a, b) {
                var as = a.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
                var bs = b.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
                return (as - bs) || a.name.localeCompare(b.name)
            })
        } else {
            all.sort(function(a, b) { return a.name.localeCompare(b.name) })
        }
        return all
    }

    function openPanel(target) {
        win.visible = false
        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/snow", "ipc", "call", target, "toggle"])
    }

    function launch(entry) {
        if (!entry) return
        win.visible = false
        entry.execute()
    }

    onVisibleChanged: {
        if (visible) {
            search.text = ""
            win.query = ""
            grid.currentIndex = 0
            search.forceActiveFocus()
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { win.visible = !win.visible }
    }

    Item {
        anchors.fill: parent

        MouseArea { anchors.fill: parent; onClicked: win.visible = false }

        Rectangle {
            id: panel
            width: win.listMode ? 470 : 534
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            height: Math.min(parent.height - 100, 680)
            anchors.centerIn: parent
            radius: 14
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.24)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(Theme.bg, Qt.alpha(Theme.accent, 0.07)) }
                GradientStop { position: 1.0; color: Theme.bg }
            }

            MouseArea { anchors.fill: parent }

            // search box
            Rectangle {
                id: searchBox
                x: 18
                y: 18
                width: parent.width - 36 - 82
                height: 52
                radius: 10
                color: Qt.alpha(Theme.tint, 0.08)
                border.width: 1
                border.color: search.activeFocus ? Theme.accent : Qt.alpha(Theme.tint, 0.14)

                // search icon (Google Material Symbols)
                Text {
                    id: mag
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uef7a"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 24
                    color: Theme.muted
                }

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 48
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 18
                    color: Theme.text
                    clip: true
                    onTextChanged: { win.query = text; grid.currentIndex = 0 }

                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true }
                        else if (e.key === Qt.Key_Down)  { grid.moveCurrentIndexDown();  e.accepted = true }
                        else if (e.key === Qt.Key_Up)    { grid.moveCurrentIndexUp();    e.accepted = true }
                        else if (e.key === Qt.Key_Right) { grid.moveCurrentIndexRight(); e.accepted = true }
                        else if (e.key === Qt.Key_Left)  { grid.moveCurrentIndexLeft();  e.accepted = true }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            win.launch(win.apps[grid.currentIndex]); e.accepted = true
                        }
                    }

                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search..."
                        font.pixelSize: 18
                        color: Theme.muted
                    }
                }
            }

            // grid / list switcher (top right)
            Row {
                id: viewSwitch
                anchors.right: parent.right
                anchors.rightMargin: 18
                y: 18
                height: 52
                spacing: 6

                Repeater {
                    model: ["grid", "list"]
                    delegate: Rectangle {
                        id: vb
                        required property string modelData
                        readonly property bool on: (modelData === "list") === win.listMode
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 10
                        color: on ? Theme.accent : (vma.containsMouse ? Qt.alpha(Theme.tint, 0.12) : Qt.alpha(Theme.tint, 0.07))
                        Text {
                            anchors.centerIn: parent
                            text: vb.modelData === "grid" ? "\ue9b0" : "\ue8ef"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 22
                            color: vb.on ? "#ffffff" : Theme.text
                        }
                        MouseArea {
                            id: vma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.setView(vb.modelData === "list")
                        }
                    }
                }
            }

            Text {
                visible: win.apps.length === 0
                anchors.centerIn: parent
                text: "No applications found"
                font.pixelSize: 14
                color: Theme.muted
            }

            // sidebar (grid view only): clock, themes, settings, power (power is the lowest)
            Rectangle {
                id: sidebar
                visible: !win.listMode
                x: 18
                y: searchBox.y + searchBox.height + 16
                width: 52
                height: parent.height - y - 18
                radius: 12
                color: Qt.alpha(Theme.tint, 0.05)
                border.width: 1
                border.color: Qt.alpha(Theme.tint, 0.08)

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 7
                    spacing: 6

                    Repeater {
                        model: [
                            { glyph: "\uefd6", target: "clock",   danger: false },
                            { glyph: "\ue40a", target: "themes",  danger: false },
                            { glyph: "\ue8b8", target: "control", danger: false },
                            { glyph: "\uf8c7", target: "power",   danger: true }
                        ]
                        delegate: Rectangle {
                            id: sb
                            required property var modelData
                            width: 38
                            height: 38
                            radius: 10
                            color: sma.containsMouse ? (sb.modelData.danger ? Qt.alpha(Theme.danger, 0.85) : Qt.alpha(Theme.accent, 0.28)) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: sb.modelData.glyph
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 22
                                color: sma.containsMouse && sb.modelData.danger ? "#ffffff" : Theme.text
                            }
                            MouseArea {
                                id: sma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.openPanel(sb.modelData.target)
                            }
                        }
                    }
                }
            }

            GridView {
                id: grid
                x: win.listMode ? 18 : 18 + 52 + 12
                y: searchBox.y + searchBox.height + 16
                width: parent.width - x - 18
                height: parent.height - y - 18
                clip: true
                cellWidth: win.listMode ? width : Math.floor(width / 4)
                cellHeight: win.listMode ? 54 : 104
                model: win.apps
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    property bool cur: GridView.isCurrentItem

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 10
                        color: cell.cur || cma.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
                        border.width: 1
                        border.color: cell.cur ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent"

                        // grid view
                        Column {
                            visible: !win.listMode
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 58
                                height: 58
                                radius: 14
                                color: Qt.alpha(Theme.tint, 0.07)

                                Image {
                                    anchors.centerIn: parent
                                    width: 38
                                    height: 38
                                    sourceSize: Qt.size(76, 76)
                                    source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                                }
                            }
                            Text {
                                width: grid.cellWidth - 14
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: cell.modelData.name
                                font.pixelSize: 12
                                color: Theme.text
                            }
                        }

                        // list view
                        Row {
                            visible: win.listMode
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            spacing: 12

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 38
                                height: 38
                                radius: 10
                                color: Qt.alpha(Theme.tint, 0.07)
                                Image {
                                    anchors.centerIn: parent
                                    width: 26
                                    height: 26
                                    sourceSize: Qt.size(52, 52)
                                    source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: grid.cellWidth - 80
                                spacing: 1
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: cell.modelData.name
                                    font.pixelSize: 14
                                    color: Theme.text
                                }
                                Text {
                                    visible: text !== ""
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: cell.modelData.genericName || cell.modelData.comment || ""
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }
                            }
                        }

                        MouseArea {
                            id: cma
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: grid.currentIndex = cell.index
                            onClicked: win.launch(cell.modelData)
                        }
                    }
                }
            }
        }
    }
}
