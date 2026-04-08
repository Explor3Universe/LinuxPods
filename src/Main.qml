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
    // Always hidden by default — the window is a tray dropdown popup,
    // not a regular window. It appears with a slide-down animation only
    // when the user clicks the tray icon (or when reopen() is invoked
    // from C++).
    visible: false
    width: 360
    height: 540
    minimumWidth: 340
    minimumHeight: 480
    maximumWidth: 400
    maximumHeight: 620
    title: "LinuxPods"
    objectName: "mainWindowObject"
    color: "transparent"

    // Frameless dropdown / "shutter from the top panel" behaviour.
    // No Qt.Tool — that flag blocks focus on Wayland/X11, which kills both
    // requestActivate() and the auto-hide-on-focus-lost logic.
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    property bool _hadFocus: false
    property bool _autoHide: Qt.application.arguments.indexOf("--no-autohide") === -1
    // Show on startup only when explicitly told via --no-autohide or
    // a sub-page deeplink. The default daemon mode (--hide) keeps the
    // popup invisible until C++ reopen() is invoked.
    property bool _initialAutoShow: Qt.application.arguments.indexOf("--no-autohide") !== -1
                                    || Qt.application.arguments.indexOf("--settings") !== -1
                                    || Qt.application.arguments.indexOf("--hearing") !== -1
    // Brief grace period after the popup appears, during which losing focus
    // will NOT trigger auto-hide (avoids the popup vanishing the instant
    // the spawning bash / spectacle process steals focus).
    property bool _autoHideArmed: false


    // Show the popup. We do NOT try to set x/y manually — Wayland
    // compositors (KWin) ignore client-side positioning for normal
    // top-level windows. Instead we let KStatusNotifierItem +
    // KWin handle placement; on KDE Plasma 6 this anchors the window
    // to the tray icon automatically because we registered it via
    // setAssociatedWindow() in C++.
    function showFromTopPanel(anchorX, anchorY) {
        mainWindow.visible = true;
        mainWindow.raise();
        mainWindow.requestActivate();
    }

    function hideToTopPanel() {
        mainWindow.visible = false;
    }

    Timer {
        id: armAutoHideTimer
        interval: 800
        onTriggered: mainWindow._autoHideArmed = true
    }

    Component.onCompleted: {
        if (_initialAutoShow) {
            showFromTopPanel(-1, -1);
        }
    }

    // When the popup loses focus, slide it back up and hide.
    onActiveChanged: {
        if (active) {
            _hadFocus = true;
        } else if (_autoHide && _autoHideArmed && _hadFocus && visible) {
            hideToTopPanel();
            _hadFocus = false;
            _autoHideArmed = false;
        }
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

    // Called from C++ when the user clicks the tray icon.
    // anchorX/anchorY are the global screen coordinates of the click on the
    // tray icon (KStatusNotifierItem::activateRequested gives us this on
    // Wayland — the geometry that QSystemTrayIcon::geometry() can't return).
    // Pass -1, -1 to use the default top-right placement.
    function reopen(pageToLoad, anchorX, anchorY) {
        console.error("[LinuxPods] reopen pageToLoad=" + pageToLoad
                      + " anchor=(" + anchorX + "," + anchorY + ")"
                      + " visible=" + mainWindow.visible);
        if (pageToLoad === "settings") {
            if (stackView.depth === 1) {
                stackView.push(settingsPage)
            }
        } else {
            if (stackView.depth > 1) {
                stackView.pop()
            }
        }

        if (mainWindow.visible) {
            // Toggle behaviour: clicking the tray icon while visible hides
            // the popup (matches KDE Quick Settings).
            hideToTopPanel();
            return;
        }

        showFromTopPanel(anchorX === undefined ? -1 : anchorX,
                         anchorY === undefined ? -1 : anchorY);
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
                anchors.bottom: bottomBar.top
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

                    // ── Compact hero (Stitch: 100px image + 96px halo blur 40px) ─
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.preferredHeight: 130

                        Rectangle {
                            id: heroGlowSource
                            anchors.centerIn: parent
                            width: 90
                            height: 90
                            radius: width / 2
                            color: "#7bafff"
                            visible: false
                            layer.enabled: true
                        }

                        MultiEffect {
                            anchors.centerIn: parent
                            width: 200
                            height: 200
                            source: heroGlowSource
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 64
                            blurMultiplier: 1.2
                            opacity: 0.20
                            autoPaddingEnabled: true
                        }

                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/icons/assets/airpods.png"
                            width: 100
                            height: 100
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

                    // ── Features card (single glass with divide-y rows) ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.topMargin: 2
                        Layout.preferredHeight: 129
                        radius: 16
                        color: Qt.rgba(30 / 255, 30 / 255, 30 / 255, 0.55)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.06)
                        visible: airPodsTrayApp.airpodsConnected

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 0

                            SettingRow {
                                label: qsTr("Conversational Awareness")
                                iconText: "\u2B25"
                                iconColor: "#7bafff"
                                type: "toggle"
                                toggleChecked: airPodsTrayApp.deviceInfo.conversationalAwareness
                                onToggleClicked: airPodsTrayApp.setConversationalAwareness(!toggleChecked)
                            }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                            SettingRow {
                                label: qsTr("Hearing Aid Mode")
                                iconText: "\u266B"
                                iconColor: "#eda8ff"
                                type: "toggle"
                                toggleChecked: airPodsTrayApp.deviceInfo.hearingAidEnabled
                                clickable: true
                                onRowClicked: stackView.push(hearingAidPage)
                                onToggleClicked: airPodsTrayApp.setHearingAidEnabled(!toggleChecked)
                            }
                        }
                    }

                    // Spacer + bottom margin
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                    }
                }
            }

            // ── Bottom strip: "More Settings..." link ─────────────────
            Rectangle {
                id: bottomBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 36
                color: Qt.rgba(0, 0, 0, 0.40)
                z: 100

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.05)
                }

                MouseArea {
                    id: footerHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stackView.push(settingsPage)
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    text: qsTr("More Settings...")
                    color: footerHover.containsMouse ? "#ffffff" : "#9a9996"
                    font.family: "Inter"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16
                    text: "\u203A"
                    color: footerHover.containsMouse ? "#ffffff" : "#9a9996"
                    font.family: "Inter"
                    font.pixelSize: 16
                    font.bold: true
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
