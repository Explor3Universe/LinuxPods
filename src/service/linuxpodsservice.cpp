#include "service/linuxpodsservice.h"

#include <QLoggingCategory>
#include <QProcessEnvironment>

Q_DECLARE_LOGGING_CATEGORY(librepods)

LinuxPodsService::LinuxPodsService(bool debugMode, QObject *parent)
    : QObject(parent)
    , m_debugMode(debugMode)
    , m_settings(new QSettings("AirPodsTrayApp", "AirPodsTrayApp", this))
    , m_deviceInfo(new DeviceInfo(this))
    , m_autoStartManager(new AutoStartManager(this))
    , m_bleManager(new BleManager(this))
    , m_systemSleepMonitor(new SystemSleepMonitor(this))
{
    QLoggingCategory::setFilterRules(
        QString("librepods.debug=%1").arg(debugMode ? "true" : "false"));
    LOG_INFO("LinuxPodsService: initializing");

    // Media controller
    m_mediaController = new MediaController(this);
    connect(m_mediaController, &MediaController::mediaStateChanged,
            this, &LinuxPodsService::onMediaStateChanged);
    m_mediaController->followMediaChanges();

    // BlueZ monitor
    m_monitor = new BluetoothMonitor(this);
    connect(m_monitor, &BluetoothMonitor::deviceConnected,
            this, &LinuxPodsService::onBluezDeviceConnected);
    connect(m_monitor, &BluetoothMonitor::deviceDisconnected,
            this, &LinuxPodsService::onBluezDeviceDisconnected);

    // BLE proximity scanner
    connect(m_bleManager, &BleManager::deviceFound,
            this, &LinuxPodsService::onBleDeviceFound);

    // Battery primary-changed → forward
    connect(m_deviceInfo->getBattery(), &Battery::primaryChanged,
            this, &LinuxPodsService::connectionChanged);

    // System sleep/wake
    connect(m_systemSleepMonitor, &SystemSleepMonitor::systemGoingToSleep,
            this, &LinuxPodsService::onSystemGoingToSleep);
    connect(m_systemSleepMonitor, &SystemSleepMonitor::systemWakingUp,
            this, &LinuxPodsService::onSystemWakingUp);

    // Forward DeviceInfo signals for D-Bus / UI convenience
    connect(m_deviceInfo, &DeviceInfo::batteryStatusChanged,
            this, &LinuxPodsService::batteryStatusChanged);
    connect(m_deviceInfo, &DeviceInfo::noiseControlModeChangedInt,
            this, &LinuxPodsService::noiseControlModeChanged);
    connect(m_deviceInfo, &DeviceInfo::conversationalAwarenessChanged,
            this, &LinuxPodsService::conversationalAwarenessChanged);
    connect(m_deviceInfo, &DeviceInfo::hearingAidEnabledChanged,
            this, &LinuxPodsService::hearingAidEnabledChanged);

    // Load persisted settings
    m_crossDevice.isEnabled = loadCrossDeviceEnabled();
    setEarDetectionBehavior(loadEarDetectionSettings());
    setRetryAttempts(loadRetryAttempts());
    m_notificationsEnabled = loadNotificationsEnabled();

    LOG_INFO("LinuxPodsService: initialized");
}

LinuxPodsService::~LinuxPodsService()
{
    saveCrossDeviceEnabled();
    saveEarDetectionSettings();
    if (m_socket) { m_socket->close(); m_socket = nullptr; }
    if (m_phoneSocket) { m_phoneSocket->close(); m_phoneSocket = nullptr; }
}

