// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const L = load("locales.js");

test("bundled() maps locale names to bundled data", () => {
    assert.equal(L.bundled("en"), L.EN);
    assert.equal(L.bundled("en-GB"), L.EN);
    assert.equal(L.bundled("tr_TR"), L.TR);
    assert.equal(L.bundled("TR"), L.TR);
    assert.equal(L.bundled("de"), null);
    assert.equal(L.bundled(""), null);
    assert.equal(L.bundled(undefined), null);
});

test("defaultDoy() matches common moment locales", () => {
    assert.equal(L.defaultDoy(0), 6); // en-us
    assert.equal(L.defaultDoy(1), 4); // de, fr, en-gb (ISO-like)
    assert.equal(L.defaultDoy(6), 12); // ar
});

test("make() fills gaps from English and derives doy", () => {
    const de = L.make({ name: "de", months: ["Januar"], dow: 1 });
    assert.equal(de.months[0], "Januar");
    assert.equal(de.weekdays[0], "Sunday");
    assert.equal(de.doy, 4);
    assert.equal(de.ordinal(3), "3");
    assert.equal(L.make({}).dow, 0);
});

test("withWeekStart() keeps doy, like moment.updateLocale", () => {
    const mon = L.withWeekStart(L.EN, 1);
    assert.equal(mon.dow, 1);
    assert.equal(mon.doy, 6);
    assert.equal(mon.months, L.EN.months);
    assert.equal(L.withWeekStart(L.EN, 0), L.EN);
    assert.equal(L.withWeekStart(L.EN, null), L.EN);
});

test("forSystem() uses the desktop language when bundled, English otherwise", () => {
    assert.equal(L.forSystem("tr_TR", 1), L.TR);
    assert.equal(L.forSystem("en_US", 0), L.EN);
    assert.equal(L.forSystem("tr_TR"), L.TR);
    // en_GB: English names, Monday start, ISO-like first week (moment's en-gb)
    const gb = L.forSystem("en_GB", 1);
    assert.equal(gb.months[0], "January");
    assert.deepEqual([gb.dow, gb.doy], [1, 4]);
    assert.equal(gb.ordinal(2), "2nd");
    // Unsupported language: English names, desktop week start
    const de = L.forSystem("de_DE", 1);
    assert.equal(de.name, "en");
    assert.equal(de.weekdays[1], "Monday");
    assert.equal(de.dow, 1);
    assert.equal(L.forSystem("ar_SA", 6).doy, 12);
    assert.equal(L.forSystem("C", 7).dow, 0);
});
