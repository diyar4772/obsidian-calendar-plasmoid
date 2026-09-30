// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const C = load("obsidianconfig.js");
const L = load("locales.js");

const json = (value) => JSON.stringify(value);

// Periodic Notes 0.0.17 (the version in the community plugin list)
const PERIODIC_0 = json({
    showGettingStartedBanner: false,
    hasMigratedDailyNoteSettings: true,
    hasMigratedWeeklyNoteSettings: true,
    daily: { format: "YYYY/MM/YYYY-MM-DD", folder: " Journal/Daily ", template: "Templates/Daily", enabled: true },
    weekly: { format: "gggg-[W]ww", folder: "Journal/Weekly", template: "", enabled: true },
    monthly: { format: "", folder: "", template: "", enabled: false }
});

// Periodic Notes 1.0 beta
const PERIODIC_1 = json({
    activeCalendarSet: "work",
    calendarSets: [
        { id: "default", day: { enabled: true, format: "DD.MM.YYYY", folder: "Other" } },
        { id: "work", day: { enabled: true, format: "YYYY-MM-DD", folder: "Work/Daily", templatePath: "T.md" },
          week: { enabled: true, format: "GGGG-[W]WW", folder: "Work/Weekly" } }
    ]
});

const CALENDAR = json({
    shouldConfirmBeforeCreate: true,
    weekStart: "locale",
    wordsPerDot: 250,
    showWeeklyNote: true,
    weeklyNoteFormat: "",
    weeklyNoteTemplate: "",
    weeklyNoteFolder: "",
    localeOverride: "system-default"
});

const DAILY_NOTES = json({ folder: "70 - Journal/71 - Daily", format: "YYYY-MM-DD", template: "Templates/Daily" });

test("defaults when nothing is configured", () => {
    const det = C.detect({});
    assert.deepEqual(det.daily, { folder: "", format: "YYYY-MM-DD", template: "", source: "default" });
    assert.equal(det.weekly, null);
    assert.equal(det.weekStart, null);
    assert.equal(det.wordsPerDot, 250);
    assert.equal(det.showWeekNumbers, false);
    assert.equal(det.dailyCoreEnabled, true);
    assert.deepEqual(det.errors, []);

    const res = C.resolve(det, {}, L.TR);
    assert.deepEqual(res.daily, { folder: "", format: "YYYY-MM-DD", template: "" });
    assert.equal(res.weekStart, 1); // Turkish desktop: Monday
    assert.equal(res.locale.name, "tr");
    assert.equal(C.resolve(det, {}, L.EN).weekStart, 0);
    assert.equal(C.resolve(det, {}, null).locale, L.EN);
});

test("core Daily notes settings", () => {
    const det = C.detect({ dailyNotes: DAILY_NOTES, calendar: CALENDAR });
    assert.deepEqual(det.daily, { folder: "70 - Journal/71 - Daily", format: "YYYY-MM-DD",
                                  template: "Templates/Daily", source: "daily-notes" });
    assert.equal(det.showWeekNumbers, true);
    // showWeeklyNote alone doesn't make a weekly-note config
    assert.equal(det.weekly, null);
    const res = C.resolve(det, {}, L.EN);
    assert.equal(res.daily.folder, "70 - Journal/71 - Daily");
    assert.equal(res.sources.weekStart, "locale");
});

test("empty core format falls back to the default", () => {
    const det = C.detect({ dailyNotes: json({ folder: "Daily", format: "" }) });
    assert.equal(det.daily.format, "YYYY-MM-DD");
    assert.equal(det.daily.folder, "Daily");
});

test("Periodic Notes 0.x takes priority over core Daily notes", () => {
    const det = C.detect({ dailyNotes: DAILY_NOTES, periodicNotes: PERIODIC_0,
                           communityPlugins: json(["periodic-notes", "calendar"]) });
    assert.deepEqual(det.daily, { folder: " Journal/Daily ", format: "YYYY/MM/YYYY-MM-DD",
                                  template: "Templates/Daily", source: "periodic-notes" });
    assert.deepEqual(det.weekly, { folder: "Journal/Weekly", format: "gggg-[W]ww", source: "periodic-notes" });
    const res = C.resolve(det, {}, L.EN);
    assert.equal(res.daily.folder, "Journal/Daily");
    assert.deepEqual(res.weekly, { folder: "Journal/Weekly", format: "gggg-[W]ww" });
});

