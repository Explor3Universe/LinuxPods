// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QDebug>
#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(linuxpods)

#define LOG_INFO(msg) qCInfo(linuxpods) << "\033[32m" << msg << "\033[0m"
#define LOG_WARN(msg) qCWarning(linuxpods) << "\033[33m" << msg << "\033[0m"
#define LOG_ERROR(msg) qCCritical(linuxpods) << "\033[31m" << msg << "\033[0m"
#define LOG_DEBUG(msg) qCDebug(linuxpods) << "\033[34m" << msg << "\033[0m"
