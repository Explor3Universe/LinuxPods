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
    width: 460
    height: 720
    minimumWidth: 420
    minimumHeight: 600
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

                    // ── Hero: battery ring grid ──────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.preferredHeight: heroRow.implicitHeight + 16

                        Row {
                            id: heroRow
                            anchors.centerIn: parent
                            spacing: 18

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

                            PodColumn {
                                visible: airPodsTrayApp.deviceInfo.battery.headsetAvailable
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
                        icon: "\u26AC"
                        checked: airPodsTrayApp.deviceInfo.conversationalAwareness
                        visible: airPodsTrayApp.airpodsConnected
                        onToggled: (v) => airPodsTrayApp.setConversationalAwareness(v)
                    }

                    // Feature card: Hearing Aid
                    FeatureCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        title: qsTr("Hearing Aid Mode")
                        subtitle: qsTr("Amplifies environmental speech")
                        icon: "\u266B"
                        checked: airPodsTrayApp.deviceInfo.hearingAidEnabled
                        visible: airPodsTrayApp.airpodsConnected
                        onToggled: (v) => airPodsTrayApp.setHearingAidEnabled(v)
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
    //  SETTINGS PAGE — preserved from original, dark-tweaked
    // ─────────────────────────────────────────────────────────────────
    Component {
        id: settingsPage
        Page {
            id: settingsPageItem
            title: qsTr("Settings")
            background: Rectangle { color: "transparent" }

            ScrollView {
                anchors.fill: parent

                Column {
                    width: parent.width
                    spacing: 18
                    padding: 22

                    Label {
                        text: qsTr("Settings")
                        font.family: "Inter"
                        font.pixelSize: 22
                        font.bold: true
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Column {
                        spacing: 6

                        Label {
                            text: qsTr("Pause Behavior When Removing AirPods:")
                            color: "#9a9996"
                            font.family: "Inter"
                            font.pixelSize: 12
                        }

                        ComboBox {
                            width: parent.width
                            model: [qsTr("One Removed"), qsTr("Both Removed"), qsTr("Never")]
                            currentIndex: airPodsTrayApp.earDetectionBehavior
                            onActivated: airPodsTrayApp.earDetectionBehavior = currentIndex
                        }
                    }

                    Switch {
                        text: qsTr("Cross-Device Connectivity with Android")
                        checked: airPodsTrayApp.crossDeviceEnabled
                        onCheckedChanged: airPodsTrayApp.setCrossDeviceEnabled(checked)
                    }

                    Switch {
                        text: qsTr("Auto-Start on Login")
                        checked: airPodsTrayApp.autoStartManager.autoStartEnabled
                        onCheckedChanged: airPodsTrayApp.autoStartManager.autoStartEnabled = checked
                    }

                    Switch {
                        text: qsTr("Enable System Notifications")
                        checked: airPodsTrayApp.notificationsEnabled
                        onCheckedChanged: airPodsTrayApp.notificationsEnabled = checked
                    }

                    Switch {
                        visible: airPodsTrayApp.airpodsConnected
                        text: qsTr("One Bud ANC Mode")
                        checked: airPodsTrayApp.deviceInfo.oneBudANCMode
                        onCheckedChanged: airPodsTrayApp.deviceInfo.oneBudANCMode = checked

                        ToolTip {
                            visible: parent.hovered
                            text: qsTr("Enable ANC when using one AirPod\n(More noise reduction, but uses more battery)")
                            delay: 500
                        }
                    }

                    Row {
                        spacing: 6
                        Label {
                            text: qsTr("Bluetooth Retry Attempts:")
                            color: "#9a9996"
                            font.family: "Inter"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        SpinBox {
                            from: 1
                            to: 10
                            value: airPodsTrayApp.retryAttempts
                            onValueChanged: airPodsTrayApp.retryAttempts = value
                        }
                    }

                    Row {
                        spacing: 10
                        visible: airPodsTrayApp.airpodsConnected

                        TextField {
                            id: newNameField
                            placeholderText: airPodsTrayApp.deviceInfo.deviceName
                            maximumLength: 32
                        }

                        Button {
                            text: qsTr("Rename")
                            onClicked: airPodsTrayApp.renameAirPods(newNameField.text)
                        }
                    }

                    Row {
                        spacing: 10
                        visible: airPodsTrayApp.airpodsConnected

                        TextField {
                            id: newPhoneMacField
                            placeholderText: (PHONE_MAC_ADDRESS !== "" ? PHONE_MAC_ADDRESS : "00:00:00:00:00:00")
                            maximumLength: 32
                        }

                        Button {
                            text: qsTr("Change Phone MAC")
                            onClicked: airPodsTrayApp.setPhoneMac(newPhoneMacField.text)
                        }
                    }

                    Button {
                        text: qsTr("Show Magic Cloud Keys QR")
                        onClicked: keysQrDialog.show()
                    }

                    KeysQRDialog {
                        id: keysQrDialog
                        encKey: airPodsTrayApp.deviceInfo.magicAccEncKey
                        irk: airPodsTrayApp.deviceInfo.magicAccIRK
                    }
                }
            }

            // Floating back button
            RoundButton {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 12
                font.family: iconFont.name
                font.pixelSize: 18
                text: "\uecb1"
                onClicked: stackView.pop()
            }
        }
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
        signal toggled(bool value)

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
