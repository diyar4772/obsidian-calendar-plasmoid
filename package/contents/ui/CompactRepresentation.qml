/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// Panel icon, optionally followed by today's day number (horizontal panels).
MouseArea {
    id: compact

    required property VaultScanner scanner
    required property var today
    required property bool expanded
    property string description

    signal toggled()

    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property bool showDate: Plasmoid.configuration.showDateInPanel && horizontal

    property bool wasExpanded: false

    Layout.minimumWidth: horizontal ? row.implicitWidth : Kirigami.Units.iconSizes.small
    Layout.minimumHeight: horizontal ? Kirigami.Units.iconSizes.small : width

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    // Remember the state at press time: the popup closes on press when it
    // loses focus, and the click must not reopen it.
    onPressed: wasExpanded = expanded
    onClicked: if (expanded === wasExpanded) toggled()

    Accessible.name: Plasmoid.title
    Accessible.description: description
    Accessible.role: Accessible.Button

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            source: Plasmoid.icon
            active: compact.containsMouse
        }
        PlasmaComponents.Label {
            visible: compact.showDate
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            text: String(compact.today.d)
            textFormat: Text.PlainText
            font.weight: compact.scanner.revision >= 0 && compact.scanner.hasNote(compact.today) ? Font.Normal : Font.DemiBold
        }
    }
}
