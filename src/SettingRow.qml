// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// One row inside a Stitch-style settings glass card.
// Used by SettingsPage / HearingAidPage. Holds an icon tile, a label
// (with optional secondary subtitle) and one of several control types
// — toggle, button, or just a chevron acting as a "navigates to page" cue.
Item {
    id: row

    // ── Public API ────────────────────────────────────────────────────
    property string label: ""
    property string sublabel: ""
    property string iconText: "\u25CF"
    property color iconColor: "#7bafff"
    // type: "toggle" | "chevron" | "none"
    property string type: "toggle"
    property bool toggleChecked: false
    property bool clickable: false

    signal toggleClicked()
    signal rowClicked()

    // Explicit Layout sizing (binding implicitHeight → Layout.preferredHeight
    // races with the inner RowLayout sizing pass and collapses the row).
    Layout.fillWidth: true
    Layout.preferredHeight: sublabel === "" ? 64 : 72
    implicitHeight: sublabel === "" ? 64 : 72
    implicitWidth: 320

    // Whole-row click area (used when type === "chevron" or clickable === true)
    MouseArea {
        id: rowMouse
        anchors.fill: parent
        anchors.rightMargin: 70
        cursorShape: (row.clickable || row.type === "chevron") ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: row.clickable || row.type === "chevron"
        hoverEnabled: true
        onClicked: row.rowClicked()
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 0
        color: rowMouse.containsMouse && rowMouse.enabled ? Qt.rgba(1, 1, 1, 0.03) : "transparent"
        radius: 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14

        // Icon tile (44x44 rounded square)
        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 14
            color: "#262626"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.04)

            Text {
                anchors.centerIn: parent
                text: row.iconText
                color: row.iconColor
                font.family: "Inter"
                font.pixelSize: 18
                font.bold: true
            }
        }

        // Label + optional sublabel
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: row.label
                color: "#ffffff"
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: row.sublabel !== ""
                text: row.sublabel
                color: "#9a9996"
                font.family: "Inter"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        // Toggle (Stitch style)
        Rectangle {
            visible: row.type === "toggle"
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            radius: 12
            color: row.toggleChecked ? "#7bafff" : Qt.rgba(1, 1, 1, 0.10)

            Behavior on color { ColorAnimation { duration: 200 } }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                x: row.toggleChecked ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggleClicked()
            }
        }

        // Chevron (right arrow)
        Text {
            visible: row.type === "chevron"
            text: "\u203A"
            color: "#9a9996"
            font.family: "Inter"
            font.pixelSize: 22
            font.bold: true
        }
    }
}
