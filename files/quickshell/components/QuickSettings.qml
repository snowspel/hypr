import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import qs

PanelWindow {
    id: win

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "snow-control"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property string binDir: Quickshell.env("HOME") + "/.config/snow/bin/"

    // ---------- custom tray menu ----------
    property var menuStack: []
    property var menuCur: null
    property real menuX: 0
    property real menuY: 0
    QsMenuOpener { id: menuOpener; menu: win.menuCur }
    function openMenu(handle, x, y) {
        win.menuX = x
        win.menuY = y
        win.menuStack = [handle]
        win.menuCur = handle
    }
    function menuPush(h) {
        var st = win.menuStack.slice()
        st.push(h)
        win.menuStack = st
        win.menuCur = h
    }
    function menuBack() {
        var st = win.menuStack.slice()
        st.pop()
        win.menuStack = st
        win.menuCur = st.length ? st[st.length - 1] : null
    }
    function menuClose() {
        win.menuStack = []
        win.menuCur = null
    }

    // ---------- state ----------
    property real vol: 0
    property bool muted: false
    property bool ethConnected: false
    property bool saveFile: true
    property bool isLight: false
    property string warpState: "na"     // on | off | wait | na
    property int updateCount: 0
    property var outputs: []            // [{sink, port, label, active, kind}]
    property bool outOpen: false
    property bool powerOpen: false      // the "Power Setting" card
    readonly property string iconFont: "Material Symbols Rounded"   // Google icon font (installed by install-fonts.sh)
    property int pArm: -1               // which of Log out / Restart / Shut down waits for a 2nd click
    readonly property var pActions: [
        { label: "Log out",   glyph: "\ue9ba", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { label: "Restart",   glyph: "\uf053", cmd: ["systemctl", "reboot"] },
        { label: "Shut down", glyph: "\uf8c7", cmd: ["systemctl", "poweroff"] }
    ]
    Timer { id: armTimer; interval: 3000; onTriggered: win.pArm = -1 }
    function pAct(i) {
        if (win.pArm !== i) { win.pArm = i; armTimer.restart(); return }
        win.pArm = -1
        win.visible = false
        Quickshell.execDetached(win.pActions[i].cmd)
    }
    property string pDd: ""             // which Power Setting dropdown is open: "" | screenoff | lock | sleep
    readonly property var pChoices: [0, 5, 10, 15, 30, 45, 60]
    function minLabel(m) { return m === 0 ? "Never" : (m + " min") }
    property int pScreen: 0             // minutes, 0 = Never
    property int pLock: 0
    property int pSleep: 0
    readonly property string outCurrent: {
        for (var i = 0; i < outputs.length; i++) if (outputs[i].active) return outputs[i].label
        return outputs.length > 0 ? outputs[0].label : "No output"
    }

    // dropdown: "" (closed), "wifi" or "bt"
    property string dd: ""
    readonly property bool btOpen: dd === "bt"
    readonly property bool wifiOpen: dd === "wifi"

    property bool btOn: false
    property int btCount: 0
    property bool btScanning: false
    property var btDevices: []

    property bool wifiDev: false
    property bool wifiOn: false
    property string wifiSsid: ""
    property bool wifiScanning: false
    property var wifiNets: []
    property string wifiSel: ""

    property bool brightOk: false
    property bool brightLoaded: false
    property real bright: 0.5
    property int brightMax: 100

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // 12-hour time from the hour number (Qt's "h"/"hh" gives 24h unless "AP" is in the same format)
    readonly property int hour24: clock.date.getHours()
    readonly property string timeText: (hour24 % 12 === 0 ? 12 : hour24 % 12) + ":" + ("0" + clock.date.getMinutes()).slice(-2)
    readonly property string ampmText: hour24 >= 12 ? "PM" : "AM"


    // ---------- inline components (design v8) ----------
    // icons: Google Material Symbols Rounded (font installed by install-fonts.sh); set text to the code point
    component Ms: Text {
        font.family: "Material Symbols Rounded"
        font.pixelSize: 20
        color: Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // card with a soft top-to-bottom gradient (tintColor mixed in at the top)
    component Card: Rectangle {
        id: card
        property color tintColor: Theme.tint
        property real tintAmt: 0.04
        border.width: 1
        border.color: Qt.alpha(Theme.tint, 0.06)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.tint(Theme.surface, Qt.alpha(card.tintColor, card.tintAmt)) }
            GradientStop { position: 1.0; color: Theme.surface }
        }
    }

    // section label: small accent dot + spaced capitals
    component Lab: Item {
        id: lab
        property string text: ""
        height: 28
        Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Theme.accent }
        Text {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            text: lab.text.toUpperCase()
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.6
            color: Theme.muted
        }
    }

    // small pill button (Connect / Disconnect / Pair / Scan)
    component Pill: Rectangle {
        id: pb
        property string text: ""
        property bool primary: false
        signal clicked()
        height: 28
        width: pbt.width + 28
        radius: height / 2
        color: primary ? (pbm.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                       : (pbm.containsMouse ? Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.tint, 0.08)) : Theme.surfaceHi)
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
            id: pbt
            anchors.centerIn: parent
            text: pb.text
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: pb.primary ? "#ffffff" : Theme.text
        }
        MouseArea {
            id: pbm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    // Wi-Fi / Bluetooth pill: click = on / off, the chevron (or right-click) = open its own list
    component ConnPill: Rectangle {
        id: cp
        property string glyph: ""
        property string label: ""
        property bool active: false
        property bool open: false
        signal toggled()
        signal expand()
        height: 56
        radius: 28
        readonly property color hovBg: Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.tint, 0.08))
        property color c0: active ? Qt.tint(Theme.accent, Qt.rgba(1, 1, 1, 0.2)) : (pma.containsMouse ? hovBg : Theme.surfaceHi)
        property color c1: active ? Theme.accent : (pma.containsMouse ? hovBg : Theme.surfaceHi)
        Behavior on c0 { ColorAnimation { duration: 150 } }
        Behavior on c1 { ColorAnimation { duration: 150 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: cp.c0 }
            GradientStop { position: 1.0; color: cp.c1 }
        }
        scale: pma.pressed ? 0.98 : 1

        // soft ring when on
        Rectangle {
            z: -1
            visible: cp.active
            x: -3
            y: -3
            width: parent.width + 6
            height: parent.height + 6
            radius: 31
            color: Qt.alpha(Theme.accent, 0.24)
        }

        MouseArea {
            id: pma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => { if (m.button === Qt.RightButton) cp.expand(); else cp.toggled() }
        }

        Rectangle {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 18
            color: cp.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.alpha(Theme.accent, 0.14)
            Ms { anchors.centerIn: parent; text: cp.glyph; color: cp.active ? "#ffffff" : Theme.accent }
        }
        Text {
            x: 56
            width: parent.width - 56 - 44
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: cp.label
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: cp.active ? "#ffffff" : Theme.text
        }
        Rectangle {
            width: 32
            height: 32
            radius: 16
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: cma.containsMouse ? (cp.active ? Qt.rgba(1, 1, 1, 0.2) : Qt.alpha(Theme.tint, 0.10)) : "transparent"
            Ms {
                anchors.centerIn: parent
                text: cp.open ? "\ue5ce" : "\ue5cf"
                color: cp.active ? "#ffffff" : Theme.muted
            }
            MouseArea {
                id: cma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cp.expand()
            }
        }
    }

    // tile in the side rail (Quick / System): icon turns accent when lit or hovered
    component RailTile: Rectangle {
        id: rt
        property string glyph: ""
        property string label: ""
        property bool lit: false
        property bool disabled: false
        signal clicked()
        width: 62
        height: 56
        radius: 18
        color: (rma.containsMouse && !rt.disabled) ? Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.tint, 0.08)) : Theme.surfaceHi
        Behavior on color { ColorAnimation { duration: 150 } }
        opacity: rt.disabled ? 0.5 : 1
        scale: (rma.pressed && !rt.disabled) ? 0.97 : 1
        Column {
            anchors.centerIn: parent
            spacing: 3
            Ms {
                anchors.horizontalCenter: parent.horizontalCenter
                text: rt.glyph
                font.pixelSize: 24
                color: (rt.lit || (rma.containsMouse && !rt.disabled)) ? Theme.accent : Theme.muted
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: rt.label
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }
        MouseArea {
            id: rma
            anchors.fill: parent
            hoverEnabled: true
            enabled: !rt.disabled
            cursorShape: Qt.PointingHandCursor
            onClicked: rt.clicked()
        }
    }

    // ---------- volume ----------
    Process {
        id: volGet
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/([0-9]+\.[0-9]+)/)
                if (m) win.vol = parseFloat(m[1])
                win.muted = text.indexOf("MUTED") !== -1
            }
        }
    }
    Process { id: volSet }
    property real pendingVol: 0
    Timer {
        id: volThrottle
        interval: 50
        onTriggered: {
            volSet.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", win.pendingVol.toFixed(2)]
            volSet.running = true
        }
    }
    function setVolume(v) {
        win.vol = v
        win.pendingVol = v
        if (!volThrottle.running) volThrottle.start()
    }
    Process {
        id: muteToggle
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onRunningChanged: if (!running) volGet.running = true
    }

    // ---------- ethernet ----------
    Process {
        id: ethCheck
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: win.ethConnected = text.indexOf("ethernet:connected") !== -1
        }
    }

    // ---------- bluetooth ----------
    Process {
        id: btGet
        command: ["sh", "-c", "p=off; bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && p=on; n=$(bluetoothctl devices Connected 2>/dev/null | wc -l); echo \"$p $n\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(" ")
                win.btOn = p[0] === "on"
                win.btCount = parseInt(p[1]) || 0
            }
        }
    }
    Process {
        id: btSet
        onRunningChanged: if (!running) btGet.running = true
    }
    function toggleBt() {
        btSet.command = ["bluetoothctl", "power", win.btOn ? "off" : "on"]
        btSet.running = true
    }
    Process {
        id: btList
        command: ["sh", "-c", "bluetoothctl devices | while read -r _ mac name; do i=$(bluetoothctl info \"$mac\"); c=0; p=0; ic=$(echo \"$i\" | sed -n 's/^[[:space:]]*Icon: //p' | head -1); echo \"$i\" | grep -q 'Connected: yes' && c=1; echo \"$i\" | grep -q 'Paired: yes' && p=1; echo \"$mac|$name|$c|$p|$ic\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("|")
                    if (f.length < 4) continue
                    out.push({ mac: f[0], name: f[1], connected: f[2] === "1", paired: f[3] === "1", icon: f.length > 4 ? f[4] : "" })
                }
                out.sort(function(a, b) { return (b.connected - a.connected) || (b.paired - a.paired) })
                win.btDevices = out
            }
        }
    }
    Process {
        id: btScan
        command: ["bluetoothctl", "--timeout", "10", "scan", "on"]
        onRunningChanged: { win.btScanning = running; if (!running) btList.running = true }
    }
    Process {
        id: btAct
        onRunningChanged: if (!running) btList.running = true
    }
    Timer {
        interval: 2000
        repeat: true
        running: win.btOpen && win.visible
        onTriggered: if (!btList.running) btList.running = true
    }
    onBtOpenChanged: {
        if (btOpen) {
            btList.running = true
            if (btOn && !btScan.running) btScan.running = true
        }
    }
    function btAction(dev) {
        if (dev.connected) btAct.command = ["bluetoothctl", "disconnect", dev.mac]
        else if (dev.paired) btAct.command = ["bluetoothctl", "connect", dev.mac]
        else btAct.command = ["sh", "-c", "bluetoothctl pair " + dev.mac + " && bluetoothctl trust " + dev.mac + " && bluetoothctl connect " + dev.mac]
        btAct.running = true
    }

    // ---------- wifi ----------
    Process {
        id: wifiGet
        command: ["sh", "-c", "has=0; nmcli -t -f TYPE device | grep -q '^wifi$' && has=1; r=$(nmcli radio wifi); s=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2-); echo \"$has|$r|$s\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("|")
                win.wifiDev = p[0] === "1"
                win.wifiOn = p[1] === "enabled"
                win.wifiSsid = p.length > 2 ? p[2] : ""
            }
        }
    }
    Process {
        id: wifiList
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var seen = {}
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split(":")
                    if (f.length < 4) continue
                    var ssid = f.slice(1, f.length - 2).join(":").replace(/\\/g, "")
                    if (ssid === "" || seen[ssid]) continue
                    seen[ssid] = true
                    var sec = f[f.length - 1]
                    out.push({ ssid: ssid, signal: parseInt(f[f.length - 2]) || 0, secure: sec !== "" && sec !== "--", inUse: f[0] === "*" })
                }
                out.sort(function(a, b) { return (b.inUse - a.inUse) || (b.signal - a.signal) })
                win.wifiNets = out
            }
        }
    }
    Process {
        id: wifiScan
        command: ["nmcli", "dev", "wifi", "rescan"]
        onRunningChanged: { win.wifiScanning = running; if (!running) wifiList.running = true }
    }
    Timer {
        id: wifiAfter
        interval: 2500
        onTriggered: { wifiGet.running = true; wifiList.running = true }
    }
    function toggleWifi() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", win.wifiOn ? "off" : "on"])
        wifiAfter.restart()
    }
    function wifiConnect(ssid, pw) {
        var cmd = ["nmcli", "dev", "wifi", "connect", ssid]
        if (pw !== "") cmd = cmd.concat(["password", pw])
        Quickshell.execDetached(cmd)
        Quickshell.execDetached(["notify-send", "Wi-Fi", "Connecting to " + ssid + "..."])
        win.wifiSel = ""
        wifiAfter.restart()
    }
    function wifiDisconnect() {
        Quickshell.execDetached(["sh", "-c", "nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE device | grep ':wifi$' | head -1 | cut -d: -f1)"])
        wifiAfter.restart()
    }
    onWifiOpenChanged: {
        if (wifiOpen) {
            wifiList.running = true
            if (wifiOn && !wifiScan.running) wifiScan.running = true
        } else {
            win.wifiSel = ""
        }
    }

    // icon for a Bluetooth device: BlueZ "Icon:" value (audio-headset, input-keyboard ...) plus the name as a fallback
    function btGlyph(icon, name) {
        var s = ((icon || "") + " " + (name || "")).toLowerCase()
        if (/head|buds|pods/.test(s)) return "\uf01f"
        if (/keyboard/.test(s)) return "\ue312"
        if (/mouse|pointer/.test(s)) return "\ue323"
        if (/phone/.test(s)) return "\ue7ba"
        if (/gaming|gamepad|controller/.test(s)) return "\ue30f"
        if (/speaker|audio-card/.test(s)) return "\ue32d"
        if (/computer|laptop/.test(s)) return "\ue31e"
        return "\ue1a7"
    }

    function toggleDropdown() {
        if (dd !== "") dd = ""
        else dd = (wifiDev && wifiOn) ? "wifi" : "bt"
    }

    // ---------- screenshot ----------
    function screenshot(mode) {
        win.visible = false
        Quickshell.execDetached(["bash", win.binDir + "screenshot.sh", mode, win.saveFile ? "save" : "copy"])
    }

    // ---------- brightness (ddcutil is slow, so we debounce) ----------
    Process {
        id: brightGet
        command: ["sh", "-c", "ddcutil getvcp 10 --brief 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/VCP 10 C (\d+) (\d+)/)
                if (m) {
                    win.brightMax = parseInt(m[2])
                    win.bright = parseInt(m[1]) / win.brightMax
                    win.brightOk = true
                }
            }
        }
    }
    Process { id: brightSet }
    Timer {
        id: brightDebounce
        interval: 400
        onTriggered: {
            brightSet.command = ["ddcutil", "setvcp", "10", String(Math.round(win.bright * win.brightMax)), "--noverify"]
            brightSet.running = true
            Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/snow", "ipc", "call", "osd", "brightness", String(win.bright)])
        }
    }
    function setBright(v) {
        win.bright = v
        brightDebounce.restart()
    }

    // ---------- theme (dark / light) + WARP ----------
    Process {
        id: modeGet
        command: ["sh", "-c", "cat \"$HOME/.config/snow/mode\" 2>/dev/null || echo dark"]
        stdout: StdioCollector { onStreamFinished: win.isLight = text.trim() === "light" }
    }
    function toggleTheme() {
        win.isLight = !win.isLight
        Quickshell.execDetached([win.binDir + "switch-theme.sh", win.isLight ? "light" : "dark"])
    }
    Process {
        id: warpGet
        command: [win.binDir + "warp.sh", "status"]
        stdout: StdioCollector { onStreamFinished: win.warpState = text.trim() || "na" }
    }
    Timer {
        id: warpAfter
        interval: 2500
        onTriggered: warpGet.running = true
    }
    function toggleWarp() {
        win.warpState = "wait"
        Quickshell.execDetached([win.binDir + "warp.sh", "toggle"])
        warpAfter.restart()
    }

    // ---------- themes menu, backup / update / clean ----------
    function openThemes() {
        win.visible = false
        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/snow", "ipc", "call", "themes", "toggle"])
    }
    function runTerm(title, script) {
        win.visible = false
        Quickshell.execDetached(["kitty", "--class", "snow-float", "--title", title, "-e", "bash", win.binDir + script])
    }
    Process {
        id: updGet
        command: ["sh", "-c", "cat \"$HOME/.cache/snow/updates\" 2>/dev/null || echo 0"]
        stdout: StdioCollector { onStreamFinished: win.updateCount = parseInt(text.trim()) || 0 }
    }

    // ---------- sound output (speaker / headphones / HDMI / Bluetooth) ----------
    Process {
        id: outGet
        command: [win.binDir + "audio.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|")
                    if (p.length >= 5) out.push({ sink: p[0], port: p[1], label: p[2], active: p[3] === "1", kind: p[4] })
                }
                win.outputs = out
            }
        }
    }
    Timer { id: outAfter; interval: 500; onTriggered: outGet.running = true }
    function setOutput(o) {
        Quickshell.execDetached([win.binDir + "audio.sh", "set", o.sink, o.port])
        win.outOpen = false
        outAfter.restart()
    }
    function kindGlyph(k) {
        return k === "headphones" || k === "bluetooth" ? "\uf01f" : (k === "display" ? "\ue30c" : "\ue32d")
    }

    // ---------- power setting (screen off / lock / sleep) ----------
    Process {
        id: powerGet
        command: [win.binDir + "power.sh", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("|")
                if (p.length >= 3) {
                    win.pScreen = parseInt(p[0]) || 0
                    win.pLock = parseInt(p[1]) || 0
                    win.pSleep = parseInt(p[2]) || 0
                }
            }
        }
    }
    function setPower(key, m) {
        win.pDd = ""
        if (key === "screenoff") win.pScreen = m
        else if (key === "lock") win.pLock = m
        else win.pSleep = m
        Quickshell.execDetached([win.binDir + "power.sh", "set", key, String(m)])
    }
    function sleepNow() {
        win.visible = false
        Quickshell.execDetached([win.binDir + "power.sh", "sleep"])
    }
    function lockNow() {
        win.visible = false
        Quickshell.execDetached([win.binDir + "power.sh", "lock-now"])
    }

    // ---------- refresh ----------
    function refresh() {
        outGet.running = true
        powerGet.running = true
        updGet.running = true
        modeGet.running = true
        if (!warpAfter.running) warpGet.running = true
        volGet.running = true
        ethCheck.running = true
        btGet.running = true
        wifiGet.running = true
    }

    onVisibleChanged: {
        if (visible) {
            refresh()
            if (!brightLoaded) { brightLoaded = true; brightGet.running = true }
        } else {
            dd = ""
            win.outOpen = false
            win.powerOpen = false
            win.pDd = ""
            win.pArm = -1
            win.menuClose()
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: win.visible
        onTriggered: if (!volThrottle.running) win.refresh()
    }

    IpcHandler {
        target: "control"
        function toggle(): void { win.visible = !win.visible }
    }


    // ---------- UI ----------
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: { if (win.menuCur !== null) win.menuClose(); else win.visible = false }

        MouseArea { anchors.fill: parent; onClicked: win.visible = false }

        // ----- themed tray menu -----
        MouseArea {
            z: 99
            anchors.fill: parent
            visible: win.menuCur !== null
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: win.menuClose()
        }
        Rectangle {
            id: tmenu
            z: 100
            visible: win.menuCur !== null
            width: 230
            height: Math.min(mcol.height + 12, 420)
            x: Math.max(8, Math.min(win.menuX, parent.width - width - 8))
            y: Math.max(8, Math.min(win.menuY, parent.height - height - 8))
            radius: 14
            color: Theme.bg
            border.width: 1
            border.color: Qt.alpha(Theme.tint, 0.10)
            clip: true

            MouseArea { anchors.fill: parent }

            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: mcol.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: mcol
                    width: parent.width
                    spacing: 2

                    Rectangle {
                        visible: win.menuStack.length > 1
                        width: mcol.width
                        height: 30
                        radius: 8
                        color: bma.containsMouse ? Theme.surfaceHi : "transparent"
                        Row {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "\ue5cb"; font.family: win.iconFont; font.pixelSize: 18; color: Theme.muted }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Back"; font.pixelSize: 12; color: Theme.muted }
                        }
                        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; onClicked: win.menuBack() }
                    }

                    Repeater {
                        model: menuOpener.children
                        delegate: Item {
                            id: mi
                            required property var modelData
                            width: mcol.width
                            height: modelData.isSeparator ? 9 : 30

                            Rectangle {
                                visible: mi.modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8
                                width: parent.width - 16
                                height: 1
                                color: Qt.alpha(Theme.tint, 0.10)
                            }

                            Rectangle {
                                visible: !mi.modelData.isSeparator
                                anchors.fill: parent
                                radius: 8
                                color: mima.containsMouse && mi.modelData.enabled ? Theme.surfaceHi : "transparent"
                                opacity: mi.modelData.enabled ? 1 : 0.4

                                Text {
                                    x: 10
                                    width: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: mi.modelData.buttonType !== 0 && mi.modelData.checkState === Qt.Checked ? "\ue876" : ""
                                    font.family: win.iconFont
                                    font.pixelSize: 15
                                    color: Theme.accent
                                }
                                Text {
                                    x: 28
                                    width: parent.width - 28 - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: (mi.modelData.text || "").replace(/[&_]/g, "")
                                    font.pixelSize: 12
                                    color: Theme.text
                                }
                                Text {
                                    visible: mi.modelData.hasChildren
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\ue5cc"
                                    font.family: win.iconFont
                                    font.pixelSize: 18
                                    color: Theme.muted
                                }
                                MouseArea {
                                    id: mima
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: mi.modelData.enabled
                                    onClicked: {
                                        if (mi.modelData.hasChildren) {
                                            win.menuPush(mi.modelData)
                                        } else {
                                            mi.modelData.triggered()
                                            win.menuClose()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }


        Rectangle {
            id: panel
            width: 380
            height: content.height + 32
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 16
            anchors.bottomMargin: 16
            radius: 28
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.24)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(Theme.bg, Qt.alpha(Theme.accent, 0.07)) }
                GradientStop { position: 1.0; color: Theme.bg }
            }

            MouseArea { anchors.fill: parent }

            // click anywhere else on the panel = close the Power Setting card
            MouseArea {
                z: 15
                anchors.fill: parent
                visible: win.powerOpen
                onClicked: { win.pArm = -1; if (win.pDd !== "") win.pDd = ""; else win.powerOpen = false }
            }

            // Power Setting card: floats under the power button (the panel does not grow)
            Rectangle {
                id: pwCard
                z: 20
                visible: win.powerOpen
                width: 290
                height: 14 + 22 + 8 + 66 + 3 * 40 + 6 + 36 + 14
                anchors.top: parent.top
                anchors.topMargin: 62
                anchors.right: parent.right
                anchors.rightMargin: 24
                radius: 16
                color: Theme.surface
                border.width: 1
                border.color: Qt.alpha(Theme.tint, 0.14)

                MouseArea { anchors.fill: parent; onClicked: win.pDd = "" }

                Text { x: 14; y: 14; text: "Power Setting"; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.text }

                // Log out / Restart / Shut down (first click arms the button, second click does it)
                Row {
                    x: 14
                    y: 14 + 22 + 8
                    spacing: 8
                    Repeater {
                        model: win.pActions
                        delegate: Rectangle {
                            id: act
                            required property var modelData
                            required property int index
                            readonly property bool armed: win.pArm === index
                            width: (pwCard.width - 28 - 16) / 3
                            height: 58
                            radius: 14
                            color: armed ? Theme.danger : (acma.containsMouse ? Qt.lighter(Theme.surfaceHi, 1.15) : Theme.surfaceHi)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: act.modelData.glyph
                                    font.family: win.iconFont
                                    font.pixelSize: 22
                                    color: act.armed ? "#ffffff" : Theme.text
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: act.armed ? "Click again" : act.modelData.label
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: act.armed ? "#ffffff" : Theme.muted
                                }
                            }
                            MouseArea {
                                id: acma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { win.pDd = ""; win.pAct(act.index) }
                            }
                        }
                    }
                }

                Repeater {
                    model: [
                        { key: "screenoff", label: "Screen off after" },
                        { key: "lock", label: "Lock after" },
                        { key: "sleep", label: "Sleep after" }
                    ]
                    delegate: Item {
                        id: prow
                        required property var modelData
                        required property int index
                        readonly property int cur: modelData.key === "screenoff" ? win.pScreen : (modelData.key === "lock" ? win.pLock : win.pSleep)
                        x: 14
                        y: 14 + 22 + 8 + 66 + index * 40
                        width: pwCard.width - 28
                        height: 40

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: prow.modelData.label
                            font.pixelSize: 12
                            color: Theme.text
                        }
                        Rectangle {
                            id: selBtn
                            width: 108
                            height: 30
                            radius: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: win.pDd === prow.modelData.key ? Theme.accent : (selma.containsMouse ? Qt.lighter(Theme.surfaceHi, 1.15) : Theme.surfaceHi)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.minLabel(prow.cur)
                                font.pixelSize: 12
                                color: win.pDd === prow.modelData.key ? "#ffffff" : Theme.text
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.pDd === prow.modelData.key ? "\ue5c7" : "\ue5c5"
                                font.family: win.iconFont
                                font.pixelSize: 20
                                color: win.pDd === prow.modelData.key ? "#ffffff" : Theme.muted
                            }
                            MouseArea {
                                id: selma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.pDd = (win.pDd === prow.modelData.key) ? "" : prow.modelData.key
                            }
                        }
                    }
                }

                // two buttons: Sleep | Lock
                Row {
                    x: 14
                    y: 14 + 22 + 8 + 66 + 3 * 40 + 6
                    width: pwCard.width - 28
                    height: 36
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "Sleep", glyph: "\uf159", act: "sleep" },
                            { label: "Lock",  glyph: "\ue899", act: "lock" }
                        ]
                        delegate: Rectangle {
                            id: nb
                            required property var modelData
                            width: (pwCard.width - 28 - 8) / 2
                            height: 36
                            radius: 10
                            color: nbma.containsMouse ? Qt.lighter(Theme.surfaceHi, 1.15) : Theme.surfaceHi
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { anchors.verticalCenter: parent.verticalCenter; text: nb.modelData.glyph; font.family: win.iconFont; font.pixelSize: 17; color: Theme.text }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: nb.modelData.label; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.text }
                            }
                            MouseArea {
                                id: nbma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: nb.modelData.act === "sleep" ? win.sleepNow() : win.lockNow()
                            }
                        }
                    }
                }

                // the open dropdown list (on top of everything in the card)
                Rectangle {
                    id: pwList
                    visible: win.pDd !== ""
                    z: 30
                    width: 108
                    height: win.pChoices.length * 30 + 10
                    radius: 12
                    color: Theme.surfaceHi
                    border.width: 1
                    border.color: Qt.alpha(Theme.tint, 0.14)
                    x: pwCard.width - 14 - width
                    y: 14 + 22 + 8 + 66 + (win.pDd === "screenoff" ? 0 : (win.pDd === "lock" ? 1 : 2)) * 40 + 40 - 4
                    readonly property int curVal: win.pDd === "screenoff" ? win.pScreen : (win.pDd === "lock" ? win.pLock : win.pSleep)

                    MouseArea { anchors.fill: parent }
                    Column {
                        x: 5
                        y: 5
                        width: parent.width - 10
                        Repeater {
                            model: win.pChoices
                            delegate: Rectangle {
                                id: pit
                                required property int modelData
                                width: parent.width
                                height: 30
                                radius: 8
                                color: pwList.curVal === pit.modelData ? Qt.alpha(Theme.accent, 0.28) : (pima.containsMouse ? Qt.alpha(Theme.tint, 0.08) : "transparent")
                                Text {
                                    x: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: win.minLabel(pit.modelData)
                                    font.pixelSize: 12
                                    color: Theme.text
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: pwList.curVal === pit.modelData
                                    text: "\ue876"
                                    font.family: win.iconFont
                                    font.pixelSize: 16
                                    color: Theme.accent
                                }
                                MouseArea {
                                    id: pima
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.setPower(win.pDd, pit.modelData)
                                }
                            }
                        }
                    }
                }
            }

            // power setting button (top right) with a small tooltip
            Rectangle {
                id: pwrBtn
                z: 25
                width: 32
                height: 32
                radius: 16
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 24
                anchors.rightMargin: 24
                color: win.powerOpen ? Theme.accent : (pwma.containsMouse ? Qt.lighter(Theme.surfaceHi, 1.15) : Theme.surfaceHi)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf8c7"
                    font.family: win.iconFont
                    font.pixelSize: 19
                    color: win.powerOpen ? "#ffffff" : Theme.text
                }
                MouseArea {
                    id: pwma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { win.dd = ""; win.outOpen = false; win.powerOpen = !win.powerOpen }
                }
                Rectangle {
                    visible: pwma.containsMouse
                    anchors.right: parent.right
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    width: tipTxt.width + 18
                    height: 24
                    radius: 8
                    color: Theme.surfaceHi
                    border.width: 1
                    border.color: Qt.alpha(Theme.tint, 0.14)
                    Text {
                        id: tipTxt
                        anchors.centerIn: parent
                        text: "Power Setting"
                        font.pixelSize: 11
                        color: Theme.text
                    }
                }
            }

            // click anywhere under the Wi-Fi / Bluetooth tiles = close their list (the tiles themselves stay clickable)
            MouseArea {
                z: 15
                visible: win.dd !== ""
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.topMargin: ddCard.y - 8
                onClicked: win.dd = ""
            }

            // Wi-Fi OR Bluetooth list: floats under the two tiles (the panel does not grow)
            Card {
                id: ddCard
                z: 20
                visible: win.dd !== ""
                x: 16
                width: 348
                y: content.y + connectSec.y + connectSec.height + 8
                height: Math.min(ddCol.height + 16, 272)
                radius: 22
                tintAmt: 0.04

                MouseArea { anchors.fill: parent }

                Flickable {
                    x: 8
                    y: 8
                    width: parent.width - 16
                    height: parent.height - 16
                    contentHeight: ddCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: ddCol
                        width: parent.width
                        spacing: 2

                        // title + scan
                        Item {
                            width: parent.width
                            height: 32
                            Text {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.dd === "wifi" ? "Available Networks" : "Devices"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Pill {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                height: 24
                                text: (win.dd === "wifi" ? win.wifiScanning : win.btScanning) ? "Scanning..." : "Scan"
                                onClicked: {
                                    if (win.dd === "wifi") { if (win.wifiOn && !wifiScan.running) wifiScan.running = true }
                                    else if (win.btOn && !btScan.running) btScan.running = true
                                }
                            }
                        }

                        Text {
                            readonly property bool isWifi: win.dd === "wifi"
                            visible: isWifi ? (!win.wifiOn || win.wifiNets.length === 0) : (!win.btOn || win.btDevices.length === 0)
                            leftPadding: 8
                            height: 36
                            verticalAlignment: Text.AlignVCenter
                            text: isWifi ? (!win.wifiOn ? "Wi-Fi is turned off. Click the Wi-Fi tile to turn it on."
                                                         : (win.wifiScanning ? "Searching for networks..." : "No networks found"))
                                         : (!win.btOn ? "Bluetooth is turned off. Click the Bluetooth tile to turn it on."
                                                       : (win.btScanning ? "Searching for devices..." : "No devices found"))
                            font.pixelSize: 11
                            color: Theme.muted
                        }

                        // ---- Wi-Fi networks ----
                        Repeater {
                            model: (win.dd === "wifi" && win.wifiOn) ? win.wifiNets : []
                            delegate: Column {
                                id: nRow
                                required property var modelData
                                width: ddCol.width
                                spacing: 2
                                readonly property bool sel: win.wifiSel === modelData.ssid

                                Rectangle {
                                    width: parent.width
                                    height: 48
                                    radius: 14
                                    color: nRow.modelData.inUse ? Qt.alpha(Theme.success, 0.09)
                                         : ((nma.containsMouse || nRow.sel) ? Qt.alpha(Theme.tint, 0.08) : "transparent")

                                    MouseArea {
                                        id: nma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: win.wifiSel = nRow.sel ? "" : nRow.modelData.ssid
                                    }

                                    Rectangle {
                                        id: nIco
                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Theme.surfaceHi
                                        Ms {
                                            anchors.centerIn: parent
                                            text: nRow.modelData.secure ? "\ue1e1" : "\ue63e"
                                            font.pixelSize: 18
                                            color: Theme.muted
                                        }
                                    }
                                    Column {
                                        anchors.left: nIco.right
                                        anchors.leftMargin: 10
                                        anchors.right: sigTxt.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1
                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: nRow.modelData.ssid
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: Theme.text
                                        }
                                        Row {
                                            spacing: 5
                                            Rectangle {
                                                visible: nRow.modelData.inUse
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 6; height: 6; radius: 3
                                                color: Theme.success
                                            }
                                            Text {
                                                text: nRow.modelData.inUse ? "Connected" : (nRow.modelData.secure ? "Secured" : "Open")
                                                font.pixelSize: 11
                                                color: nRow.modelData.inUse ? Theme.success : Theme.muted
                                            }
                                        }
                                    }
                                    Text {
                                        id: sigTxt
                                        anchors.right: nBtn.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: nRow.modelData.signal + "%"
                                        font.pixelSize: 11
                                        font.family: "JetBrains Mono"
                                        color: nRow.modelData.signal >= 60 ? Theme.success : (nRow.modelData.signal >= 30 ? Theme.warn : Theme.danger)
                                    }
                                    Pill {
                                        id: nBtn
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        primary: !nRow.modelData.inUse
                                        text: nRow.modelData.inUse ? "Disconnect" : "Connect"
                                        onClicked: {
                                            if (nRow.modelData.inUse) win.wifiDisconnect()
                                            else if (nRow.modelData.secure && !nRow.sel) win.wifiSel = nRow.modelData.ssid
                                            else win.wifiConnect(nRow.modelData.ssid, pwIn.text)
                                        }
                                    }
                                }

                                // password box (secured network that was picked)
                                Item {
                                    visible: nRow.sel && nRow.modelData.secure && !nRow.modelData.inUse
                                    width: parent.width
                                    height: 40
                                    Rectangle {
                                        x: 50
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 58
                                        height: 32
                                        radius: 16
                                        color: Theme.bg
                                        border.width: 1
                                        border.color: pwIn.activeFocus ? Theme.accent : Qt.alpha(Theme.tint, 0.06)
                                        TextInput {
                                            id: pwIn
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: TextInput.Password
                                            color: Theme.text
                                            font.pixelSize: 13
                                            clip: true
                                            onAccepted: win.wifiConnect(nRow.modelData.ssid, text)
                                            onVisibleChanged: if (visible) forceActiveFocus()
                                        }
                                        Text {
                                            visible: pwIn.text === ""
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 14
                                            text: "Password (leave blank if saved)"
                                            font.pixelSize: 12
                                            color: Theme.muted
                                        }
                                    }
                                }
                            }
                        }

                        // ---- Bluetooth devices ----
                        Repeater {
                            model: (win.dd === "bt" && win.btOn) ? win.btDevices : []
                            delegate: Rectangle {
                                id: dRow
                                required property var modelData
                                width: ddCol.width
                                height: 48
                                radius: 14
                                color: dRow.modelData.connected ? Qt.alpha(Theme.success, 0.09)
                                     : (dma.containsMouse ? Qt.alpha(Theme.tint, 0.08) : "transparent")

                                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true }

                                Rectangle {
                                    id: dIco
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.surfaceHi
                                    Ms {
                                        anchors.centerIn: parent
                                        text: win.btGlyph(dRow.modelData.icon, dRow.modelData.name)
                                        font.pixelSize: 18
                                        color: Theme.muted
                                    }
                                }
                                Column {
                                    anchors.left: dIco.right
                                    anchors.leftMargin: 10
                                    anchors.right: dBtn.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: dRow.modelData.name
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                    Row {
                                        spacing: 5
                                        Rectangle {
                                            visible: dRow.modelData.connected
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 6; height: 6; radius: 3
                                            color: Theme.success
                                        }
                                        Text {
                                            text: dRow.modelData.connected ? "Connected" : (dRow.modelData.paired ? "Paired" : "New device")
                                            font.pixelSize: 11
                                            color: dRow.modelData.connected ? Theme.success : Theme.muted
                                        }
                                    }
                                }
                                Pill {
                                    id: dBtn
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    primary: !dRow.modelData.connected && !dRow.modelData.paired
                                    text: dRow.modelData.connected ? "Disconnect" : (dRow.modelData.paired ? "Connect" : "Pair")
                                    onClicked: win.btAction(dRow.modelData)
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: content
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 12

                // ----- clock + ethernet -----
                Card {
                    id: hero
                    width: parent.width
                    height: heroCol.height + 28
                    radius: 24
                    tintColor: Theme.accent
                    tintAmt: 0.26

                    Column {
                        id: heroCol
                        x: 18
                        y: 16
                        width: parent.width - 36
                        spacing: 4

                        // 12-hour time: big, with a small AM / PM
                        Item {
                            width: parent.width
                            height: 56
                            Text {
                                id: timeTxt
                                text: win.timeText
                                font.pixelSize: 56
                                font.weight: Font.ExtraBold
                                font.letterSpacing: -2
                                lineHeight: 56
                                lineHeightMode: Text.FixedHeight
                                color: Theme.text
                            }
                            Text {
                                x: timeTxt.width + 8
                                anchors.baseline: timeTxt.baseline
                                text: win.ampmText
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Theme.muted
                            }
                        }
                        Text {
                            text: Qt.formatDateTime(clock.date, "dddd, MMM d, yyyy")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.muted
                        }

                        // ethernet
                        Item {
                            width: parent.width
                            height: 8 + 1 + 10 + 36
                            Rectangle { y: 8; width: parent.width; height: 1; color: Qt.alpha(Theme.tint, 0.06) }
                            Item {
                                y: 19
                                width: parent.width
                                height: 36
                                Ms { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 22; text: "\ueb2f"; font.pixelSize: 22; color: Theme.muted }
                                Column {
                                    x: 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text { text: "Ethernet"; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                                    Text { text: "Wired connection"; font.pixelSize: 11; color: Theme.muted }
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: pill.width + 20
                                    height: 24
                                    radius: 12
                                    property color c: win.ethConnected ? Theme.success : Theme.danger
                                    color: Qt.rgba(c.r, c.g, c.b, 0.15)
                                    Text {
                                        id: pill
                                        anchors.centerIn: parent
                                        text: win.ethConnected ? "Connected" : "Disconnected"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: win.ethConnected ? Theme.success : Theme.danger
                                    }
                                }
                            }
                        }
                    }
                }

                // ----- connect: [Wi-Fi] [Bluetooth] -----
                Item {
                    id: connectSec
                    width: parent.width
                    height: 28 + 56

                    Lab { text: "Connect"; width: parent.width }
                    Row {
                        id: connRow
                        y: 28
                        width: parent.width
                        spacing: 8
                        readonly property int n: win.wifiDev ? 2 : 1
                        readonly property real tileW: (width - 8 * (n - 1)) / n

                        ConnPill {
                            visible: win.wifiDev
                            width: connRow.tileW
                            glyph: "\ue63e"
                            label: "Wi-Fi"
                            active: win.wifiOn
                            open: win.dd === "wifi"
                            onToggled: win.toggleWifi()
                            onExpand: win.dd = (win.dd === "wifi") ? "" : "wifi"
                        }
                        ConnPill {
                            width: connRow.tileW
                            glyph: "\ue1a7"
                            label: "Bluetooth"
                            active: win.btOn
                            open: win.dd === "bt"
                            onToggled: win.toggleBt()
                            onExpand: win.dd = (win.dd === "bt") ? "" : "bt"
                        }
                    }
                }

                // ----- lower part: side rail + main column -----
                Item {
                    id: lower
                    width: parent.width
                    height: Math.max(mainCol.height, 308)

                    Card {
                        id: rail
                        width: 80
                        height: parent.height
                        radius: 26
                        tintColor: Theme.accent
                        tintAmt: 0.14

                        Column {
                            x: 9
                            y: 8
                            width: 62
                            spacing: 6
                            Item {
                                width: parent.width
                                height: 22
                                Text { anchors.centerIn: parent; text: "QUICK"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.muted }
                            }
                            RailTile {
                                glyph: win.isLight ? "\ue518" : "\ue51c"
                                label: win.isLight ? "Light" : "Dark"
                                lit: win.isLight
                                onClicked: win.toggleTheme()
                            }
                            RailTile {
                                glyph: "\ue9e0"
                                label: win.warpState === "on" ? "WARP on" : (win.warpState === "wait" ? "WARP..." : (win.warpState === "na" ? "WARP n/a" : "WARP off"))
                                lit: win.warpState === "on"
                                disabled: win.warpState === "na" || win.warpState === "wait"
                                onClicked: win.toggleWarp()
                            }
                        }
                        Column {
                            x: 9
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            width: 62
                            spacing: 6
                            Item {
                                width: parent.width
                                height: 22
                                Text { anchors.centerIn: parent; text: "SYSTEM"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.muted }
                            }
                            RailTile {
                                glyph: "\ue8d7"
                                label: win.updateCount > 0 ? "Update (" + win.updateCount + ")" : "Update"
                                lit: win.updateCount > 0
                                onClicked: win.runTerm("Snow Update", "update.sh")
                            }
                            RailTile {
                                glyph: "\uf0ff"
                                label: "Clean"
                                onClicked: win.runTerm("Snow Cleanup", "cleanup.sh")
                            }
                        }
                    }

                    Column {
                        id: mainCol
                        x: 92
                        width: parent.width - 92
                        spacing: 12

                        // screenshot
                        Card {
                            width: parent.width
                            height: 68
                            radius: 34

                            Column {
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { text: "Screenshot"; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.text }
                                Item {
                                    width: swRow.width
                                    height: 28
                                    Row {
                                        id: swRow
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Rectangle {
                                            width: 32
                                            height: 18
                                            radius: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: win.saveFile ? Theme.accent : Theme.surfaceHi
                                            border.width: 1
                                            border.color: Qt.alpha(Theme.tint, 0.06)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Rectangle {
                                                width: 12
                                                height: 12
                                                radius: 6
                                                y: 3
                                                x: win.saveFile ? 17 : 3
                                                color: win.saveFile ? "#ffffff" : Theme.muted
                                                Behavior on x { NumberAnimation { duration: 150 } }
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: win.saveFile ? "Save + copy" : "Copy only"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Theme.muted
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.saveFile = !win.saveFile
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Repeater {
                                    model: [
                                        { g: "\uf7d2", m: "region" },
                                        { g: "\ue5d0", m: "full" },
                                        { g: "\ue069", m: "window" }
                                    ]
                                    delegate: Rectangle {
                                        id: sb
                                        required property var modelData
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: sma.pressed ? Qt.alpha(Theme.accent, 0.36) : (sma.containsMouse ? Qt.alpha(Theme.accent, 0.28) : Qt.alpha(Theme.accent, 0.16))
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: sma.pressed ? 0.96 : 1
                                        Ms { anchors.centerIn: parent; text: sb.modelData.g; color: Theme.accent }
                                        MouseArea {
                                            id: sma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.screenshot(sb.modelData.m)
                                        }
                                    }
                                }
                            }
                        }

                        // sound & display
                        Card {
                            id: soundCard
                            width: parent.width
                            height: sliders.height + 24
                            z: win.outOpen ? 20 : 0      // keeps the output dropdown above the TRAY row
                            radius: 22

                            Column {
                                id: sliders
                                x: 12
                                y: 12
                                width: parent.width - 24
                                spacing: 10

                                SliderRow {
                                    width: parent.width
                                    glyph: win.muted ? "\ue04f" : "\ue050"
                                    label: "Output"
                                    value: win.vol
                                    dimmed: win.muted
                                    onMoved: (v) => win.setVolume(v)
                                    onIconClicked: muteToggle.running = true
                                    gear: true
                                    gearActive: win.outOpen
                                    onGearClicked: { win.outOpen = !win.outOpen; if (win.outOpen) outGet.running = true }
                                }

                                SliderRow {
                                    width: parent.width
                                    visible: win.brightOk
                                    glyph: "\ue1ac"
                                    label: "Brightness"
                                    value: win.bright
                                    onMoved: (v) => win.setBright(v)
                                    gear: true
                                    onGearClicked: win.openThemes()
                                }
                            }

                            // sound output dropdown (opens under the volume gear, on top of the rows below)
                            Rectangle {
                                id: outDrop
                                visible: win.outOpen
                                z: 50
                                x: 12
                                width: parent.width - 24
                                y: 12 + 19 + 40 + 4
                                height: dropCol.height + 8
                                radius: 16
                                color: Theme.surfaceHi
                                border.width: 1
                                border.color: Qt.alpha(Theme.tint, 0.14)

                                MouseArea { anchors.fill: parent }

                                Column {
                                    id: dropCol
                                    x: 4
                                    y: 4
                                    width: parent.width - 8
                                    spacing: 0
                                    Repeater {
                                        model: win.outOpen ? win.outputs : []
                                        delegate: Rectangle {
                                            id: oRow
                                            required property var modelData
                                            width: parent.width
                                            height: 36
                                            radius: 12
                                            color: oRow.modelData.active ? Qt.alpha(Theme.accent, 0.16) : (orma.containsMouse ? Qt.alpha(Theme.tint, 0.08) : "transparent")
                                            Ms {
                                                x: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: win.kindGlyph(oRow.modelData.kind)
                                                font.pixelSize: 18
                                                color: oRow.modelData.active ? Theme.text : Theme.muted
                                            }
                                            Text {
                                                x: 38
                                                width: parent.width - 38 - 32
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                                text: oRow.modelData.label
                                                font.pixelSize: 12
                                                font.weight: oRow.modelData.active ? Font.Bold : Font.Medium
                                                color: oRow.modelData.active ? Theme.text : Theme.muted
                                            }
                                            Ms {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: oRow.modelData.active
                                                text: "\ue876"
                                                font.pixelSize: 18
                                                color: Theme.accent
                                            }
                                            MouseArea {
                                                id: orma
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: win.setOutput(oRow.modelData)
                                            }
                                        }
                                    }
                                    Text {
                                        visible: win.outputs.length === 0
                                        leftPadding: 12
                                        height: 36
                                        verticalAlignment: Text.AlignVCenter
                                        text: "No sound outputs found"
                                        font.pixelSize: 12
                                        color: Theme.muted
                                    }
                                }
                            }
                        }

                        // tray
                        Item {
                            id: traySec
                            width: parent.width
                            height: 28 + (trayEmpty.visible ? 36 : trayFlow.height)

                            Lab { text: "Tray"; width: parent.width }
                            Text {
                                id: trayEmpty
                                visible: SystemTray.items.values.length === 0
                                x: 4
                                y: 28
                                height: 36
                                verticalAlignment: Text.AlignVCenter
                                text: "No tray apps"
                                font.pixelSize: 12
                                color: Theme.muted
                            }
                            Flow {
                                id: trayFlow
                                x: 4
                                y: 28
                                width: parent.width - 8
                                spacing: 8
                                Repeater {
                                    model: SystemTray.items
                                    delegate: Rectangle {
                                        id: tItem
                                        required property var modelData
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: tma.containsMouse || xma.containsMouse ? Qt.tint(Theme.surfaceHi, Qt.alpha(Theme.tint, 0.08)) : Theme.surfaceHi

                                        QsMenuOpener { id: opener; menu: tItem.modelData.menu }

                                        function entryFor() {
                                            var keys = [tItem.modelData.id, tItem.modelData.title]
                                            for (var i = 0; i < keys.length; i++) {
                                                if (!keys[i]) continue
                                                var e = DesktopEntries.heuristicLookup(keys[i])
                                                if (e) return e
                                            }
                                            return null
                                        }

                                        function killApp() {
                                            var names = []
                                            var e = tItem.entryFor()
                                            if (e && e.command && e.command.length) names.push(e.command[0].split("/").pop())
                                            if (e && e.id) names.push(e.id)
                                            if (tItem.modelData.id) names.push(tItem.modelData.id)
                                            if (tItem.modelData.title) names.push(tItem.modelData.title)
                                            Quickshell.execDetached(["bash", win.binDir + "killapp.sh"].concat(names))
                                        }

                                        function quitApp() {
                                            var list = opener.children ? opener.children.values : []
                                            var pick = null
                                            for (var i = 0; i < list.length; i++) {
                                                var t = (list[i].text || "").replace(/[&_]/g, "")
                                                if (list[i].isSeparator || !list[i].enabled) continue
                                                if (/quit|exit/i.test(t)) { pick = list[i]; break }
                                                if (!pick && /close/i.test(t)) pick = list[i]
                                            }
                                            if (pick) pick.triggered()
                                            else tItem.killApp()
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            width: 22
                                            height: 22
                                            sourceSize: Qt.size(44, 44)
                                            source: tItem.modelData.icon
                                        }

                                        MouseArea {
                                            id: tma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: (m) => {
                                                var p = mapToItem(null, m.x, m.y)
                                                if (m.button === Qt.RightButton) {
                                                    if (tItem.modelData.hasMenu) win.openMenu(tItem.modelData.menu, p.x, p.y)
                                                }
                                            }
                                            onDoubleClicked: (m) => {
                                                if (m.button === Qt.LeftButton) {
                                                    var e = tItem.entryFor()
                                                    if (e) e.execute()
                                                    else tItem.modelData.activate()
                                                    win.visible = false
                                                }
                                            }
                                        }

                                        // "X" in the top-right corner on hover
                                        Rectangle {
                                            visible: tma.containsMouse || xma.containsMouse
                                            width: 16
                                            height: 16
                                            radius: 8
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            color: xma.containsMouse ? Theme.danger : Qt.rgba(0, 0, 0, 0.55)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\ue5cd"
                                                font.family: win.iconFont
                                                font.pixelSize: 12
                                                color: "#ffffff"
                                            }
                                            MouseArea {
                                                id: xma
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: tItem.quitApp()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
