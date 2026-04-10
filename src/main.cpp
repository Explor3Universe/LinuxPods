// SPDX-License-Identifier: GPL-3.0-or-later

#include <QSettings>
#include <QLocalServer>
#include <QLocalSocket>
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QLoggingCategory>
#include <QTimer>
#include <QTranslator>
#include <QLibraryInfo>
#include <QDir>
#include <QStandardPaths>
#include <QProcessEnvironment>

#include "logger.h"
#include "enums.h"
#include "service/linuxpodsservice.h"
#include "dbus/linuxpodsdbusadaptor.h"
#include "trayiconmanager.h"
#include "QRCodeImageProvider.hpp"

using namespace AirpodsTrayApp::Enums;

Q_LOGGING_CATEGORY(librepods, "librepods")

// AirPodsTrayApp: thin GUI shell that wires LinuxPodsService (headless
// backend) to a QML UI and a KStatusNotifierItem tray icon.
//
// All device/protocol/media/settings logic lives in LinuxPodsService.
// This class only handles:
//   - QML engine lifecycle
//   - Tray icon ↔ QML popup coordination
//   - Forwarding QML actions to the service
//   - QLocalServer for single-instance / CLI commands
class AirPodsTrayApp : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool airpodsConnected READ isConnected NOTIFY connectionChanged)
    Q_PROPERTY(DeviceInfo *deviceInfo READ deviceInfo CONSTANT)
    Q_PROPERTY(AutoStartManager *autoStartManager READ autoStartManager CONSTANT)
    Q_PROPERTY(int earDetectionBehavior READ earDetectionBehavior
               WRITE setEarDetectionBehavior NOTIFY earDetectionBehaviorChanged)
    Q_PROPERTY(bool crossDeviceEnabled READ crossDeviceEnabled
               WRITE setCrossDeviceEnabled NOTIFY crossDeviceEnabledChanged)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled
               WRITE setNotificationsEnabled NOTIFY notificationsEnabledChanged)
    Q_PROPERTY(int retryAttempts READ retryAttempts
               WRITE setRetryAttempts NOTIFY retryAttemptsChanged)
    Q_PROPERTY(bool hideOnStart READ hideOnStart CONSTANT)
    Q_PROPERTY(QString phoneMacStatus READ phoneMacStatus NOTIFY phoneMacStatusChanged)
    Q_PROPERTY(bool hearingAidEnabled READ hearingAidEnabled
               WRITE setHearingAidEnabled NOTIFY hearingAidEnabledChanged)

public:
    AirPodsTrayApp(LinuxPodsService *service, bool hideOnStart,
                   QQmlApplicationEngine *engine, QObject *parent = nullptr)
        : QObject(parent)
        , m_service(service)
        , m_hideOnStart(hideOnStart)
        , m_engine(engine)
    {
        // ── Tray icon ───────────────────────────────────────────────
        m_trayManager = new TrayIconManager(this);
        m_trayManager->setNotificationsEnabled(m_service->notificationsEnabled());

        // Tray → this (UI coordination)
        connect(m_trayManager, &TrayIconManager::trayActivationRequested,
                this, &AirPodsTrayApp::onTrayActivationRequested);
        connect(m_trayManager, &TrayIconManager::openApp,
                this, &AirPodsTrayApp::onOpenApp);
        connect(m_trayManager, &TrayIconManager::openSettings,
                this, &AirPodsTrayApp::onOpenSettings);

        // Tray → service (actions from context menu)
        connect(m_trayManager, &TrayIconManager::noiseControlChanged,
                m_service, &LinuxPodsService::setNoiseControlMode);
        connect(m_trayManager, &TrayIconManager::conversationalAwarenessToggled,
                m_service, &LinuxPodsService::setConversationalAwareness);

        // Service → tray (state updates)
        connect(m_service->deviceInfo(), &DeviceInfo::batteryStatusChanged,
                m_trayManager, &TrayIconManager::updateBatteryStatus);
        connect(m_service->deviceInfo(), &DeviceInfo::noiseControlModeChanged,
                m_trayManager, &TrayIconManager::updateNoiseControlState);
        connect(m_service->deviceInfo(), &DeviceInfo::conversationalAwarenessChanged,
                m_trayManager, &TrayIconManager::updateConversationalAwareness);

        // Service notifications → tray
        connect(m_service, &LinuxPodsService::showNotificationRequested,
                m_trayManager, &TrayIconManager::showNotification);
        connect(m_service, &LinuxPodsService::deviceDisconnected,
                this, [this]() { m_trayManager->resetTrayIcon(); });

        // Tray notifications ↔ service
        connect(m_trayManager, &TrayIconManager::notificationsEnabledChanged,
                m_service, &LinuxPodsService::setNotificationsEnabled);

        // ── Forward service signals to QML bindings ─────────────────
        connect(m_service, &LinuxPodsService::connectionChanged,
                this, &AirPodsTrayApp::connectionChanged);
        connect(m_service, &LinuxPodsService::earDetectionBehaviorChanged,
                this, &AirPodsTrayApp::earDetectionBehaviorChanged);
        connect(m_service, &LinuxPodsService::crossDeviceEnabledChanged,
                this, &AirPodsTrayApp::crossDeviceEnabledChanged);
        connect(m_service, &LinuxPodsService::notificationsEnabledChanged,
                this, &AirPodsTrayApp::notificationsEnabledChanged);
        connect(m_service, &LinuxPodsService::retryAttemptsChanged,
                this, &AirPodsTrayApp::retryAttemptsChanged);
        connect(m_service, &LinuxPodsService::phoneMacStatusChanged,
                this, [this](const QString &) { emit phoneMacStatusChanged(); });
        connect(m_service, &LinuxPodsService::hearingAidEnabledChanged,
                this, &AirPodsTrayApp::hearingAidEnabledChanged);
    }

    // ── Property accessors (delegate to service) ────────────────────
    bool isConnected() const { return m_service->isConnected(); }
    DeviceInfo *deviceInfo() const { return m_service->deviceInfo(); }
    AutoStartManager *autoStartManager() const { return m_service->autoStartManager(); }
    int earDetectionBehavior() const { return m_service->earDetectionBehavior(); }
    bool crossDeviceEnabled() const { return m_service->crossDeviceEnabled(); }
    bool notificationsEnabled() const { return m_service->notificationsEnabled(); }
    int retryAttempts() const { return m_service->retryAttempts(); }
    bool hideOnStart() const { return m_hideOnStart; }
    QString phoneMacStatus() const { return {}; }  // placeholder for QML compat
    bool hearingAidEnabled() const { return m_service->deviceInfo()->hearingAidEnabled(); }

    void loadMainModule()
    {
        m_engine->load(QUrl(QStringLiteral("qrc:/linux/Main.qml")));
        if (!m_engine->rootObjects().isEmpty())
        {
            QObject *root = m_engine->rootObjects().first();
            if (auto qw = qobject_cast<QQuickWindow *>(root))
            {
                m_trayManager->setAssociatedQmlWindow(qw);
                LOG_INFO("KStatusNotifierItem: associated window registered");
            }
        }
    }

