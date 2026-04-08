pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects

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
    width: 380
    height: 620
    minimumWidth: 360
    minimumHeight: 540
    maximumWidth: 440
    maximumHeight: 720
    title: "LinuxPods"
    objectName: "mainWindowObject"
    color: "transparent"

    // Frameless dropdown / "shutter from the top panel" behaviour.
    // No Qt.Tool — that flag blocks focus on Wayland/X11, which kills both
    // requestActivate() and the auto-hide-on-focus-lost logic.
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    property bool _hadFocus: false
    property bool _autoHide: Qt.application.arguments.indexOf("--no-autohide") === -1
    property int _targetY: 40
    property real _slideOffset: 0   // 0 = parked at _targetY, >0 = above

    // Animated slide-down. Start with the popup parked ~120 px above its
    // final position with opacity 0; the OutCubic animation slides it
    // into place over ~450 ms — enough to feel like it's dropping out
    // of the top system panel.
    y: _targetY - _slideOffset
    opacity: _slideOffset === 0 ? 1.0 : Math.max(0.0, 1.0 - _slideOffset / 120)

    Behavior on _slideOffset {
        NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
    }

    function showFromTopPanel() {
        const screen = Qt.application.primaryScreen || Qt.application.screens[0];
        if (screen) {
            mainWindow.x = screen.virtualX + screen.width - mainWindow.width - 16;
            mainWindow._targetY = screen.virtualY + 40;
        }
        mainWindow._slideOffset = 120;   // park above
        mainWindow.visible = true;
        Qt.callLater(() => {
            mainWindow.raise();
            mainWindow.requestActivate();
            mainWindow._slideOffset = 0;   // animate down
        });
    }

    Component.onCompleted: {
        showFromTopPanel();
    }

    onActiveChanged: {
        if (active) {
            _hadFocus = true;
        } else if (_autoHide && _hadFocus && visible) {
            mainWindow._slideOffset = 120;   // animate out
            hideTimer.start();
        }
    }

    Timer {
        id: hideTimer
        interval: 480
        onTriggered: mainWindow.visible = false
    }

    // ── Stitch dark gradient background ───────────────────────────────
    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1c24" }
            GradientStop { position: 0.35; color: "#0e0e0e" }
            GradientStop { position: 1.0; color: "#000000" }
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

        // Allow opening directly on a sub-page from the CLI:
        //   librepods --settings    or    librepods --hearing
        Component.onCompleted: {
            const args = Qt.application.arguments;
            if (args.indexOf("--settings") !== -1) {
                stackView.push(settingsPage);
            } else if (args.indexOf("--hearing") !== -1) {
                stackView.push(hearingAidPage);
            }
        }
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

            // ── Compact Top Strip (dropdown popup style) ─────────────
            Rectangle {
                id: topBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                color: Qt.rgba(0, 0, 0, 0.40)
                z: 100

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.05)
                }

                // Left: device name (compact, no hamburger)
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    text: airPodsTrayApp.deviceInfo.deviceName || "AirPods Pro"
                    color: Qt.rgba(1, 1, 1, 0.92)
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.3
                }

                // Right: settings gear
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 12
                    width: 30
                    height: 30
                    radius: 15
                    color: settingsHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf958"
                        font.family: iconFont.name
                        font.pixelSize: 14
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

            ScrollView {
                anchors.top: topBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentWidth: width
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width
                    spacing: 18

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

                    // ── Compact hero ─────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.preferredHeight: 130

                        Rectangle {
                            id: heroGlowSource
                            anchors.centerIn: parent
                            width: 110
                            height: 110
                            radius: width / 2
                            color: "#3584e4"
                            visible: false
                            layer.enabled: true
                        }

                        MultiEffect {
                            anchors.centerIn: parent
                            width: 220
                            height: 220
                            source: heroGlowSource
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 96
                            blurMultiplier: 1.4
                            opacity: 0.18
                            autoPaddingEnabled: true
                        }

                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/icons/assets/airpods.png"
                            width: 120
                            height: 120
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                        }
                    }

                    // ── Battery ring grid: 3 columns ─────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        Layout.preferredHeight: heroRow.implicitHeight + 6

                        Row {
                            id: heroRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 24

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
                        Layout.leftMargin: 18
                        Layout.topMargin: 4
                        text: qsTr("NOISE CONTROL")
                        color: "#9a9996"
                        font.family: "Inter"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 2.0
                        visible: airPodsTrayApp.airpodsConnected
                    }

                    SegmentedControl {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.preferredHeight: 36
                        model: [qsTr("Off"), qsTr("Transp."), qsTr("Adaptive"), qsTr("ANC")]
                        currentIndex: airPodsTrayApp.deviceInfo.noiseControlMode
                        onCurrentIndexChanged: airPodsTrayApp.setNoiseControlModeInt(currentIndex)
                        visible: airPodsTrayApp.airpodsConnected
                    }

                    // Adaptive noise level slider — only when actually in Adaptive mode (idx 3).
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        spacing: 4
                        visible: airPodsTrayApp.airpodsConnected
                            && airPodsTrayApp.deviceInfo.adaptiveModeActive
                            && airPodsTrayApp.deviceInfo.noiseControlMode === 3

                        Slider {
                            id: adaptiveSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
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
                    }

                    // ── Section: FEATURES ────────────────────────────
                    Text {
                        Layout.leftMargin: 18
                        Layout.topMargin: 4
                        text: qsTr("FEATURES")
                        color: "#9a9996"
                        font.family: "Inter"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 2.0
                        visible: airPodsTrayApp.airpodsConnected
                    }

                    // Feature card: Conversational Awareness
                    FeatureCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        title: qsTr("Conversational Awareness")
                        subtitle: qsTr("Lowers media when you speak")
                        icon: "\u2B25"
                        checked: airPodsTrayApp.deviceInfo.conversationalAwareness
                        visible: airPodsTrayApp.airpodsConnected
                        onToggled: (v) => airPodsTrayApp.setConversationalAwareness(v)
                    }

                    // Feature card: Hearing Aid (clickable — opens dedicated page)
                    FeatureCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        title: qsTr("Hearing Aid Mode")
                        subtitle: qsTr("Tap to configure profile")
                        icon: "\u266B"
                        checked: airPodsTrayApp.deviceInfo.hearingAidEnabled
                        visible: airPodsTrayApp.airpodsConnected
                        cardClickable: true
                        onCardClicked: stackView.push(hearingAidPage)
                        onToggled: (v) => airPodsTrayApp.setHearingAidEnabled(v)
                    }

                    // Bottom spacer
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
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

        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: 60
            cursorShape: card.cardClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: card.cardClickable
            onClicked: card.cardClicked()
        }

        // Compact card for popup dropdown
        height: 56
        radius: 16
        color: Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                Text {
                    anchors.centerIn: parent
                    text: card.icon
                    font.pixelSize: 18
                    color: "#7bafff"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: card.title
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: card.subtitle
                    color: "#9a9996"
                    font.family: "Inter"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                id: toggleTrack
                Layout.preferredWidth: 38
                Layout.preferredHeight: 22
                radius: 11
                color: card.checked
                    ? "#3584e4"
                    : Qt.rgba(1, 1, 1, 0.1)

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                Rectangle {
                    id: toggleKnob
                    width: 16
                    height: 16
                    radius: 8
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
