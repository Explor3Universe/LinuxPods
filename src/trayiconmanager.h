// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QPoint>

#include "enums.h"

class KStatusNotifierItem;
class QMenu;
class QAction;
class QActionGroup;
class QWindow;

// Tray icon manager built on top of KStatusNotifierItem (KDE's modern
// StatusNotifierItem D-Bus implementation). Compared to QSystemTrayIcon
// this gives us:
//   * activateRequested(bool active, QPoint pos) — the *real* click
//     position on Wayland, so we can anchor a dropdown popup next to
//     the tray icon (QSystemTrayIcon::geometry() returns 0,0,0,0 on
//     Wayland — the long-standing reason tray dropdowns "appear in the
//     centre of the screen").
//   * setAssociatedWindow() — registers our QWindow with the
//     compositor as the main window of the SNI, so KWin keeps the
//     popup linked to the tray icon for activation/focus.
class TrayIconManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled WRITE setNotificationsEnabled NOTIFY notificationsEnabledChanged)

public:
    explicit TrayIconManager(QObject *parent = nullptr);

    void updateBatteryStatus(const QString &status);
    void updateNoiseControlState(AirpodsTrayApp::Enums::NoiseControlMode);
    void updateConversationalAwareness(bool enabled);
    void showNotification(const QString &title, const QString &message);
    void showAssociatedWindow(const QPoint &pos = QPoint());
    void hideAssociatedWindow();

    bool notificationsEnabled() const { return m_notificationsEnabled; }
    void setNotificationsEnabled(bool enabled);

    void resetTrayIcon();

    // Register the QML ApplicationWindow handle so KStatusNotifierItem can
    // emit Wayland activation tokens that target the right surface.
    void setAssociatedQmlWindow(QWindow *window);

signals:
    void notificationsEnabledChanged(bool enabled);

    // Emitted when the host asks us to show or hide the associated popup.
    // `active=true` means "show/open", `false` means "hide/close".
    void trayActivationRequested(bool active, const QPoint &pos);

    // Legacy signal kept for menu wiring; carries no positional info.
    void trayClicked();

    void noiseControlChanged(AirpodsTrayApp::Enums::NoiseControlMode);
    void conversationalAwarenessToggled(bool enabled);
    void openApp();
    void openSettings();

private:
    void setupMenuActions();
    void updateIconFromBattery(const QString &status);

    KStatusNotifierItem *trayIcon = nullptr;
    QMenu *trayMenu = nullptr;
    QAction *caToggleAction = nullptr;
    QActionGroup *noiseControlGroup = nullptr;
    bool m_notificationsEnabled = true;
};