void LinuxPodsService::initialize()
{
    // Check already-connected BlueZ devices
    m_monitor->checkAlreadyConnectedDevices();

    QBluetoothLocalDevice localDevice;
    const QList<QBluetoothAddress> connectedDevices = localDevice.connectedDevices();
    for (const QBluetoothAddress &address : connectedDevices)
    {
        QBluetoothDeviceInfo device(address, "", 0);
        if (isAirPodsDevice(device))
        {
            connectToDevice(device);
            QTimer::singleShot(2000, this, [this, address]() {
                QString formattedAddress = address.toString().replace(":", "_");
                m_mediaController->setConnectedDeviceMacAddress(formattedAddress);
                m_mediaController->activateA2dpProfile();
                LOG_INFO("A2DP profile activation attempted for AirPods found on startup");
            });
            return;
        }
    }

    // No AirPods found on startup — start scanning and phone connection
    connectToPhone();
    m_deviceInfo->loadFromSettings(*m_settings);
    if (!isConnected())
    {
        m_bleManager->startScan();
    }
}

// ─── Accessors ──────────────────────────────────────────────────────

bool LinuxPodsService::isConnected() const
{
    bool connected = m_socket && m_socket->isOpen()
                     && m_socket->state() == QBluetoothSocket::SocketState::ConnectedState;
    return connected;
}

int LinuxPodsService::earDetectionBehavior() const
{
    return m_mediaController->getEarDetectionBehavior();
}

// ─── Commands ───────────────────────────────────────────────────────

void LinuxPodsService::setNoiseControlMode(NoiseControlMode mode)
{
    if (m_deviceInfo->noiseControlMode() == mode)
    {
        LOG_INFO("Noise control mode already set to: " << static_cast<int>(mode));
        return;
    }
    LOG_INFO("Setting noise control mode to: " << static_cast<int>(mode));
    QByteArray packet = AirPodsPackets::NoiseControl::getPacketForMode(mode);
    writePacketToSocket(packet, "Noise control mode packet written: ");
}

void LinuxPodsService::setNoiseControlModeInt(int mode)
{
    if (mode < 0 || mode > static_cast<int>(NoiseControlMode::Adaptive))
    {
        LOG_ERROR("Invalid noise control mode: " << mode);
        return;
    }
    setNoiseControlMode(static_cast<NoiseControlMode>(mode));
}

void LinuxPodsService::setAdaptiveNoiseLevel(int level)
{
    level = qBound(0, level, 100);
    if (m_deviceInfo->adaptiveNoiseLevel() != level && m_deviceInfo->adaptiveModeActive())
    {
        QByteArray packet = AirPodsPackets::AdaptiveNoise::getPacket(level);
        writePacketToSocket(packet, "Adaptive noise level packet written: ");
        m_deviceInfo->setAdaptiveNoiseLevel(level);
    }
}

void LinuxPodsService::setConversationalAwareness(bool enabled)
{
    LOG_INFO("Setting conversational awareness to: " << (enabled ? "enabled" : "disabled"));
    QByteArray packet = enabled ? AirPodsPackets::ConversationalAwareness::ENABLED
                                : AirPodsPackets::ConversationalAwareness::DISABLED;
    writePacketToSocket(packet, "Conversational awareness packet written: ");
    m_deviceInfo->setConversationalAwareness(enabled);
}

void LinuxPodsService::setHearingAidEnabled(bool enabled)
{
    LOG_INFO("Setting hearing aid to: " << (enabled ? "enabled" : "disabled"));
    QByteArray packet = enabled ? AirPodsPackets::HearingAid::ENABLED
                                : AirPodsPackets::HearingAid::DISABLED;
    writePacketToSocket(packet, "Hearing aid packet written: ");
    m_deviceInfo->setHearingAidEnabled(enabled);
}

void LinuxPodsService::setOneBudANCMode(bool enabled)
{
    if (m_deviceInfo->oneBudANCMode() == enabled)
    {
        LOG_INFO("One Bud ANC mode already " << (enabled ? "enabled" : "disabled"));
        return;
    }
    LOG_INFO("Setting One Bud ANC mode to: " << (enabled ? "enabled" : "disabled"));
    QByteArray packet = enabled ? AirPodsPackets::OneBudANCMode::ENABLED
                                : AirPodsPackets::OneBudANCMode::DISABLED;
    if (writePacketToSocket(packet, "One Bud ANC mode packet written: "))
    {
        m_deviceInfo->setOneBudANCMode(enabled);
    }
    else
    {
        LOG_ERROR("Failed to send One Bud ANC mode command: socket not open");
    }
}

