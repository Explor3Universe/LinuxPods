import QtQuick 2.15

// PodColumn — single AirPod / case slot in the hero grid.
// Stitch redesign: large circular ring around the device image,
// uppercase tracking-wide label below, big percentage number.
// Public API (inEar, iconSource, batteryLevel, isCharging, indicator)
// is unchanged from the original implementation.
Column {
    id: root

    property bool inEar: true
    property string iconSource
    property int batteryLevel: 0
    property bool isCharging: false
    property string indicator: ""

    // Faded look when the pod is out of the ear (legacy behaviour).
    property real targetOpacity: inEar ? 1 : 0.45
    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    onInEarChanged: root.opacity = root.targetOpacity
    Component.onCompleted: root.opacity = root.targetOpacity

    spacing: 6

    // Ring + image stack
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 88
        height: 88

        BatteryIndicator {
            anchors.fill: parent
            batteryLevel: root.batteryLevel
            isCharging: root.isCharging
            indicator: root.indicator
        }

        Image {
            anchors.centerIn: parent
            source: root.iconSource
            // Case icon is rendered larger (no L/R indicator), pods are smaller
            // because they share the ring with their mirrored counterpart.
            width: root.indicator === "" ? 56 : 48
            height: width
            fillMode: Image.PreserveAspectFit
            mipmap: true
            mirror: root.indicator === "R"
        }
    }

    // Slot label (LEFT / RIGHT / CASE)
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
            if (root.indicator === "L") return "LEFT";
            if (root.indicator === "R") return "RIGHT";
            return "CASE";
        }
        color: "#9a9996"
        font.family: "Inter"
        font.pixelSize: 9
        font.bold: true
        font.letterSpacing: 1.6
    }

    // Battery percentage
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.batteryLevel + "%"
        color: "#ffffff"
        font.family: "Inter"
        font.pixelSize: 18
        font.weight: Font.Black
    }
}
