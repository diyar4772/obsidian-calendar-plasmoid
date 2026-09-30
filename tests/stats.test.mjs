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

test("dotsForSizes() spreads sizes over 1-5 on a log scale", () => {
    assert.deepEqual(S.dotsForSizes([]), []);
    assert.deepEqual(S.dotsForSizes([0, 0]), [1, 1]);
    const dots = S.dotsForSizes([10, 100, 1000, 10000]);
    assert.equal(dots[3], 5);
    assert.ok(dots.every((n, i) => i === 0 || n >= dots[i - 1]), "monotonic");
    assert.ok(dots.every((n) => n >= 1 && n <= 5));
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