void LinuxPodsService::setEarDetectionBehavior(int behavior)
{
    if (behavior == earDetectionBehavior())
    {
        return;
    }
    m_mediaController->setEarDetectionBehavior(
        static_cast<MediaController::EarDetectionBehavior>(behavior));
    saveEarDetectionSettings();
    emit earDetectionBehaviorChanged(behavior);
}

void LinuxPodsService::setCrossDeviceEnabled(bool enabled)
{
    if (m_crossDevice.isEnabled == enabled) return;
    m_crossDevice.isEnabled = enabled;
    saveCrossDeviceEnabled();
    connectToPhone();
    emit crossDeviceEnabledChanged(enabled);
}

void LinuxPodsService::setNotificationsEnabled(bool enabled)
{
    if (m_notificationsEnabled != enabled)
    {
        m_notificationsEnabled = enabled;
        saveNotificationsEnabled(enabled);
        emit notificationsEnabledChanged(enabled);
    }
}

void LinuxPodsService::setRetryAttempts(int attempts)
{
    if (m_retryAttempts != attempts)
    {
        m_retryAttempts = attempts;
        saveRetryAttempts(attempts);
        emit retryAttemptsChanged(attempts);
    }
}

void LinuxPodsService::renameDevice(const QString &newName)
{
    if (newName.isEmpty())
    {
        LOG_WARN("Cannot set empty name");
        return;
    }
    if (newName.size() > 32)
    {
        LOG_WARN("Name too long, must be 32 characters or less");
        return;
    }
    if (newName == m_deviceInfo->deviceName()) return;

    QByteArray packet = AirPodsPackets::Rename::getPacket(newName);
    if (writePacketToSocket(packet, "Rename packet written: "))
    {
        LOG_INFO("Sent rename command for: " << newName);
        m_deviceInfo->setDeviceName(newName);
    }
    else
    {
        LOG_ERROR("Failed to send rename command: socket not open");
    }
}

void LinuxPodsService::setPhoneMac(const QString &mac)
{
    if (mac.isEmpty())
    {
        LOG_WARN("Empty MAC provided, ignoring");
        m_phoneMacStatus = QStringLiteral("No MAC provided (ignoring)");
        emit phoneMacStatusChanged(m_phoneMacStatus);
        return;
    }

    QRegularExpression re("^([0-9A-Fa-f]{2}([-:]?)){5}[0-9A-Fa-f]{2}$");
    if (!re.match(mac).hasMatch())
    {
        LOG_ERROR("Invalid MAC address format: " << mac);
        m_phoneMacStatus = QStringLiteral("Invalid MAC: ") + mac;
        emit phoneMacStatusChanged(m_phoneMacStatus);
        return;
    }

    qputenv("PHONE_MAC_ADDRESS", mac.toUtf8());
    LOG_INFO("PHONE_MAC_ADDRESS set to: " << mac);

    m_phoneMacStatus = QStringLiteral("Updated MAC: ") + mac;
    emit phoneMacStatusChanged(m_phoneMacStatus);

    if (m_phoneSocket && m_phoneSocket->isOpen())
    {
        m_phoneSocket->close();
        m_phoneSocket->deleteLater();
        m_phoneSocket = nullptr;
    }
    connectToPhone();
}

void LinuxPodsService::requestMagicCloudKeys()
{
    if (!m_socket || !m_socket->isOpen())
    {
        LOG_ERROR("Socket not open, cannot request Magic Cloud Keys");
        return;
    }
    writePacketToSocket(AirPodsPackets::MagicPairing::REQUEST_MAGIC_CLOUD_KEYS,
                        "Magic Pairing packet written: ");
}

void LinuxPodsService::connectToDevice(const QString &address)
{
    LOG_INFO("Connecting to device with address: " << address);
    QBluetoothAddress btAddress(address);
    QBluetoothDeviceInfo device(btAddress, "", 0);
    connectToDevice(device);
}

