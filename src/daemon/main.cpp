// SPDX-License-Identifier: GPL-3.0-or-later

#include <QCoreApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QTranslator>
#include <QStandardPaths>
#include <QFile>
#include <QLoggingCategory>
#include <unistd.h>

#include "logger.h"
#include "service/linuxpodsservice.h"
#include "dbus/linuxpodsdbusadaptor.h"

Q_LOGGING_CATEGORY(linuxpods, "linuxpods")

// Headless daemon entry point for LinuxPods.
//
// Runs without any GUI (QCoreApplication).
// Provides:
//   - AirPods protocol, BLE scanning, media integration
//   - D-Bus service at io.github.Explor3Universe.LinuxPods
//   - QLocalServer for CLI commands (linuxpods-ctl)
//
// On Plasma, the plasmoid talks to this daemon over D-Bus.

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("linuxpods-daemon"));
    app.setOrganizationName(QStringLiteral("AirPodsTrayApp"));

    // Load translations
    QTranslator *translator = new QTranslator(&app);
    QString locale = QLocale::system().name();
    QStringList translationPaths = {
        QCoreApplication::applicationDirPath() + "/translations",
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + "/linuxpods/translations",
        "/usr/share/linuxpods/translations",
        "/usr/local/share/linuxpods/translations"
    };
    for (const QString &path : translationPaths)
    {
        if (translator->load("linuxpods_" + locale, path))
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

    // ── Socket path in XDG_RUNTIME_DIR (user-private, no root conflicts) ──
    QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtimeDir.isEmpty())
        runtimeDir = QString("/run/user/%1").arg(getuid());
    QString socketPath = runtimeDir + "/linuxpods-daemon";

    // ── Single-instance check ───────────────────────────────────────
    // Remove stale socket file (from a crashed previous run)
    QFile::remove(socketPath);
    QLocalSocket socketCheck;
    socketCheck.connectToServer(socketPath);
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

    // ── Local server for CLI commands ────────────────────────────────
    QLocalServer server;
    server.setSocketOptions(QLocalServer::UserAccessOption);
    if (!server.listen(socketPath))
    {
        LOG_ERROR("Unable to start CLI listening server: " << server.errorString());
    }
    else
    {
        LOG_INFO("CLI server listening on " << socketPath);
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
            else if (msg == "ca:on")
                service.setConversationalAwareness(true);
            else if (msg == "ca:off")
                service.setConversationalAwareness(false);
            else
                LOG_ERROR("Unknown CLI message: " << msg);
            sock->disconnectFromServer();
        });
        QObject::connect(sock, &QLocalSocket::disconnected, sock, &QLocalSocket::deleteLater);
    });

    QObject::connect(&app, &QCoreApplication::aboutToQuit, [&]() {
        if (server.isListening()) server.close();
        QFile::remove(socketPath);
    });

    LOG_INFO("linuxpods-daemon running. D-Bus: io.github.Explor3Universe.LinuxPods");
    return app.exec();
}
