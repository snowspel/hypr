pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property color bg: adapter.bg
    readonly property color surface: adapter.surface
    readonly property color surfaceHi: adapter.surfaceHi
    readonly property color text: adapter.text
    readonly property color muted: adapter.muted
    readonly property color accent: adapter.accent
    readonly property color warn: adapter.warn
    readonly property color danger: adapter.danger
    readonly property color success: adapter.success
    readonly property color tint: adapter.tint   // white in dark mode, black in light mode (for light overlays)

    FileView {
        path: Quickshell.env("HOME") + "/.config/snow/theme.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string bg: "#1e1e2e"
            property string surface: "#252636"
            property string surfaceHi: "#2a2b3c"
            property string text: "#ffffff"
            property string muted: "#8b90a6"
            property string accent: "#6366f1"
            property string warn: "#fbbf24"
            property string danger: "#ef4444"
            property string success: "#4ade80"
            property string tint: "#ffffff"
        }
    }
}
