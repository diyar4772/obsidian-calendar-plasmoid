// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const C = load("calendar.js");
const D = load("dates.js");
const L = load("locales.js");

test("weekdayOrder()", () => {
    assert.deepEqual(C.weekdayOrder(0), [0, 1, 2, 3, 4, 5, 6]);
    assert.deepEqual(C.weekdayOrder(1), [1, 2, 3, 4, 5, 6, 0]);
    assert.deepEqual(C.weekdayOrder(6), [6, 0, 1, 2, 3, 4, 5]);
});

test("rows start on the week start and cover the month", () => {
    for (const locale of [L.EN, L.TR, L.withWeekStart(L.EN, 6), L.withWeekStart(L.TR, 3)]) {
        for (let y = 2023; y <= 2026; y++) {
            for (let m = 1; m <= 12; m++) {
                const weeks = C.monthGrid(y, m, locale);
                const days = weeks.flatMap((w) => w.days);
                assert.ok(weeks.every((w) => D.dayOfWeek(w.start) === locale.dow));
                assert.ok(D.compare(days[0], D.make(y, m, 1)) <= 0);
                assert.ok(D.compare(days[days.length - 1], D.make(y, m, D.daysInMonth(y, m))) >= 0);
                assert.ok(weeks.length >= 4 && weeks.length <= 6);
                // The first and last rows both contain days of the month
                assert.ok(weeks[0].days.some((x) => x.m === m));
                assert.ok(weeks[weeks.length - 1].days.some((x) => x.m === m));
                assert.equal(C.monthGrid(y, m, locale, { fixedRows: true }).length, 6);
            }
        }
    }
});

test("February 2026 fits in four rows when starting on Sunday", () => {
    assert.equal(C.monthGrid(2026, 2, L.EN).length, 4);
    assert.equal(C.monthGrid(2026, 2, L.TR).length, 5);
});

test("week numbers: locale weeks like the Calendar plugin, or ISO", () => {
    // December 2024, Monday start (tr): 2024-12-30 is locale week 1 of 2025
    const tr = C.monthGrid(2024, 12, L.TR);
    assert.deepEqual(tr.map((w) => w.week), [48, 49, 50, 51, 52, 1]);
    // January 2021, Sunday start (en): Jan 1st is in locale week 1, ISO week 53
    assert.deepEqual(C.monthGrid(2021, 1, L.EN).map((w) => w.week), [1, 2, 3, 4, 5, 6]);
    assert.deepEqual(C.monthGrid(2021, 1, L.EN, { iso: true }).map((w) => w.week), [53, 1, 2, 3, 4, 5]);
    // ISO with a Monday start is simply the ISO week of every day in the row
    for (const w of C.monthGrid(2026, 1, L.TR, { iso: true })) {
        assert.ok(w.days.every((day) => load("dateformat.js").isoWeek(day).week === w.week));
    }
});
