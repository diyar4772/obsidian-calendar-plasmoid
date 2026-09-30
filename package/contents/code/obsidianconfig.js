.pragma library
.import "dateformat.js" as DateFormat
.import "locales.js" as Locales

// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Resolves daily/weekly note settings the way Obsidian's plugins do
// (see obsidian-daily-notes-interface), then applies the widget's overrides.
//
// Priority for daily notes:
//   1. Periodic Notes `daily`, when the plugin is enabled and daily is on
//   2. the core Daily notes plugin (.obsidian/daily-notes.json)
//   3. defaults: vault root, YYYY-MM-DD
// Weekly notes come from Periodic Notes `weekly`, or from the Calendar
// plugin's older weekly-note settings when they were filled in.
//
// Problems are reported as { code, file, detail } objects so the UI can
// translate them; nothing here throws on bad input.

const DEFAULT_DAILY_FORMAT = "YYYY-MM-DD";
const DEFAULT_WEEKLY_FORMAT = "gggg-[W]ww";
const DEFAULT_WORDS_PER_DOT = 250;

// Paths relative to the vault's .obsidian folder that detect() reads.
const FILES = {
    dailyNotes: "daily-notes.json",
    corePlugins: "core-plugins.json",
    communityPlugins: "community-plugins.json",
    periodicNotes: "plugins/periodic-notes/data.json",
    calendar: "plugins/calendar/data.json"
};

// Relative paths of FILES, for paths.configCommand().
function configFiles() {
    return Object.keys(FILES).map(function (k) { return FILES[k]; });
}

// Turns { "daily-notes.json": text, ... } (paths.parseConfigOutput()) into
// the keyed form detect() takes.
function filesByKey(byPath) {
    const files = {};
    const keys = Object.keys(FILES);
    for (let i = 0; i < keys.length; i++) {
        files[keys[i]] = byPath.hasOwnProperty(FILES[keys[i]]) ? byPath[FILES[keys[i]]] : null;
    }
    return files;
}

const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function stringOr(value, fallback) {
    return typeof value === "string" ? value : fallback;
}

// Parses a config file. Returns { value } or { error } and never throws.
// `text` is null when the file doesn't exist.
function parseJson(text) {
    if (text === null || text === undefined) {
        return { value: null };
    }
    try {
        return { value: JSON.parse(text) };
    } catch (e) {
        return { error: String(e.message || e) };
    }
}

// Normalizes a vault-relative folder like Obsidian: trims, drops empty and
// "." segments and leading/trailing slashes. Returns null for folders that
// would leave the vault ("..").
function normalizeFolder(folder) {
    const parts = String(folder || "").trim().replace(/\\/g, "/").split("/");
    const out = [];
    for (let i = 0; i < parts.length; i++) {
        const part = parts[i].trim() === "" ? "" : parts[i];
        if (part === "" || part === ".") {
            continue;
        }
        if (part === "..") {
            return null;
        }
        out.push(part);
    }
    return out.join("/");
}

// Periodic Notes 0.x stores { daily, weekly, ... }; the 1.0 beta stores
// calendar sets with { day, week, ... }. Returns { daily, weekly } configs.
function periodicConfigs(data) {
    if (Array.isArray(data.calendarSets)) {
        let set = null;
        for (let i = 0; i < data.calendarSets.length; i++) {
            const candidate = data.calendarSets[i];
            if (isObject(candidate) && (set === null || candidate.id === data.activeCalendarSet)) {
                set = candidate;
            }
        }
        set = set || {};
        return { daily: set.day, weekly: set.week, templateKey: "templatePath" };
    }
    return { daily: data.daily, weekly: data.weekly, templateKey: "template" };
}

function isPluginEnabled(list, id) {
    // No community-plugins.json: treat installed plugins as enabled.
    return list === null || list.indexOf(id) !== -1;
}

function isCorePluginEnabled(core, id) {
    if (core === null) {
        return true; // Daily notes is on by default in new vaults.
    }
    if (Array.isArray(core)) {
        return core.indexOf(id) !== -1; // Obsidian < 1.4 kept a list of enabled ids.
    }
    return core[id] === true;
}

// community-plugins.json is a list of ids, core-plugins.json a list (older
// Obsidian) or an { id: enabled } map; plugin settings are objects.
function hasExpectedShape(key, value) {
    if (key === "communityPlugins") {
        return Array.isArray(value);
    }
    if (key === "corePlugins") {
        return Array.isArray(value) || isObject(value);
    }
    return isObject(value);
}