// ─── BlueZ slots ────────────────────────────────────────────────────

void LinuxPodsService::onBluezDeviceConnected(const QString &address, const QString &name)
{
    QBluetoothDeviceInfo device(QBluetoothAddress(address), name, 0);
    connectToDevice(device);

    QTimer::singleShot(2000, this, [this, address]() {
        if (!address.isEmpty())
        {
            QString formatted = QString(address).replace(":", "_");
            m_mediaController->setConnectedDeviceMacAddress(formatted);
            m_mediaController->activateA2dpProfile();
            LOG_INFO("A2DP profile activation attempted for newly connected device");
        }
    });
}

void LinuxPodsService::onBluezDeviceDisconnected(const QString &address, const QString &name)
{
    Q_UNUSED(name)
    if (address == m_deviceInfo->bluetoothAddress())
    {
        handleDeviceDisconnected(QBluetoothAddress(address));
    }
    else
    {
        LOG_WARN("Disconnected device does not match connected device: "
                 << address << " != " << m_deviceInfo->bluetoothAddress());
    }
}

void LinuxPodsService::onBleDeviceFound(const BleInfo &device)
{
    if (BLEUtils::isValidIrkRpa(m_deviceInfo->magicAccIRK(), device.address))
    {
        m_deviceInfo->setModel(device.modelName);
        auto decrypted = BLEUtils::decryptLastBytes(
            device.encryptedPayload, m_deviceInfo->magicAccEncKey());
        m_deviceInfo->getBattery()->parseEncryptedPacket(
            decrypted, device.primaryLeft, device.isThisPodInTheCase,
            isModelHeadset(m_deviceInfo->model()));
        m_deviceInfo->getEarDetection()->overrideEarDetectionStatus(
            device.isPrimaryInEar, device.isSecondaryInEar);
    }
}

void LinuxPodsService::onSystemGoingToSleep()
{
    if (m_bleManager->isScanning())
    {
        LOG_INFO("Stopping BLE scan before sleep");
        m_bleManager->stopScan();
    }
}

void LinuxPodsService::onSystemWakingUp()
{
    LOG_INFO("System waking up, starting BLE scan");
    m_bleManager->startScan();

    if (isConnected() && m_deviceInfo
        && !m_deviceInfo->bluetoothAddress().isEmpty())
    {
        LOG_INFO("AirPods connected after wake-up, re-activating A2DP");
        m_mediaController->setConnectedDeviceMacAddress(
            m_deviceInfo->bluetoothAddress().replace(":", "_"));
        QTimer::singleShot(1000, this, [this]() {
            m_mediaController->activateA2dpProfile();
        });
    }

    m_monitor->checkAlreadyConnectedDevices();
}

void LinuxPodsService::onMediaStateChanged(MediaController::MediaState state)
{
    if (state == MediaController::MediaState::Playing)
    {
        LOG_INFO("Media started playing, sending disconnect request to Android");
        sendDisconnectRequestToAndroid();

        // Force-connect if needed
        if (m_socket && m_socket->isOpen()) return;
        LOG_INFO("Forcing connection to AirPods");
        QProcess process;
        process.start("bluetoothctl",
                      QStringList() << "connect" << m_deviceInfo->bluetoothAddress());
        process.waitForFinished();

        QBluetoothLocalDevice localDevice;
        for (const QBluetoothAddress &addr : localDevice.connectedDevices())
        {
            QBluetoothDeviceInfo dev(addr, "", 0);
            if (isAirPodsDevice(dev))
            {
                connectToDevice(dev);
                return;
            }
        }
        LOG_WARN("AirPods not found among connected devices");
    }
}

// ─── Protocol internals ─────────────────────────────────────────────

bool LinuxPodsService::isAirPodsDevice(const QBluetoothDeviceInfo &device)
{
    return device.serviceUuids().contains(
        QBluetoothUuid("74ec2172-0bad-4d01-8f77-997b2be0722a"));
}

