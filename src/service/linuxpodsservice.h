#pragma once

#include <QObject>
#include <QSettings>
#include <QBluetoothSocket>
#include <QBluetoothDeviceInfo>
#include <QBluetoothLocalDevice>
#include <QTimer>
#include <QProcess>
#include <QRegularExpression>

#include "airpods_packets.h"
#include "logger.h"
#include "enums.h"
#include "battery.hpp"
#include "deviceinfo.hpp"
#include "eardetection.hpp"
#include "BluetoothMonitor.h"
#include "autostartmanager.hpp"
#include "systemsleepmonitor.hpp"
#include "ble/blemanager.h"
#include "ble/bleutils.h"
#include "media/mediacontroller.h"

using namespace AirpodsTrayApp::Enums;

// LinuxPodsService: headless backend that owns all AirPods protocol,
// device state, BLE scanning, media integration, and settings.
// No QML, no GUI, no tray — pure business logic.
//
// Consumers (daemon D-Bus adaptor, standalone GUI, plasmoid) talk to
// this class through its public API of Q_PROPERTY / Q_INVOKABLE / signals.
class LinuxPodsService : public QObject
{
    Q_OBJECT

    // ── Connection state ────────────────────────────────────────────
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionChanged)
    Q_PROPERTY(DeviceInfo *deviceInfo READ deviceInfo CONSTANT)
    Q_PROPERTY(AutoStartManager *autoStartManager READ autoStartManager CONSTANT)

    // ── Settings ────────────────────────────────────────────────────
    Q_PROPERTY(int earDetectionBehavior READ earDetectionBehavior
               WRITE setEarDetectionBehavior NOTIFY earDetectionBehaviorChanged)
    Q_PROPERTY(bool crossDeviceEnabled READ crossDeviceEnabled
               WRITE setCrossDeviceEnabled NOTIFY crossDeviceEnabledChanged)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled
               WRITE setNotificationsEnabled NOTIFY notificationsEnabledChanged)
    Q_PROPERTY(int retryAttempts READ retryAttempts
               WRITE setRetryAttempts NOTIFY retryAttemptsChanged)

public:
    explicit LinuxPodsService(bool debugMode, QObject *parent = nullptr);
    ~LinuxPodsService() override;

    // ── Accessors ───────────────────────────────────────────────────
    bool isConnected() const;
    DeviceInfo *deviceInfo() const { return m_deviceInfo; }
    AutoStartManager *autoStartManager() const { return m_autoStartManager; }
    int earDetectionBehavior() const;
    bool crossDeviceEnabled() const { return m_crossDevice.isEnabled; }
    bool notificationsEnabled() const { return m_notificationsEnabled; }
    int retryAttempts() const { return m_retryAttempts; }

    // ── Initialization (call after construction) ────────────────────
    void initialize();

public slots:
    // ── Commands ────────────────────────────────────────────────────
    void setNoiseControlMode(NoiseControlMode mode);
    void setNoiseControlModeInt(int mode);
    void setAdaptiveNoiseLevel(int level);
    void setConversationalAwareness(bool enabled);
    void setHearingAidEnabled(bool enabled);
    void setOneBudANCMode(bool enabled);
    void setEarDetectionBehavior(int behavior);
    void setCrossDeviceEnabled(bool enabled);
    void setNotificationsEnabled(bool enabled);
    void setRetryAttempts(int attempts);
    void renameDevice(const QString &newName);
    void setPhoneMac(const QString &mac);
    void requestMagicCloudKeys();

    void connectToDevice(const QString &address);

signals:
    // ── State change signals ────────────────────────────────────────
    void connectionChanged();
    void deviceConnected(const QString &name);
    void deviceDisconnected();
    void earDetectionBehaviorChanged(int behavior);
    void crossDeviceEnabledChanged(bool enabled);
    void notificationsEnabledChanged(bool enabled);
    void retryAttemptsChanged(int attempts);
    void phoneMacStatusChanged(const QString &status);

    // Forwarded from sub-models for convenience
    void batteryStatusChanged(const QString &status);
    void noiseControlModeChanged(int mode);
    void conversationalAwarenessChanged(bool enabled);
    void hearingAidEnabledChanged(bool enabled);

    // Notification request (for tray / plasmoid to display)
    void showNotificationRequested(const QString &title, const QString &message);

private slots:
    void onBluezDeviceConnected(const QString &address, const QString &name);
    void onBluezDeviceDisconnected(const QString &address, const QString &name);
    void onBleDeviceFound(const BleInfo &device);
    void onSystemGoingToSleep();
    void onSystemWakingUp();
    void onMediaStateChanged(MediaController::MediaState state);

private:
    // ── Protocol ────────────────────────────────────────────────────
    bool isAirPodsDevice(const QBluetoothDeviceInfo &device);
    void connectToDevice(const QBluetoothDeviceInfo &device);
    void sendHandshake();
    bool writePacketToSocket(const QByteArray &packet, const QString &logMessage);
    void parseData(const QByteArray &data);
    void parseMetadata(const QByteArray &data);

    // ── Phone / Cross-device ────────────────────────────────────────
    void connectToPhone();
    void notifyAndroidDevice();
    void relayPacketToPhone(const QByteArray &packet);
    void handlePhonePacket(const QByteArray &packet);
    void sendDisconnectRequestToAndroid();

    // ── Internal disconnect handling ────────────────────────────────
    void handleDeviceDisconnected(const QBluetoothAddress &address);

    // ── Settings persistence ────────────────────────────────────────
    bool loadCrossDeviceEnabled();
    void saveCrossDeviceEnabled();
    int loadEarDetectionSettings();
    void saveEarDetectionSettings();
    bool loadNotificationsEnabled() const;
    void saveNotificationsEnabled(bool enabled);
    int loadRetryAttempts() const;
    void saveRetryAttempts(int attempts);

    // ── Members ─────────────────────────────────────────────────────
    bool m_debugMode;
    QSettings *m_settings;
    DeviceInfo *m_deviceInfo;
    AutoStartManager *m_autoStartManager;

    // Bluetooth
    QBluetoothSocket *m_socket = nullptr;
    QBluetoothSocket *m_phoneSocket = nullptr;
    BluetoothMonitor *m_monitor;
    BleManager *m_bleManager;

    // Media
    MediaController *m_mediaController;

    // System
    SystemSleepMonitor *m_systemSleepMonitor;

    // Settings state
    struct {
        bool isAvailable = true;
        bool isEnabled = false;
    } m_crossDevice;

    bool m_notificationsEnabled = true;
    int m_retryAttempts = 3;
    int m_retryCount = 0;

    // Cross-device relay buffers
    QByteArray m_lastBatteryStatus;
    QByteArray m_lastEarDetectionStatus;
    bool m_isConnectedLocally = false;

    QString m_phoneMacStatus;
};
