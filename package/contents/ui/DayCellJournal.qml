/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// "Journal": rounded tiles tinted with the accent color by note length,
// like an activity heatmap. Today gets an accent ring.
DayCell {
    id: cell

    // "rounded", "circle" or "square"
    property string shape: "rounded"

    // Tint strength per dot level (0 = no note).
    readonly property var tints: [0, 0.22, 0.36, 0.52, 0.7, 0.88]
    // A note always gets at least the first level, even when dots are off.
    readonly property real tint: cell.cellData.hasNote ? tints[Math.max(1, Math.min(5, cell.cellData.dots))] : 0
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property bool strong: tint >= 0.6

    background: Rectangle {
        // Circles are square-sized; other tiles are kept from turning into
        // long pills when the widget is very wide or tall. Centered in the cell.
        readonly property real side: Math.min(cell.width, cell.height)
        width: cell.shape === "circle" ? side : Math.min(cell.width, cell.height * 1.6)
        height: cell.shape === "circle" ? side : Math.min(cell.height, cell.width * 1.25)
        x: (cell.width - width) / 2
        y: (cell.height - height) / 2
        radius: cell.shape === "circle" ? side / 2 : cell.shape === "square" ? 0 : (Kirigami.Units.cornerRadius ?? Kirigami.Units.smallSpacing)
        color: {
            if (cell.cellData.hasNote) {
                return Qt.rgba(cell.accent.r, cell.accent.g, cell.accent.b, cell.tint);
            }
            const t = Kirigami.Theme.textColor;
            return cell.cellData.inMonth ? Qt.rgba(t.r, t.g, t.b, cell.hovered ? 0.1 : 0.045) : "transparent";
        }
        border.width: cell.cellData.isToday || cell.visualFocus ? 2 : (cell.hovered ? 1 : 0)
        border.color: cell.cellData.isToday || cell.visualFocus
            ? cell.accent
            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    contentItem: PlasmaComponents.Label {
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Math.max(Kirigami.Units.gridUnit * 0.4, Math.min(cell.height / 2.8, cell.width / 2.4) * cell.textScale)
        font.weight: cell.cellData.isToday ? Font.Bold : (cell.cellData.hasNote ? Font.DemiBold : Font.Normal)
        text: cell.text
        textFormat: Text.PlainText
        color: cell.strong ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        opacity: cell.cellData.inMonth ? 1 : 0.35
    }
}
