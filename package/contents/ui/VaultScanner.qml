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
import "../code/yearview.js" as YearView

// Reads a vault through read-only shell commands and exposes what the
// calendar needs. A scan runs: config files -> daily folder listing ->
// weekly folder listing; word counts are read separately, per month (and
// per year while the Year Overview is open).
QtObject {
    id: scanner

    // Inputs
    property string vaultPath
    property var overrides: ({})
    property var systemLocale
    property string dotSource: "words" // "words", "size" or "none"

    // State: "unconfigured", "loading", "ready" or "error"
    property string status: vaultPath === "" ? "unconfigured" : "loading"
    // For "error": "no-vault", "not-a-vault", "timeout" or "command-failed"
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

    // Listing problems are shown next to the calendar rather than hidden:
    // a folder outside the vault, or find reporting errors (unreadable
    // folders…) while still listing what it could.
    function listProblem(exitCode, stderr, which) {
        if (exitCode === Paths.EXIT_OUTSIDE_VAULT) {
            return { code: "folder-outside-vault", file: which, detail: "" };
        }
        if (exitCode !== 0 && exitCode !== Paths.EXIT_NO_FOLDER) {
            return { code: "list-incomplete", file: which, detail: String(stderr || "").split("\n")[0] };
        }
        return null;
    }

    function listDaily(gen) {
        if (!settings) {
            return;
        }
        const command = Paths.listCommand(dailyFolderPath, Paths.searchDepth(settings.daily.format), vaultPath);
        run(command, (exitCode, stdout, stderr) => {
            if (gen !== generation) {
                return;
            }
            dailyFolderMissing = exitCode === Paths.EXIT_NO_FOLDER;
            dailyFiles = dailyFolderMissing || exitCode === Paths.EXIT_OUTSIDE_VAULT ? {} : Paths.parseListOutput(stdout);
            const problem = listProblem(exitCode, stderr, "daily");
            if (problem) {
                problems = problems.concat([problem]);
            }
            if (settings.weekly) {
                listWeekly(gen);
            } else {
                weeklyFiles = {};
                finish();
            }
        });
    }

    function listWeekly(gen) {
        const command = Paths.listCommand(weeklyFolderPath, Paths.searchDepth(settings.weekly.format), vaultPath);
        run(command, (exitCode, stdout, stderr) => {
            if (gen !== generation) {
                return;
            }
            weeklyFiles = exitCode === Paths.EXIT_NO_FOLDER || exitCode === Paths.EXIT_OUTSIDE_VAULT
                ? {} : Paths.parseListOutput(stdout);
            const problem = listProblem(exitCode, stderr, "weekly");
            if (problem) {
                problems = problems.concat([problem]);
            }
            finish();
        });
    }

    // Fingerprint of everything the calendar shows, so a rescan that found
    // nothing new doesn't rebuild the grid (and drop focus and tooltips).
    property string lastFingerprint: ""

    function fingerprint() {
        return JSON.stringify([settings, problems, dailyFolderMissing, dailyFiles, weeklyFiles, dotSource]);
    }

    function finish() {
        busy = false;
        status = "ready";
        errorCode = "";
        const current = fingerprint();
        if (current !== lastFingerprint) {
            lastFingerprint = current;
            revision++;
        }
        if (wordsWanted) {
            loadWords(wordsWanted.y, wordsWanted.m);
        }
        if (yearWanted !== 0) {
            loadYearWords(yearWanted);
        }
        if (pending) {
            refreshNow();
        }
    }

    function fail(code, detail) {
        busy = false;
        lastFingerprint = "";
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

    // Reads word counts for the notes shown for month (y, m), i.e. the six
    // weeks of its grid, that are new or changed since they were last counted.
    // Counting runs in a worker thread (wordworker.mjs).
    property int wordRequest: 0
    property var wordRequests: ({})

    function loadWords(y, m) {
        wordsWanted = { y: y, m: m };
        if (!settings || dotSource !== "words" || busy) {
            return;
        }
        const rels = [];
        const first = Dates.startOfWeek(Dates.make(y, m, 1), settings.locale.dow);
        for (let i = 0; i < 42; i++) {
            rels.push(dailyPath(Dates.addDays(first, i)));
        }
        requestWords(rels);
    }

    // Year shown in the Year Overview window, or 0 when it's closed. Its
    // notes are counted whatever the dot source, since the overview charts
    // words; the month on screen is requested first and never waits for it.
    property int yearWanted: 0

    function loadYearWords(y) {
        yearWanted = y;
        if (!settings || busy || y === 0) {
            return;
        }
        const first = Dates.make(y, 1, 1);
        const rels = [];
        for (let i = 0; i < Dates.daysInYear(y); i++) {
            rels.push(dailyPath(Dates.addDays(first, i)));
        }
        requestWords(rels);
    }

    // Reads and counts the notes among `rels` (daily-folder relative paths)
    // that exist and are new or changed since they were last counted, in
    // batches so a year of notes doesn't become one huge command.
    function requestWords(rels) {
        const stale = [];
        for (let i = 0; i < rels.length; i++) {
            const rel = rels[i];
            const file = dailyFiles[rel];
            const cached = wordCache[rel];
            if (file && !wordsInFlight.hasOwnProperty(rel)
                    && (!cached || cached.mtime !== file.mtime || cached.size !== file.size)) {
                stale.push(rel);
            }
        }
        for (let i = 0; i < stale.length; i += 60) {
            readWords(stale.slice(i, i + 60));
        }
    }

    function readWords(stale) {
        for (let i = 0; i < stale.length; i++) {
            wordsInFlight[stale[i]] = true;
        }
        const gen = generation;
        run(Paths.readCommand(dailyFolderPath, stale, vaultPath), (exitCode, stdout, stderr) => {
            if (gen !== generation || exitCode !== 0) {
                scanner.clearInFlight(stale);
                return;
            }
            const id = ++wordRequest;
            wordRequests[id] = { generation: gen, files: stale };
            wordWorker.sendMessage({ id: id, output: stdout });
        });
    }

    // Files being read or counted right now, so they aren't requested twice.
    property var wordsInFlight: ({})

    function clearInFlight(files) {
        for (let i = 0; i < files.length; i++) {
            delete wordsInFlight[files[i]];
        }
    }

    function wordsCounted(id, words) {
        const request = wordRequests[id];
        delete wordRequests[id];
        if (request) {
            clearInFlight(request.files);
        }
        if (!request || request.generation !== generation) {
            return;
        }
        const cache = wordCache;
        let changed = false;
        for (let i = 0; i < request.files.length; i++) {
            const rel = request.files[i];
            const file = dailyFiles[rel];
            // An empty read of a non-empty file failed; try again next time.
            if (!file || !words.hasOwnProperty(rel) || (words[rel] === 0 && file.size > 0 && !readEmptyOk(rel))) {
                continue;
            }
            const old = cache[rel];
            if (!old || old.words !== words[rel]) {
                changed = true;
            }
            cache[rel] = { size: file.size, mtime: file.mtime, words: words[rel] };
        }
        wordCache = cache;
        if (changed) {
            revision++;
        }
    }

    // Notes with only frontmatter or whitespace legitimately count 0 words;
    // those are small. Larger files reading as 0 words were unreadable.
    function readEmptyOk(rel) {
        return dailyFiles[rel].size < 4096;
    }

    property WorkerScript wordWorker: WorkerScript {
        source: "../code/wordworker.mjs"
        onMessage: message => scanner.wordsCounted(message.id, message.words)
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

    // { date, hasNote, words, size } for each day of year y, as
    // yearview.js expects; words is -1 until counted.
    function yearEntries(y) {
        const days = YearView.daysOfYear(y);
        return days.map(date => {
            const rel = dailyPath(date);
            const file = settings && dailyFiles.hasOwnProperty(rel) ? dailyFiles[rel] : null;
            const cached = file ? wordCache[rel] : undefined;
            return { date: date, hasNote: file !== null, words: cached ? cached.words : -1, size: file ? file.size : 0 };
        });
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
        if (command === null) {
            // A path that can't be passed to a command (e.g. contains NUL)
            Qt.callLater(() => callback(-1, "", "invalid path"));
            return;
        }
        runner.run(command, callback);
    }

    property CommandRunner runner: CommandRunner {}

    // A command that never returns (a sleeping network or USB drive) must not
    // leave the widget reading forever: give up and say so.
    property Timer watchdog: Timer {
        interval: 20000
        running: scanner.busy
        onTriggered: {
            scanner.generation++;
            scanner.fail("timeout", scanner.vaultPath);
        }
    }

    property Timer debounce: Timer {
        interval: 250
        onTriggered: scanner.refreshNow()
    }

    // Results of a scan that is still running belong to the old inputs:
    // invalidate them and start over.
    function restart() {
        generation++;
        busy = false;
        pending = false;
        refresh();
    }

    onVaultPathChanged: {
        generation++;
        wordsInFlight = {};
        busy = false;
        pending = false;
        status = vaultPath === "" ? "unconfigured" : "loading";
        settings = null;
        dailyFiles = {};
        weeklyFiles = {};
        wordCache = {};
        refresh();
    }
    onOverridesChanged: restart()
    onSystemLocaleChanged: restart()
    onDotSourceChanged: {
        revision++;
        if (wordsWanted) {
            loadWords(wordsWanted.y, wordsWanted.m);
        }
    }
}
