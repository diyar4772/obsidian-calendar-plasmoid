/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "../code/calendar.js" as Calendar
import "../code/dates.js" as Dates

// One month: six rows of seven days, with an optional week-number column.
Item {
    id: page

    property VaultScanner scanner
    property var today
    property string variant: "native"
    property var locale
    property bool showWeekNumbers: false
    property bool isoWeekNumbers: false
    property int year
    property int month
    // Only the page on screen takes keyboard focus.
    property bool active: false

    signal dayActivated(var date)
    signal weekActivated(var weekStart)

    readonly property int columns: 7 + (showWeekNumbers ? 1 : 0)
    readonly property real spacing: variant === "journal" ? Math.round(Kirigami.Units.smallSpacing / 2) : 0

    // Flat list of cells, row by row: an optional week cell, then seven days.
    readonly property var cells: {
        if (!locale || year === 0) {
            return [];
        }
        const revision = scanner.revision; // re-evaluate when the vault changes
        const weeks = Calendar.monthGrid(year, month, locale, { fixedRows: true, iso: isoWeekNumbers });
        const sizeDots = scanner.dotSource === "size" ? scanner.monthSizeDots(year, month) : null;
        const hasWeekly = scanner.settings !== null && scanner.settings.weekly !== null;
        const result = [];
        for (let r = 0; r < weeks.length; r++) {
            if (showWeekNumbers) {
                result.push({
                    isWeek: true,
                    week: weeks[r].week,
                    start: weeks[r].start,
                    clickable: hasWeekly,
                    hasNote: scanner.hasWeeklyNote(weeks[r].start),
                    path: hasWeekly ? scanner.weeklyPath(weeks[r].start) : ""
                });
            }
            for (let i = 0; i < 7; i++) {
                const date = weeks[r].days[i];
                const hasNote = scanner.hasNote(date);
                result.push({
                    isWeek: false,
                    date: date,
                    inMonth: date.m === month,
                    isToday: Dates.equals(date, today),
                    hasNote: hasNote,
                    dots: hasNote ? scanner.dotsFor(date, sizeDots) : 0,
                    words: hasNote ? scanner.wordsFor(date) : -1,
                    path: scanner.settings ? scanner.dailyPath(date) : ""
                });
            }
        }
        return result;
    }

    function focusCell(index) {
        const loader = repeater.itemAt(Math.max(0, Math.min(cells.length - 1, index))) as Loader;
        if (loader && loader.item) {
            (loader.item as Item).forceActiveFocus(Qt.TabFocusReason);
        }
    }

    function focusToday() {
        for (let i = 0; i < cells.length; i++) {
            if (!cells[i].isWeek && cells[i].isToday) {
                focusCell(i);
                return;
            }
        }
        focusCell(showWeekNumbers ? 1 : 0);
    }

    // Moves focus from cell `index` by `step` cells, skipping week cells.
    function moveFocus(index, step) {
        let target = index + step;
        if (target >= 0 && target < cells.length && cells[target].isWeek) {
            target += step > 0 ? 1 : -1;
        }
        if (target >= 0 && target < cells.length) {
            focusCell(target);
        }
    }

    GridLayout {
        anchors.fill: parent
        columns: page.columns
        rowSpacing: page.spacing
        columnSpacing: page.spacing

        Repeater {
            id: repeater
            model: page.cells

            delegate: Loader {
                id: cellLoader

                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: page.width / page.columns
                Layout.preferredHeight: page.height / 6

                sourceComponent: modelData.isWeek
                    ? weekCell
                    : (page.variant === "journal" ? journalDay : nativeDay)

                Component {
                    id: nativeDay
                    DayCellNative {
                        cellData: cellLoader.modelData
                        onClicked: page.dayActivated(cellLoader.modelData.date)
                        onMoveFocus: step => page.moveFocus(cellLoader.index, step)
                        activeFocusOnTab: page.active && cellLoader.modelData.isToday
                    }
                }
                Component {
                    id: journalDay
                    DayCellJournal {
                        cellData: cellLoader.modelData
                        onClicked: page.dayActivated(cellLoader.modelData.date)
                        onMoveFocus: step => page.moveFocus(cellLoader.index, step)
                        activeFocusOnTab: page.active && cellLoader.modelData.isToday
                    }
                }
                Component {
                    id: weekCell
                    WeekCell {
                        cellData: cellLoader.modelData
                        variant: page.variant
                        onClicked: page.weekActivated(cellLoader.modelData.start)
                    }
                }
            }
        }
    }
}
