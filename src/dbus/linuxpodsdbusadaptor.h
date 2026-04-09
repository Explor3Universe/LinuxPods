#pragma once

#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include "service/linuxpodsservice.h"

// D-Bus adaptor that exposes LinuxPodsService on the session bus.
//
//   Service:   me.kavishdevar.linuxpods
//   Path:      /me/kavishdevar/linuxpods
//   Interface: me.kavishdevar.linuxpods.Manager
//
// All properties are read-only on D-Bus; mutations go through methods.
// PropertiesChanged is emitted automatically by Qt when properties change.
class LinuxPodsDBusAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "me.kavishdevar.linuxpods.Manager")

    // ── Connection ──────────────────────────────────────────────────
    Q_PROPERTY(bool Connected READ connected)
    Q_PROPERTY(QString DeviceName READ deviceName)
    Q_PROPERTY(QString DeviceModel READ deviceModel)
    Q_PROPERTY(QString BluetoothAddress READ bluetoothAddress)

    // ── Battery ─────────────────────────────────────────────────────
    Q_PROPERTY(uchar LeftBatteryLevel READ leftBatteryLevel)
    Q_PROPERTY(bool LeftBatteryCharging READ leftBatteryCharging)
    Q_PROPERTY(bool LeftBatteryAvailable READ leftBatteryAvailable)
    Q_PROPERTY(uchar RightBatteryLevel READ rightBatteryLevel)
    Q_PROPERTY(bool RightBatteryCharging READ rightBatteryCharging)
    Q_PROPERTY(bool RightBatteryAvailable READ rightBatteryAvailable)
    Q_PROPERTY(uchar CaseBatteryLevel READ caseBatteryLevel)
    Q_PROPERTY(bool CaseBatteryCharging READ caseBatteryCharging)
    Q_PROPERTY(bool CaseBatteryAvailable READ caseBatteryAvailable)
    Q_PROPERTY(uchar HeadsetBatteryLevel READ headsetBatteryLevel)
    Q_PROPERTY(bool HeadsetBatteryCharging READ headsetBatteryCharging)
    Q_PROPERTY(bool HeadsetBatteryAvailable READ headsetBatteryAvailable)

    // ── Ear detection ───────────────────────────────────────────────
    Q_PROPERTY(bool LeftPodInEar READ leftPodInEar)
    Q_PROPERTY(bool RightPodInEar READ rightPodInEar)

    // ── Noise control ───────────────────────────────────────────────
    Q_PROPERTY(int NoiseControlMode READ noiseControlMode)
    Q_PROPERTY(int AdaptiveNoiseLevel READ adaptiveNoiseLevel)

    // ── Feature toggles ─────────────────────────────────────────────
    Q_PROPERTY(bool ConversationalAwareness READ conversationalAwareness)
    Q_PROPERTY(bool HearingAidEnabled READ hearingAidEnabled)
    Q_PROPERTY(bool OneBudANCMode READ oneBudANCMode)

    // ── Settings ────────────────────────────────────────────────────
    Q_PROPERTY(int EarDetectionBehavior READ earDetectionBehavior)
    Q_PROPERTY(bool NotificationsEnabled READ notificationsEnabled)
    Q_PROPERTY(bool AutoStartEnabled READ autoStartEnabled)
    Q_PROPERTY(int RetryAttempts READ retryAttempts)
    Q_PROPERTY(bool CrossDeviceEnabled READ crossDeviceEnabled)

    // ── Magic Cloud Keys ────────────────────────────────────────────
    Q_PROPERTY(QString MagicAccIRK READ magicAccIRK)
    Q_PROPERTY(QString MagicAccEncKey READ magicAccEncKey)

