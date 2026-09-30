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

    // Five dots plus gaps must fit the cell width too.
    readonly property real dotSize: Math.max(1.5, Math.min(Kirigami.Units.smallSpacing * 1.25, height / 9, width / 9))

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

    readonly property bool showDots: cellData.dots > 0
    // Room for the dot row under the number
    readonly property real dotsHeight: showDots ? dotSize * 2 : 0

    contentItem: Item {
        Column {
            anchors.centerIn: parent
            spacing: 0

            PlasmaComponents.Label {
                id: label
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                // Scaled with the text-size setting, but never taller than the cell allows.
                font.pixelSize: Math.max(Kirigami.Units.gridUnit * 0.4,
                    Math.min(Math.min(cell.height / 2.6, cell.width / 2.2) * cell.textScale,
                             (cell.height - cell.dotsHeight) / 1.35,
                             cell.width / 2))
                font.weight: cell.cellData.isToday ? Font.DemiBold : Font.Normal
                text: cell.text
                textFormat: Text.PlainText
                opacity: cell.cellData.inMonth ? 1 : 0.5
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: cell.showDots
                height: cell.dotsHeight
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
}
