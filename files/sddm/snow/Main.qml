import QtQuick 2.15

Item {
    id: root

    // ------------------------- THEME / TUNING -------------------------
    property color ink: config.ink ? config.ink : "#F3EEE3"
    property string wallpaper: config.background ? config.background : ""
    property real dimAlpha: 0.52
    property real blurAmount: 0.65
    property real hourXScale: 0.8
    property real hourSize: 180
    property real hourCenterX: 180        // centre of the big hour text, in design pixels (0 = screen edge, 360 = hours ring)
    property real labelDim: 0.28          // opacity of the ring numbers (05, 10, 15...)
    property string fontFamily: "Montserrat"
    // ------------------------------------------------------------------

    readonly property real u: height / 1189
    readonly property real cx: 22 * u
    readonly property real cy: 585 * u
    readonly property real rm: 133 * u
    focus: true
    Component.onCompleted: forceActiveFocus()

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    readonly property int hour12: (now.getHours() + 11) % 12 + 1        // 1..12
    readonly property string ampm: now.getHours() < 12 ? "AM" : "PM"

    // ---------------------------- time ----------------------------
    property var now: new Date()
    property real nowMs: now.getTime()
    property real lastSec: -1
    // 33ms (~30fps) timer: keeps the seconds ring moving smoothly.
    // Text (HH / MM / SS / date) changes only when the real second changes, so ring and text stay in sync.
    Timer {
        interval: 33; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            root.nowMs = d.getTime()
            var s = Math.floor(d.getTime() / 1000)
            if (s !== root.lastSec) { root.lastSec = s; root.now = d }
        }
    }
    readonly property real nowSec: Math.floor(now.getTime() / 1000) - now.getTimezoneOffset() * 60
    property real secPos: nowMs / 1000 - now.getTimezoneOffset() * 60     // float: moves a little every frame
    property real minPos: nowSec / 60
    property real hourPos: Math.floor(nowSec / 3600)
    Behavior on minPos  { NumberAnimation { duration: 1000 } }
    Behavior on hourPos { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    // ---------------------------- auth state ----------------------------
    property string password: ""
    property string status: ""
    property bool failed: false
    property bool busy: false

    // user and session come from the SDDM lists
    ListView {
        id: users
        model: userModel
        currentIndex: userModel.lastIndex
        width: 10; height: 10; opacity: 0; interactive: false; cacheBuffer: 10000
        delegate: Item { required property string name; width: 1; height: 1 }
    }
    ListView {
        id: sessions
        model: sessionModel
        currentIndex: sessionModel.lastIndex
        width: 10; height: 10; opacity: 0; interactive: false; cacheBuffer: 10000
        delegate: Item { required property string name; width: 1; height: 1 }
    }
    readonly property string userName: users.currentItem ? users.currentItem.name : ""
    readonly property string sessionName: sessions.currentItem ? sessions.currentItem.name : ""

    function submit() {
        if (busy || password === "" || userName === "") return;
        failed = false; busy = true; status = "VERIFYING";
        sddm.login(userName, password, sessions.currentIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.failed = true;
            root.status = "TRY AGAIN"; root.password = "";
        }
        function onLoginSucceeded() { root.status = "WELCOME"; }
    }

    // -------------------------- background --------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#1b1420" }
            GradientStop { position: 1; color: "#141830" }
        }
    }
    Image {
        anchors.fill: parent
        asynchronous: true
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0.035, 0.035, 0.07, root.dimAlpha) }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.30) }
        }
    }

    component T: Text {
        color: root.ink
        font.family: root.fontFamily
        antialiasing: true
    }

    // ------------------------------ pill ------------------------------
    Rectangle {
        x: 395 * root.u; y: root.cy - 68 * root.u + 7 * root.u
        width: 498 * root.u; height: 136 * root.u; radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.18)
    }
    Rectangle {
        x: 395 * root.u; y: root.cy - 68 * root.u
        width: 498 * root.u; height: 136 * root.u; radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: Math.max(1, 1.5 * root.u)
        border.color: Qt.rgba(1, 1, 1, 0.26)
    }
    Rectangle {
        x: 651 * root.u; y: root.cy - 26 * root.u
        width: Math.max(1, 1.5 * root.u); height: 52 * root.u
        color: Qt.rgba(1, 1, 1, 0.35)
    }

    // ----------------------------- rings -----------------------------
    Ring {   // SECONDS
        x: root.cx; y: root.cy
        count: 60; pos: root.secPos
        radius: 760 * root.u; majorLen: 24 * root.u; minorLen: 9 * root.u
        majorWidth: 3 * root.u; minorWidth: 1.5 * root.u
        labelRadius: 703 * root.u; labelSize: 26 * root.u; hideBand: 1.2
        labelAlpha: root.labelDim
        ink: root.ink; fontFamily: root.fontFamily; minorAlpha: 0.5
    }
    Ring {   // MINUTES
        x: root.cx; y: root.cy
        count: 60; pos: root.minPos
        radius: 519 * root.u; majorLen: 32 * root.u; minorLen: 12 * root.u
        majorWidth: 3 * root.u; minorWidth: 1.5 * root.u
        labelRadius: 454 * root.u; labelSize: 30 * root.u; hideBand: 1.9
        labelAlpha: root.labelDim
        ink: root.ink; fontFamily: root.fontFamily; minorAlpha: 0.55
    }
    Ring {   // HOURS (12h)
        x: root.cx; y: root.cy
        count: 12; pos: root.hourPos
        twelveHour: true
        majorEvery: 3; labelEvery: 1
        radius: 362 * root.u; majorLen: 24 * root.u; minorLen: 12 * root.u
        majorWidth: 3 * root.u; minorWidth: 1.5 * root.u
        labelRadius: 316 * root.u; labelSize: 22 * root.u
        labelAlpha: root.labelDim
        ink: root.ink; fontFamily: root.fontFamily; minorAlpha: 0.45
    }

    component Needle: Item {
        property real r
        property real len
        x: root.cx + r - len; y: root.cy; width: len; height: 0
        Rectangle { y: -height / 2; width: parent.width + 6 * root.u; x: -3 * root.u; height: 9 * root.u; radius: height / 2; color: root.ink; opacity: 0.10 }
        Rectangle { y: -height / 2; width: parent.width; height: 3.2 * root.u; color: root.ink }
    }
    Needle { r: 519 * root.u; len: 32 * root.u }
    Needle { r: 760 * root.u; len: 24 * root.u }
    Needle { r: 362 * root.u; len: 24 * root.u }

    // -------------------- big hour + live MM | SS --------------------
    T {
        text: root.pad(root.hour12)
        font.pixelSize: root.hourSize * root.u
        font.weight: Font.Black
        font.letterSpacing: -3 * root.u
        x: root.hourCenterX * root.u - width * root.hourXScale / 2
        y: root.cy - 0.618 * font.pixelSize
        transform: Scale { origin.x: 0; xScale: root.hourXScale }
    }
    T {   // AM / PM (small, under the hour)
        text: root.ampm
        font.pixelSize: 24 * root.u; font.weight: Font.Bold; font.letterSpacing: 5 * root.u
        opacity: 0.85
        x: root.hourCenterX * root.u - width / 2
        y: root.cy + 0.35 * root.hourSize * root.u + 16 * root.u
    }
    T {
        text: root.pad(root.now.getMinutes())
        font.pixelSize: 38 * root.u; font.weight: Font.Bold
        x: 476 * root.u - width / 2; y: root.cy - height / 2
    }
    T {
        text: root.pad(root.now.getSeconds())
        font.pixelSize: 38 * root.u; font.weight: Font.Bold
        x: 725 * root.u - width / 2; y: root.cy - height / 2
    }

    // ----------------------------- date ------------------------------
    Column {
        x: 1060 * root.u
        y: root.cy - height / 2
        spacing: 12 * root.u
        T {
            text: root.now.toLocaleDateString(Qt.locale("en_US"), "dd MMMM yyyy")
            font.pixelSize: 20 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 5.5 * root.u
            opacity: 0.85
        }
        T {
            text: root.now.toLocaleDateString(Qt.locale("en_US"), "dddd").toUpperCase()
            font.pixelSize: 29 * root.u; font.weight: Font.Black; font.letterSpacing: 9 * root.u
        }
    }

    // ------------------------ top-right controls ------------------------
    // Two round buttons. Double click to run (no confirm step).
    property string hint: ""
    function power(k) {
        if (k === "restart") sddm.reboot(); else sddm.powerOff();
    }

    component RoundBtn: Item {
        id: btn
        property string kind
        property string hintText
        property color hoverColor: root.ink
        readonly property bool hot: ma.containsMouse
        width: 40 * root.u; height: 40 * root.u

        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: btn.hot ? btn.hoverColor : Qt.rgba(1, 1, 1, 0.08)
            border.width: Math.max(1, 1.5 * root.u)
            border.color: btn.hot ? btn.hoverColor : Qt.rgba(1, 1, 1, 0.30)
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Canvas {
            id: cv
            anchors.fill: parent
            antialiasing: true
            property color stroke: btn.hot ? Qt.rgba(0.08, 0.07, 0.10, 1) : root.ink
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var c = width / 2, r = width * 0.22;
                ctx.lineWidth = Math.max(1.5, width * 0.07);
                ctx.lineCap = "round"; ctx.lineJoin = "round";
                ctx.strokeStyle = cv.stroke;
                ctx.beginPath();
                if (btn.kind === "poweroff") {
                    ctx.arc(c, c + r * 0.08, r, -Math.PI / 2 + 0.62, -Math.PI / 2 - 0.62 + 2 * Math.PI, false);
                    ctx.moveTo(c, c - r * 1.08);
                    ctx.lineTo(c, c - r * 0.10);
                } else {
                    ctx.arc(c, c, r, -Math.PI / 2 + 0.9, -Math.PI / 2 + 2 * Math.PI, false);
                    var h = r * 0.5;
                    ctx.moveTo(c - h, c - r - h);
                    ctx.lineTo(c, c - r);
                    ctx.lineTo(c - h, c - r + h);
                }
                ctx.stroke();
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent; anchors.margins: -6 * root.u
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onEntered: root.hint = btn.hintText
            onExited: if (root.hint === btn.hintText) root.hint = ""
            onDoubleClicked: root.power(btn.kind)
        }
    }
    Row {
        id: powerRow
        anchors.right: parent.right
        anchors.rightMargin: 44 * root.u - 4 * root.u
        y: 38 * root.u - height / 2
        spacing: 16 * root.u
        RoundBtn { kind: "restart"; hintText: "DOUBLE CLICK TO RESTART" }
        RoundBtn { kind: "poweroff"; hintText: "DOUBLE CLICK TO SHUT DOWN"; hoverColor: "#E8B4A8" }
    }
    T {
        text: root.hint
        visible: root.hint !== ""
        font.pixelSize: 11 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 3.5 * root.u
        opacity: 0.7
        anchors.right: powerRow.right
        y: powerRow.y + powerRow.height + 12 * root.u
    }

    // ------------------------ bottom-right login ------------------------
    T {   // user (click for the next user, if there is more than one)
        text: root.userName.toUpperCase()
        font.pixelSize: 15 * root.u; font.weight: Font.ExtraBold; font.letterSpacing: 5.6 * root.u
        opacity: 0.85
        anchors.right: parent.right; anchors.rightMargin: root.rm - 5.6 * root.u
        y: 905 * root.u - height / 2
        MouseArea {
            anchors.fill: parent; anchors.margins: -8 * root.u
            enabled: users.count > 1
            cursorShape: users.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: users.currentIndex = (users.currentIndex + 1) % users.count
        }
    }
    T {
        text: root.status !== "" ? root.status
            : (root.password.length > 0 ? "•".repeat(Math.min(root.password.length, 40)) : "TYPE PASSWORD")
        color: root.failed ? "#E8B4A8" : root.ink
        opacity: (root.status !== "" || root.password.length > 0) ? 0.95 : 0.5
        font.pixelSize: 15 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 5.6 * root.u
        anchors.right: parent.right; anchors.rightMargin: root.rm - 5.6 * root.u
        y: 950 * root.u - height / 2
    }
    T {   // session (click for the next session)
        text: root.sessionName.toUpperCase()
        font.pixelSize: 12 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 4.5 * root.u
        opacity: 0.55
        anchors.right: parent.right; anchors.rightMargin: root.rm - 4.5 * root.u
        y: 990 * root.u - height / 2
        MouseArea {
            anchors.fill: parent; anchors.margins: -8 * root.u
            enabled: sessions.count > 1
            cursorShape: sessions.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: sessions.currentIndex = (sessions.currentIndex + 1) % sessions.count
        }
    }

    // ----------------------------- keyboard -----------------------------
    Keys.onPressed: event => {
        const k = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            root.submit();
        } else if (k === Qt.Key_Escape || (ctrl && k === Qt.Key_U)) {
            root.password = ""; root.status = ""; root.failed = false;
        } else if (k === Qt.Key_Backspace) {
            if (!root.busy) { root.password = root.password.slice(0, -1); root.status = ""; }
        } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32
                   && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            if (root.busy) { event.accepted = true; return; }
            root.status = ""; root.failed = false;
            root.password += event.text;
        }
        event.accepted = true;
    }
}
