// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root
    // Parent PlasmoidItem is passed in from main.qml. We toggle `expanded`
    // on that object to show/hide the popup. The `Plasmoid` attached
    // property's `expanded` is effectively read-only in Plasma 6 — the
    // writable one lives on the PlasmoidItem itself. This is how KDE's
    // own kdeconnect plasmoid does it.
    required property PlasmoidItem plasmoidItem

    Kirigami.Icon {
        anchors.fill: parent
        source: "audio-headphones"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.plasmoidItem.expanded = !root.plasmoidItem.expanded
    }
}
