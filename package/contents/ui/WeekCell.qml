/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../code/paths.js" as Paths

// Week number; clickable when a weekly-note format is configured.
PlasmaComponents.AbstractButton {
    id: cell

    // { week, start, clickable, hasNote, path }
    property var cellData
    property string variant: "native"
    property real textScale: 1
    property bool ownHighlight: false
    // Strings in the widget's language (from MonthPage).
    property Translator tr

    enabled: cellData.clickable
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    text: String(cellData.week)

    // Press feedback, at Plasma's animation speed
    scale: down ? 0.92 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    Accessible.name: cell.tr.ui18nc("@info week number", "Week %1", cellData.week)
    Accessible.description: cellData.hasNote ? Paths.plainText(cellData.path) : (cellData.clickable ? cell.tr.ui18nc("@info:tooltip", "No weekly note") : "")

    PlasmaComponents.ToolTip.text: Accessible.name + (Accessible.description ? "\n" + Accessible.description : "")
    PlasmaComponents.ToolTip.visible: hovered && cellData.clickable
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: Item {
        PlasmaExtras.Highlight {
            anchors.fill: parent
            visible: cell.variant === "native" && !cell.ownHighlight && opacity > 0
            hovered: true
            opacity: cell.hovered ? 0.3 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: cell.variant === "native" && cell.ownHighlight && opacity > 0
            radius: (Kirigami.Units.cornerRadius ?? Kirigami.Units.smallSpacing)
            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.18)
            opacity: cell.hovered ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
        Rectangle {
            visible: cell.variant === "journal" && opacity > 0
            opacity: cell.cellData.hasNote || cell.hovered ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
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
        font.pixelSize: Math.max(Kirigami.Units.gridUnit * 0.4,
            Math.min(Kirigami.Units.gridUnit * (cell.variant === "journal" ? 0.6 : 0.7) * cell.textScale,
                     cell.height / 1.8, cell.width / 2))
        font.italic: cell.variant === "native"
        font.weight: cell.cellData.hasNote ? Font.DemiBold : Font.Normal
        color: cell.cellData.hasNote ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: cell.cellData.hasNote ? 1 : 0.6
    }
}
