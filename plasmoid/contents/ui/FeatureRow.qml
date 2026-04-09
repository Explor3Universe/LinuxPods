import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Standard toggle row: label + switch, native Plasma styling.
RowLayout {
    id: featureRow

    required property string text
    required property bool checked

    signal toggled(bool checked)

    Layout.fillWidth: true
    Layout.topMargin: Kirigami.Units.smallSpacing
    Layout.bottomMargin: Kirigami.Units.smallSpacing
    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        text: featureRow.text
        elide: Text.ElideRight
    }

    PlasmaComponents3.Switch {
        checked: featureRow.checked
        onToggled: featureRow.toggled(checked)
    }
}
