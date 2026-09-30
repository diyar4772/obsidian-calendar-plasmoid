.pragma library
.import "dates.js" as Dates
.import "dateformat.js" as DateFormat
.import "stats.js" as Stats

// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Year overview: a GitHub-style grid of the year's days, totals per month
// and per ISO week, and streaks. Days are passed in as `entries`, one per
// day of the year in order: { date, hasNote, words, size } where `words` is
// -1 while it hasn't been counted.

// Weeks of year `y` as columns of seven days, the first row being
// `weekStart` (0 = Sunday). Returns { columns, cells } where `cells` is
// column-major (seven per column) and each cell is
//   { date, column, row, inYear }
// Days of the neighboring years that fill the first and last column have
// `inYear` false. A year needs 53 columns, or 54 when a leap year starts on
// the last day of the week.
function yearGrid(y, weekStart) {
    const first = Dates.make(y, 1, 1);
    const start = Dates.startOfWeek(first, weekStart);
    const last = Dates.make(y, 12, 31);
    const columns = Math.floor((Dates.toDayNumber(last) - Dates.toDayNumber(start)) / 7) + 1;
    const cells = [];
    for (let c = 0; c < columns; c++) {
        for (let r = 0; r < 7; r++) {
            const date = Dates.addDays(start, c * 7 + r);
            cells.push({ date: date, column: c, row: r, inYear: date.y === y });
        }
    }
    return { columns: columns, cells: cells };
}

// Column of the grid (see yearGrid) where each month's label goes: the first
// column that starts inside the month, as GitHub does, so a label never sits
// over the previous month's days. Returns [{ m, column }] for m = 1-12.
function monthColumns(y, weekStart) {
    const start = Dates.startOfWeek(Dates.make(y, 1, 1), weekStart);
    const result = [];
    for (let m = 1; m <= 12; m++) {
        const offset = Dates.toDayNumber(Dates.make(y, m, 1)) - Dates.toDayNumber(start);
        result.push({ m: m, column: Math.ceil(offset / 7) });
    }
    return result;
}

// Every day of year `y` in order.
function daysOfYear(y) {
    const days = [];
    const first = Dates.make(y, 1, 1);
    const count = Dates.daysInYear(y);
    for (let i = 0; i < count; i++) {
        days.push(Dates.addDays(first, i));
    }
    return days;
}

// Heat level 0-5 for each entry (0 = no note), following the widget's
// "dots" setting like the month view: "words" uses the Calendar plugin's
// words per dot, "size" ranks file sizes among the year's notes, "none"
// gives every note level 1. A note is always at least level 1, also while
// its words haven't been counted yet.
function levels(entries, source, wordsPerDot) {
    const result = entries.map(function () { return 0; });
    if (source === "size") {
        const indexes = [];
        const sizes = [];
        entries.forEach(function (e, i) {
            if (e.hasNote) {
                indexes.push(i);
                sizes.push(e.size || 0);
            }
        });
        const dots = Stats.dotsForSizes(sizes);
        for (let i = 0; i < indexes.length; i++) {
            result[indexes[i]] = dots[i];
        }
        return result;
    }
    entries.forEach(function (e, i) {
        if (!e.hasNote) {
            return;
        }
        if (source !== "words" || !(e.words >= 0)) {
            result[i] = 1;
            return;
        }
        result[i] = Math.max(1, Stats.dotsForWords(e.words, wordsPerDot));
    });
    return result;
}

// Notes and words per month: an array of 12 { m, notes, words }. Words
// not counted yet (-1) add nothing.
function monthTotals(entries) {
    const totals = [];
    for (let m = 1; m <= 12; m++) {
        totals.push({ m: m, notes: 0, words: 0 });
    }
    entries.forEach(function (e) {
        if (e.hasNote) {
            const t = totals[e.date.m - 1];
            t.notes++;
            t.words += e.words > 0 ? e.words : 0;
        }
    });
    return totals;
}

// Notes and words per ISO 8601 week of year `y`: an array of
// { week, start, notes, words } for weeks 1 to 52 or 53, `start` being the
// week's Monday. Days of the year that belong to a week of the previous or
// next ISO year (around New Year) aren't counted.
function weekTotals(y, entries) {
    const count = DateFormat.weeksInYear(y, 1, 4);
    // Monday of ISO week 1: the week that contains January 4th.
    const firstMonday = Dates.startOfWeek(Dates.make(y, 1, 4), 1);
    const totals = [];
    for (let w = 1; w <= count; w++) {
        totals.push({ week: w, start: Dates.addDays(firstMonday, (w - 1) * 7), notes: 0, words: 0 });
    }
    entries.forEach(function (e) {
        if (!e.hasNote) {
            return;
        }
        const iso = DateFormat.isoWeek(e.date);
        if (iso.year !== y) {
            return;
        }
        const t = totals[iso.week - 1];
        t.notes++;
        t.words += e.words > 0 ? e.words : 0;
    });
    return totals;
}

// Longest run of consecutive days with a note among `entries` (consecutive
// days in order). Returns { length, start, end }; start and end are null
// when there's no note.
function longestStreak(entries) {
    let best = { length: 0, start: null, end: null };
    let length = 0;
    let start = null;
    for (let i = 0; i < entries.length; i++) {
        if (!entries[i].hasNote) {
            length = 0;
            continue;
        }
        if (length === 0) {
            start = entries[i].date;
        }
        length++;
        if (length > best.length) {
            best = { length: length, start: start, end: entries[i].date };
        }
    }
    return best;
}

// Totals for the whole year: { notes, words, counted, longest } where
// `counted` is how many notes have a word count yet and `longest` the
// longestStreak() length.
function summary(entries) {
    let notes = 0;
    let words = 0;
    let counted = 0;
    entries.forEach(function (e) {
        if (e.hasNote) {
            notes++;
            if (e.words >= 0) {
                counted++;
                words += e.words;
            }
        }
    });
    return { notes: notes, words: words, counted: counted, longest: longestStreak(entries).length };
}

// The largest of `values`, at least 1, for scaling bars.
function scaleMax(values) {
    let max = 1;
    for (let i = 0; i < values.length; i++) {
        if (values[i] > max) {
            max = values[i];
        }
    }
    return max;
}
