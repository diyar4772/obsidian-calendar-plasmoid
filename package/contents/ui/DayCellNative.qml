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
            opacity: cell.cellData.isToday ? Math.min(1, cell.todayIntro) : cell.hovered ? 0.3 : cell.activeFocus ? 0.1 : 0
            scale: cell.todayScale
            Behavior on opacity {
                enabled: cell.todayIntro === 1
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: cell.ownHighlight
            radius: (Kirigami.Units.cornerRadius ?? Kirigami.Units.smallSpacing)
            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b,
                           cell.cellData.isToday ? 0.3 : cell.hovered ? 0.18 : cell.activeFocus ? 0.08 : 0)
            scale: cell.todayScale
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
            border.width: cell.cellData.isToday ? 1 : 0
            border.color: Kirigami.Theme.highlightColor
        }
    }

    // Today's highlight grows in the first time the page shows it.
    readonly property real todayScale: cellData.isToday ? 0.6 + 0.4 * todayIntro : 1

    readonly property bool showDots: cellData.dots > 0
    readonly property bool tinyDots: dotSize < 2
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

            // Too small for separate dots: a bar whose length shows the
            // level, like Plasma's calendar does for many events.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: cell.showDots && cell.tinyDots
                width: Math.max(2, cell.width * 0.14 * cell.cellData.dots)
                height: 2
                radius: 1
                color: Kirigami.Theme.highlightColor
                opacity: label.opacity * cell.reveal
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: cell.showDots && !cell.tinyDots
                height: cell.dotsHeight
                spacing: Math.max(1, Math.round(cell.dotSize / 2))
                opacity: label.opacity * cell.reveal
                scale: 0.5 + 0.5 * cell.reveal

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
