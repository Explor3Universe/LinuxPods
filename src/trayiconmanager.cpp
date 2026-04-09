#include "trayiconmanager.h"

#include <KStatusNotifierItem>
#include <QMenu>
#include <QAction>
#include <QApplication>
#include <QPainter>
#include <QFont>
#include <QColor>
#include <QActionGroup>
#include <QIcon>
#include <QWindow>

using namespace AirpodsTrayApp::Enums;

TrayIconManager::TrayIconManager(QObject *parent) : QObject(parent)
{
    // Use a unique service ID so multiple LinuxPods instances don't fight
    // over the same StatusNotifierItem registration.
    trayIcon = new KStatusNotifierItem(QStringLiteral("linuxpods"), this);
    trayIcon->setCategory(KStatusNotifierItem::Hardware);
    trayIcon->setStatus(KStatusNotifierItem::Active);
    trayIcon->setIconByPixmap(QIcon(QStringLiteral(":/icons/assets/airpods.png")));
    trayIcon->setTitle(QStringLiteral("LinuxPods"));
    trayIcon->setToolTipTitle(QStringLiteral("LinuxPods"));
    trayIcon->setToolTipSubTitle(QStringLiteral("AirPods control"));
    trayIcon->setStandardActionsEnabled(false);

    trayMenu = new QMenu();
    setupMenuActions();
    trayIcon->setContextMenu(trayMenu);

    // KStatusNotifierItem::activateRequested fires on left-click and gives
    // us the actual click position — exactly what we need to anchor the
    // popup next to the tray icon on Wayland.
    connect(trayIcon, &KStatusNotifierItem::activateRequested,
            this, [this](bool active, const QPoint &pos) {
                emit trayActivationRequested(active, pos);
                if (active) {
                    emit trayClicked();
                }
            });
}

void TrayIconManager::setNotificationsEnabled(bool enabled)
{
    if (m_notificationsEnabled != enabled) {
        m_notificationsEnabled = enabled;
        emit notificationsEnabledChanged(enabled);
    }
}

void TrayIconManager::resetTrayIcon()
{
    trayIcon->setIconByPixmap(QIcon(QStringLiteral(":/icons/assets/airpods.png")));
    trayIcon->setToolTipSubTitle(QString());
}

void TrayIconManager::setAssociatedQmlWindow(QWindow *window)
{
    if (trayIcon && window) {
        trayIcon->setAssociatedWindow(window);
    }
}

void TrayIconManager::showAssociatedWindow(const QPoint &pos)
{
    if (!trayIcon) {
        return;
    }

    if (auto *window = trayIcon->associatedWindow(); window && window->isVisible()) {
        window->raise();
        window->requestActivate();
        return;
    }

    trayIcon->activate(pos);
}

void TrayIconManager::hideAssociatedWindow()
{
    if (trayIcon) {
        trayIcon->hideAssociatedWindow();
    }
}

void TrayIconManager::showNotification(const QString &title, const QString &message)
{
    if (!m_notificationsEnabled)
        return;
    trayIcon->showMessage(title, message, QStringLiteral("dialog-information"), 3000);
}

void TrayIconManager::updateBatteryStatus(const QString &status)
{
    trayIcon->setToolTipSubTitle(tr("Battery: ") + status);
    updateIconFromBattery(status);
}

void TrayIconManager::updateNoiseControlState(NoiseControlMode mode)
{
    QList<QAction *> actions = noiseControlGroup->actions();
    for (QAction *action : actions) {
        action->setChecked(action->data().toInt() == (int)mode);
    }
}

void TrayIconManager::updateConversationalAwareness(bool enabled)
{
    caToggleAction->setChecked(enabled);
}

void TrayIconManager::setupMenuActions()
{
    QAction *openAction = new QAction(tr("Open"), trayMenu);
    trayMenu->addAction(openAction);
    connect(openAction, &QAction::triggered, qApp, [this]() { emit openApp(); });

    QAction *settingsMenu = new QAction(tr("Settings"), trayMenu);
    trayMenu->addAction(settingsMenu);
    connect(settingsMenu, &QAction::triggered, qApp, [this]() { emit openSettings(); });

    trayMenu->addSeparator();

    caToggleAction = new QAction(tr("Toggle Conversational Awareness"), trayMenu);
    caToggleAction->setCheckable(true);
    trayMenu->addAction(caToggleAction);
    connect(caToggleAction, &QAction::triggered, this,
            [this](bool checked) { emit conversationalAwarenessToggled(checked); });

    trayMenu->addSeparator();

    noiseControlGroup = new QActionGroup(trayMenu);
    const QPair<QString, NoiseControlMode> noiseOptions[] = {
        {tr("Adaptive"), NoiseControlMode::Adaptive},
        {tr("Transparency"), NoiseControlMode::Transparency},
        {tr("Noise Cancellation"), NoiseControlMode::NoiseCancellation},
        {tr("Off"), NoiseControlMode::Off}};

    for (auto option : noiseOptions) {
        QAction *action = new QAction(option.first, trayMenu);
        action->setCheckable(true);
        action->setData((int)option.second);
        noiseControlGroup->addAction(action);
        trayMenu->addAction(action);
        connect(action, &QAction::triggered, this,
                [this, mode = option.second]() { emit noiseControlChanged(mode); });
    }

    trayMenu->addSeparator();

    QAction *quitAction = new QAction(tr("Quit"), trayMenu);
    trayMenu->addAction(quitAction);
    connect(quitAction, &QAction::triggered, qApp, &QApplication::quit);
}

void TrayIconManager::updateIconFromBattery(const QString &status)
{
    int leftLevel = 0;
    int rightLevel = 0;
    int minLevel = 0;

    if (!status.isEmpty()) {
        QStringList parts = status.split(QStringLiteral(", "));
        if (parts.size() >= 2) {
            leftLevel = parts[0].split(QStringLiteral(": "))[1].replace(QStringLiteral("%"), QString()).toInt();
            rightLevel = parts[1].split(QStringLiteral(": "))[1].replace(QStringLiteral("%"), QString()).toInt();
            minLevel = (leftLevel == 0) ? rightLevel
                       : (rightLevel == 0) ? leftLevel
                                            : qMin(leftLevel, rightLevel);
        } else if (parts.size() == 1) {
            minLevel = parts[0].split(QStringLiteral(": "))[1].replace(QStringLiteral("%"), QString()).toInt();
        }
    }

    QPixmap pixmap(32, 32);
    pixmap.fill(Qt::transparent);
    QPainter painter(&pixmap);
    painter.setPen(Qt::white);
    painter.setFont(QFont(QStringLiteral("Arial"), 12, QFont::Bold));
    painter.drawText(pixmap.rect(), Qt::AlignCenter, QString::number(minLevel) + QStringLiteral("%"));
    painter.end();

    trayIcon->setIconByPixmap(QIcon(pixmap));
}
