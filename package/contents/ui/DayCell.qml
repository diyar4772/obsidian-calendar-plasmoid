/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/dates.js" as Dates

// Behavior shared by both day cell designs: tooltip, accessibility and
// keyboard navigation. Subclasses provide background and contentItem.
PlasmaComponents.AbstractButton {
    id: cell

    // { date, inMonth, isToday, hasNote, dots, words, path }
    property var cellData

    // Text-size setting as a factor
    property real textScale: 1

    // Arrow keys: -1/+1 for left/right, -7/+7 for up/down.
    signal moveFocus(int step)

    readonly property string longDate: Dates.toJsDate(cellData.date).toLocaleDateString(Qt.locale(), Locale.LongFormat)

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    text: String(cellData.date.d)

    Accessible.name: longDate
    Accessible.description: {
        if (!cellData.hasNote) {
            return cellData.isToday ? i18nc("@info:tooltip", "No note yet") : i18nc("@info:tooltip", "No note");
        }
        return cellData.words >= 0
            ? i18ncp("@info:tooltip note path and word count", "%2, %1 word", "%2, %1 words", cellData.words, cellData.path)
            : cellData.path;
    }

    PlasmaComponents.ToolTip.text: longDate + "\n" + Accessible.description
    PlasmaComponents.ToolTip.visible: hovered
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    Keys.onLeftPressed: moveFocus(Application.layoutDirection === Qt.RightToLeft ? 1 : -1)
    Keys.onRightPressed: moveFocus(Application.layoutDirection === Qt.RightToLeft ? -1 : 1)
    Keys.onUpPressed: moveFocus(-7)
    Keys.onDownPressed: moveFocus(7)
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
}