public slots:
    // ── QML-facing slots (delegates to service) ─────────────────────
    void setNoiseControlModeInt(int mode) { m_service->setNoiseControlModeInt(mode); }
    void setConversationalAwareness(bool e) { m_service->setConversationalAwareness(e); }
    void setHearingAidEnabled(bool e) { m_service->setHearingAidEnabled(e); }
    void setOneBudANCMode(bool e) { m_service->setOneBudANCMode(e); }
    void setAdaptiveNoiseLevel(int l) { m_service->setAdaptiveNoiseLevel(l); }
    void setEarDetectionBehavior(int b) { m_service->setEarDetectionBehavior(b); }
    void setCrossDeviceEnabled(bool e) { m_service->setCrossDeviceEnabled(e); }
    void setNotificationsEnabled(bool e) { m_service->setNotificationsEnabled(e); }
    void setRetryAttempts(int a) { m_service->setRetryAttempts(a); }
    void renameAirPods(const QString &name) { m_service->renameDevice(name); }
    void setPhoneMac(const QString &mac) { m_service->setPhoneMac(mac); }
    void initiateMagicPairing() { m_service->requestMagicCloudKeys(); }

    void hidePopupWindow()
    {
        if (QObject *root = ensureRootObject())
        {
            LOG_INFO("Hiding popup window");
            root->setProperty("visible", false);
        }
    }

    void showPage(const QString &page, const QPoint &pos = QPoint(-1, -1))
    {
        showPreparedPage(page, pos);
    }

signals:
    void connectionChanged();
    void earDetectionBehaviorChanged(int);
    void crossDeviceEnabledChanged(bool);
    void notificationsEnabledChanged(bool);
    void retryAttemptsChanged(int);
    void phoneMacStatusChanged();
    void hearingAidEnabledChanged(bool);

private slots:
    void onTrayActivationRequested(bool active, const QPoint &pos)
    {
        QObject *root = ensureRootObject();
        if (!root)
        {
            LOG_ERROR("Tray activation: QML root window unavailable");
            return;
        }

        LOG_INFO("Tray activation: active=" << active << " pos=" << pos);
        if (active)
            showPreparedPage(QStringLiteral("app"), pos);
        else
            QMetaObject::invokeMethod(root, "hideToTopPanel");
    }

    void onOpenApp()
    {
        showPreparedPage(QStringLiteral("app"));
    }

    void onOpenSettings()
    {
        showPreparedPage(QStringLiteral("settings"));
    }

