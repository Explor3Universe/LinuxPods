// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    property alias backend: _backend
    DbusBackend { id: _backend }

    Plasmoid.status: _backend.connected
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    Plasmoid.icon: "audio-headphones"

    toolTipMainText: _backend.deviceName || i18n("LinuxPods")
    toolTipSubText: {
        if (!_backend.available)
            return i18n("Daemon not running");
        if (!_backend.connected)
            return i18n("AirPods disconnected");
        if (_backend.leftAvailable && _backend.rightAvailable)
            return i18n("L: %1%   R: %2%", _backend.leftLevel, _backend.rightLevel);
        if (_backend.headsetAvailable)
            return i18n("Battery: %1%", _backend.headsetLevel);
        return i18n("Connected");
    }

    badgeText: _backend.connected && _backend.minBattery > 0
        ? _backend.minBattery + "%"
        : ""

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}
    // NO preferredRepresentation — system tray requires it unset
    // to handle click-to-expand
}
