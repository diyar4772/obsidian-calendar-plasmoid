// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const D = load("dates.js");
const Y = load("yearview.js");

const d = (s) => { const [y, m, dd] = s.split("-").map(Number); return D.make(y, m, dd); };

// One entry per day of year `y`; `notes` maps "YYYY-MM-DD" to words (or -1).
function entries(y, notes, sizes = {}) {
    return Y.daysOfYear(y).map((date) => {
        const key = D.key(date);
        return {
            date,
            hasNote: Object.hasOwn(notes, key),
            words: Object.hasOwn(notes, key) ? notes[key] : -1,
            size: sizes[key] ?? 0
        };
    });
}

test("yearGrid() covers the year in week columns", () => {
    // 2026 starts on a Thursday
    const sun = Y.yearGrid(2026, 0);
    assert.equal(sun.columns, 53);
    assert.equal(sun.cells.length, 53 * 7);
    assert.deepEqual(sun.cells[0], { date: d("2025-12-28"), column: 0, row: 0, inYear: false });
    assert.deepEqual(sun.cells[4], { date: d("2026-01-01"), column: 0, row: 4, inYear: true });
    assert.deepEqual(sun.cells[7], { date: d("2026-01-04"), column: 1, row: 0, inYear: true });
    assert.equal(sun.cells.filter((c) => c.inYear).length, 365);
    const last = sun.cells.filter((c) => c.inYear).at(-1);
    assert.deepEqual(last, { date: d("2026-12-31"), column: 52, row: 4, inYear: true });

    const mon = Y.yearGrid(2026, 1);
    assert.deepEqual(mon.cells[0].date, d("2025-12-29"));
    assert.equal(mon.cells[3].row, 3);
    assert.deepEqual(mon.cells[3].date, d("2026-01-01"));
});

test("yearGrid() needs 54 columns for a leap year starting on the last weekday", () => {
    // 2028 is a leap year starting on a Saturday
    assert.equal(Y.yearGrid(2028, 0).columns, 54);
    assert.equal(Y.yearGrid(2028, 1).columns, 53);
    assert.equal(Y.yearGrid(2028, 0).cells.filter((c) => c.inYear).length, 366);
});

test("monthColumns() puts labels on the first week starting in the month", () => {
    const cols = Y.monthColumns(2026, 0);
    assert.equal(cols.length, 12);
    assert.deepEqual(cols[0], { m: 1, column: 1 }); // Jan 1 is a Thursday
    assert.deepEqual(cols[1], { m: 2, column: 5 }); // Feb 1 is a Sunday
    assert.deepEqual(cols[2], { m: 3, column: 9 }); // Mar 1 is a Sunday too
    // A year starting on the first weekday labels January on column 0
    assert.equal(Y.monthColumns(2023, 0)[0].column, 0); // 2023-01-01 is a Sunday
    for (let i = 1; i < 12; i++) {
        assert.ok(cols[i].column > cols[i - 1].column);
    }
});

test("daysOfYear()", () => {
    assert.equal(Y.daysOfYear(2026).length, 365);
    assert.equal(Y.daysOfYear(2024).length, 366);
    assert.deepEqual(Y.daysOfYear(2024)[59], d("2024-02-29"));
});

test("levels() follows the dot source", () => {
    const e = [
        { hasNote: false, words: -1, size: 0 },
        { hasNote: true, words: 100, size: 900 },
        { hasNote: true, words: 800, size: 5000 },
        { hasNote: true, words: -1, size: 2000 },
        { hasNote: true, words: 5000, size: 9000 }
    ];
    assert.deepEqual(Y.levels(e, "words", 250), [0, 1, 3, 1, 5]);
    assert.deepEqual(Y.levels(e, "none", 250), [0, 1, 1, 1, 1]);
    assert.deepEqual(Y.levels(e, "size", 250), [0, 1, 4, 2, 5]);
    // Dots turned off: notes still show
    assert.deepEqual(Y.levels(e, "words", 0), [0, 1, 1, 1, 1]);
    assert.deepEqual(Y.levels([], "size", 250), []);
});

test("monthTotals() counts notes and counted words per month", () => {
    const t = Y.monthTotals(entries(2026, { "2026-01-01": 100, "2026-01-31": -1, "2026-03-15": 250, "2026-12-31": 7 }));
    assert.equal(t.length, 12);
    assert.deepEqual(t[0], { m: 1, notes: 2, words: 100 });
    assert.deepEqual(t[1], { m: 2, notes: 0, words: 0 });
    assert.deepEqual(t[2], { m: 3, notes: 1, words: 250 });
    assert.deepEqual(t[11], { m: 12, notes: 1, words: 7 });
});

test("weekTotals() groups by ISO week of the year", () => {
    // 2026 has 53 ISO weeks; week 1 starts on Monday 2025-12-29.
    const t = Y.weekTotals(2026, entries(2026, { "2026-01-01": 10, "2026-01-04": 5, "2026-01-05": 1, "2026-12-31": 3 }));
    assert.equal(t.length, 53);
    assert.deepEqual(t[0], { week: 1, start: d("2025-12-29"), notes: 2, words: 15 });
    assert.deepEqual(t[1], { week: 2, start: d("2026-01-05"), notes: 1, words: 1 });
    assert.deepEqual(t[52], { week: 53, start: d("2026-12-28"), notes: 1, words: 3 });

    // 2027 has 52; Jan 1-3 2027 belong to 2026-W53 and aren't counted.
    const n = Y.weekTotals(2027, entries(2027, { "2027-01-01": 10, "2027-01-04": 20 }));
    assert.equal(n.length, 52);
    assert.deepEqual(n[0], { week: 1, start: d("2027-01-04"), notes: 1, words: 20 });
    assert.equal(n.reduce((s, w) => s + w.notes, 0), 1);
});

test("longestStreak() finds the longest run", () => {
    const e = entries(2026, {
        "2026-01-30": 1, "2026-01-31": 1, "2026-02-01": 1, // 3, across months
        "2026-05-01": 1, "2026-05-02": 1,
        "2026-12-31": 1
    });
    assert.deepEqual(Y.longestStreak(e), { length: 3, start: d("2026-01-30"), end: d("2026-02-01") });
    assert.deepEqual(Y.longestStreak(entries(2026, {})), { length: 0, start: null, end: null });
    // The first of equally long runs wins
    assert.deepEqual(Y.longestStreak(entries(2026, { "2026-02-01": 1, "2026-03-01": 1 })).start, d("2026-02-01"));
});

test("summary()", () => {
    const s = Y.summary(entries(2026, { "2026-01-01": 100, "2026-01-02": -1, "2026-01-03": 0, "2026-06-01": 50 }));
    assert.deepEqual(s, { notes: 4, words: 150, counted: 3, longest: 3 });
    assert.deepEqual(Y.summary([]), { notes: 0, words: 0, counted: 0, longest: 0 });
});

test("scaleMax()", () => {
    assert.equal(Y.scaleMax([]), 1);
    assert.equal(Y.scaleMax([0, 0]), 1);
    assert.equal(Y.scaleMax([3, 9, 2]), 9);
});
