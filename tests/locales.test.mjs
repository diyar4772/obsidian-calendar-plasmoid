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
