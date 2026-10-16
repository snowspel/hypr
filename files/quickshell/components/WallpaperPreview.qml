import QtQuick
import QtQuick.Effects

// Rounded wallpaper picture for the Themes menu.
// Separate file on purpose: ThemeMenu.qml loads it with a Loader, so if the QtQuick.Effects module is
// missing, only this picture is lost (the gradient behind it stays) and the menu still works.
Item {
    id: root

    property url source: ""
    property real radius: 12

    Image {
        id: img
        anchors.fill: parent
        visible: false
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(1, root.width) * 2, Math.max(1, root.height) * 2)
        source: root.source
    }

    // the rounded shape that cuts the picture
    Item {
        id: msk
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: msk
        opacity: img.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