public:
    explicit LinuxPodsDBusAdaptor(LinuxPodsService *service)
        : QDBusAbstractAdaptor(service)
        , m_service(service)
    {
        setAutoRelaySignals(true);

        // Emit PropertiesChanged when service state changes
        auto emitAll = [this]() { emitPropertiesChanged(); };

        connect(m_service, &LinuxPodsService::connectionChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::batteryStatusChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::noiseControlModeChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::conversationalAwarenessChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::hearingAidEnabledChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::earDetectionBehaviorChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::notificationsEnabledChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::retryAttemptsChanged, this, emitAll);
        connect(m_service, &LinuxPodsService::crossDeviceEnabledChanged, this, emitAll);

        // Forward DeviceInfo sub-signals
        connect(m_service->deviceInfo(), &DeviceInfo::deviceNameChanged, this, emitAll);
        connect(m_service->deviceInfo(), &DeviceInfo::modelChanged, this, emitAll);
        connect(m_service->deviceInfo(), &DeviceInfo::bluetoothAddressChanged, this, emitAll);
        connect(m_service->deviceInfo(), &DeviceInfo::oneBudANCModeChanged, this, emitAll);
        connect(m_service->deviceInfo(), &DeviceInfo::adaptiveNoiseLevelChanged, this, emitAll);
        connect(m_service->deviceInfo(), &DeviceInfo::primaryChanged, this, emitAll);
        connect(m_service->deviceInfo()->getBattery(), &Battery::batteryStatusChanged, this, emitAll);
        connect(m_service->deviceInfo()->getEarDetection(), &EarDetection::statusChanged, this, emitAll);
    }

    // Register this service on the session bus.
    // If the D-Bus name is already taken (e.g. old instance still running),
    // queue for ownership instead of failing hard.
    static bool registerService(LinuxPodsService *service)
    {
        auto *adaptor = new LinuxPodsDBusAdaptor(service);
        Q_UNUSED(adaptor)

        QDBusConnection bus = QDBusConnection::sessionBus();
        if (!bus.registerObject(QStringLiteral("/me/kavishdevar/linuxpods"), service))
        {
            LOG_ERROR("D-Bus: failed to register object: " << bus.lastError().message());
            return false;
        }
        if (!bus.registerService(QStringLiteral("me.kavishdevar.linuxpods")))
        {
            LOG_WARN("D-Bus: name already taken, queuing for ownership");
            // Queue — we'll get the name when the old owner exits.
            bus.interface()->call(QStringLiteral("RequestName"),
                                  QStringLiteral("me.kavishdevar.linuxpods"),
                                  (uint)4 /* DBUS_NAME_FLAG_DO_NOT_QUEUE=0, just queue */);
        }
        LOG_INFO("D-Bus: registered me.kavishdevar.linuxpods on session bus");
        return true;
    }

    // ── Property getters ────────────────────────────────────────────
    bool connected() const { return m_service->isConnected(); }
    QString deviceName() const { return m_service->deviceInfo()->deviceName(); }
    QString deviceModel() const { return m_service->deviceInfo()->modelNumber(); }
    QString bluetoothAddress() const { return m_service->deviceInfo()->bluetoothAddress(); }

    uchar leftBatteryLevel() const { return m_service->deviceInfo()->getBattery()->getLeftPodLevel(); }
    bool leftBatteryCharging() const { return m_service->deviceInfo()->getBattery()->isLeftPodCharging(); }
    bool leftBatteryAvailable() const { return m_service->deviceInfo()->getBattery()->isLeftPodAvailable(); }
    uchar rightBatteryLevel() const { return m_service->deviceInfo()->getBattery()->getRightPodLevel(); }
    bool rightBatteryCharging() const { return m_service->deviceInfo()->getBattery()->isRightPodCharging(); }
    bool rightBatteryAvailable() const { return m_service->deviceInfo()->getBattery()->isRightPodAvailable(); }
    uchar caseBatteryLevel() const { return m_service->deviceInfo()->getBattery()->getCaseLevel(); }
    bool caseBatteryCharging() const { return m_service->deviceInfo()->getBattery()->isCaseCharging(); }
    bool caseBatteryAvailable() const { return m_service->deviceInfo()->getBattery()->isCaseAvailable(); }
    uchar headsetBatteryLevel() const { return m_service->deviceInfo()->getBattery()->getHeadsetLevel(); }
    bool headsetBatteryCharging() const { return m_service->deviceInfo()->getBattery()->isHeadsetCharging(); }
    bool headsetBatteryAvailable() const { return m_service->deviceInfo()->getBattery()->isHeadsetAvailable(); }

    bool leftPodInEar() const { return m_service->deviceInfo()->isLeftPodInEar(); }
    bool rightPodInEar() const { return m_service->deviceInfo()->isRightPodInEar(); }

    int noiseControlMode() const { return static_cast<int>(m_service->deviceInfo()->noiseControlMode()); }
    int adaptiveNoiseLevel() const { return m_service->deviceInfo()->adaptiveNoiseLevel(); }

    bool conversationalAwareness() const { return m_service->deviceInfo()->conversationalAwareness(); }
    bool hearingAidEnabled() const { return m_service->deviceInfo()->hearingAidEnabled(); }
    bool oneBudANCMode() const { return m_service->deviceInfo()->oneBudANCMode(); }

    int earDetectionBehavior() const { return m_service->earDetectionBehavior(); }
    bool notificationsEnabled() const { return m_service->notificationsEnabled(); }
    bool autoStartEnabled() const { return m_service->autoStartManager()->autoStartEnabled(); }
    int retryAttempts() const { return m_service->retryAttempts(); }
    bool crossDeviceEnabled() const { return m_service->crossDeviceEnabled(); }

    QString magicAccIRK() const { return m_service->deviceInfo()->magicAccIRKHex(); }
    QString magicAccEncKey() const { return m_service->deviceInfo()->magicAccEncKeyHex(); }

