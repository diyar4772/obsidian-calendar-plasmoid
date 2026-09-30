.pragma library
.import "dates.js" as Dates
.import "dateformat.js" as DateFormat

// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Month grid layout.

// Weekday numbers (0 = Sunday) in column order for a week starting on `weekStart`.
function weekdayOrder(weekStart) {
    const order = [];
    for (let i = 0; i < 7; i++) {
        order.push((weekStart + i) % 7);
    }
    return order;
}

// Weeks to show for month (y, m): an array of rows, each
//   { start: first day of the row, days: [7 dates], week: number }
// Rows always cover the whole month; with `fixedRows` there are always six
// so the widget doesn't change height between months.
//
// `week` is the locale week number of the row's first day, like the Calendar
// plugin (locale = locales.js data with dow == weekStart). With `iso` it is
// the ISO week of the row's Thursday instead, which covers most of the row
// whatever day it starts on.
function monthGrid(y, m, locale, options) {
    const opts = options || {};
    const first = Dates.make(y, m, 1);
    const start = Dates.startOfWeek(first, locale.dow);
    const last = Dates.make(y, m, Dates.daysInMonth(y, m));
    const needed = Math.floor((Dates.toDayNumber(last) - Dates.toDayNumber(start)) / 7) + 1;
    const rows = opts.fixedRows ? 6 : needed;

    const weeks = [];
    for (let r = 0; r < rows; r++) {
        const rowStart = Dates.addDays(start, r * 7);
        const days = [];
        for (let i = 0; i < 7; i++) {
            days.push(Dates.addDays(rowStart, i));
        }
        const week = opts.iso
            ? DateFormat.isoWeek(Dates.addDays(rowStart, (4 - locale.dow + 7) % 7)).week
            : DateFormat.localeWeek(rowStart, locale).week;
        weeks.push({ start: rowStart, days: days, week: week });
    }
    return weeks;
}

// Whether a weekly-note format numbers weeks the ISO way (GGGG/WW) rather
// than by locale weeks (gggg/ww).
function usesIsoWeeks(format) {
    const parts = DateFormat.compile(format).parts;
    const has = function (tokens) {
        return parts.some(function (p) { return p.token !== undefined && tokens.indexOf(p.token) !== -1; });
    };
    return has(["W", "WW", "GG", "GGGG"]) && !has(["w", "ww", "gg", "gggg"]);
}

// The date to format a row's weekly note with. Locale formats use the row's
// first day, like the Calendar plugin. ISO formats use the row's Thursday,
// the day that decides its ISO week, so a Sunday-first row labeled week 40
// opens W40 rather than W39.
function weekNoteDate(rowStart, weekStart, format) {
    return usesIsoWeeks(format) ? Dates.addDays(rowStart, (4 - weekStart + 7) % 7) : rowStart;
}
