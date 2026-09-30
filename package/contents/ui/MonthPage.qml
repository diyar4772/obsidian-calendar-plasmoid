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
    property var style: ({})
    property int year
    property int month
    // Only the page on screen takes keyboard focus.
    property bool active: false

    signal dayActivated(var date)
    signal weekActivated(var weekStart)
    // Keyboard navigation left the grid; `date` is the day to focus.
    signal focusBeyond(var date)

    readonly property int columns: 7 + (showWeekNumbers ? 1 : 0)
    readonly property real spacing: {
        if (variant === "journal") {
            return style.density === "compact" ? 1
                : style.density === "comfortable" ? Kirigami.Units.smallSpacing
                : Math.round(Kirigami.Units.smallSpacing / 2);
        }
        return style.density === "comfortable" ? Math.round(Kirigami.Units.smallSpacing / 2) : 0;
    }

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
                const noteDate = hasWeekly
                    ? Calendar.weekNoteDate(weeks[r].start, locale.dow, scanner.settings.weekly.format)
                    : weeks[r].start;
                result.push({
                    isWeek: true,
                    week: weeks[r].week,
                    start: noteDate,
                    clickable: hasWeekly,
                    hasNote: scanner.hasWeeklyNote(noteDate),
                    path: hasWeekly ? scanner.weeklyPath(noteDate) : ""
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

    // The day that had keyboard focus. Rescans and word counts rebuild the
    // cells, which destroys the focused one and leaves focus on the month
    // list; focus then goes back to that day. Focus the user moved elsewhere
    // is left alone.
    property var lastFocusedDate: null

    onCellsChanged: {
        if (!active || lastFocusedDate === null) {
            return;
        }
        const date = lastFocusedDate;
        Qt.callLater(() => {
            const focusItem = page.Window.activeFocusItem;
            if (focusItem === null || focusItem === page.ListView.view) {
                page.focusDate(date);
            }
        });
    }

    // The day that takes keyboard focus on Tab: today if it's in this
    // month, otherwise the 1st.
    readonly property bool containsToday: today !== undefined && today.y === year && today.m === month

    function isTabStop(cell) {
        return containsToday ? cell.isToday : (cell.inMonth && cell.date.d === 1);
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

    function focusDate(date) {
        for (let i = 0; i < cells.length; i++) {
            if (!cells[i].isWeek && Dates.equals(cells[i].date, date)) {
                focusCell(i);
                return;
            }
        }
    }

    // Moves focus from day cell `index` by `step` days (±1 or ±7), moving
    // to another month when the target isn't a day of this one.
    function moveFocus(index, step) {
        const date = Dates.addDays(cells[index].date, step);
        if (date.y === year && date.m === month) {
            focusDate(date);
        } else {
            focusBeyond(date);
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
                        textScale: page.style.textScale || 1
                        ownHighlight: page.style.ownHighlight === true
                        onClicked: page.dayActivated(cellLoader.modelData.date)
                        onMoveFocus: step => page.moveFocus(cellLoader.index, step)
                        activeFocusOnTab: page.active && page.isTabStop(cellLoader.modelData)
                        onActiveFocusChanged: if (activeFocus) page.lastFocusedDate = cellLoader.modelData.date
                    }
                }
                Component {
                    id: journalDay
                    DayCellJournal {
                        cellData: cellLoader.modelData
                        textScale: page.style.textScale || 1
                        shape: page.style.tileShape || "rounded"
                        onClicked: page.dayActivated(cellLoader.modelData.date)
                        onMoveFocus: step => page.moveFocus(cellLoader.index, step)
                        activeFocusOnTab: page.active && page.isTabStop(cellLoader.modelData)
                        onActiveFocusChanged: if (activeFocus) page.lastFocusedDate = cellLoader.modelData.date
                    }
                }
                Component {
                    id: weekCell
                    WeekCell {
                        cellData: cellLoader.modelData
                        textScale: page.style.textScale || 1
                        ownHighlight: page.style.ownHighlight === true
                        variant: page.variant
                        onClicked: page.weekActivated(cellLoader.modelData.start)
                    }
                }
            }
        }
    }
}