// Reads what Obsidian itself would use. `files` maps the keys of FILES to the
// file contents, or to null when the file doesn't exist.
function detect(files) {
    const errors = [];
    const data = {};
    const keys = Object.keys(FILES);
    for (let i = 0; i < keys.length; i++) {
        const parsed = parseJson(files ? files[keys[i]] : null);
        if (parsed.error !== undefined) {
            errors.push({ code: "malformed-json", file: FILES[keys[i]], detail: parsed.error });
            data[keys[i]] = null;
        } else if (parsed.value !== null && !hasExpectedShape(keys[i], parsed.value)) {
            errors.push({ code: "invalid-config", file: FILES[keys[i]], detail: "" });
            data[keys[i]] = null;
        } else {
            data[keys[i]] = parsed.value;
        }
    }

    const community = Array.isArray(data.communityPlugins) ? data.communityPlugins : null;
    const result = {
        daily: { folder: "", format: DEFAULT_DAILY_FORMAT, template: "", source: "default" },
        weekly: null,
        weekStart: null,        // 0-6, or null to use the locale's first day
        wordsPerDot: DEFAULT_WORDS_PER_DOT,
        showWeekNumbers: false,
        locale: null,           // moment locale name from the Calendar plugin, if any
        dailyCoreEnabled: isCorePluginEnabled(data.corePlugins, "daily-notes"),
        plugins: {
            periodicNotes: data.periodicNotes !== null && isPluginEnabled(community, "periodic-notes"),
            calendar: data.calendar !== null && isPluginEnabled(community, "calendar")
        },
        errors: errors
    };

    const periodic = result.plugins.periodicNotes ? periodicConfigs(data.periodicNotes) : null;

    if (periodic && isObject(periodic.daily) && periodic.daily.enabled === true) {
        result.daily = {
            folder: stringOr(periodic.daily.folder, ""),
            format: stringOr(periodic.daily.format, "") || DEFAULT_DAILY_FORMAT,
            template: stringOr(periodic.daily[periodic.templateKey], "").trim(),
            source: "periodic-notes"
        };
    } else if (data.dailyNotes !== null) {
        result.daily = {
            folder: stringOr(data.dailyNotes.folder, ""),
            format: stringOr(data.dailyNotes.format, "") || DEFAULT_DAILY_FORMAT,
            template: stringOr(data.dailyNotes.template, "").trim(),
            source: "daily-notes"
        };
    }

    const calendar = result.plugins.calendar ? data.calendar : null;

    if (periodic && isObject(periodic.weekly) && periodic.weekly.enabled === true) {
        result.weekly = {
            folder: stringOr(periodic.weekly.folder, ""),
            format: stringOr(periodic.weekly.format, "") || DEFAULT_WEEKLY_FORMAT,
            source: "periodic-notes"
        };
    } else if (calendar && (stringOr(calendar.weeklyNoteFormat, "") || stringOr(calendar.weeklyNoteFolder, ""))) {
        result.weekly = {
            folder: stringOr(calendar.weeklyNoteFolder, ""),
            format: stringOr(calendar.weeklyNoteFormat, "") || DEFAULT_WEEKLY_FORMAT,
            source: "calendar"
        };
    }

    if (calendar) {
        const start = WEEKDAYS.indexOf(calendar.weekStart);
        result.weekStart = start === -1 ? null : start;
        if (typeof calendar.wordsPerDot === "number" && isFinite(calendar.wordsPerDot)) {
            result.wordsPerDot = calendar.wordsPerDot;
        }
        result.showWeekNumbers = calendar.showWeeklyNote === true;
        const locale = stringOr(calendar.localeOverride, "");
        result.locale = locale && locale !== "system-default" ? locale : null;
    }

    return result;
}

// Problems with a note format: [] when usable, else error codes
// ("unsupported-token", "invalid-format").
function formatProblems(format) {
    const problems = [];
    if (DateFormat.compile(format).unsupported.length > 0) {
        problems.push("unsupported-token");
    }
    // Literal text could still walk out of the folder, e.g. "[../]YYYY".
    const sample = DateFormat.format({ y: 2000, m: 1, d: 1 }, format, Locales.EN).split("/");
    if (String(format).trim() === "" || sample.indexOf("..") !== -1 || sample.indexOf(".") !== -1
            || sample[sample.length - 1] === "" || sample[0] === "") {
        problems.push("invalid-format");
    }
    return problems;
}

// Validates a format; returns false when it can't be used at all.
function validFormat(format, which, errors) {
    const problems = formatProblems(format);
    if (problems.indexOf("unsupported-token") !== -1) {
        errors.push({ code: "unsupported-token", file: which, detail: DateFormat.compile(format).unsupported.join(", ") });
    }
    if (problems.indexOf("invalid-format") !== -1) {
        errors.push({ code: "invalid-format", file: which, detail: format });
        return false;
    }
    return true;
}

