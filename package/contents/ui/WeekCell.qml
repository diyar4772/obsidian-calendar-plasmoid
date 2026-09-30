/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

// Week number; clickable when a weekly-note format is configured.
PlasmaComponents.AbstractButton {
    id: cell

    // { week, start, clickable, hasNote, path }
    property var cellData
    property string variant: "native"

    enabled: cellData.clickable
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    text: String(cellData.week)

    Accessible.name: i18nc("@info week number", "Week %1", cellData.week)
    Accessible.description: cellData.hasNote ? cellData.path : (cellData.clickable ? i18nc("@info:tooltip", "No weekly note") : "")

    PlasmaComponents.ToolTip.text: Accessible.name + (Accessible.description ? "\n" + Accessible.description : "")
    PlasmaComponents.ToolTip.visible: hovered && cellData.clickable
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: Item {
        PlasmaExtras.Highlight {
            anchors.fill: parent
            visible: cell.variant === "native" && opacity > 0
            hovered: true
            opacity: cell.hovered ? 0.3 : 0
        }
        Rectangle {
            visible: cell.variant === "journal" && (cell.cellData.hasNote || cell.hovered)
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.8
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: cell.cellData.hasNote ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
        }
    }

    contentItem: PlasmaComponents.Label {
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: cell.text
        textFormat: Text.PlainText
        font.pixelSize: cell.variant === "journal" ? Kirigami.Theme.smallFont.pixelSize : Kirigami.Theme.defaultFont.pixelSize
        font.italic: cell.variant === "native"
        font.weight: cell.cellData.hasNote ? Font.DemiBold : Font.Normal
        color: cell.cellData.hasNote ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: cell.cellData.hasNote ? 1 : 0.6
    }
}
