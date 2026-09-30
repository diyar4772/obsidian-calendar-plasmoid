// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const D = load("dates.js");
const F = load("dateformat.js");
const L = load("locales.js");

const d = (s) => { const [y, m, dd] = s.split("-").map(Number); return D.make(y, m, dd); };
const LOCALES = {
    en: L.EN,
    tr: L.TR,
    // en with the Calendar plugin's week start set to Monday (doy is kept).
    "en-mon": L.withWeekStart(L.EN, 1)
};

// Expected values were generated with moment.js 2.x (moment.utc(date).locale(l).format(f)).
const MOMENT_CASES = [
    // Week numbering around New Year
    ["en", "2024-12-30", "gggg-[W]ww", "2025-W01"],
    ["en", "2024-12-30", "GGGG-[W]WW", "2025-W01"],
    ["tr", "2024-12-30", "gggg-[W]ww", "2025-W01"],
    ["en", "2021-01-01", "GGGG-[W]WW", "2020-W53"],
    ["en", "2021-01-01", "gggg-[W]ww", "2021-W01"],
    ["tr", "2021-01-01", "gggg-[W]ww", "2021-W01"],
    ["en", "2020-12-31", "GGGG-[W]WW", "2020-W53"],
    ["en", "2026-01-01", "GGGG-[W]WW", "2026-W01"],
    ["en", "2027-01-01", "GGGG-[W]WW", "2026-W53"],
    ["en", "2015-12-31", "GGGG-[W]WW", "2015-W53"],
    ["en", "2016-01-03", "GGGG-[W]WW", "2015-W53"],
    ["en-mon", "2024-12-30", "gggg-[W]ww", "2025-W01"],
    ["en-mon", "2023-01-01", "gggg-[W]ww", "2022-W53"],
    ["en", "2023-01-01", "gggg-[W]ww", "2023-W01"],
    ["tr", "2023-01-01", "gggg-[W]ww", "2023-W01"],
    ["en", "2024-03-01", "[Week] w [of] gggg", "Week 9 of 2024"],
    // Names and ordinals
    ["en", "2024-02-29", "Do MMMM YYYY, dddd", "29th February 2024, Thursday"],
    ["tr", "2024-02-29", "Do MMMM YYYY, dddd", "29 Şubat 2024, Perşembe"],
    ["en", "2024-01-11", "Do", "11th"],
    ["en", "2024-01-22", "Do", "22nd"],
    ["en", "2024-01-23", "Do", "23rd"],
    ["tr", "2024-08-05", "D MMM YYYY ddd", "5 Ağu 2024 Pzt"],
    // Numbers
    ["en", "2009-06-07", "YY.M.D", "09.6.7"],
    ["en", "2024-12-31", "DDD DDDD Q", "366 366 4"],
    ["en", "2024-03-10", "d e E", "0 0 7"],
    ["tr", "2024-03-10", "d e E", "0 6 7"],
    // Escaped text
    ["en", "2024-03-09", "YYYY [Daily] DD\\M", "2024 Daily 09M"],
    ["en", "2024-03-09", "[a]b]YYYY", "a]b2024"],
    ["en", "2024-03-09", "[YYYY-MM-DD]", "YYYY-MM-DD"],
    // Nested folder formats
    ["en", "2024-03-09", "YYYY/MM/YYYY-MM-DD", "2024/03/2024-03-09"],
    ["en", "2024-03-09", "MMMM/YYYY-MM-DD dddd", "March/2024-03-09 Saturday"],
    ["tr", "2024-03-09", "YYYY/MM MMMM/DD dddd", "2024/03 Mart/09 Cumartesi"]
];

test("matches moment.js output", () => {
    for (const [locale, date, fmt, expected] of MOMENT_CASES) {
        assert.equal(F.format(d(date), fmt, LOCALES[locale]), expected, `${locale} ${date} ${fmt}`);
    }
});

test("ISO weeks: every year has 52 or 53, and 53-week years are correct", () => {
    const longYears = [];
    for (let y = 2000; y <= 2040; y++) {
        const w = F.isoWeek(d(`${y}-12-28`)); // Dec 28 is always in the last ISO week
        assert.ok(w.week === 52 || w.week === 53);
        assert.equal(w.year, y);
        if (w.week === 53) longYears.push(y);
    }
    assert.deepEqual(longYears, [2004, 2009, 2015, 2020, 2026, 2032, 2037]);
});

test("week numbers never skip or repeat across a year boundary", () => {
    for (const locale of Object.values(LOCALES)) {
        let prev = F.localeWeek(d("2019-12-01"), locale);
        for (let date = d("2019-12-02"); date.y < 2031; date = D.addDays(date, 1)) {
            const cur = F.localeWeek(date, locale);
            if (D.dayOfWeek(date) === locale.dow) {
                const rolled = cur.year === prev.year + 1 && cur.week === 1;
                assert.ok(rolled || (cur.year === prev.year && cur.week === prev.week + 1),
                    `${locale.name} ${D.key(date)}: ${prev.year}-${prev.week} -> ${cur.year}-${cur.week}`);
            } else {
                assert.deepEqual(cur, prev);
            }
            prev = cur;
        }
    }
});

test("compile() reports unsupported tokens but not escaped ones", () => {
    assert.deepEqual(F.compile("YYYY-MM-DD").unsupported, []);
    assert.deepEqual(F.compile("YYYY-MM-DD HH:mm").unsupported, ["HH", "mm"]);
    assert.deepEqual(F.compile("YYYY-MM-DD [HH:mm]").unsupported, []);
    assert.deepEqual(F.compile("\\H YYYY").unsupported, []);
    assert.deepEqual(F.compile("Mo").unsupported, ["Mo"]);
    // Letters that aren't moment tokens are plain text, as in moment.
    assert.deepEqual(F.compile("Tqtn").unsupported, []);
    assert.equal(F.format(d("2024-03-09"), "Tqtn", L.EN), "Tqtn");
});

test("compile() merges adjacent literals", () => {
    assert.deepEqual(F.compile("[Daily] - YYYY").parts, [{ literal: "Daily - " }, { token: "YYYY" }]);
});

test("non-ASCII literal text passes through unchanged", () => {
    assert.equal(F.format(d("2024-03-09"), "[Günlük]/YYYY-MM-DD [Özet]", L.TR), "Günlük/2024-03-09 Özet");
    assert.equal(F.format(d("2024-03-09"), "YYYY年M月D日", L.EN), "2024年3月9日");
});

test("years outside 1000-9999", () => {
    assert.equal(F.format(D.make(987, 1, 5), "YYYY YY", L.EN), "0987 87");
    assert.equal(F.format(D.make(10000, 1, 5), "YYYY", L.EN), "+10000");
});