void LinuxPodsService::connectToDevice(const QBluetoothDeviceInfo &device)
{
    if (m_socket && m_socket->isOpen()
        && m_socket->peerAddress() == device.address())
    {
        LOG_INFO("[connect] Already connected to: " << device.address().toString());
        return;
    }

    LOG_INFO("[connect] Connecting to " << device.address().toString());

    if (m_socket)
    {
        LOG_INFO("[connect] Closing old socket");
        m_socket->close();
        m_socket->deleteLater();
        m_socket = nullptr;
    }

    QBluetoothSocket *sock = new QBluetoothSocket(QBluetoothServiceInfo::L2capProtocol);
    m_socket = sock;

    // ── Connected handler ───────────────────────────────────────────
    connect(sock, &QBluetoothSocket::connected, this, [this]() {
        LOG_INFO("[connect] Socket connected, sending handshake");
        m_retryCount = 0;

        if (!m_socket) return;

        connect(m_socket, &QBluetoothSocket::readyRead, this, [this]() {
            if (!m_socket) return;
            QByteArray data = m_socket->readAll();
            QMetaObject::invokeMethod(this, [this, data]() { parseData(data); },
                                      Qt::QueuedConnection);
            QMetaObject::invokeMethod(this, [this, data]() { relayPacketToPhone(data); },
                                      Qt::QueuedConnection);
        });

        connect(m_socket, &QBluetoothSocket::disconnected, this, [this]() {
            LOG_WARN("[connect] Socket disconnected by remote");
            if (m_socket)
                handleDeviceDisconnected(QBluetoothAddress(m_deviceInfo->bluetoothAddress()));
        });

        sendHandshake();
        emit connectionChanged();
    });

    // ── Error handler with retry ────────────────────────────────────
    connect(sock, QOverload<QBluetoothSocket::SocketError>::of(
                &QBluetoothSocket::errorOccurred),
            this, [this, device, sock](QBluetoothSocket::SocketError error) {
        LOG_ERROR("[connect] Socket error: " << error << " " << sock->errorString());

        if (m_retryCount < m_retryAttempts)
        {
            m_retryCount++;
            LOG_INFO("[connect] Retrying (" << m_retryCount << "/" << m_retryAttempts << ")");
            QTimer::singleShot(1500, this, [this, device]() {
                connectToDevice(device);
            });
        }
        else
        {
            LOG_ERROR("[connect] Failed after " << m_retryAttempts << " attempts");
            m_retryCount = 0;
            emit connectionChanged();
        }
    });

    sock->connectToService(device.address(),
        QBluetoothUuid("74ec2172-0bad-4d01-8f77-997b2be0722a"));
    m_deviceInfo->setBluetoothAddress(device.address().toString());
    notifyAndroidDevice();
}

void LinuxPodsService::sendHandshake()
{
    LOG_INFO("Connected to device, sending initial packets");
    writePacketToSocket(AirPodsPackets::Connection::HANDSHAKE,
                        "Handshake packet written: ");
}

bool LinuxPodsService::writePacketToSocket(const QByteArray &packet,
                                           const QString &logMessage)
{
    if (m_socket && m_socket->isOpen())
    {
        m_socket->write(packet);
        LOG_DEBUG(logMessage << packet.toHex());
        return true;
    }
    LOG_ERROR("Socket not open, cannot write packet");
    return false;
}