private:
    QObject *ensureRootObject()
    {
        if (!m_engine) return nullptr;
        if (m_engine->rootObjects().isEmpty()) loadMainModule();
        if (m_engine->rootObjects().isEmpty()) return nullptr;

        QObject *root = m_engine->rootObjects().first();
        if (auto qw = qobject_cast<QQuickWindow *>(root))
            m_trayManager->setAssociatedQmlWindow(qw);
        return root;
    }

    void preparePage(const QString &page, const QPoint &pos = QPoint(-1, -1))
    {
        if (QObject *root = ensureRootObject())
        {
            QMetaObject::invokeMethod(root, "preparePage",
                                      Q_ARG(QVariant, page));
            if (pos.x() >= 0 || pos.y() >= 0)
            {
                QMetaObject::invokeMethod(root, "anchorToTray",
                                          Q_ARG(QVariant, pos.x()),
                                          Q_ARG(QVariant, pos.y()));
            }
        }
    }

    void showPreparedPage(const QString &page, const QPoint &pos = QPoint(-1, -1))
    {
        if (QObject *root = ensureRootObject())
        {
            preparePage(page, pos);
            QMetaObject::invokeMethod(root, "showFromTopPanel",
                                      Q_ARG(QVariant, pos.x()),
                                      Q_ARG(QVariant, pos.y()));
        }
    }

    LinuxPodsService *m_service;
    TrayIconManager *m_trayManager;
    bool m_hideOnStart;
    QQmlApplicationEngine *m_engine;
};

// ─────────────────────────────────────────────────────────────────────
//  main() — application entry point
// ─────────────────────────────────────────────────────────────────────
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // Load translations
    QTranslator *translator = new QTranslator(&app);
    QString locale = QLocale::system().name();
    QStringList translationPaths = {
        QCoreApplication::applicationDirPath() + "/translations",
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + "/librepods/translations",
        "/usr/share/librepods/translations",
        "/usr/local/share/librepods/translations"
    };
    for (const QString &path : translationPaths)
    {
        if (translator->load("librepods_" + locale, path))
        {
            app.installTranslator(translator);
            break;
        }
    }

    // ── Single-instance check ───────────────────────────────────────
    QLocalServer::removeServer("linuxpods-gui");
    QFile stale("/tmp/app_server");
    if (stale.exists()) stale.remove();

    QLocalSocket socketCheck;
    socketCheck.connectToServer("linuxpods-gui");
    if (socketCheck.waitForConnected(300))
    {
        LOG_INFO("Another instance already running! Reopening window...");
        socketCheck.write("reopen");
        socketCheck.flush();
        socketCheck.waitForBytesWritten(200);
        socketCheck.disconnectFromServer();
        return 0;
    }

    app.setDesktopFileName("me.kavishdevar.librepods");
    app.setQuitOnLastWindowClosed(false);

    // ── Parse arguments ─────────────────────────────────────────────
    bool debugMode = false;
    bool hideOnStart = false;
    for (int i = 1; i < argc; ++i)
    {
        if (QString(argv[i]) == "--debug") debugMode = true;
        if (QString(argv[i]) == "--hide") hideOnStart = true;
    }

    // ── Create service (headless backend) ───────────────────────────
    LinuxPodsService service(debugMode);

    // ── Register D-Bus interface ────────────────────────────────────
    LinuxPodsDBusAdaptor::registerService(&service);

    // ── Create QML engine and GUI shell ─────────────────────────────
    QQmlApplicationEngine engine;
    qmlRegisterType<Battery>("me.kavishdevar.Battery", 1, 0, "Battery");
    qmlRegisterType<DeviceInfo>("me.kavishdevar.DeviceInfo", 1, 0, "DeviceInfo");

    AirPodsTrayApp trayApp(&service, hideOnStart, &engine);
    engine.rootContext()->setContextProperty("airPodsTrayApp", &trayApp);

    // Expose PHONE_MAC_ADDRESS for QML placeholders
    {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        QString phoneMacEnv = env.value("PHONE_MAC_ADDRESS", "");
        engine.rootContext()->setContextProperty("PHONE_MAC_ADDRESS", phoneMacEnv);
    }

    engine.addImageProvider("qrcode", new QRCodeImageProvider());
    trayApp.loadMainModule();

    // ── Initialize service (connects to already-paired devices) ─────
    service.initialize();

    // ── Local server for single-instance and CLI commands ────────────
    QLocalServer server;
    QLocalServer::removeServer("linuxpods-gui");
    if (!server.listen("linuxpods-gui"))
    {
        LOG_ERROR("Unable to start listening server");
    }

    QObject::connect(&server, &QLocalServer::newConnection, [&]() {
        QLocalSocket *sock = server.nextPendingConnection();
        QObject::connect(sock, &QLocalSocket::readyRead, [sock, &trayApp, &service]() {
            QString msg = sock->readAll();
            if (msg == "reopen")
                trayApp.showPage(QStringLiteral("app"));
            else if (msg == "noise:off")
                service.setNoiseControlModeInt(0);
            else if (msg == "noise:anc")
                service.setNoiseControlModeInt(1);
            else if (msg == "noise:transparency")
                service.setNoiseControlModeInt(2);
            else if (msg == "noise:adaptive")
                service.setNoiseControlModeInt(3);
            else
                LOG_ERROR("Unknown message: " << msg);
            sock->disconnectFromServer();
        });
    });

    QObject::connect(&app, &QCoreApplication::aboutToQuit, [&]() {
        if (server.isListening()) server.close();
        QLocalServer::removeServer("linuxpods-gui");
        QFile staleFile("/tmp/app_server");
        if (staleFile.exists()) staleFile.remove();
    });

    return app.exec();
}

#include "main.moc"
