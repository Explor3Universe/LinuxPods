import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: fullRep

    // Access the global backend from PlasmoidItem (main.qml)
    readonly property var b: root.backend

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 55
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 60
    Layout.maximumHeight: Kirigami.Units.gridUnit * 65

    spacing: 0

    // ── Header ──────────────────────────────────────────────────────
    PlasmaExtras.PlasmoidHeading {
        Layout.fillWidth: true

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: "audio-headphones"
            }

            PC3.Label {
                Layout.fillWidth: true
                text: fullRep.b ? (fullRep.b.deviceName || i18n("LinuxPods")) : i18n("LinuxPods")
                elide: Text.ElideRight
                font.weight: Font.DemiBold
            }

            Rectangle {
                visible: fullRep.b !== null
                Layout.preferredWidth: stLbl.implicitWidth + Kirigami.Units.largeSpacing
                Layout.preferredHeight: stLbl.implicitHeight + 4
                radius: height / 2
                color: fullRep.b && fullRep.b.connected
                    ? Qt.rgba(Kirigami.Theme.positiveTextColor.r,
                              Kirigami.Theme.positiveTextColor.g,
                              Kirigami.Theme.positiveTextColor.b, 0.15)
                    : Qt.rgba(Kirigami.Theme.negativeTextColor.r,
                              Kirigami.Theme.negativeTextColor.g,
                              Kirigami.Theme.negativeTextColor.b, 0.15)

                PC3.Label {
                    id: stLbl
                    anchors.centerIn: parent
                    text: fullRep.b && fullRep.b.connected ? i18n("Connected") : i18n("Disconnected")
                    color: fullRep.b && fullRep.b.connected
                        ? Kirigami.Theme.positiveTextColor
                        : Kirigami.Theme.negativeTextColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    // ── Placeholder ─────────────────────────────────────────────────
    PlasmaExtras.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !fullRep.b || !fullRep.b.available
        iconName: "network-disconnect-symbolic"
        text: i18n("Daemon is not running")
        explanation: i18n("systemctl --user start linuxpods-daemon")
    }

    // ── Content ─────────────────────────────────────────────────────
    PC3.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: fullRep.b && fullRep.b.available
        contentWidth: availableWidth
        PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

        ColumnLayout {
            id: content
            width: parent.width
            spacing: Kirigami.Units.mediumSpacing

            // ── Battery ─────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.gridUnit * 2
                visible: fullRep.b && fullRep.b.connected

                BatteryItem {
                    visible: fullRep.b && fullRep.b.leftAvailable
                    label: i18n("Left")
                    level: fullRep.b ? fullRep.b.leftLevel : 0
                    charging: fullRep.b ? fullRep.b.leftCharging : false
                    inEar: fullRep.b ? fullRep.b.leftInEar : false
                }
                BatteryItem {
                    visible: fullRep.b && fullRep.b.caseAvailable
                    label: i18n("Case")
                    level: fullRep.b ? fullRep.b.caseLevel : 0
                    charging: fullRep.b ? fullRep.b.caseCharging : false
                    inEar: true
                }
                BatteryItem {
                    visible: fullRep.b && fullRep.b.rightAvailable
                    label: i18n("Right")
                    level: fullRep.b ? fullRep.b.rightLevel : 0
                    charging: fullRep.b ? fullRep.b.rightCharging : false
                    inEar: fullRep.b ? fullRep.b.rightInEar : false
                }
                BatteryItem {
                    visible: fullRep.b && fullRep.b.headsetAvailable
                             && !(fullRep.b && fullRep.b.leftAvailable)
                    label: i18n("Headset")
                    level: fullRep.b ? fullRep.b.headsetLevel : 0
                    charging: fullRep.b ? fullRep.b.headsetCharging : false
                    inEar: true
                }
            }

            // ── Noise Control ───────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                visible: fullRep.b && fullRep.b.connected

                Kirigami.Heading { text: i18n("Noise Control"); level: 5; opacity: 0.6 }

                PC3.TabBar {
                    id: noiseBar
                    Layout.fillWidth: true

                    // Sync from backend without triggering command
                    property bool updating: false
                    Component.onCompleted: { updating = true; currentIndex = fullRep.b ? fullRep.b.noiseMode : 0; updating = false; }

                    Connections {
                        target: fullRep.b
                        function onNoiseModeChanged() {
                            noiseBar.updating = true;
                            noiseBar.currentIndex = fullRep.b.noiseMode;
                            noiseBar.updating = false;
                        }
                    }

                    onCurrentIndexChanged: {
                        if (!updating && fullRep.b)
                            fullRep.b.setNoise(currentIndex);
                    }

                    PC3.TabButton { text: i18n("Off") }
                    PC3.TabButton { text: i18n("ANC") }
                    PC3.TabButton { text: i18n("Transp") }
                    PC3.TabButton { text: i18n("Adapt") }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: fullRep.b && fullRep.b.noiseMode === 3

                    PC3.Slider {
                        id: adSlider
                        Layout.fillWidth: true
                        from: 0; to: 100; stepSize: 1
                        value: fullRep.b ? fullRep.b.adaptiveLevel : 50
                        onPressedChanged: if (!pressed && fullRep.b)
                            fullRep.b.setAdaptive(value)
                    }
                    PC3.Label {
                        text: Math.round(adSlider.value) + "%"
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // ── Features ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: 0
                visible: fullRep.b && fullRep.b.connected

                Kirigami.Heading { text: i18n("Features"); level: 5; opacity: 0.6; Layout.bottomMargin: Kirigami.Units.smallSpacing }

                Kirigami.Separator { Layout.fillWidth: true }
                FeatureRow { text: i18n("Conversational Awareness"); checked: fullRep.b ? fullRep.b.conversationalAwareness : false; onToggled: fullRep.b.setCA(checked) }
                Kirigami.Separator { Layout.fillWidth: true }
                FeatureRow { text: i18n("Hearing Aid"); checked: fullRep.b ? fullRep.b.hearingAid : false; onToggled: fullRep.b.setHA(checked) }
                Kirigami.Separator { Layout.fillWidth: true }
                FeatureRow { text: i18n("One Bud ANC"); checked: fullRep.b ? fullRep.b.oneBudANC : false; onToggled: fullRep.b.set1Bud(checked) }
            }

            // ── Settings ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: 0

                Kirigami.Heading { text: i18n("Settings"); level: 5; opacity: 0.6; Layout.bottomMargin: Kirigami.Units.smallSpacing }

                Kirigami.Separator { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    PC3.Label { Layout.fillWidth: true; text: i18n("Pause when removed") }
                    PC3.ComboBox {
                        model: [i18n("One ear"), i18n("Both"), i18n("Never")]
                        currentIndex: fullRep.b ? fullRep.b.earBehavior : 0
                        onActivated: (i) => { if (fullRep.b) fullRep.b.setEarBeh(i) }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }
                FeatureRow { text: i18n("Notifications"); checked: fullRep.b ? fullRep.b.notifications : false; onToggled: { if (fullRep.b) fullRep.b.setNotif(checked) } }
                Kirigami.Separator { Layout.fillWidth: true }
                FeatureRow { text: i18n("Auto-start"); checked: fullRep.b ? fullRep.b.autoStart : false; onToggled: { if (fullRep.b) fullRep.b.setAutoSt(checked) } }
                Kirigami.Separator { Layout.fillWidth: true }
                FeatureRow { text: i18n("Cross-device"); checked: fullRep.b ? fullRep.b.crossDevice : false; onToggled: { if (fullRep.b) fullRep.b.setCross(checked) } }
            }

            Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
        }
    }
}
