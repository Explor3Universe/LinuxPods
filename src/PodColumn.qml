import QtQuick 2.15

// Compact PodColumn for the dropdown popup (Stitch "LinuxPods Tray Panel").
// Number is rendered INSIDE the ring (not below); slot label sits under
// the ring as a tiny uppercase tracking-wide caption.
Column {
    id: root

    property bool inEar: true
    property string iconSource    // unused in compact layout (no inline image)
    property int batteryLevel: 0
    property bool isCharging: false
    property string indicator: ""

    property real targetOpacity: inEar ? 1 : 0.5
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    onInEarChanged: root.opacity = root.targetOpacity
    Component.onCompleted: root.opacity = root.targetOpacity

    spacing: 6

    // Ring + percent stack (60x60 like Stitch reference)
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 60
        height: 60

        BatteryIndicator {
            anchors.fill: parent
            batteryLevel: root.batteryLevel
            isCharging: root.isCharging
            // Case ring (no L/R indicator) goes secondary-green when >= 95%
            ringColor: (root.indicator === "" && root.batteryLevel >= 95)
                ? "#70f9af"
                : "#7bafff"
        }

        // Percent number INSIDE the ring
        Text {
            anchors.centerIn: parent
            text: root.batteryLevel + "%"
            color: "#ffffff"
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }

    // Slot label
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
        font.weight: Font.Medium
        font.letterSpacing: 1.0
    }
}
