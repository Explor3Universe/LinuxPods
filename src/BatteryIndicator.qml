import QtQuick 2.15

// Ring-style battery indicator (Stitch redesign).
// Renders an animated circular ring whose sweep represents the battery
// level (0..100). The legacy public API (batteryLevel, isCharging,
// indicator) is preserved so the C++/QML callers do not need any change.
Item {
    id: root

    // ── Public API (kept for backwards compatibility) ─────────────────
    property int batteryLevel: 0
    property bool isCharging: false
    property string indicator: ""

    // ── Visual customisation ──────────────────────────────────────────
    property color ringColor: "#7bafff"        // primary accent
    property color chargingColor: "#5edb8a"
    property color lowColor: "#ff716c"
    property color trackColor: Qt.rgba(1, 1, 1, 0.06)
    property real ringWidth: 4

    // Effective ring colour: low → red, charging → green, otherwise primary.
    readonly property color effectiveColor: {
        if (batteryLevel <= 15 && !isCharging) return lowColor;
        if (isCharging) return chargingColor;
        return ringColor;
    }

    // Smoothly animated progress (0..100) for the canvas sweep.
    property real animatedLevel: 0
    Behavior on animatedLevel {
        NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
    }
    onBatteryLevelChanged: animatedLevel = batteryLevel
    Component.onCompleted: animatedLevel = batteryLevel

    width: 88
    height: 88

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            const radius = Math.min(width, height) / 2 - root.ringWidth - 2;

            // Track ring
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
            ctx.lineWidth = root.ringWidth - 1;
            ctx.strokeStyle = root.trackColor;
            ctx.stroke();

            // Progress ring (clockwise from 12 o'clock)
            const sweep = 2 * Math.PI * (root.animatedLevel / 100);
            if (sweep > 0.001) {
                ctx.beginPath();
                ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + sweep);
                ctx.lineWidth = root.ringWidth;
                ctx.strokeStyle = root.effectiveColor;
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
    }

    // Repaint whenever the animated level or colour changes.
    onAnimatedLevelChanged: canvas.requestPaint()
    onEffectiveColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()

    // Optional charging bolt overlay (unobtrusive).
    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
        visible: root.isCharging
        text: "\u26A1"
        color: root.chargingColor
        font.pixelSize: 14
        font.bold: true
    }
}
