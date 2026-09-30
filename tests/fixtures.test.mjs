// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// End-to-end: generate the fixture vaults, then run the same pipeline as the
// widget (config command -> detect/resolve -> list -> format dates -> read).

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { load } from "./qmljs.mjs";
import * as WordCount from "../package/contents/code/wordcount.mjs";
import { makeFixtures, VAULTS } from "../scripts/make-fixtures.mjs";

const Dates = load("dates.js");
const DateFormat = load("dateformat.js");
const Locales = load("locales.js");
const Config = load("obsidianconfig.js");
const Paths = load("paths.js");
const Stats = load("stats.js");


// Friday; the last months cross a year boundary.
const TODAY = Dates.make(2025, 1, 3);

function sh(command) {
    const r = spawnSync("/bin/sh", ["-c", command], { encoding: "utf8" });
    return { status: r.status, stdout: r.stdout };
}

function scan(vaultPath, systemLocale = Locales.EN) {
    const config = sh(Paths.configCommand(vaultPath, Config.configFiles()));
    assert.equal(config.status, 0);
    const detected = Config.detect(Config.filesByKey(Paths.parseConfigOutput(config.stdout)));
    const res = Config.resolve(detected, {}, systemLocale);
    const folder = Paths.joinPath(vaultPath, res.daily.folder);
    const list = sh(Paths.listCommand(folder, Paths.searchDepth(res.daily.format)));
    const files = Paths.parseListOutput(list.stdout);
    const pathFor = (date) => Paths.notePath("", DateFormat.format(date, res.daily.format, res.locale));
    const hasNote = (date) => Object.prototype.hasOwnProperty.call(files, pathFor(date));
    return { res, folder, files, pathFor, hasNote };
}

let root;
let generated;

test.before(() => {
    root = mkdtempSync(join(tmpdir(), "obsidian-calendar-fixtures-"));
    generated = makeFixtures(root, TODAY);
});

test.after(() => rmSync(root, { recursive: true, force: true }));

test("Örnek Vault: core Daily notes, spaces and non-ASCII in the path", () => {
    const { res, folder, files, pathFor, hasNote } = scan(generated.example.path);
    assert.deepEqual(res.errors, []);
    assert.equal(res.daily.folder, "70 - Journal/71 - Daily");
    assert.equal(res.daily.template, "Templates/Daily");
    assert.equal(res.showWeekNumbers, true);
    assert.equal(res.weekly, null);
    assert.equal(res.wordsPerDot, 250);

    assert.ok(generated.example.days.length > 50);
    for (const date of generated.example.days) {
        assert.ok(hasNote(date), Dates.key(date));
    }
    assert.ok("Fikirler.md" in files); // listed, but never matches a date
    assert.equal(Object.keys(files).length, generated.example.days.length + 1);
    assert.deepEqual(Stats.streak(hasNote, TODAY), { length: 12, includesToday: true });

    // Word dots for December: every level from 1 to 5 appears
    const december = [];
    for (let d = 1; d <= 31; d++) {
        const date = Dates.make(2024, 12, d);
        if (hasNote(date)) december.push(pathFor(date));
    }
    const contents = Paths.parseReadOutput(sh(Paths.readCommand(folder, december)).stdout);
    const dots = december.map((p) => Stats.dotsForWords(WordCount.noteWords(contents[p]), res.wordsPerDot));
    assert.deepEqual([...new Set(dots)].sort(), [1, 2, 3, 4, 5]);

    assert.equal(Paths.vaultName(generated.example.path), "Örnek Vault");
    assert.match(Paths.openUri(Paths.joinPath(folder, pathFor(TODAY))), /%C3%96rnek%20Vault%2F70%20-%20Journal%2F71%20-%20Daily%2F2025-01-03\.md$/);
});

test("Periodic Vault: Periodic Notes wins, nested format, weekly notes", () => {
    const { res, files, hasNote } = scan(generated.periodic.path);
    assert.deepEqual(res.errors, []);
    assert.deepEqual(res.daily, { folder: "Journal/Daily", format: "YYYY/MM/YYYY-MM-DD", template: "" });
    assert.deepEqual(res.weekly, { folder: "Journal/Weekly", format: "gggg-[W]ww" });
    assert.equal(res.weekStart, 1);
    assert.equal(res.wordsPerDot, 100);
    assert.equal(res.dailyUriAvailable, false);

    for (const date of generated.periodic.days) {
        assert.ok(hasNote(date), Dates.key(date));
    }
    assert.ok("2024/12/2024-12-31.md" in files || "2025/01/2025-01-01.md" in files);
    assert.deepEqual(Stats.streak(hasNote, TODAY), { length: 6, includesToday: false });

    // Weekly notes: the row start formatted with the weekly format
    const weeklyFolder = Paths.joinPath(generated.periodic.path, res.weekly.folder);
    const weekly = Paths.parseListOutput(sh(Paths.listCommand(weeklyFolder, Paths.searchDepth(res.weekly.format))).stdout);
    assert.equal(Object.keys(weekly).length, generated.periodic.weeks.length);
    for (const start of generated.periodic.weeks) {
        assert.ok(Paths.notePath("", DateFormat.format(start, res.weekly.format, res.locale)) in weekly, Dates.key(start));
    }
    assert.ok("2025-W01.md" in weekly); // the week of 2024-12-30
});

test("Defaults Vault: no daily-notes.json", () => {
    const { res, hasNote } = scan(generated.defaults.path, Locales.TR);
    assert.deepEqual(res.errors, []);
    assert.equal(res.sources.daily, "default");
    assert.deepEqual(res.daily, { folder: "", format: "YYYY-MM-DD", template: "" });
    assert.equal(res.weekStart, 1);
    for (const date of generated.defaults.days) {
        assert.ok(hasNote(date), Dates.key(date));
    }
    assert.equal(Stats.streak(hasNote, TODAY).length, 3);
});

test("Broken Vault: malformed config is reported", () => {
    const { res } = scan(generated.broken.path);
    assert.equal(res.errors.length, 1);
    assert.equal(res.errors[0].code, "malformed-json");
    assert.equal(res.errors[0].file, "daily-notes.json");
});

test("generation is deterministic and the CLI works", (t) => {
    const other = mkdtempSync(join(tmpdir(), "obsidian-calendar-fixtures-"));
    t.after(() => rmSync(other, { recursive: true, force: true }));
    const again = makeFixtures(other, TODAY);
    assert.deepEqual(again.example.days, generated.example.days);

    const cli = spawnSync(process.execPath, ["scripts/make-fixtures.mjs", "--out", other, "--today", "2024-02-29"], { encoding: "utf8" });
    assert.equal(cli.status, 0, cli.stderr);
    assert.match(cli.stdout, new RegExp(VAULTS.example));
    const bad = spawnSync(process.execPath, ["scripts/make-fixtures.mjs", "--today", "2023-02-29"], { encoding: "utf8" });
    assert.equal(bad.status, 1);
});