test("Periodic Notes 1.0 beta calendar sets", () => {
    const det = C.detect({ periodicNotes: PERIODIC_1 });
    assert.deepEqual(det.daily, { folder: "Work/Daily", format: "YYYY-MM-DD", template: "T.md", source: "periodic-notes" });
    assert.deepEqual(det.weekly, { folder: "Work/Weekly", format: "GGGG-[W]WW", source: "periodic-notes" });
    // Unknown active set: first set
    const first = C.detect({ periodicNotes: json({ activeCalendarSet: "gone", calendarSets: JSON.parse(PERIODIC_1).calendarSets }) });
    assert.equal(first.daily.folder, "Other");
});

test("disabled Periodic Notes plugin or daily periodicity is ignored", () => {
    const disabled = C.detect({ dailyNotes: DAILY_NOTES, periodicNotes: PERIODIC_0, communityPlugins: json(["calendar"]) });
    assert.equal(disabled.daily.source, "daily-notes");
    assert.equal(disabled.weekly, null);

    const p = JSON.parse(PERIODIC_0);
    p.daily.enabled = false;
    const dailyOff = C.detect({ dailyNotes: DAILY_NOTES, periodicNotes: json(p) });
    assert.equal(dailyOff.daily.source, "daily-notes");
    assert.equal(dailyOff.weekly.source, "periodic-notes");
});

test("Calendar plugin's own weekly-note settings are used without Periodic Notes", () => {
    const cal = JSON.parse(CALENDAR);
    cal.weeklyNoteFolder = "Weekly";
    const det = C.detect({ calendar: json(cal) });
    assert.deepEqual(det.weekly, { folder: "Weekly", format: "gggg-[W]ww", source: "calendar" });
});

test("Calendar plugin weekStart, wordsPerDot and localeOverride", () => {
    const cal = JSON.parse(CALENDAR);
    Object.assign(cal, { weekStart: "saturday", wordsPerDot: 100, localeOverride: "tr" });
    const det = C.detect({ calendar: json(cal) });
    assert.equal(det.weekStart, 6);
    assert.equal(det.wordsPerDot, 100);
    assert.equal(det.locale, "tr");
    const res = C.resolve(det, {}, L.EN);
    assert.equal(res.weekStart, 6);
    assert.equal(res.locale.name, "tr");
    assert.equal(res.locale.dow, 6);
    assert.equal(res.locale.doy, 7); // kept from tr, as moment.updateLocale does
    assert.deepEqual(res.sources, { daily: "default", weekly: null, weekStart: "calendar", locale: "calendar" });
});

test("Calendar plugin settings are ignored when the plugin is disabled", () => {
    const cal = JSON.parse(CALENDAR);
    cal.wordsPerDot = 10;
    const det = C.detect({ calendar: json(cal), communityPlugins: json(["periodic-notes"]) });
    assert.equal(det.wordsPerDot, 250);
    assert.equal(det.showWeekNumbers, false);
});

test("bad wordsPerDot values fall back to 250", () => {
    for (const v of ["100", null, "", Infinity]) {
        assert.equal(C.detect({ calendar: json({ wordsPerDot: v }) }).wordsPerDot, 250);
    }
    assert.equal(C.detect({ calendar: json({ wordsPerDot: 0 }) }).wordsPerDot, 0);
});

test("core-plugins.json in both formats", () => {
    assert.equal(C.detect({ corePlugins: json({ "daily-notes": false }) }).dailyCoreEnabled, false);
    assert.equal(C.detect({ corePlugins: json({ "daily-notes": true }) }).dailyCoreEnabled, true);
    assert.equal(C.detect({ corePlugins: json(["file-explorer"]) }).dailyCoreEnabled, false);
    assert.equal(C.detect({ corePlugins: json(["daily-notes"]) }).dailyCoreEnabled, true);
    const res = C.resolve(C.detect({ corePlugins: json({ "daily-notes": false }) }), {}, L.EN);
    assert.equal(res.dailyUriAvailable, false);
});

