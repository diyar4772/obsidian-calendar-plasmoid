// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const D = load("dates.js");
const S = load("stats.js");

const d = (s) => { const [y, m, dd] = s.split("-").map(Number); return D.make(y, m, dd); };
const having = (...keys) => { const set = new Set(keys); return (date) => set.has(D.key(date)); };

test("dotsForWords() follows the Calendar plugin", () => {
    assert.equal(S.dotsForWords(0, 250), 1); // an existing note always gets a dot
    assert.equal(S.dotsForWords(249, 250), 1);
    assert.equal(S.dotsForWords(500, 250), 2);
    assert.equal(S.dotsForWords(1249, 250), 4);
    assert.equal(S.dotsForWords(99999, 250), 5);
    assert.equal(S.dotsForWords(300, 100), 3);
    assert.equal(S.dotsForWords(1000, 0), 0);
    assert.equal(S.dotsForWords(1000, -5), 0);
    assert.equal(S.dotsForWords(1000, NaN), 0);
});

test("dotsForSizes() spreads sizes evenly over 1-5 by rank", () => {
    assert.deepEqual(S.dotsForSizes([]), []);
    assert.deepEqual(S.dotsForSizes([0, 0]), [1, 1]);
    assert.deepEqual(S.dotsForSizes([500]), [1]);
    assert.deepEqual(S.dotsForSizes([1000, 5000]), [1, 5]);
    assert.deepEqual(S.dotsForSizes([3000, 1000, 2000, 5000, 4000]), [3, 1, 2, 5, 4]);
    assert.deepEqual(S.dotsForSizes([2000, 2000, 9000, 1000]), [3, 3, 5, 1]);
    // Similar sizes (the old log scale put these all at 4-5 dots)
    const dots = S.dotsForSizes([1200, 2500, 4100, 6800, 9900, 11000]);
    assert.deepEqual(dots, [1, 2, 3, 3, 4, 5]);
});

test("streak() counts back from today", () => {
    const has = having("2024-03-07", "2024-03-08", "2024-03-09", "2024-03-05");
    assert.deepEqual(S.streak(has, d("2024-03-09")), { length: 3, includesToday: true });
    // No note today yet: yesterday's streak is still alive
    assert.deepEqual(S.streak(has, d("2024-03-10")), { length: 3, includesToday: false });
    assert.deepEqual(S.streak(has, d("2024-03-11")), { length: 0, includesToday: false });
});

test("streak() crosses month and year boundaries", () => {
    const has = having("2023-12-30", "2023-12-31", "2024-01-01", "2024-01-02");
    assert.deepEqual(S.streak(has, d("2024-01-02")), { length: 4, includesToday: true });
    const leap = having("2024-02-28", "2024-02-29", "2024-03-01");
    assert.equal(S.streak(leap, d("2024-03-01")).length, 3);
});

test("streak() stops at the limit", () => {
    assert.equal(S.streak(() => true, d("2024-03-09"), 10).length, 10);
});

test("countInMonth()", () => {
    const has = having("2024-02-01", "2024-02-29", "2024-03-01");
    assert.equal(S.countInMonth(has, 2024, 2), 2);
    assert.equal(S.countInMonth(has, 2024, 3), 1);
    assert.equal(S.countInMonth(has, 2024, 4), 0);
});
