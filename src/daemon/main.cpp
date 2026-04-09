#include <QCoreApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QTranslator>
#include <QStandardPaths>
#include <QFile>
#include <QLoggingCategory>

#include "logger.h"
#include "service/linuxpodsservice.h"
#include "dbus/linuxpodsdbusadaptor.h"

Q_LOGGING_CATEGORY(librepods, "librepods")

// Headless daemon entry point for LinuxPods.
//
// Runs without any GUI (QCoreApplication, not QApplication).
// Provides:
//   - AirPods protocol, BLE scanning, media integration
//   - D-Bus service at me.kavishdevar.linuxpods
//   - QLocalServer for CLI commands (librepods-ctl)
//   - KStatusNotifierItem for basic tray icon (fallback for non-Plasma DE)
//
// On Plasma, the plasmoid talks to this daemon over D-Bus.
// On GNOME/XFCE/Sway, the SNI tray icon + context menu provide basic control.

int main(int argc, char *argv[])
{
    // KStatusNotifierItem requires QApplication for icon rendering.
    // Use QApplication to support SNI fallback tray icon.
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("linuxpods-daemon"));
    app.setOrganizationName(QStringLiteral("AirPodsTrayApp"));

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

    // ── Parse arguments ─────────────────────────────────────────────
    bool debugMode = false;
    for (int i = 1; i < argc; ++i)
    {
        if (QString(argv[i]) == "--debug") debugMode = true;
    }

    // ── Single-instance check ───────────────────────────────────────
    QLocalServer::removeServer("app_server");
    QFile stale("/tmp/app_server");
    if (stale.exists()) stale.remove();

    QLocalSocket socketCheck;
    socketCheck.connectToServer("app_server");
    if (socketCheck.waitForConnected(300))
    {
        LOG_INFO("Another instance already running, exiting.");
        return 0;
    }

    // ── Create service ──────────────────────────────────────────────
    LinuxPodsService service(debugMode);

    // ── Register D-Bus ──────────────────────────────────────────────
    // Non-fatal: if another instance holds the name, we queue for it.
    LinuxPodsDBusAdaptor::registerService(&service);

    // ── Initialize (connect to already-paired devices) ──────────────
    service.initialize();

    // ── Local server for CLI commands (librepods-ctl) ────────────────
    QLocalServer server;
    QLocalServer::removeServer("app_server");
    if (!server.listen("app_server"))
    {
        LOG_ERROR("Unable to start CLI listening server: " << server.errorString());
    }
    else
    {
        LOG_INFO("CLI server started on app_server");
    }

    QObject::connect(&server, &QLocalServer::newConnection, [&]() {
        QLocalSocket *sock = server.nextPendingConnection();
        QObject::connect(sock, &QLocalSocket::readyRead, [sock, &service]() {
            QString msg = sock->readAll();
            if (msg == "noise:off")
                service.setNoiseControlModeInt(0);
            else if (msg == "noise:anc")
                service.setNoiseControlModeInt(1);
            else if (msg == "noise:transparency")
                service.setNoiseControlModeInt(2);
            else if (msg == "noise:adaptive")
                service.setNoiseControlModeInt(3);
            else
                LOG_ERROR("Unknown CLI message: " << msg);
            sock->disconnectFromServer();
        });
    });

    QObject::connect(&app, &QCoreApplication::aboutToQuit, [&]() {
        if (server.isListening()) server.close();
        QLocalServer::removeServer("app_server");
        QFile staleFile("/tmp/app_server");
        if (staleFile.exists()) staleFile.remove();
    });

    LOG_INFO("linuxpods-daemon running. D-Bus: me.kavishdevar.linuxpods");
    return app.exec();
}