test("malformed JSON is reported and treated as missing", () => {
    const det = C.detect({ dailyNotes: '{"folder": "Daily", "format": ', calendar: CALENDAR });
    assert.equal(det.errors.length, 1);
    assert.equal(det.errors[0].code, "malformed-json");
    assert.equal(det.errors[0].file, "daily-notes.json");
    assert.ok(det.errors[0].detail.length > 0);
    assert.equal(det.daily.source, "default");
    assert.equal(det.showWeekNumbers, true); // other files still count
    assert.equal(C.resolve(det, {}, L.EN).errors.length, 1);
});

test("valid JSON of the wrong shape is reported", () => {
    const det = C.detect({ dailyNotes: "[1, 2]", communityPlugins: '{"a": 1}', periodicNotes: "null" });
    assert.deepEqual(det.errors.map((e) => [e.code, e.file]), [
        ["invalid-config", "daily-notes.json"],
        ["invalid-config", "community-plugins.json"]
    ]);
});

test("wrong value types inside config files are ignored", () => {
    const det = C.detect({ dailyNotes: json({ folder: 42, format: ["x"], template: null }) });
    assert.deepEqual(det.daily, { folder: "", format: "YYYY-MM-DD", template: "", source: "daily-notes" });
});

test("overrides win and are validated", () => {
    const det = C.detect({ dailyNotes: DAILY_NOTES, calendar: CALENDAR });
    const res = C.resolve(det, {
        dailyFolder: "Günlük/", dailyFormat: "DD.MM.YYYY", weeklyFormat: "GGGG-[W]WW",
        weekStart: 0, wordsPerDot: 50, showWeekNumbers: false, locale: "en"
    }, L.TR);
    assert.deepEqual(res.daily, { folder: "Günlük", format: "DD.MM.YYYY", template: "Templates/Daily" });
    assert.deepEqual(res.weekly, { folder: "", format: "GGGG-[W]WW" });
    assert.equal(res.weekStart, 0);
    assert.equal(res.wordsPerDot, 50);
    assert.equal(res.showWeekNumbers, false);
    assert.equal(res.locale.name, "en");
    assert.equal(res.locale.months[0], "January");
    assert.deepEqual(res.sources, { daily: "override", weekly: "override", weekStart: "override", locale: "override" });
    assert.deepEqual(res.errors, []);
});

test("an empty folder override means the vault root; empty format keeps the detected one", () => {
    const det = C.detect({ dailyNotes: DAILY_NOTES });
    const res = C.resolve(det, { dailyFolder: "", dailyFormat: "" }, L.EN);
    assert.equal(res.daily.folder, "");
    assert.equal(res.daily.format, "YYYY-MM-DD");
});

test("null overrides keep detected values", () => {
    const det = C.detect({ dailyNotes: DAILY_NOTES, calendar: CALENDAR });
    const res = C.resolve(det, { dailyFolder: null, weekStart: null, wordsPerDot: undefined, showWeekNumbers: null }, L.EN);
    assert.equal(res.daily.folder, "70 - Journal/71 - Daily");
    assert.equal(res.weekStart, 0);
    assert.equal(res.showWeekNumbers, true);
    assert.equal(res.sources.daily, "daily-notes");
});

