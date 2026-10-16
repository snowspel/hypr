//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs.components

ShellRoot {
    id: root

    Wallpaper {}
    PowerMenu {}
    QuickSettings {}
    ThemeMenu {}
    Launcher {}
    NotificationPopups {}
    OsdPopup {}
    ClockOsd {}

    // Pieces that are loaded from code (after start-up) so that a Quickshell build without
    // the Polkit or the Hyprland module cannot break the whole shell:
    //  - PolkitDialog: password dialog (hyprpolkitagent is the fallback if it is missing)
    //  - WorkspaceOsd: the small "Workspace N" pop-up at the top-left
    Timer {
        interval: 200
        running: true
        repeat: false
        onTriggered: {
            var files = ["components/PolkitDialog.qml", "components/WorkspaceOsd.qml"]
            for (var i = 0; i < files.length; i++) {
                var c = Qt.createComponent(files[i], Component.PreferSynchronous)
                if (c.status === Component.Ready) c.createObject(root)
                else console.warn("snow: " + files[i] + " not loaded: " + c.errorString())
            }
        }
    }
}
