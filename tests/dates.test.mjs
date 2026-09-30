import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const D = load("dates.js");
const d = (s) => { const [y, m, dd] = s.split("-").map(Number); return D.make(y, m, dd); };

test("day numbers match Date.UTC over four centuries", () => {
    for (let n = -150000; n <= 150000; n += 7) {
        const date = D.fromDayNumber(n);
        const js = new Date(n * 86400000);
        assert.deepEqual(date, D.make(js.getUTCFullYear(), js.getUTCMonth() + 1, js.getUTCDate()));
        assert.equal(D.toDayNumber(date), n);
        assert.equal(D.dayOfWeek(date), js.getUTCDay());
    }
});

test("leap years and month lengths", () => {
    assert.equal(D.daysInMonth(2024, 2), 29);
    assert.equal(D.daysInMonth(2023, 2), 28);
    assert.equal(D.daysInMonth(1900, 2), 28);
    assert.equal(D.daysInMonth(2000, 2), 29);
    assert.equal(D.daysInMonth(2024, 4), 30);
    assert.equal(D.daysInMonth(2024, 12), 31);
    assert.equal(D.daysInYear(2024), 366);
});

test("addDays crosses month and year boundaries", () => {
    assert.deepEqual(D.addDays(d("2024-12-31"), 1), d("2025-01-01"));
    assert.deepEqual(D.addDays(d("2025-01-01"), -1), d("2024-12-31"));
    assert.deepEqual(D.addDays(d("2024-02-28"), 1), d("2024-02-29"));
    assert.deepEqual(D.addDays(d("2023-02-28"), 1), d("2023-03-01"));
    assert.deepEqual(D.addDays(d("2024-01-01"), 366), d("2025-01-01"));
});

test("addMonths clamps the day", () => {
    assert.deepEqual(D.addMonths(d("2024-01-31"), 1), d("2024-02-29"));
    assert.deepEqual(D.addMonths(d("2023-01-31"), 1), d("2023-02-28"));
    assert.deepEqual(D.addMonths(d("2024-12-15"), 1), d("2025-01-15"));
    assert.deepEqual(D.addMonths(d("2024-01-15"), -1), d("2023-12-15"));
    assert.deepEqual(D.addMonths(d("2024-03-31"), -13), d("2023-02-28"));
    assert.deepEqual(D.addMonths(d("2024-05-10"), 24), d("2026-05-10"));
});

test("dayOfYear, startOfWeek, compare, key", () => {
    assert.equal(D.dayOfYear(d("2024-01-01")), 1);
    assert.equal(D.dayOfYear(d("2024-12-31")), 366);
    assert.deepEqual(D.startOfWeek(d("2024-03-09"), 1), d("2024-03-04")); // Saturday -> Monday
    assert.deepEqual(D.startOfWeek(d("2024-03-09"), 0), d("2024-03-03")); // -> Sunday
    assert.deepEqual(D.startOfWeek(d("2024-03-09"), 6), d("2024-03-09")); // already Saturday
    assert.deepEqual(D.startOfWeek(d("2025-01-01"), 1), d("2024-12-30")); // across the year
    assert.ok(D.compare(d("2024-01-01"), d("2023-12-31")) > 0);
    assert.ok(D.equals(d("2024-01-01"), D.make(2024, 1, 1)));
    assert.equal(D.key(D.make(987, 3, 9)), "0987-03-09");
});

test("isValid rejects impossible dates", () => {
    assert.ok(D.isValid(d("2024-02-29")));
    assert.ok(!D.isValid(d("2023-02-29")));
    assert.ok(!D.isValid(D.make(2024, 13, 1)));
    assert.ok(!D.isValid(D.make(2024, 1, 0)));
    assert.ok(!D.isValid(null));
});

test("JS Date conversion is safe across DST transitions", () => {
    const saved = process.env.TZ;
    try {
        // São Paulo used to skip local midnight when DST started (2018-11-04),
        // so code that built dates at 00:00 got the previous day back.
        for (const tz of ["America/Sao_Paulo", "Europe/Berlin", "America/New_York", "Australia/Lord_Howe"]) {
            process.env.TZ = tz;
            for (let date = d("2018-01-01"); date.y < 2019; date = D.addDays(date, 1)) {
                assert.deepEqual(D.fromJsDate(D.toJsDate(date)), date, `${tz} ${D.key(date)}`);
            }
        }
    } finally {
        if (saved === undefined) delete process.env.TZ; else process.env.TZ = saved;
    }
});