void LinuxPodsService::parseData(const QByteArray &data)
{
    LOG_DEBUG("Received: " << data.toHex());

    if (data.startsWith(AirPodsPackets::Parse::HANDSHAKE_ACK))
    {
        writePacketToSocket(AirPodsPackets::Connection::SET_SPECIFIC_FEATURES,
                            "Set specific features packet written: ");
    }
    else if (data.startsWith(AirPodsPackets::Parse::FEATURES_ACK))
    {
        writePacketToSocket(AirPodsPackets::Connection::REQUEST_NOTIFICATIONS,
                            "Request notifications packet written: ");
        QTimer::singleShot(2000, this, [this]() {
            if (m_deviceInfo->batteryStatus().isEmpty())
            {
                writePacketToSocket(AirPodsPackets::Connection::REQUEST_NOTIFICATIONS,
                                    "Request notifications (retry) written: ");
            }
        });
    }
    else if (data.startsWith(AirPodsPackets::MagicPairing::MAGIC_CLOUD_KEYS_HEADER))
    {
        auto keys = AirPodsPackets::MagicPairing::parseMagicCloudKeysPacket(data);
        LOG_INFO("Received Magic Cloud Keys");
        m_deviceInfo->setMagicAccIRK(keys.magicAccIRK);
        m_deviceInfo->setMagicAccEncKey(keys.magicAccEncKey);
        m_deviceInfo->saveToSettings(*m_settings);
    }
    else if (data.startsWith(AirPodsPackets::ConversationalAwareness::HEADER))
    {
        if (auto result = AirPodsPackets::ConversationalAwareness::parseState(data))
        {
            m_deviceInfo->setConversationalAwareness(result.value());
            LOG_INFO("Conversational awareness: " << m_deviceInfo->conversationalAwareness());
        }
    }
    else if (data.startsWith(AirPodsPackets::HearingAid::HEADER))
    {
        if (auto result = AirPodsPackets::HearingAid::parseState(data))
        {
            m_deviceInfo->setHearingAidEnabled(result.value());
            LOG_INFO("Hearing aid: " << m_deviceInfo->hearingAidEnabled());
        }
    }
    else if (data.size() == 11
             && data.startsWith(AirPodsPackets::NoiseControl::HEADER))
    {
        if (auto value = AirPodsPackets::NoiseControl::parseMode(data))
        {
            m_deviceInfo->setNoiseControlMode(value.value());
            LOG_INFO("Noise control mode: " << static_cast<int>(m_deviceInfo->noiseControlMode()));
        }
    }
    else if (data.size() == 8
             && data.startsWith(AirPodsPackets::Parse::EAR_DETECTION))
    {
        m_deviceInfo->getEarDetection()->parseData(data);
        m_mediaController->handleEarDetection(m_deviceInfo->getEarDetection());
    }
    else if ((data.size() == 22 || data.size() == 12)
             && data.startsWith(AirPodsPackets::Parse::BATTERY_STATUS))
    {
        m_deviceInfo->getBattery()->parsePacket(data);
        m_deviceInfo->updateBatteryStatus();
        LOG_INFO("Battery status: " << m_deviceInfo->batteryStatus());
    }
    else if (data.size() == 10
             && data.startsWith(AirPodsPackets::ConversationalAwareness::DATA_HEADER))
    {
        LOG_INFO("Received conversational awareness data");
        m_mediaController->handleConversationalAwareness(data);
    }
    else if (data.startsWith(AirPodsPackets::Parse::METADATA))
    {
        parseMetadata(data);
        requestMagicCloudKeys();
        m_mediaController->setConnectedDeviceMacAddress(
            m_deviceInfo->bluetoothAddress().replace(":", "_"));
        if (m_deviceInfo->getEarDetection()->oneOrMorePodsInEar())
        {
            m_mediaController->activateA2dpProfile();
        }
        m_bleManager->stopScan();
        LOG_INFO("[state] CONNECTED " << m_deviceInfo->deviceName()
                 << " addr=" << m_deviceInfo->bluetoothAddress());
        emit connectionChanged();
        emit deviceConnected(m_deviceInfo->deviceName());
        emit showNotificationRequested(
            tr("AirPods Connected"),
            m_deviceInfo->deviceName());
    }
    else if (data.startsWith(AirPodsPackets::OneBudANCMode::HEADER))
    {
        if (auto value = AirPodsPackets::OneBudANCMode::parseState(data))
        {
            m_deviceInfo->setOneBudANCMode(value.value());
            LOG_INFO("One Bud ANC mode: " << m_deviceInfo->oneBudANCMode());
        }
    }
    else
    {
        LOG_DEBUG("Unrecognized packet: " << data.toHex());
    }
}

