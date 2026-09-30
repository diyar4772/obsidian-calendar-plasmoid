// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { load } from "./qmljs.mjs";
import { catalogFor, generate, parsePo, pluralExpression } from "../scripts/po2js.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const T = load("translate.js");
const { CATALOGS } = load("catalogs.js");

test("catalogs.js is up to date with po/*.po", () => {
    const files = {};
    for (const f of readdirSync(join(ROOT, "po")).filter((f) => f.endsWith(".po"))) {
        files[basename(f, ".po")] = readFileSync(join(ROOT, "po", f), "utf8");
    }
    assert.equal(readFileSync(join(ROOT, "package/contents/code/catalogs.js"), "utf8"), generate(files),
        "run scripts/i18n.sh compile");
});

test("English shows the source strings with arguments and English plurals", () => {
    assert.equal(T.translate(CATALOGS, "en", "@info:tooltip", "No note"), "No note");
    assert.equal(T.translate(CATALOGS, "en", "@info week number", "Week %1", [36]), "Week 36");
    const p = (n) => T.translatePlural(CATALOGS, "en", "@info notes in the visible month",
        "%1 note this month", "%1 notes this month", n);
    assert.equal(p(0), "0 notes this month");
    assert.equal(p(1), "1 note this month");
    assert.equal(p(2), "2 notes this month");
});

test("Turkish uses the bundled catalog, with Turkish plurals", () => {
    assert.equal(T.translate(CATALOGS, "tr", "@action:button", "Next Month"), "Sonraki Ay");
    assert.equal(T.translate(CATALOGS, "tr", "@action:button reset calendar to today", "Today"), "Bugün");
    assert.equal(T.translatePlural(CATALOGS, "tr", "@info current streak of consecutive days",
        "%1-day streak", "%1-day streak", 3), "3 günlük seri");
    assert.equal(CATALOGS.tr.plural(0), 0);
    assert.equal(CATALOGS.tr.plural(1), 0);
    assert.equal(CATALOGS.tr.plural(2), 1);
});

test("missing translations fall back to English", () => {
    assert.equal(T.translate(CATALOGS, "tr", "@info", "Not in the catalog %1", ["x"]), "Not in the catalog x");
    assert.equal(T.translatePlural(CATALOGS, "tr", "@info", "%1 thing", "%1 things", 1), "1 thing");
    assert.equal(T.translatePlural(CATALOGS, "tr", "@info", "%1 thing", "%1 things", 4), "4 things");
});

test("substitute() works like KI18n placeholders", () => {
    assert.equal(T.substitute("%2, %1 words", [5, "a.md"]), "a.md, 5 words");
    assert.equal(T.substitute("%1 %2", ["only"]), "only %2");
    assert.equal(T.substitute("100% sure, %10", Array.from({ length: 10 }, (_, i) => i + 1)), "100% sure, 10");
    // Arguments are inserted as they are, never re-expanded.
    assert.equal(T.substitute("%1 and %2", ["%2", "b"]), "%2 and b");
});

test("normalize() accepts only languages the widget can show", () => {
    assert.equal(T.normalize("", CATALOGS), "");
    assert.equal(T.normalize("en", CATALOGS), "en");
    assert.equal(T.normalize("tr", CATALOGS), "tr");
    assert.equal(T.normalize("de", CATALOGS), "");
    assert.equal(T.normalize("constructor", CATALOGS), "");
    assert.equal(T.normalize(undefined, CATALOGS), "");
    for (const l of T.LANGUAGES) {
        assert.equal(T.normalize(l.code, CATALOGS), l.code);
    }
});

test("localeNames() keeps the desktop's region when the language matches", () => {
    assert.deepEqual(T.localeNames("", "tr_TR", "tr-TR"), { names: "tr-TR", formats: "tr_TR" });
    assert.deepEqual(T.localeNames("", "de_DE", undefined), { names: "de_DE", formats: "de_DE" });
    assert.deepEqual(T.localeNames("en", "tr_TR", "tr-TR"), { names: "en", formats: "en" });
    assert.deepEqual(T.localeNames("en", "en_GB", "en-GB"), { names: "en_GB", formats: "en_GB" });
    assert.deepEqual(T.localeNames("tr", "en_US", "en-US"), { names: "tr", formats: "tr" });
    assert.deepEqual(T.localeNames("tr", "tr_TR", "tr-TR"), { names: "tr_TR", formats: "tr_TR" });
});

test("po parser handles contexts, plurals, continuations, fuzzy and obsolete entries", () => {
    const po = [
        'msgid ""',
        'msgstr ""',
        '"Language: xx\\n"',
        '"Plural-Forms: nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 ? 1 : 2);\\n"',
        "",
        "#, kde-format",
        'msgctxt "@info"',
        'msgid ""',
        '"Long "',
        '"text with \\"quotes\\""',
        'msgstr "Lang \\"x\\"\\n"',
        "",
        "#, fuzzy",
        'msgctxt "@info"',
        'msgid "Fuzzy"',
        'msgstr "Flou"',
        "",
        'msgctxt "@info"',
        'msgid "Empty"',
        'msgstr ""',
        "",
        'msgctxt "@info"',
        'msgid "%1 file"',
        'msgid_plural "%1 files"',
        'msgstr[0] "%1 a"',
        'msgstr[1] "%1 b"',
        'msgstr[2] "%1 c"',
        "",
        '#~ msgid "Old"',
        '#~ msgstr "Alt"',
        ""
    ].join("\n");
    assert.equal(parsePo(po).length, 5);
    const catalog = catalogFor(po);
    assert.deepEqual(Object.keys(catalog.messages), ["@info\u0004Long text with \"quotes\"", "@info\u0004%1 file"]);
    assert.deepEqual(catalog.messages["@info\u0004Long text with \"quotes\""], ["Lang \"x\"\n"]);
    const plural = new Function("n", `return Number(${catalog.plural});`);
    assert.deepEqual([1, 2, 5, 22].map(plural), [0, 1, 2, 1]);
});

test("plural formulas that aren't plain arithmetic are refused", () => {
    assert.equal(pluralExpression("Plural-Forms: nplurals=2; plural=(n > 1);\n"), "(n > 1)");
    assert.throws(() => pluralExpression("Plural-Forms: nplurals=2; plural=alert(1);\n"));
});
