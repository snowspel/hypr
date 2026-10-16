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

    WlrLayershell.namespace: "snow-themes"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string binDir: Quickshell.env("HOME") + "/.config/snow/bin/"

    // ---------- data ----------
    property var themes: []            // [{name, mode, bg, surface, accent, text}]
    property string current: ""
    property bool autoWall: false
    property string mode: "dark"
    property var looks: []             // ["minimal", "glassy", ...]
    property string look: "minimal"

    // ---------- editor state ----------
    property bool editing: false
    property string editKind: ""       // "theme" or "look" (what is open in the right panel)
    property string editOrig: ""       // name that was opened
    property string edName: ""         // name in the text box (change it to save a copy)
    property var ed: ({})              // theme colors or look values being edited
    property string pickKey: ""        // color key whose picker is open

    readonly property var colorKeys: [
        { k: "bg", l: "Background" }, { k: "surface", l: "Surface" }, { k: "surfaceHi", l: "Surface (raised)" },
        { k: "text", l: "Text" }, { k: "muted", l: "Muted text" }, { k: "accent", l: "Accent" },
        { k: "warn", l: "Warning" }, { k: "danger", l: "Danger" }, { k: "success", l: "Success" },
        { k: "tint", l: "Tint (borders, overlays)" }
    ]
    readonly property var curves: ["quick", "easeOutQuint", "easeInOutCubic", "spring"]

    // fixed geometry of the single Personalisation window (design: 560 wide, 960 wide while editing)
    readonly property int bodyH: 384
    property bool previewed: false     // true while unsaved theme colors are shown on screen (Cancel / switching puts the old ones back)
    property string wpPath: ""         // the current wallpaper picture (shown as the preview)
    property string wpStamp: ""        // its modified time (so a new picture with the same name is loaded again)

    // looks in display order: "custom" first (full width), then the others
    readonly property var lookModel: {
        var out = []
        if (win.looks.indexOf("custom") >= 0) out.push("custom")
        for (var i = 0; i < win.looks.length; i++) if (win.looks[i] !== "custom") out.push(win.looks[i])
        return out
    }
    function lookGlyph(n) {
        var m = { custom: "\ue429", glassy: "\ue3a5", minimal: "\ue3c6", snappy: "\uea0b", soft: "\uef4a" }
        return m[n] || "\ue41d"
    }
    // which theme / look the editor opens first
    function themeToEdit() {
        for (var i = 0; i < win.themes.length; i++) if (win.themes[i].name === win.current) return win.current
        return win.themes.length > 0 ? win.themes[0].name : ""
    }
    function lookToEdit() {
        return win.looks.indexOf(win.look) >= 0 ? win.look : (win.looks.length > 0 ? win.looks[0] : "")
    }
    function switchTab(kind) {
        if (kind === win.editKind) return
        if (kind === "theme") { var t = win.themeToEdit(); if (t !== "") win.openTheme(t) }
        else { var l = win.lookToEdit(); if (l !== "") win.openLook(l) }
    }
    // put the saved colors back if unsaved ones are being previewed
    function dropPreview() {
        previewTimer.stop()
        if (win.previewed) Quickshell.execDetached([win.binDir + "switch-theme.sh", "--restore"])
        win.previewed = false
    }

    function isHex(s) { return /^#[0-9a-fA-F]{6}$/.test(s) }
    // same cleaning as the scripts: spaces -> "-", only letters, digits, "-" and "_" (capital letters are kept)
    function clean(n) { return n.replace(/ /g, "-").replace(/[^A-Za-z0-9_-]/g, "") }
    readonly property string edClean: clean(win.edName)
    readonly property bool nameTaken: {
        if (win.edClean === "" || win.edClean === win.editOrig) return false
        if (win.editKind === "theme") return win.themes.some(function(t) { return t.name === win.edClean })
        return win.looks.indexOf(win.edClean) >= 0
    }
    readonly property bool canSave: win.editKind !== "" && win.edClean !== "" && !win.nameTaken
    readonly property bool canSaveNew: win.canSave && win.edClean !== win.editOrig
    readonly property string nameHint: {
        if (win.edClean === "") return "Type a name."
        if (win.nameTaken) return "This name is already used."
        if (win.edClean !== win.editOrig) return "Done renames it to \"" + win.edClean + "\". Save as new keeps the old one too."
        return "Done saves your changes. Change the name and press Save as new to make a copy."
    }

    function reload() {
        listGet.running = true
        stateGet.running = true
        lookList.running = true
        lookGet.running = true
        if (!wpFind.running) wpFind.running = true
    }
    function run(args) {
        Quickshell.execDetached([win.binDir + "switch-theme.sh"].concat(args))
        reloadTimer.restart()
    }
    // choose a new wallpaper picture (the menu hides while the file window is open, then comes back)
    function pickWallpaper() {
        win.visible = false
        Quickshell.execDetached(["bash", win.binDir + "wallpaper.sh", "pick"])
    }
    function setLook(n) {
        win.look = n
        Quickshell.execDetached([win.binDir + "look.sh", "set", n])
    }

    // ---- editor actions ----
    function openTheme(name) {
        win.dropPreview()
        win.pickKey = ""
        win.editKind = "theme"
        win.editOrig = name
        win.edName = name
        editLoad.command = [win.binDir + "themes.sh", "get", name]
        editLoad.running = true
    }
    function openLook(name) {
        win.dropPreview()
        win.pickKey = ""
        win.editKind = "look"
        win.editOrig = name
        win.edName = name
        editLoad.command = [win.binDir + "look.sh", "get", name]
        editLoad.running = true
    }
    function setField(key, val) {
        var o = Object.assign({}, win.ed)
        o[key] = val
        win.ed = o
        if (win.editKind === "theme") { win.previewed = true; previewTimer.restart() }
    }
    function startEdit() {
        win.editing = true
        var t = win.themeToEdit()
        if (t !== "") win.openTheme(t)
    }
    function cancel() {
        win.dropPreview()
        win.editing = false
        win.editKind = ""
        win.pickKey = ""
        win.ed = ({})
    }
    function finish() {
        win.previewed = false
        win.editing = false
        win.editKind = ""
        win.pickKey = ""
        win.ed = ({})
        reloadTimer.restart()
    }
    // Done: save the changes to THIS theme / look (a new name renames it)
    function done() {
        if (!win.canSave) return
        var script = win.editKind === "theme" ? "themes.sh" : "look.sh"
        if (win.editKind !== "theme") win.dropPreview()
        Quickshell.execDetached([win.binDir + script, "save", win.edClean, JSON.stringify(win.ed), win.editOrig])
        win.finish()
    }
    // Save as new: keep the original and create a copy with the new name
    function doneNew() {
        if (!win.canSaveNew) return
        var script = win.editKind === "theme" ? "themes.sh" : "look.sh"
        if (win.editKind !== "theme") win.dropPreview()
        Quickshell.execDetached([win.binDir + script, "save", win.edClean, JSON.stringify(win.ed)])
        win.finish()
    }

    Process {
        id: listGet
        command: [win.binDir + "themes.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|")
                    if (p.length >= 6) out.push({ name: p[0], mode: p[1], bg: p[2], surface: p[3], accent: p[4], text: p[5] })
                }
                win.themes = out
            }
        }
    }
    Process {
        id: stateGet
        command: [win.binDir + "themes.sh", "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("|")
                if (p.length >= 3) {
                    win.current = p[0]
                    win.autoWall = p[1] === "on"
                    win.mode = p[2]
                }
            }
        }
    }
    Process {
        id: lookList
        command: [win.binDir + "look.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.split("\n").filter(function(x) { return x.trim() !== "" })
                if (out.length > 0) win.looks = out
            }
        }
    }
    Process {
        id: lookGet
        command: [win.binDir + "look.sh", "state"]
        stdout: StdioCollector { onStreamFinished: win.look = text.trim() || "minimal" }
    }
    Process {
        id: wpFind
        // same search as Wallpaper.qml: the newest picture in ~/.config/hypr/wallpaper
        command: ["bash", "-c", "shopt -s nullglob nocaseglob; f=$(ls -t \"$HOME\"/.config/hypr/wallpaper/*.{jpg,jpeg,png,webp} 2>/dev/null | head -1); [ -n \"$f\" ] && echo \"$(stat -c %Y \"$f\")|$f\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim()
                var i = s.indexOf("|")
                if (i > 0) { win.wpStamp = s.slice(0, i); win.wpPath = s.slice(i + 1) }
                else { win.wpStamp = ""; win.wpPath = "" }
            }
        }
    }
    Process {
        id: editLoad
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.ed = JSON.parse(text) } catch (e) { win.ed = ({}) }
            }
        }
    }
    Timer { id: reloadTimer; interval: 900; onTriggered: win.reload() }
    Timer {
        id: previewTimer
        interval: 250
        onTriggered: Quickshell.execDetached([win.binDir + "themes.sh", "preview", JSON.stringify(win.ed)])
    }

    onVisibleChanged: {
        if (visible) { reload(); keys.forceActiveFocus() }
        else if (win.editing) win.cancel()
    }

    IpcHandler {
        target: "themes"
        function toggle(): void { win.visible = !win.visible }
    }


    // ---------- small reusable pieces (same look as Quick Settings v8) ----------
    component Ms: Text {
        font.family: "Material Symbols Rounded"
        font.pixelSize: 20
        color: Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // section label: small accent dot + spaced capitals (+ optional hint in accent color)
    component Lab: Item {
        id: lab
        property string text: ""
        property string hint: ""
        height: 22
        Rectangle { x: 2; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Theme.accent }
        Text {
            id: labTxt
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: lab.text.toUpperCase()
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.6
            color: Theme.muted
        }
        Text {
            visible: lab.hint !== ""
            x: labTxt.x + labTxt.width + 8
            anchors.verticalCenter: parent.verticalCenter
            text: lab.hint
            font.pixelSize: 10
            color: Theme.accent
        }
    }

    // gradient surface card (tintColor mixed in at the top)
    component Card: Rectangle {
        id: cd
        property color tintColor: Theme.tint
        property real tintAmt: 0.04
        border.width: 1
        border.color: Qt.alpha(Theme.tint, 0.06)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.tint(Theme.surface, Qt.alpha(cd.tintColor, cd.tintAmt)) }
            GradientStop { position: 1.0; color: Theme.surface }
        }
    }

    // pill button: plain (surfaceHi) or primary (accent gradient)
    component Btn: Rectangle {
        id: bt
        property string text: ""
        property bool primary: false
        property bool bordered: false
        property bool enabledBtn: true
        signal clicked()
        height: 32
        radius: 12
        opacity: enabledBtn ? 1 : 0.4
        readonly property color hovBg: Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.tint, 0.08))
        property color c0: primary ? Qt.tint(Theme.accent, Qt.rgba(1, 1, 1, 0.2)) : (bma.containsMouse && enabledBtn ? hovBg : Theme.surfaceHi)
        property color c1: primary ? Theme.accent : (bma.containsMouse && enabledBtn ? hovBg : Theme.surfaceHi)
        Behavior on c0 { ColorAnimation { duration: 150 } }
        Behavior on c1 { ColorAnimation { duration: 150 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: bt.c0 }
            GradientStop { position: 1.0; color: bt.c1 }
        }
        border.width: bordered ? 1 : 0
        border.color: Qt.alpha(Theme.tint, 0.10)
        scale: (bma.pressed && enabledBtn) ? 0.97 : 1
        Text {
            anchors.centerIn: parent
            text: bt.text
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: bt.primary ? "#ffffff" : Theme.text
        }
        MouseArea {
            id: bma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (bt.enabledBtn) bt.clicked()
        }
    }

    component Switch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        width: 36
        height: 20
        radius: 10
        color: checked ? Theme.accent : Theme.surfaceHi
        border.width: 1
        border.color: Qt.alpha(Theme.tint, 0.06)
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 14; height: 14; radius: 7
            y: 3
            x: sw.checked ? 19 : 3
            color: sw.checked ? "#ffffff" : Theme.muted
            Behavior on x { NumberAnimation { duration: 150 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }

    component Caption: Text {
        font.pixelSize: 10
        font.weight: Font.Bold
        font.letterSpacing: 1.4
        color: Theme.muted
        topPadding: 6
    }

    component NumRow: Item {
        id: nr
        property string label: ""
        property real from: 0
        property real to: 1
        property real step: 1
        property real value: 0
        property int decimals: 0
        signal moved(real v)
        readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
        width: parent ? parent.width : 300
        height: 30

        function pick(mx) {
            var f = Math.max(0, Math.min(1, mx / track.width))
            var v = nr.from + f * (nr.to - nr.from)
            v = Math.round(v / nr.step) * nr.step
            v = Math.max(nr.from, Math.min(nr.to, v))
            nr.moved(Number(v.toFixed(4)))
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 146
            elide: Text.ElideRight
            text: nr.label
            font.pixelSize: 12
            color: Theme.text
        }
        Rectangle {
            id: track
            x: 152
            width: parent.width - 152 - 40
            height: 6
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceHi
            Rectangle {
                width: track.width * nr.frac
                height: parent.height
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.accent, 0.5)) }
                    GradientStop { position: 1.0; color: Theme.accent }
                }
            }
            Rectangle {
                x: track.width * nr.frac - 7
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: "#ffffff"
                border.width: 1
                border.color: Qt.alpha(Theme.tint, 0.3)
            }
            MouseArea {
                anchors { fill: parent; topMargin: -10; bottomMargin: -10 }
                onPressed: (m) => nr.pick(m.x)
                onPositionChanged: (m) => { if (pressed) nr.pick(m.x) }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: nr.value.toFixed(nr.decimals)
            font.pixelSize: 11
            font.family: "JetBrains Mono"
            color: Theme.muted
        }
    }

    component ToggleRow: Item {
        id: tr
        property string label: ""
        property bool checked: false
        signal toggled()
        width: parent ? parent.width : 300
        height: 30
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            font.pixelSize: 12
            color: Theme.text
        }
        Switch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: tr.checked
            onToggled: tr.toggled()
        }
    }

    component ChipRow: Column {
        id: cr
        property string label: ""
        property var options: []
        property string current: ""
        signal picked(string v)
        width: parent ? parent.width : 300
        spacing: 6
        Text { text: cr.label; font.pixelSize: 12; color: Theme.text }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: cr.options
                delegate: Rectangle {
                    id: chip
                    required property string modelData
                    width: chipTxt.width + 22
                    height: 26
                    radius: 13
                    color: cr.current === modelData ? Theme.accent : Theme.surfaceHi
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        id: chipTxt
                        anchors.centerIn: parent
                        text: chip.modelData
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: cr.current === chip.modelData ? "#ffffff" : Theme.text
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cr.picked(chip.modelData) }
                }
            }
        }
    }

    // GUI color chooser: saturation/brightness square + hue bar
    component ColorPicker: Item {
        id: cp
        property real h: 0
        property real s: 0
        property real v: 1
        signal picked(string hex)
        width: parent ? parent.width : 300
        height: svBox.height + 12 + hueBar.height

        function load(hex) {
            var q = Qt.color(hex)
            if (q.hsvHue >= 0) cp.h = q.hsvHue
            cp.s = q.hsvSaturation
            cp.v = q.hsvValue
        }
        function emitColor() { cp.picked(Qt.hsva(cp.h, cp.s, cp.v, 1).toString()) }

        Rectangle {
            id: svBox
            width: parent.width
            height: 150
            radius: 8
            color: Qt.hsva(cp.h, 1, 1, 1)
            Rectangle {
                anchors.fill: parent
                radius: 8
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ffffff" }
                    GradientStop { position: 1; color: "#00ffffff" }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#000000" }
                }
            }
            Rectangle {
                x: cp.s * svBox.width - 7
                y: (1 - cp.v) * svBox.height - 7
                width: 14; height: 14; radius: 7
                color: "transparent"
                border.width: 2
                border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                function pick(m) {
                    cp.s = Math.max(0, Math.min(1, m.x / width))
                    cp.v = 1 - Math.max(0, Math.min(1, m.y / height))
                    cp.emitColor()
                }
                onPressed: (m) => pick(m)
                onPositionChanged: (m) => { if (pressed) pick(m) }
            }
        }
        Rectangle {
            id: hueBar
            y: svBox.height + 12
            width: parent.width
            height: 14
            radius: 7
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "#ff0000" }
                GradientStop { position: 0.17; color: "#ffff00" }
                GradientStop { position: 0.33; color: "#00ff00" }
                GradientStop { position: 0.50; color: "#00ffff" }
                GradientStop { position: 0.67; color: "#0000ff" }
                GradientStop { position: 0.83; color: "#ff00ff" }
                GradientStop { position: 1.00; color: "#ff0000" }
            }
            Rectangle {
                x: cp.h * hueBar.width - 7
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: Qt.hsva(cp.h, 1, 1, 1)
                border.width: 2
                border.color: "#ffffff"
            }
            MouseArea {
                anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
                function pick(m) {
                    cp.h = Math.max(0, Math.min(0.999, m.x / width))
                    cp.emitColor()
                }
                onPressed: (m) => pick(m)
                onPositionChanged: (m) => { if (pressed) pick(m) }
            }
        }
    }

    // ---------- layout: ONE window; it gets wider (560 -> 960) while editing ----------
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (win.pickKey !== "") win.pickKey = ""
            else if (win.editing) win.cancel()
            else win.visible = false
        }

        MouseArea { anchors.fill: parent; onClicked: if (!win.editing) win.visible = false }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: win.editing ? 960 : 560
            height: 20 + 28 + 14 + 1 + 12 + win.bodyH + 20
            radius: 24
            clip: true
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.24)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(Theme.bg, Qt.alpha(Theme.accent, 0.07)) }
                GradientStop { position: 1.0; color: Theme.bg }
            }
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent }

            // ----- header -----
            Item {
                id: header
                x: 20
                y: 20
                width: parent.width - 40
                height: 28
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Personalisation"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: Theme.text
                }
                Btn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 80
                    height: 28
                    radius: 14
                    primary: win.editing
                    text: win.editing ? "Editing" : "Edit"
                    onClicked: if (win.editing) win.cancel(); else win.startEdit()
                }
            }
            Rectangle { x: 20; y: 20 + 28 + 14; width: parent.width - 40; height: 1; color: Qt.alpha(Theme.tint, 0.05) }

            // ----- body -----
            Item {
                id: body
                x: 20
                y: 20 + 28 + 14 + 1 + 12
                width: parent.width - 40
                height: win.bodyH

                // ================= left column (210): wallpaper + window look =================
                Item {
                    id: leftCol
                    width: 210
                    height: parent.height

                    Lab { id: wpLab; text: "Wallpaper"; width: parent.width }

                    Card {
                        id: wpCard
                        y: 22
                        width: parent.width
                        height: Math.max(120, lkLab.y - 12 - 22)     // fills the space down to the Window Look label
                        radius: 16

                        // current wallpaper as a picture; click = choose a new one (a glass icon sits on top of it)
                        Rectangle {
                            id: wpBtn
                            x: 10
                            y: 10
                            width: parent.width - 20
                            height: wpCard.height - 10 - 8 - 24 - 10
                            radius: 12
                            border.width: 1
                            border.color: Qt.alpha(Theme.tint, 0.10)
                            scale: wpMa.containsMouse ? 1.01 : 1
                            Behavior on scale { NumberAnimation { duration: 150 } }
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.darker(Theme.bg, 1.3) }
                                GradientStop { position: 0.55; color: Theme.bg }
                                GradientStop { position: 1.0; color: Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.accent, 0.35)) }
                            }

                            // the picture (own file + Loader: if the effects module is missing, only the picture is lost)
                            Loader {
                                id: wpPic
                                anchors.fill: parent
                                source: "WallpaperPreview.qml"
                                onLoaded: { item.radius = 12; item.source = Qt.binding(function() { return win.wpPath !== "" ? "file://" + win.wpPath + "?v=" + win.wpStamp : "" }) }
                            }
                            // dark veil: a little always (so the icon reads on any picture), more on hover
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: Qt.rgba(0, 0, 0, wpMa.containsMouse ? 0.40 : 0.18)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            // glass icon chip
                            Rectangle {
                                id: glass
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: wpMa.containsMouse ? -10 : 0
                                width: 48
                                height: 48
                                radius: 24
                                color: Qt.rgba(0, 0, 0, 0.45)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.28)
                                scale: wpMa.containsMouse ? 1.08 : 1
                                Behavior on scale { NumberAnimation { duration: 150 } }
                                Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 150 } }
                                Ms { anchors.centerIn: parent; text: "\ue1bc"; font.pixelSize: 26; color: "#ffffff" }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: glass.bottom
                                anchors.topMargin: 6
                                text: "Change wallpaper"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                                opacity: wpMa.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            MouseArea {
                                id: wpMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.pickWallpaper()
                            }
                        }

                        // Auto (+ Dark / Light when Auto is on) ........ switch
                        Item {
                            x: 10
                            y: wpCard.height - 10 - 24
                            width: parent.width - 20
                            height: 24

                            Text {
                                id: autoTxt
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Auto"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: win.autoWall ? Theme.accent : Theme.muted
                            }
                            Rectangle {
                                visible: win.autoWall
                                x: autoTxt.x + autoTxt.width + 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 92
                                height: 24
                                radius: 12
                                color: Theme.surfaceHi
                                Row {
                                    x: 2
                                    y: 2
                                    Repeater {
                                        model: ["dark", "light"]
                                        delegate: Rectangle {
                                            id: seg
                                            required property string modelData
                                            width: 44
                                            height: 20
                                            radius: 10
                                            color: win.mode === modelData ? Theme.accent : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: seg.modelData === "dark" ? "Dark" : "Light"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: win.mode === seg.modelData ? "#ffffff" : Theme.muted
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { win.mode = seg.modelData; win.run([seg.modelData]) }
                                            }
                                        }
                                    }
                                }
                            }
                            Switch {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                checked: win.autoWall
                                onToggled: { win.autoWall = !win.autoWall; win.run(["auto", win.autoWall ? "on" : "off"]) }
                            }
                        }
                    }

                    Lab { id: lkLab; y: lkBar.y - 22; text: "Window look"; hint: win.editing ? "(click to edit)" : ""; width: parent.width }

                    Rectangle {
                        id: lkBar
                        y: parent.height - height            // sits at the bottom, level with the end of the themes column
                        width: parent.width
                        height: Math.min(lkFlow.height + 8, 148)
                        radius: 14
                        color: Qt.darker(Theme.bg, 1.25)
                        border.width: 1
                        border.color: Qt.alpha(Theme.tint, 0.05)

                        Flickable {
                            x: 4
                            y: 4
                            width: parent.width - 8
                            height: parent.height - 8
                            contentHeight: lkFlow.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Flow {
                                id: lkFlow
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: win.lookModel
                                    delegate: Rectangle {
                                        id: lk
                                        required property string modelData
                                        readonly property bool sel: win.editing
                                            ? (win.editKind === "look" && win.editOrig === modelData)
                                            : win.look === modelData
                                        width: modelData === "custom" ? lkFlow.width : (lkFlow.width - 6) / 2
                                        height: 32
                                        radius: 10
                                        property color c0: sel ? Qt.tint(Theme.accent, Qt.rgba(1, 1, 1, 0.2)) : (lkMa.containsMouse ? Qt.alpha(Theme.tint, 0.06) : "transparent")
                                        property color c1: sel ? Theme.accent : (lkMa.containsMouse ? Qt.alpha(Theme.tint, 0.06) : "transparent")
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: lk.c0 }
                                            GradientStop { position: 1.0; color: lk.c1 }
                                        }
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Ms { anchors.verticalCenter: parent.verticalCenter; text: win.lookGlyph(lk.modelData); font.pixelSize: 15; color: lk.sel ? "#ffffff" : Theme.muted }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: lk.modelData.charAt(0).toUpperCase() + lk.modelData.slice(1)
                                                font.pixelSize: 12
                                                font.weight: lk.sel ? Font.Bold : Font.DemiBold
                                                color: lk.sel ? "#ffffff" : Theme.text
                                            }
                                        }
                                        MouseArea {
                                            id: lkMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (win.editing) win.openLook(lk.modelData); else win.setLook(lk.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= right column (294): custom themes =================
                Item {
                    id: rightCol
                    x: 226
                    width: 294
                    height: parent.height

                    Lab { text: "Custom themes"; hint: win.editing ? "(click to edit)" : ""; width: parent.width }

                    Flickable {
                        y: 22
                        width: parent.width
                        height: parent.height - 22
                        contentHeight: tGrid.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Grid {
                            id: tGrid
                            columns: 2
                            spacing: 8
                            width: parent.width
                            readonly property real cardW: (width - spacing) / 2
                            readonly property real cardH: Math.floor((win.bodyH - 22 - 3 * spacing) / 4)    // 4 rows fill the column

                            Repeater {
                                model: win.themes
                                delegate: Rectangle {
                                    id: tc
                                    required property var modelData
                                    readonly property bool sel: win.editing
                                        ? (win.editKind === "theme" && win.editOrig === modelData.name)
                                        : (!win.autoWall && win.current === modelData.name)
                                    width: tGrid.cardW
                                    height: tGrid.cardH
                                    radius: 16
                                    border.width: sel ? 2 : 1
                                    border.color: sel ? modelData.accent : Qt.alpha(modelData.text, 0.18)
                                    opacity: (win.autoWall && !win.editing) ? 0.55 : 1
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Qt.tint(tc.modelData.bg, Qt.alpha(tc.modelData.accent, 0.14)) }
                                        GradientStop { position: 1.0; color: tc.modelData.bg }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: Qt.alpha(tc.modelData.text, 0.07)
                                        visible: tcMa.containsMouse
                                    }

                                    Text {
                                        x: 12
                                        y: 11
                                        width: parent.width - 12 - 36
                                        elide: Text.ElideRight
                                        text: tc.modelData.name
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: tc.modelData.text
                                    }
                                    // check mark (pencil while editing) on the selected card
                                    Rectangle {
                                        visible: tc.sel
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        y: 9
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: Qt.alpha(tc.modelData.accent, 0.22)
                                        Ms {
                                            anchors.centerIn: parent
                                            text: win.editing ? "\uf097" : "\ue876"
                                            font.pixelSize: 14
                                            color: tc.modelData.accent
                                        }
                                    }
                                    Row {
                                        x: 12
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 11
                                        spacing: 6
                                        Repeater {
                                            model: [tc.modelData.surface, tc.modelData.accent, tc.modelData.text]
                                            delegate: Rectangle {
                                                required property string modelData
                                                width: 14; height: 14; radius: 7
                                                color: modelData
                                                border.width: 1
                                                border.color: Qt.alpha(tc.modelData.text, 0.25)
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: tcMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (win.editing) win.openTheme(tc.modelData.name)
                                            else { win.autoWall = false; win.current = tc.modelData.name; win.run(["set", tc.modelData.name]) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= editor wing (only while editing) =================
                Rectangle {
                    x: 540
                    width: 1
                    height: parent.height
                    color: Qt.alpha(Theme.tint, 0.10)
                    opacity: edPanel.opacity
                    visible: edPanel.visible
                }

                Item {
                    id: edPanel
                    x: 561
                    width: 359
                    height: parent.height
                    opacity: win.editing ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // title + Theme / Window Look switch
                    Item {
                        id: edHdr
                        width: parent.width
                        height: 32
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Ms { anchors.verticalCenter: parent.verticalCenter; text: win.editKind === "look" ? "\ue429" : "\ue40a"; font.pixelSize: 18; color: Theme.accent }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.editKind === "look" ? "Edit Window Look" : "Edit Theme"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Theme.text
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 26
                            width: tabRow.width + 4
                            radius: 9
                            color: Theme.surfaceHi
                            Row {
                                id: tabRow
                                x: 2
                                y: 2
                                Repeater {
                                    model: [ { k: "theme", l: "Theme" }, { k: "look", l: "Window Look" } ]
                                    delegate: Rectangle {
                                        id: tab
                                        required property var modelData
                                        width: tabTxt.width + 20
                                        height: 22
                                        radius: 7
                                        color: win.editKind === modelData.k ? Theme.accent : "transparent"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            id: tabTxt
                                            anchors.centerIn: parent
                                            text: tab.modelData.l
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: win.editKind === tab.modelData.k ? "#ffffff" : Theme.muted
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.switchTab(tab.modelData.k) }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: win.editKind === ""
                        anchors.centerIn: parent
                        width: parent.width - 40
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Click a theme or a window look on the left to edit it."
                        font.pixelSize: 13
                        color: Theme.muted
                    }

                    // name + Save as new
                    Rectangle {
                        id: nameBox
                        visible: win.editKind !== ""
                        y: 40
                        width: parent.width - 100
                        height: 32
                        radius: 10
                        color: Theme.surface
                        border.width: 1
                        border.color: nameIn.activeFocus ? Theme.accent : Qt.alpha(Theme.tint, 0.10)
                        Text {
                            visible: nameIn.text === ""
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Name"
                            font.pixelSize: 13
                            color: Theme.muted
                        }
                        TextInput {
                            id: nameIn
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 13
                            color: Theme.text
                            clip: true
                            text: win.edName
                            onTextEdited: win.edName = text
                        }
                    }
                    Btn {
                        visible: win.editKind !== ""
                        x: parent.width - 92
                        y: 40
                        width: 92
                        height: 32
                        bordered: true
                        enabledBtn: win.canSaveNew
                        text: "Save as new"
                        onClicked: win.doneNew()
                    }
                    Text {
                        visible: win.editKind !== ""
                        y: 77
                        width: parent.width
                        elide: Text.ElideRight
                        text: win.nameHint
                        font.pixelSize: 10
                        color: (win.edClean === "" || win.nameTaken) ? Theme.danger : Theme.muted
                    }

                    // scrolling form
                    Flickable {
                        id: fl
                        visible: win.editKind !== ""
                        y: 96
                        width: parent.width
                        height: win.editKind === "theme" ? 232 : 238
                        clip: true
                        contentHeight: edCol.height + 4
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: edCol
                            width: fl.width
                            spacing: 4

                            // ---- theme colors ----
                            Column {
                                visible: win.editKind === "theme"
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: win.editKind === "theme" ? win.colorKeys : []
                                    delegate: Item {
                                        id: crow
                                        required property var modelData
                                        width: parent.width
                                        height: 28
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 150
                                            elide: Text.ElideRight
                                            text: crow.modelData.l
                                            font.pixelSize: 12
                                            color: Theme.text
                                        }
                                        Rectangle {
                                            x: parent.width - 20 - 8 - 86
                                            width: 86
                                            height: 26
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: 8
                                            color: Theme.surface
                                            border.width: 1
                                            border.color: hexIn.activeFocus ? Theme.accent : Qt.alpha(Theme.tint, 0.10)
                                            TextInput {
                                                id: hexIn
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                verticalAlignment: TextInput.AlignVCenter
                                                horizontalAlignment: TextInput.AlignHCenter
                                                font.pixelSize: 11
                                                font.family: "JetBrains Mono"
                                                color: win.isHex(text) ? Theme.text : Theme.danger
                                                maximumLength: 7
                                                text: win.ed[crow.modelData.k] || ""
                                                onTextEdited: if (win.isHex(text)) win.setField(crow.modelData.k, text.toLowerCase())
                                            }
                                        }
                                        Rectangle {
                                            x: parent.width - 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 20; height: 20; radius: 10
                                            color: win.isHex(win.ed[crow.modelData.k] || "") ? win.ed[crow.modelData.k] : "transparent"
                                            border.width: win.pickKey === crow.modelData.k ? 2 : 1
                                            border.color: win.pickKey === crow.modelData.k ? Theme.accent : Qt.alpha(Theme.tint, 0.3)
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (win.pickKey === crow.modelData.k) win.pickKey = ""
                                                    else { win.pickKey = crow.modelData.k; picker.load(win.ed[crow.modelData.k] || "#ffffff") }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ---- window look ----
                            Column {
                                visible: win.editKind === "look"
                                width: parent.width
                                spacing: 4

                                Caption { text: "SPACING AND SHAPE" }
                                NumRow { label: "Gap between windows"; from: 0; to: 24; step: 1; value: win.ed.gaps_in || 0; onMoved: (v) => win.setField("gaps_in", v) }
                                NumRow { label: "Gap to screen edge"; from: 0; to: 48; step: 1; value: win.ed.gaps_out || 0; onMoved: (v) => win.setField("gaps_out", v) }
                                NumRow { label: "Border width"; from: 0; to: 6; step: 1; value: win.ed.border_size || 0; onMoved: (v) => win.setField("border_size", v) }
                                NumRow { label: "Corner radius"; from: 0; to: 32; step: 1; value: win.ed.rounding || 0; onMoved: (v) => win.setField("rounding", v) }
                                NumRow { label: "Active window opacity"; from: 0.5; to: 1; step: 0.01; decimals: 2; value: win.ed.active_opacity || 1; onMoved: (v) => win.setField("active_opacity", v) }
                                NumRow { label: "Inactive window opacity"; from: 0.5; to: 1; step: 0.01; decimals: 2; value: win.ed.inactive_opacity || 1; onMoved: (v) => win.setField("inactive_opacity", v) }
                                NumRow { label: "Terminal opacity"; from: 0.5; to: 1; step: 0.01; decimals: 2; value: win.ed.terminal_opacity || 1; onMoved: (v) => win.setField("terminal_opacity", v) }

                                Caption { text: "SHADOW AND BLUR" }
                                ToggleRow { label: "Shadow"; checked: win.ed.shadow === true; onToggled: win.setField("shadow", !(win.ed.shadow === true)) }
                                NumRow { label: "Shadow size"; from: 0; to: 64; step: 1; value: win.ed.shadow_range || 0; onMoved: (v) => win.setField("shadow_range", v) }
                                ToggleRow { label: "Glow shadow (accent color)"; checked: win.ed.shadow_glow === true; onToggled: win.setField("shadow_glow", !(win.ed.shadow_glow === true)) }
                                ToggleRow { label: "Blur"; checked: win.ed.blur === true; onToggled: win.setField("blur", !(win.ed.blur === true)) }
                                NumRow { label: "Blur size"; from: 1; to: 16; step: 1; value: win.ed.blur_size || 1; onMoved: (v) => win.setField("blur_size", v) }
                                NumRow { label: "Blur passes"; from: 1; to: 5; step: 1; value: win.ed.blur_passes || 1; onMoved: (v) => win.setField("blur_passes", v) }
                                ToggleRow { label: "Blur behind panels"; checked: win.ed.panel_blur === true; onToggled: win.setField("panel_blur", !(win.ed.panel_blur === true)) }

                                Caption { text: "ANIMATION" }
                                ToggleRow { label: "Animations"; checked: win.ed.anim === true; onToggled: win.setField("anim", !(win.ed.anim === true)) }
                                NumRow { label: "Animation length"; from: 1; to: 10; step: 0.1; decimals: 1; value: win.ed.anim_speed || 3; onMoved: (v) => win.setField("anim_speed", v) }
                                NumRow { label: "Window pop-in %"; from: 70; to: 100; step: 1; value: win.ed.anim_popin || 90; onMoved: (v) => win.setField("anim_popin", v) }
                                ChipRow { label: "Animation curve"; options: win.curves; current: win.ed.anim_curve || "quick"; onPicked: (v) => win.setField("anim_curve", v) }
                                ChipRow { label: "Workspace animation"; options: ["slide", "fade"]; current: win.ed.anim_workspace || "slide"; onPicked: (v) => win.setField("anim_workspace", v) }
                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: "Window changes are applied when you press Done."
                                    font.pixelSize: 10
                                    color: Theme.muted
                                }
                            }
                        }
                    }

                    // color picker card (opens over the editor)
                    Card {
                        id: pickerCard
                        visible: win.pickKey !== "" && win.editKind === "theme"
                        z: 5
                        y: 96
                        width: parent.width
                        height: pickCol.height + 28
                        radius: 16
                        border.color: Qt.alpha(Theme.tint, 0.16)

                        Column {
                            id: pickCol
                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 12
                            Item {
                                width: parent.width
                                height: 24
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        for (var i = 0; i < win.colorKeys.length; i++) if (win.colorKeys[i].k === win.pickKey) return win.colorKeys[i].l
                                        return ""
                                    }
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                                Btn {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 56
                                    height: 24
                                    radius: 12
                                    primary: true
                                    text: "OK"
                                    onClicked: win.pickKey = ""
                                }
                            }
                            ColorPicker {
                                id: picker
                                onPicked: (hex) => { if (win.pickKey !== "") win.setField(win.pickKey, hex) }
                            }
                        }
                    }

                    // Done / Cancel
                    Row {
                        visible: win.editKind !== ""
                        y: parent.height - 38
                        width: parent.width
                        spacing: 10

                        Btn {
                            width: (parent.width - 10) / 2
                            height: 38
                            primary: true
                            enabledBtn: win.canSave
                            text: "Done"
                            onClicked: win.done()
                        }
                        Btn {
                            width: (parent.width - 10) / 2
                            height: 38
                            bordered: true
                            text: "Cancel"
                            onClicked: win.cancel()
                        }
                    }
                }
            }
        }
    }
}