void LinuxPodsService::parseMetadata(const QByteArray &data)
{
    if (!data.startsWith(AirPodsPackets::Parse::METADATA))
    {
        LOG_ERROR("Invalid metadata packet: incorrect header");
        return;
    }

    int pos = AirPodsPackets::Parse::METADATA.size();
    if (data.size() < pos + 6)
    {
        LOG_ERROR("Metadata packet too short");
        return;
    }
    pos += 6;

    auto extractString = [&data, &pos]() -> QString {
        if (pos >= data.size()) return {};
        int start = pos;
        while (pos < data.size() && data.at(pos) != '\0') ++pos;
        QString str = QString::fromUtf8(data.mid(start, pos - start));
        if (pos < data.size()) ++pos;
        return str;
    };

    m_deviceInfo->setDeviceName(extractString());
    m_deviceInfo->setModelNumber(extractString());
    m_deviceInfo->setManufacturer(extractString());
    m_deviceInfo->setModel(parseModelNumber(m_deviceInfo->modelNumber()));

    LOG_INFO("Parsed metadata: name=" << m_deviceInfo->deviceName()
             << " model=" << m_deviceInfo->modelNumber()
             << " mfr=" << m_deviceInfo->manufacturer());
}

void LinuxPodsService::handleDeviceDisconnected(const QBluetoothAddress &address)
{
    LOG_WARN("[state] DISCONNECTED " << address.toString());
    if (m_socket)
    {
        m_socket->close();
        m_socket->deleteLater();
        m_socket = nullptr;
    }

    if (m_phoneSocket && m_phoneSocket->isOpen())
    {
        m_phoneSocket->write(AirPodsPackets::Connection::AIRPODS_DISCONNECTED);
    }

    m_deviceInfo->reset();
    m_bleManager->startScan();
    emit connectionChanged();
    emit deviceDisconnected();
    emit showNotificationRequested(
        tr("AirPods Disconnected"),
        tr("Your AirPods have been disconnected"));
}

// ─── Phone / Cross-device ───────────────────────────────────────────

void LinuxPodsService::connectToPhone()
{
    if (!m_crossDevice.isEnabled) return;
    if (m_phoneSocket && m_phoneSocket->isOpen())
    {
        LOG_INFO("Already connected to phone");
        return;
    }

    // Clean up stale non-open socket
    if (m_phoneSocket)
    {
        m_phoneSocket->deleteLater();
        m_phoneSocket = nullptr;
    }

    QBluetoothAddress phoneAddress("00:00:00:00:00:00");
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    if (!env.value("PHONE_MAC_ADDRESS").isEmpty())
    {
        phoneAddress = QBluetoothAddress(env.value("PHONE_MAC_ADDRESS"));
    }

    m_phoneSocket = new QBluetoothSocket(QBluetoothServiceInfo::L2capProtocol);
    connect(m_phoneSocket, &QBluetoothSocket::connected, this, [this]() {
        LOG_INFO("Connected to phone");
        if (!m_lastBatteryStatus.isEmpty())
            m_phoneSocket->write(m_lastBatteryStatus);
        if (!m_lastEarDetectionStatus.isEmpty())
            m_phoneSocket->write(m_lastEarDetectionStatus);
    });
    connect(m_phoneSocket, &QBluetoothSocket::readyRead, this, [this]() {
        if (m_phoneSocket)
            handlePhonePacket(m_phoneSocket->readAll());
    });
    connect(m_phoneSocket,
            QOverload<QBluetoothSocket::SocketError>::of(&QBluetoothSocket::errorOccurred),
            this, [this](QBluetoothSocket::SocketError error) {
                LOG_ERROR("Phone socket error: " << error);
                if (m_phoneSocket) { m_phoneSocket->deleteLater(); m_phoneSocket = nullptr; }
            });

    m_phoneSocket->connectToService(
        phoneAddress, QBluetoothUuid("1abbb9a4-10e4-4000-a75c-8953c5471342"));
}