public slots:
    // ── D-Bus methods ───────────────────────────────────────────────
    void SetNoiseControlMode(int mode) { m_service->setNoiseControlModeInt(mode); }
    void SetAdaptiveNoiseLevel(int level) { m_service->setAdaptiveNoiseLevel(level); }
    void SetConversationalAwareness(bool enabled) { m_service->setConversationalAwareness(enabled); }
    void SetHearingAidEnabled(bool enabled) { m_service->setHearingAidEnabled(enabled); }
    void SetOneBudANCMode(bool enabled) { m_service->setOneBudANCMode(enabled); }
    void SetEarDetectionBehavior(int behavior) { m_service->setEarDetectionBehavior(behavior); }
    void SetNotificationsEnabled(bool enabled) { m_service->setNotificationsEnabled(enabled); }
    void SetAutoStartEnabled(bool enabled) { m_service->autoStartManager()->setAutoStartEnabled(enabled); }
    void SetRetryAttempts(int attempts) { m_service->setRetryAttempts(attempts); }
    void SetCrossDeviceEnabled(bool enabled) { m_service->setCrossDeviceEnabled(enabled); }
    void RenameDevice(const QString &name) { m_service->renameDevice(name); }
    void SetPhoneMac(const QString &mac) { m_service->setPhoneMac(mac); }
    void RequestMagicCloudKeys() { m_service->requestMagicCloudKeys(); }

signals:
    // ── D-Bus signals ───────────────────────────────────────────────
    void DeviceConnected(const QString &name);
    void DeviceDisconnected();

private:
    void emitPropertiesChanged()
    {
        // Emit org.freedesktop.DBus.Properties.PropertiesChanged with
        // an empty changed-properties map and all invalidated.
        // Listeners will re-read properties they care about.
        QDBusMessage signal = QDBusMessage::createSignal(
            QStringLiteral("/me/kavishdevar/linuxpods"),
            QStringLiteral("org.freedesktop.DBus.Properties"),
            QStringLiteral("PropertiesChanged"));

        signal << QStringLiteral("me.kavishdevar.linuxpods.Manager");
        signal << QVariantMap{};  // changed_properties (empty — force re-read)

        // Invalidated properties: all of them
        signal << QStringList{
            QStringLiteral("Connected"), QStringLiteral("DeviceName"),
            QStringLiteral("DeviceModel"), QStringLiteral("BluetoothAddress"),
            QStringLiteral("LeftBatteryLevel"), QStringLiteral("LeftBatteryCharging"),
            QStringLiteral("LeftBatteryAvailable"),
            QStringLiteral("RightBatteryLevel"), QStringLiteral("RightBatteryCharging"),
            QStringLiteral("RightBatteryAvailable"),
            QStringLiteral("CaseBatteryLevel"), QStringLiteral("CaseBatteryCharging"),
            QStringLiteral("CaseBatteryAvailable"),
            QStringLiteral("HeadsetBatteryLevel"), QStringLiteral("HeadsetBatteryCharging"),
            QStringLiteral("HeadsetBatteryAvailable"),
            QStringLiteral("LeftPodInEar"), QStringLiteral("RightPodInEar"),
            QStringLiteral("NoiseControlMode"), QStringLiteral("AdaptiveNoiseLevel"),
            QStringLiteral("ConversationalAwareness"), QStringLiteral("HearingAidEnabled"),
            QStringLiteral("OneBudANCMode"),
            QStringLiteral("EarDetectionBehavior"), QStringLiteral("NotificationsEnabled"),
            QStringLiteral("AutoStartEnabled"), QStringLiteral("RetryAttempts"),
            QStringLiteral("CrossDeviceEnabled"),
            QStringLiteral("MagicAccIRK"), QStringLiteral("MagicAccEncKey")
        };

        QDBusConnection::sessionBus().send(signal);
    }

    LinuxPodsService *m_service;
};
