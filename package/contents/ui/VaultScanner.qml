/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import "../code/dateformat.js" as DateFormat
import "../code/dates.js" as Dates
import "../code/obsidianconfig.js" as Config
import "../code/paths.js" as Paths
import "../code/stats.js" as Stats
import "../code/wordcount.js" as WordCount

// Reads a vault through read-only shell commands and exposes what the
// calendar needs. A scan runs: config files -> daily folder listing ->
// weekly folder listing; word counts are read separately, per month.
QtObject {
    id: scanner

    // Inputs
    property string vaultPath
    property var overrides: ({})
    property var systemLocale
    property string dotSource: "words" // "words", "size" or "none"

    // State: "unconfigured", "loading", "ready" or "error"
    property string status: vaultPath === "" ? "unconfigured" : "loading"
    // For "error": "no-vault", "not-a-vault" or "command-failed"
    property string errorCode: ""
    property string errorDetail: ""
    // Config problems ({ code, file, detail }); the calendar still works.
    property var problems: []
    property bool dailyFolderMissing: false

    // Resolved settings (obsidianconfig.resolve()), null until the first scan.
    property var settings: null
    // Bumped whenever anything the calendar shows has changed.
    property int revision: 0

    readonly property string vaultName: Paths.vaultName(vaultPath)
    readonly property string dailyFolderPath: settings ? Paths.joinPath(vaultPath, settings.daily.folder) : ""
    readonly property string weeklyFolderPath: settings && settings.weekly ? Paths.joinPath(vaultPath, settings.weekly.folder) : ""

    // relative path -> { size, mtime }
    property var dailyFiles: ({})
    property var weeklyFiles: ({})
    // relative path -> { size, mtime, words }; kept across scans
    property var wordCache: ({})

    property int generation: 0
    property bool busy: false
    property bool pending: false
    property var wordsWanted: null // { y, m } of the month on screen

    function refresh() {
        debounce.restart();
    }

    function refreshNow() {
        if (vaultPath === "") {
            status = "unconfigured";
            return;
        }
        if (status === "unconfigured") {
            status = "loading";
        }
        if (busy) {
            pending = true;
            return;
        }
        busy = true;
        pending = false;
        const gen = ++generation;
        const command = Paths.configCommand(vaultPath, Config.configFiles());
        if (command === null) {
            fail("no-vault", vaultPath);
            return;
        }
        run(command, (exitCode, stdout, stderr) => {
            if (gen !== generation) {
                return;
            }
            if (exitCode === Paths.EXIT_NO_VAULT) {
                fail("no-vault", vaultPath);
                return;
            }
            if (exitCode === Paths.EXIT_NOT_A_VAULT) {
                fail("not-a-vault", vaultPath);
                return;
            }
            if (exitCode !== 0) {
                fail("command-failed", stderr);
                return;
            }
            const detected = Config.detect(Config.filesByKey(Paths.parseConfigOutput(stdout)));
            const resolved = Config.resolve(detected, overrides, systemLocale);
            const folderChanged = !settings || settings.daily.folder !== resolved.daily.folder
                || settings.daily.format !== resolved.daily.format;
            if (folderChanged) {
                wordCache = {};
            }
            settings = resolved;
            problems = resolved.errors;
            listDaily(gen);
        });
    }

    function listDaily(gen) {
        const command = Paths.listCommand(dailyFolderPath, Paths.searchDepth(settings.daily.format));
        run(command, (exitCode, stdout, stderr) => {
            if (gen !== generation) {
                return;
            }
            dailyFolderMissing = exitCode === Paths.EXIT_NO_FOLDER;
            dailyFiles = dailyFolderMissing ? {} : Paths.parseListOutput(stdout);
            if (settings.weekly) {
                listWeekly(gen);
            } else {
                weeklyFiles = {};
                finish();
            }
        });
    }

    function listWeekly(gen) {
        const command = Paths.listCommand(weeklyFolderPath, Paths.searchDepth(settings.weekly.format));
        run(command, (exitCode, stdout, stderr) => {
            if (gen !== generation) {
                return;
            }
            weeklyFiles = exitCode === 0 ? Paths.parseListOutput(stdout) : {};
            finish();
        });
    }

    function finish() {
        busy = false;
        status = "ready";
        errorCode = "";
        revision++;
        if (wordsWanted) {
            loadWords(wordsWanted.y, wordsWanted.m);
        }
        if (pending) {
            refreshNow();
        }
    }

    function fail(code, detail) {
        busy = false;
        status = "error";
        errorCode = code;
        errorDetail = detail || "";
        settings = null;
        dailyFiles = {};
        weeklyFiles = {};
        revision++;
        if (pending) {
            refreshNow();
        }
    }

    // Reads word counts for notes of month (y, m) and the days around it that
    // are new or changed since they were last counted.
    function loadWords(y, m) {
        wordsWanted = { y: y, m: m };
        if (!settings || dotSource !== "words" || busy) {
            return;
        }
        const stale = [];
        const first = Dates.addDays(Dates.make(y, m, 1), -7);
        for (let i = 0; i < 45; i++) {
            const rel = dailyPath(Dates.addDays(first, i));
            const file = dailyFiles[rel];
            const cached = wordCache[rel];
            if (file && (!cached || cached.mtime !== file.mtime || cached.size !== file.size)) {
                stale.push(rel);
            }
        }
        if (stale.length === 0) {
            return;
        }
        const gen = generation;
        run(Paths.readCommand(dailyFolderPath, stale), (exitCode, stdout, stderr) => {
            if (gen !== generation) {
                return;
            }
            const contents = Paths.parseReadOutput(stdout);
            const cache = wordCache;
            for (let i = 0; i < stale.length; i++) {
                const file = dailyFiles[stale[i]];
                if (file && contents.hasOwnProperty(stale[i])) {
                    cache[stale[i]] = { size: file.size, mtime: file.mtime, words: WordCount.noteWords(contents[stale[i]]) };
                }
            }
            wordCache = cache;
            revision++;
        });
    }

    // Vault-queries used by the views.

    function dailyPath(date) {
        return settings ? Paths.notePath("", DateFormat.format(date, settings.daily.format, settings.locale)) : "";
    }

    function hasNote(date) {
        return settings !== null && dailyFiles.hasOwnProperty(dailyPath(date));
    }

    function weeklyPath(weekStart) {
        return settings && settings.weekly
            ? Paths.notePath("", DateFormat.format(weekStart, settings.weekly.format, settings.locale)) : "";
    }

    function hasWeeklyNote(weekStart) {
        return settings !== null && settings.weekly !== null && weeklyFiles.hasOwnProperty(weeklyPath(weekStart));
    }

    // 0-5 dots for a day, following `dotSource`. `sizeDots` is the result of
    // monthSizeDots() for the month on screen.
    function dotsFor(date, sizeDots) {
        const rel = dailyPath(date);
        if (!settings || !dailyFiles.hasOwnProperty(rel)) {
            return 0;
        }
        if (dotSource === "none") {
            return 1;
        }
        if (dotSource === "size") {
            return sizeDots && sizeDots.hasOwnProperty(rel) ? sizeDots[rel] : 1;
        }
        const cached = wordCache[rel];
        return cached ? Stats.dotsForWords(cached.words, settings.wordsPerDot) : 1;
    }

    function wordsFor(date) {
        const cached = wordCache[dailyPath(date)];
        return cached ? cached.words : -1;
    }

    // { relativePath: dots } by file size for notes of month (y, m).
    function monthSizeDots(y, m) {
        const paths = [];
        const sizes = [];
        for (let d = 1; d <= Dates.daysInMonth(y, m); d++) {
            const rel = dailyPath(Dates.make(y, m, d));
            if (dailyFiles.hasOwnProperty(rel)) {
                paths.push(rel);
                sizes.push(dailyFiles[rel].size);
            }
        }
        const dots = Stats.dotsForSizes(sizes);
        const result = {};
        for (let i = 0; i < paths.length; i++) {
            result[paths[i]] = dots[i];
        }
        return result;
    }

    function streak(today) {
        return Stats.streak(date => hasNote(date), today, Object.keys(dailyFiles).length + 1);
    }

    function countInMonth(y, m) {
        return Stats.countInMonth(date => hasNote(date), y, m);
    }

    function run(command, callback) {
        runner.run(command, callback);
    }

    property CommandRunner runner: CommandRunner {}

    property Timer debounce: Timer {
        interval: 250
        onTriggered: scanner.refreshNow()
    }

    onVaultPathChanged: {
        status = vaultPath === "" ? "unconfigured" : "loading";
        settings = null;
        dailyFiles = {};
        weeklyFiles = {};
        wordCache = {};
        refresh();
    }
    onOverridesChanged: refresh()
    onSystemLocaleChanged: refresh()
    onDotSourceChanged: {
        revision++;
        if (wordsWanted) {
            loadWords(wordsWanted.y, wordsWanted.m);
        }
    }
}