function isSet(value) {
    return value !== null && value !== undefined;
}

// Combines detected settings with the widget's overrides and validates the
// result. Override fields are null/undefined to keep the detected value:
//   dailyFolder, dailyFormat, weeklyFolder, weeklyFormat (strings),
//   weekStart (0-6), wordsPerDot (number), showWeekNumbers (bool),
//   locale (moment locale name, e.g. "en" or "tr").
// `systemLocale` is locale data for the desktop (Locales.forSystem()), used
// when neither the overrides nor the Calendar plugin name a locale.
function resolve(detected, overrides, systemLocale) {
    const o = overrides || {};
    const errors = detected.errors.slice();
    const sources = {
        daily: detected.daily.source,
        weekly: detected.weekly ? detected.weekly.source : null,
        weekStart: detected.weekStart !== null ? "calendar" : "locale",
        locale: detected.locale !== null ? "calendar" : "system"
    };

    let dailyFolder = detected.daily.folder;
    let dailyFormat = detected.daily.format;
    if (isSet(o.dailyFolder) || isSet(o.dailyFormat)) {
        sources.daily = "override";
    }
    if (isSet(o.dailyFolder)) {
        dailyFolder = o.dailyFolder;
    }
    if (isSet(o.dailyFormat) && o.dailyFormat !== "") {
        dailyFormat = o.dailyFormat;
    }

    let weekly = detected.weekly ? { folder: detected.weekly.folder, format: detected.weekly.format } : null;
    if (isSet(o.weeklyFolder) || (isSet(o.weeklyFormat) && o.weeklyFormat !== "")) {
        weekly = weekly || { folder: "", format: DEFAULT_WEEKLY_FORMAT };
        if (isSet(o.weeklyFolder)) {
            weekly.folder = o.weeklyFolder;
        }
        if (isSet(o.weeklyFormat) && o.weeklyFormat !== "") {
            weekly.format = o.weeklyFormat;
        }
        sources.weekly = "override";
    }

    // Unusable folders and formats are reported and replaced by the
    // defaults, so no path can point outside the notes folder.
    const folder = normalizeFolder(dailyFolder);
    if (folder === null) {
        errors.push({ code: "invalid-folder", file: "daily", detail: dailyFolder });
    }
    if (!validFormat(dailyFormat, "daily", errors)) {
        dailyFormat = DEFAULT_DAILY_FORMAT;
    }

    if (weekly) {
        const weeklyFolder = normalizeFolder(weekly.folder);
        if (weeklyFolder === null) {
            errors.push({ code: "invalid-folder", file: "weekly", detail: weekly.folder });
        }
        const usable = validFormat(weekly.format, "weekly", errors) && weeklyFolder !== null;
        weekly = usable ? { folder: weeklyFolder, format: weekly.format } : null;
    }

    const system = systemLocale || Locales.EN;
    let base = system;
    if (isSet(o.locale) && o.locale !== "") {
        // The widget's language setting only changes names; the week keeps
        // following the desktop (or the week-start settings below).
        const names = Locales.bundled(o.locale) || Locales.EN;
        base = Object.freeze(Object.assign({}, names, { dow: system.dow, doy: system.doy }));
        sources.locale = "override";
    } else if (detected.locale !== null) {
        // The Calendar plugin's locale override changes names and week rules,
        // like moment.locale(). Only bundled languages can be matched
        // exactly; anything else uses English names with the current week.
        const bundled = Locales.bundled(detected.locale);
        base = bundled || Locales.make({ name: "en", dow: system.dow, ordinal: Locales.EN.ordinal });
        if (!bundled) {
            sources.locale = "fallback";
        }
    }

    let weekStart = detected.weekStart;
    if (isSet(o.weekStart) && o.weekStart >= 0 && o.weekStart <= 6) {
        weekStart = o.weekStart;
        sources.weekStart = "override";
    }
    if (weekStart === null) {
        weekStart = base.dow;
    }

    let wordsPerDot = detected.wordsPerDot;
    if (isSet(o.wordsPerDot) && isFinite(o.wordsPerDot)) {
        wordsPerDot = o.wordsPerDot;
    }

    return {
        daily: { folder: folder || "", format: dailyFormat, template: detected.daily.template },
        weekly: weekly,
        weekStart: weekStart,
        locale: Locales.withWeekStart(base, weekStart),
        wordsPerDot: wordsPerDot,
        showWeekNumbers: isSet(o.showWeekNumbers) ? o.showWeekNumbers === true : detected.showWeekNumbers,
        dailyUriAvailable: detected.dailyCoreEnabled,
        sources: sources,
        errors: errors
    };
}
