pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// LinuxPods main window — Stitch redesign.
//
// Stitch design system colours (dark glass-morphism):
//   background       #0e0e0e  (with subtle vertical gradient toward #000)
//   surface          #121212
//   surface-variant  #1e1e1e
//   on-surface       #ffffff
//   on-surface-variant #9a9996
//   primary          #3584e4  /  #7bafff (lighter accent)
//   outline          #3d3d3d
//
// Public API to the C++ side (airPodsTrayApp.* properties, signals,
// methods) is preserved unchanged — this is purely a visual rewrite.
ApplicationWindow {
    id: mainWindow
    visible: !airPodsTrayApp.hideOnStart
    width: 480
    height: 920
    minimumWidth: 440
    minimumHeight: 660
    title: "LinuxPods"
    objectName: "mainWindowObject"
    color: "transparent"

    // ── Stitch dark gradient background ───────────────────────────────
    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1c24" }
            GradientStop { position: 0.35; color: "#0e0e0e" }
            GradientStop { position: 1.0; color: "#000000" }
        }

        // Subtle primary-tinted top glow.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -160
            width: 380
            height: 380
            radius: width / 2
            color: Qt.rgba(53 / 255, 132 / 255, 228 / 255, 0.12)
            opacity: 0.85
        }
    }

    onClosing: mainWindow.visible = false

    function reopen(pageToLoad) {
        if (pageToLoad === "settings") {
            if (stackView.depth === 1) {
                stackView.push(settingsPage)
            }
        } else {
            if (stackView.depth > 1) {
                stackView.pop()
            }
        }

        if (!mainWindow.visible) {
            mainWindow.visible = true
        }
        raise()
        requestActivate()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.BackButton && stackView.depth > 1) {
                stackView.pop()
            }
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: mainPage
    }

    FontLoader {
        id: iconFont
        source: "qrc:/icons/assets/fonts/SF-Symbols-6.ttf"
    }

    // ─────────────────────────────────────────────────────────────────
    //  MAIN PAGE — Stitch redesign
    // ─────────────────────────────────────────────────────────────────
    Component {
        id: mainPage
        Item {
            ScrollView {
                anchors.fill: parent
                anchors.margins: 0
                contentWidth: width
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width
                    spacing: 18

                    // ── Title strip (compact "top app bar") ──────────
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 18
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        Layout.preferredHeight: 32

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: airPodsTrayApp.deviceInfo.deviceName
                                ? airPodsTrayApp.deviceInfo.deviceName.toUpperCase()
                                : "AIRPODS"
                            color: Qt.rgba(1, 1, 1, 0.92)
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 1.8
                        }

                        // Settings button (uses bundled SF Symbols font for the gear glyph)
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 16
                            color: settingsHover.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.08)
                                : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf958"  // gear glyph from bundled SF Symbols font
                                font.family: iconFont.name
                                font.pixelSize: 16
                                color: Qt.rgba(1, 1, 1, 0.75)
                            }

                            MouseArea {
                                id: settingsHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: stackView.push(settingsPage)
                            }
                        }
                    }

                    // ── Disconnected pill (only when not connected) ──
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 28
                        radius: 14
                        visible: !airPodsTrayApp.airpodsConnected
                        color: Qt.rgba(255 / 255, 113 / 255, 108 / 255, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(255 / 255, 113 / 255, 108 / 255, 0.4)

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("DISCONNECTED")
                            color: "#ff716c"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.4
                        }
                    }

                    // ── Hero: big device image with primary glow ─────
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        Layout.preferredHeight: 170

                        // Outer glow halo
                        Rectangle {
                            anchors.centerIn: parent
                            width: 220
                            height: 220
                            radius: width / 2
                            color: Qt.rgba(53 / 255, 132 / 255, 228 / 255, 0.10)
                        }
                        // Inner glow halo
                        Rectangle {
                            anchors.centerIn: parent
                            width: 170
                            height: 170
                            radius: width / 2
                            color: Qt.rgba(53 / 255, 132 / 255, 228 / 255, 0.16)
                        }

                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/icons/assets/airpods.png"
                            width: 150
                            height: 150
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                        }
                    }

                    // ── Battery ring grid: 3 columns (L · Case · R) ──
                    // Headset shown only as a fallback when neither L nor R is available
                    // (covers e.g. AirPods Max).
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.preferredHeight: heroRow.implicitHeight + 12

                        Row {
                            id: heroRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 28

                            PodColumn {
                                visible: airPodsTrayApp.deviceInfo.battery.leftPodAvailable
                                inEar: airPodsTrayApp.deviceInfo.leftPodInEar
                                iconSource: "qrc:/icons/assets/" + airPodsTrayApp.deviceInfo.podIcon
                                batteryLevel: airPodsTrayApp.deviceInfo.battery.leftPodLevel
                                isCharging: airPodsTrayApp.deviceInfo.battery.leftPodCharging
                                indicator: "L"
                            }

                            PodColumn {
                                visible: airPodsTrayApp.deviceInfo.battery.caseAvailable
                                inEar: true
                                iconSource: "qrc:/icons/assets/" + airPodsTrayApp.deviceInfo.caseIcon
                                batteryLevel: airPodsTrayApp.deviceInfo.battery.caseLevel
                                isCharging: airPodsTrayApp.deviceInfo.battery.caseCharging
                            }

                            PodColumn {
                                visible: airPodsTrayApp.deviceInfo.battery.rightPodAvailable
                                inEar: airPodsTrayApp.deviceInfo.rightPodInEar
                                iconSource: "qrc:/icons/assets/" + airPodsTrayApp.deviceInfo.podIcon
                                batteryLevel: airPodsTrayApp.deviceInfo.battery.rightPodLevel
                                isCharging: airPodsTrayApp.deviceInfo.battery.rightPodCharging
                                indicator: "R"
                            }

                            // Fallback for AirPods Max etc. — only when no L/R pod data.
                            PodColumn {
                                visible: airPodsTrayApp.deviceInfo.battery.headsetAvailable
                                       && !airPodsTrayApp.deviceInfo.battery.leftPodAvailable
                                       && !airPodsTrayApp.deviceInfo.battery.rightPodAvailable
                                inEar: true
                                iconSource: "qrc:/icons/assets/" + airPodsTrayApp.deviceInfo.podIcon
                                batteryLevel: airPodsTrayApp.deviceInfo.battery.headsetLevel
                                isCharging: airPodsTrayApp.deviceInfo.battery.headsetCharging
                            }
                        }
                    }

                    // ── Section: NOISE CONTROL ───────────────────────
                    Text {
                        Layout.leftMargin: 26
                        Layout.topMargin: 8
                        text: qsTr("NOISE CONTROL")
                        color: "#9a9996"
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.8
                        visible: airPodsTrayApp.airpodsConnected
                    }

                    SegmentedControl {
                        Layout.fillWidth: true
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        model: [qsTr("Off"), qsTr("Transp."), qsTr("Adaptive"), qsTr("ANC")]
                        currentIndex: airPodsTrayApp.deviceInfo.noiseControlMode
                        onCurrentIndexChanged: airPodsTrayApp.setNoiseControlModeInt(currentIndex)
                        visible: airPodsTrayApp.airpodsConnected
                    }

                    // Adaptive noise level slider
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        spacing: 4
                        visible: airPodsTrayApp.deviceInfo.adaptiveModeActive

                        Slider {
                            id: adaptiveSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            stepSize: 1
                            value: airPodsTrayApp.deviceInfo.adaptiveNoiseLevel

                            Timer {
                                id: debounceTimer
                                interval: 500
                                onTriggered: if (!adaptiveSlider.pressed) airPodsTrayApp.setAdaptiveNoiseLevel(adaptiveSlider.value)
                            }

                            onPressedChanged: if (!pressed) airPodsTrayApp.setAdaptiveNoiseLevel(value)
                            onValueChanged: if (pressed) debounceTimer.restart()
                        }

                        Text {
                            text: qsTr("Adaptive level: ") + Math.round(adaptiveSlider.value) + "%"
                            color: "#9a9996"
                            font.family: "Inter"
                            font.pixelSize: 11
                        }
                    }

                    // ── Section: FEATURES ────────────────────────────
                    Text {
                        Layout.leftMargin: 26
                        Layout.topMargin: 8
                        text: qsTr("FEATURES")
                        color: "#9a9996"
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.8
                        visible: airPodsTrayApp.airpodsConnected
                    }

                    // Feature card: Conversational Awareness
                    FeatureCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        title: qsTr("Conversational Awareness")
                        subtitle: qsTr("Lowers media when you speak")
                        icon: "\u2B25"
                        checked: airPodsTrayApp.deviceInfo.conversationalAwareness
                        visible: airPodsTrayApp.airpodsConnected
                        onToggled: (v) => airPodsTrayApp.setConversationalAwareness(v)
                    }

                    // Feature card: Spatial Audio (placeholder; not yet wired to backend)
                    FeatureCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        title: qsTr("Spatial Audio")
                        subtitle: qsTr("Immersive surround sound")
                        icon: "\u25C9"
                        checked: false
                        enabled: false
                        opacity: 0.55
                        visible: airPodsTrayApp.airpodsConnected
                        onToggled: (v) => {}
                    }

                    // Feature card: Hearing Aid (clickable — opens dedicated page)
                    FeatureCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        title: qsTr("Hearing Aid Mode")
                        subtitle: qsTr("Tap to configure profile")
                        icon: "\u266B"
                        checked: airPodsTrayApp.deviceInfo.hearingAidEnabled
                        visible: airPodsTrayApp.airpodsConnected
                        cardClickable: true
                        onCardClicked: stackView.push(hearingAidPage)
                        onToggled: (v) => airPodsTrayApp.setHearingAidEnabled(v)
                    }

                    // ── Status footer card (mesh-gradient look) ─────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        Layout.topMargin: 6
                        Layout.preferredHeight: 110
                        radius: 24
                        color: "#0e0e0e"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.06)
                        visible: airPodsTrayApp.airpodsConnected

                        // Faux mesh gradient via two radial-ish overlays.
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(53/255, 132/255, 228/255, 0.10) }
                                GradientStop { position: 1.0; color: Qt.rgba(224/255, 27/255, 36/255, 0.04) }
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 26
                            spacing: 4

                            Text {
                                text: qsTr("STATUS")
                                color: "#7bafff"
                                font.family: "Inter"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 2.4
                            }
                            Text {
                                text: qsTr("System Optimal")
                                color: "#ffffff"
                                font.family: "Inter"
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                text: qsTr("LinuxPods 0.1.0 • AAP active")
                                color: "#9a9996"
                                font.family: "Inter"
                                font.pixelSize: 10
                            }
                        }

                        // Big translucent verified glyph (uses bundled SF Symbols font).
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 24
                            text: "\u2713"
                            color: Qt.rgba(1, 1, 1, 0.10)
                            font.family: "Inter"
                            font.pixelSize: 64
                            font.bold: true
                        }
                    }

                    // Bottom spacer
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────
    //  SETTINGS PAGE — Stitch redesign, loaded from SettingsPage.qml
    // ─────────────────────────────────────────────────────────────────
    Component {
        id: settingsPage
        SettingsPage {
            stackView: stackView
            iconFont: iconFont
            keysQrDialog: keysQrDialogShared
        }
    }

    // ─────────────────────────────────────────────────────────────────
    //  HEARING AID PAGE — Stitch redesign, loaded from HearingAidPage.qml
    // ─────────────────────────────────────────────────────────────────
    Component {
        id: hearingAidPage
        HearingAidPage {
            stackView: stackView
            iconFont: iconFont
        }
    }

    // Shared dialog for the Magic Cloud Keys QR code (used by SettingsPage).
    KeysQRDialog {
        id: keysQrDialogShared
        encKey: airPodsTrayApp.deviceInfo.magicAccEncKey
        irk: airPodsTrayApp.deviceInfo.magicAccIRK
    }

    // ─────────────────────────────────────────────────────────────────
    //  Inline component: glass-morphism feature card with toggle
    // ─────────────────────────────────────────────────────────────────
    component FeatureCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string icon: "•"
        property bool checked: false
        property bool cardClickable: false
        signal toggled(bool value)
        signal cardClicked()

        // Click on the card body (excluding the toggle) — used by pages.
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: 70   // leave the toggle area for its own click
            cursorShape: card.cardClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: card.cardClickable
            onClicked: card.cardClicked()
        }

        height: 68
        radius: 22
        color: Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            // Icon tile
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                Text {
                    anchors.centerIn: parent
                    text: card.icon
                    font.pixelSize: 22
                    color: "#7bafff"
                }
            }

            // Title + subtitle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: card.title
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: card.subtitle
                    color: "#9a9996"
                    font.family: "Inter"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Custom toggle (Stitch style)
            Rectangle {
                id: toggleTrack
                Layout.preferredWidth: 46
                Layout.preferredHeight: 26
                radius: 13
                color: card.checked
                    ? "#3584e4"
                    : Qt.rgba(1, 1, 1, 0.1)

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                Rectangle {
                    id: toggleKnob
                    width: 20
                    height: 20
                    radius: 10
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: card.checked ? parent.width - width - 3 : 3

                    Behavior on x {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.toggled(!card.checked)
                }
            }
        }
    }
}
