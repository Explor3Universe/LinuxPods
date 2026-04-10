// SPDX-License-Identifier: GPL-3.0-or-later

pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15

// Stitch-style segmented control: glass-morphism container with
// primary-glow active button. Public API (model, currentIndex) is
// preserved from the original implementation.
Control {
    id: root

    property var model: ["Option 1", "Option 2"]
    property int currentIndex: 0

    // Stitch design system colours
    readonly property color glassColor: Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.55)
    readonly property color borderColor: Qt.rgba(1, 1, 1, 0.06)
    readonly property color activeColor: "#3584e4"
    readonly property color activeGlow: Qt.rgba(53 / 255, 132 / 255, 228 / 255, 0.35)
    readonly property color inactiveTextColor: "#9a9996"
    readonly property color activeTextColor: "#ffffff"

    padding: 6
    implicitHeight: 44

    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true

    background: Rectangle {
        radius: 16
        color: root.glassColor
        border.width: 1
        border.color: root.borderColor
    }

    contentItem: Row {
        spacing: 4

        Repeater {
            model: root.model

            delegate: Item {
                id: segmentRoot
                required property int index
                required property string modelData
                width: (root.availableWidth - (root.model.length - 1) * 4) / root.model.length
                height: root.availableHeight

                readonly property bool isActive: root.currentIndex === segmentRoot.index

                Rectangle {
                    id: pill
                    anchors.fill: parent
                    radius: 12
                    color: segmentRoot.isActive ? root.activeColor : "transparent"
                    border.width: segmentRoot.isActive ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    // Soft outer glow when active.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.color: root.activeGlow
                        border.width: 3
                        visible: segmentRoot.isActive
                        z: -1
                    }

                    Behavior on color {
                        ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: segmentRoot.modelData
                    horizontalAlignment: Text.AlignHCenter
                    color: segmentRoot.isActive ? root.activeTextColor : root.inactiveTextColor
                    font.family: "Inter"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 0.6
                    elide: Text.ElideRight
                    width: parent.width - 8

                    Behavior on color {
                        ColorAnimation { duration: 220 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentIndex !== segmentRoot.index) {
                            root.currentIndex = segmentRoot.index;
                        }
                    }
                    onEntered: if (!segmentRoot.isActive) pill.color = Qt.rgba(1, 1, 1, 0.04)
                    onExited: if (!segmentRoot.isActive) pill.color = "transparent"
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) {
            if (root.currentIndex > 0) {
                root.currentIndex--;
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Right) {
            if (root.currentIndex < root.model.length - 1) {
                root.currentIndex++;
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Home) {
            root.currentIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.currentIndex = root.model.length - 1;
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            const index = event.key - Qt.Key_1;
            if (index < root.model.length) {
                root.currentIndex = index;
                event.accepted = true;
            }
        }
    }
}
