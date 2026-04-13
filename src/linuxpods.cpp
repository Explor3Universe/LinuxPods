// SPDX-License-Identifier: GPL-3.0-or-later

#include <QCoreApplication>
#include <QLocalSocket>
#include <QStandardPaths>
#include <QTextStream>
#include <unistd.h>

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);

    if (argc < 2 || QString(argv[1]) == "--help" || QString(argv[1]) == "-h") {
        QTextStream out(argc >= 2 ? stdout : stderr);
        out << "Usage: linuxpods <command>\n"
            << "Commands:\n"
            << "  noise:off           Disable noise control\n"
            << "  noise:anc           Enable Active Noise Cancellation\n"
            << "  noise:transparency  Enable Transparency mode\n"
            << "  noise:adaptive      Enable Adaptive mode\n";
        return argc < 2 ? 1 : 0;
    }

    QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtimeDir.isEmpty())
        runtimeDir = QString("/run/user/%1").arg(getuid());

    QLocalSocket socket;
    socket.connectToServer(runtimeDir + "/linuxpods-daemon");

    if (!socket.waitForConnected(500)) {
        QTextStream(stderr) << "Could not connect to linuxpods-daemon (is it running?)\n";
        return 1;
    }

    socket.write(QByteArray(argv[1]));
    socket.flush();
    socket.waitForBytesWritten(200);
    socket.disconnectFromServer();
    return 0;
}