test("folders and formats that leave the vault are rejected", () => {
    const det = C.detect({});
    const codes = (o) => C.resolve(det, o, L.EN).errors.map((e) => `${e.code}:${e.file}`);
    assert.deepEqual(codes({ dailyFolder: "../outside" }), ["invalid-folder:daily"]);
    assert.deepEqual(codes({ dailyFolder: "a/../../b" }), ["invalid-folder:daily"]);
    assert.deepEqual(codes({ dailyFormat: "[../]YYYY-MM-DD" }), ["invalid-format:daily"]);
    assert.deepEqual(codes({ dailyFormat: "YYYY/" }), ["invalid-format:daily"]);
    assert.deepEqual(codes({ dailyFormat: "[/etc/]YYYY" }), ["invalid-format:daily"]);
    assert.deepEqual(codes({ weeklyFolder: "..", weeklyFormat: "gggg-[W]ww" }), ["invalid-folder:weekly"]);
    // Unusable values are replaced, never used
    const res = C.resolve(det, { dailyFolder: "../x", dailyFormat: "[../]YYYY", weeklyFolder: "..", weeklyFormat: "gggg" }, L.EN);
    assert.deepEqual(res.daily, { folder: "", format: "YYYY-MM-DD", template: "" });
    assert.equal(res.weekly, null);
    assert.deepEqual(C.formatProblems("[../]YYYY"), ["invalid-format"]);
    assert.deepEqual(C.formatProblems("YYYY HH"), ["unsupported-token"]);
    assert.deepEqual(C.formatProblems("YYYY-MM-DD"), []);
    assert.deepEqual(codes({ dailyFolder: "./Daily/." }), []);
    assert.equal(C.resolve(det, { dailyFolder: "./Daily/." }, L.EN).daily.folder, "Daily");
});

test("unsupported tokens are reported", () => {
    const det = C.detect({ dailyNotes: json({ format: "YYYY-MM-DD HHmm" }) });
    const res = C.resolve(det, {}, L.EN);
    assert.deepEqual(res.errors, [{ code: "unsupported-token", file: "daily", detail: "HH, mm" }]);
});

test("unknown locale names fall back to English names without an error", () => {
    const det = C.detect({ calendar: json({ localeOverride: "de" }) });
    const res = C.resolve(det, {}, L.TR);
    assert.equal(res.locale.months[0], "January");
    assert.equal(res.locale.dow, 1); // week start still follows the desktop
    assert.equal(res.sources.locale, "fallback");
    assert.deepEqual(res.errors, []);
});

test("the language setting changes names but not the week", () => {
    const det = C.detect({});
    const tr = C.resolve(det, { locale: "tr" }, L.EN);
    assert.equal(tr.locale.months[0], "Ocak");
    assert.deepEqual([tr.weekStart, tr.locale.dow, tr.locale.doy], [0, 0, 6]);
    const en = C.resolve(det, { locale: "en" }, L.TR);
    assert.equal(en.locale.months[0], "January");
    assert.deepEqual([en.weekStart, en.locale.dow, en.locale.doy], [1, 1, 7]);
    // Unknown names fall back to English
    assert.equal(C.resolve(det, { locale: "xx" }, L.TR).locale.months[0], "January");
});

test("normalizeFolder()", () => {
    assert.equal(C.normalizeFolder(" /Journal//Daily/ "), "Journal/Daily");
    assert.equal(C.normalizeFolder("70 - Journal/71 - Daily"), "70 - Journal/71 - Daily");
    assert.equal(C.normalizeFolder("Günlük\\Notlar"), "Günlük/Notlar");
    assert.equal(C.normalizeFolder(""), "");
    assert.equal(C.normalizeFolder(null), "");
    assert.equal(C.normalizeFolder("a/../b"), null);
});

test("knownVaults() lists Obsidian's vaults, newest first", () => {
    const native = json({ vaults: {
        a1: { path: "/home/u/Notes", ts: 100, open: true },
        b2: { path: "/home/u/Masaüstü/Örnek Vault/", ts: 300 },
        c3: { path: "relative/ignored", ts: 999 },
        d4: { ts: 5 },
        e5: "junk"
    } });
    const flatpak = json({ vaults: { x: { path: "/home/u/Notes", ts: 400 }, y: { path: "/mnt/usb/Work" } } });
    assert.deepEqual(C.knownVaults([native, flatpak, "{broken", null, json([]), json({ vaults: [] })]), [
        { path: "/home/u/Notes", name: "Notes" },
        { path: "/home/u/Masaüstü/Örnek Vault", name: "Örnek Vault" },
        { path: "/mnt/usb/Work", name: "Work" }
    ]);
    assert.deepEqual(C.knownVaults([]), []);
    assert.ok(Array.isArray(C.OBSIDIAN_JSON));
});
