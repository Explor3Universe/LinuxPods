import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Single battery indicator: circular arc ring + label + percentage.
ColumnLayout {
    id: batteryItem

    required property string label
    required property int level
    required property bool charging
    required property bool inEar

    spacing: Kirigami.Units.smallSpacing
    opacity: inEar ? 1.0 : 0.5

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    readonly property real ringSize: Kirigami.Units.gridUnit * 4
    readonly property real ringWidth: 4
    readonly property real ringRadius: (ringSize - ringWidth) / 2
    readonly property real cx: ringSize / 2
    readonly property real cy: ringSize / 2

    // Clamp to valid range
    readonly property real progress: Math.max(0, Math.min(level, 100)) / 100.0

    readonly property color arcColor: {
        if (charging)
            return Kirigami.Theme.positiveTextColor;
        if (level <= 15)
            return Kirigami.Theme.negativeTextColor;
        if (level <= 30)
            return Kirigami.Theme.neutralTextColor;
        return Kirigami.Theme.highlightColor;
    }

    Item {
        Layout.preferredWidth: batteryItem.ringSize
        Layout.preferredHeight: batteryItem.ringSize
        Layout.alignment: Qt.AlignHCenter

        // Track ring (full circle, dim)
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 8
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                strokeWidth: batteryItem.ringWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: batteryItem.cx
                    centerY: batteryItem.cy
                    radiusX: batteryItem.ringRadius
                    radiusY: batteryItem.ringRadius
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // Progress arc
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 8
            visible: batteryItem.progress > 0

            ShapePath {
                fillColor: "transparent"
                strokeColor: batteryItem.arcColor
                strokeWidth: batteryItem.ringWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: batteryItem.cx
                    centerY: batteryItem.cy
                    radiusX: batteryItem.ringRadius
                    radiusY: batteryItem.ringRadius
                    startAngle: -90
                    sweepAngle: 360 * batteryItem.progress
                }
            }
        }

        // Percentage text
        PlasmaComponents3.Label {
            anchors.centerIn: parent
            text: batteryItem.level + "%"
            font.pixelSize: Kirigami.Units.gridUnit * 0.85
            font.weight: Font.Bold
        }

        // Charging bolt icon
        Kirigami.Icon {
            visible: batteryItem.charging
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            source: "battery-charging-symbolic"
            color: Kirigami.Theme.positiveTextColor
        }
    }

    PlasmaComponents3.Label {
        Layout.alignment: Qt.AlignHCenter
        text: batteryItem.label
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.7
    }
}