void LinuxPodsService::notifyAndroidDevice()
{
    if (!m_crossDevice.isEnabled) return;
    if (m_phoneSocket && m_phoneSocket->isOpen())
    {
        m_phoneSocket->write(AirPodsPackets::Phone::NOTIFICATION);
    }
    else
    {
        LOG_WARN("Phone socket not open, cannot notify");
    }
}

void LinuxPodsService::relayPacketToPhone(const QByteArray &packet)
{
    if (!m_crossDevice.isEnabled) return;
    if (m_phoneSocket && m_phoneSocket->isOpen())
    {
        m_phoneSocket->write(AirPodsPackets::Phone::NOTIFICATION + packet);
    }
    else
    {
        connectToPhone();
    }
}

void LinuxPodsService::handlePhonePacket(const QByteArray &packet)
{
    if (packet.startsWith(AirPodsPackets::Phone::NOTIFICATION))
    {
        QByteArray airpodsPacket = packet.mid(4);
        if (m_socket && m_socket->isOpen())
            m_socket->write(airpodsPacket);
    }
    else if (packet.startsWith(AirPodsPackets::Phone::CONNECTED))
    {
        m_isConnectedLocally = true;
        m_crossDevice.isAvailable = false;
    }
    else if (packet.startsWith(AirPodsPackets::Phone::DISCONNECTED))
    {
        m_isConnectedLocally = false;
        m_crossDevice.isAvailable = true;
    }
    else if (packet.startsWith(AirPodsPackets::Phone::STATUS_REQUEST))
    {
        QByteArray response = (m_socket && m_socket->isOpen())
            ? AirPodsPackets::Phone::CONNECTED
            : AirPodsPackets::Phone::DISCONNECTED;
        m_phoneSocket->write(response);
    }
    else if (packet.startsWith(AirPodsPackets::Phone::DISCONNECT_REQUEST))
    {
        if (m_socket && m_socket->isOpen())
        {
            m_socket->close();
            QProcess process;
            process.start("bluetoothctl",
                          QStringList() << "disconnect" << m_deviceInfo->bluetoothAddress());
            process.waitForFinished();
            m_isConnectedLocally = false;
            m_crossDevice.isAvailable = true;
        }
    }
    else
    {
        if (m_socket && m_socket->isOpen())
            m_socket->write(packet);
    }
}

void LinuxPodsService::sendDisconnectRequestToAndroid()
{
    if (!m_crossDevice.isEnabled) return;
    if (m_phoneSocket && m_phoneSocket->isOpen())
    {
        m_phoneSocket->write(AirPodsPackets::Phone::DISCONNECT_REQUEST);
    }
}

// ─── Settings persistence ───────────────────────────────────────────

bool LinuxPodsService::loadCrossDeviceEnabled()
{
    return m_settings->value("crossdevice/enabled", false).toBool();
}

void LinuxPodsService::saveCrossDeviceEnabled()
{
    m_settings->setValue("crossdevice/enabled", m_crossDevice.isEnabled);
}

int LinuxPodsService::loadEarDetectionSettings()
{
    return m_settings->value("earDetection/setting",
        MediaController::EarDetectionBehavior::PauseWhenOneRemoved).toInt();
}

void LinuxPodsService::saveEarDetectionSettings()
{
    m_settings->setValue("earDetection/setting",
                         m_mediaController->getEarDetectionBehavior());
}

bool LinuxPodsService::loadNotificationsEnabled() const
{
    return m_settings->value("notifications/enabled", true).toBool();
}

void LinuxPodsService::saveNotificationsEnabled(bool enabled)
{
    m_settings->setValue("notifications/enabled", enabled);
}

int LinuxPodsService::loadRetryAttempts() const
{
    return m_settings->value("bluetooth/retryAttempts", 3).toInt();
}

void LinuxPodsService::saveRetryAttempts(int attempts)
{
    m_settings->setValue("bluetooth/retryAttempts", attempts);
}
