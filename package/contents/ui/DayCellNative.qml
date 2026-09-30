/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

// "Plasma Native": looks like the days in Plasma's own calendar popup, with
// the Calendar plugin's word dots under the number.
DayCell {
    id: cell

    // Draw the highlight ourselves (custom colors) instead of with Plasma's theme.
    property bool ownHighlight: false

    readonly property real dotSize: Math.max(1.5, Math.min(Kirigami.Units.smallSpacing * 1.25, height / 9))

    background: Item {
        // Keyboard focus frame, as in Plasma's DayDelegate
        KSvg.FrameSvgItem {
            anchors {
                fill: parent
                leftMargin: -margins.left
                topMargin: -margins.top
                rightMargin: -margins.right
                bottomMargin: -margins.bottom
            }
            visible: cell.visualFocus
            imagePath: "widgets/button"
            prefix: ["toolbutton-focus", "focus"]
        }
        PlasmaExtras.Highlight {
            anchors.fill: parent
            hovered: true
            visible: !cell.ownHighlight && opacity > 0
            opacity: cell.cellData.isToday ? 1 : cell.hovered ? 0.3 : cell.activeFocus ? 0.1 : 0
        }
        Rectangle {
            anchors.fill: parent
            visible: cell.ownHighlight && (cell.cellData.isToday || cell.hovered || cell.activeFocus)
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b,
                           cell.cellData.isToday ? 0.3 : cell.hovered ? 0.18 : 0.08)
            border.width: cell.cellData.isToday ? 1 : 0
            border.color: Kirigami.Theme.highlightColor
        }
    }

    contentItem: Item {
        PlasmaComponents.Label {
            id: label
            anchors.fill: parent
            anchors.bottomMargin: cell.cellData.hasNote ? cell.dotSize * 2 : 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Math.max(Kirigami.Units.gridUnit * 0.4, Math.min(cell.height / 2.6, cell.width / 2.2) * cell.textScale)
            font.weight: cell.cellData.isToday ? Font.DemiBold : Font.Normal
            text: cell.text
            textFormat: Text.PlainText
            opacity: cell.cellData.inMonth ? 1 : 0.5
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: label.bottom
            anchors.topMargin: -Math.round(cell.dotSize * 1.5)
            spacing: Math.max(1, Math.round(cell.dotSize / 2))
            opacity: label.opacity

            Repeater {
                model: cell.cellData.dots
                Rectangle {
                    width: cell.dotSize
                    height: width
                    radius: width / 2
                    color: Kirigami.Theme.highlightColor
                }
            }
        }
    }
}
