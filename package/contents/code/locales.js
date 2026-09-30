.pragma library

// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Locale data for the moment.js tokens the formatter supports.
//
// Obsidian formats note names with moment.js, so month/day names and week
// numbering rules must match moment's locale data, not Qt's. English (moment's
// default) and Turkish are bundled verbatim from moment 2.x; any other language
// can be built with make() from names supplied by the caller (e.g. Qt.locale()).
//
// Week rules follow moment: `dow` is the first day of the week (0 = Sunday) and
// `doy` is 7 + dow - J, where January J is always in the first week of the year.

function englishOrdinal(n) {
    const b = n % 10;
    const suffix = Math.floor((n % 100) / 10) === 1 ? "th"
        : b === 1 ? "st"
        : b === 2 ? "nd"
        : b === 3 ? "rd"
        : "th";
    return n + suffix;
}

function plainOrdinal(n) {
    return String(n);
}

const EN = Object.freeze({
    name: "en",
    months: ["January", "February", "March", "April", "May", "June", "July",
             "August", "September", "October", "November", "December"],
    monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
    weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
    weekdaysShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    dow: 0,
    doy: 6,
    ordinal: englishOrdinal
});

// moment's Turkish locale returns the bare number for the `Do` token.
const TR = Object.freeze({
    name: "tr",
    months: ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz",
             "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"],
    monthsShort: ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"],
    weekdays: ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"],
    weekdaysShort: ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"],
    dow: 1,
    doy: 7,
    ordinal: plainOrdinal
});

const BUNDLED = { en: EN, tr: TR };

// Returns bundled locale data for a BCP 47 / moment name ("en-US" -> en), or null.
function bundled(name) {
    if (!name) {
        return null;
    }
    const base = String(name).toLowerCase().replace("_", "-").split("-")[0];
    return BUNDLED[base] || null;
}

// Most moment locales put January 1st (Sunday/Saturday starts) or January 4th
// (Monday starts, ISO-like) in the first week; use that when `doy` is unknown.
function defaultDoy(dow) {
    return 7 + dow - (dow === 1 ? 4 : 1);
}

// Builds locale data from caller-supplied names. Missing fields fall back to English.
function make(spec) {
    const dow = Number.isInteger(spec.dow) ? spec.dow : EN.dow;
    return Object.freeze({
        name: spec.name || "custom",
        months: spec.months || EN.months,
        monthsShort: spec.monthsShort || EN.monthsShort,
        weekdays: spec.weekdays || EN.weekdays,
        weekdaysShort: spec.weekdaysShort || EN.weekdaysShort,
        dow: dow,
        doy: Number.isInteger(spec.doy) ? spec.doy : defaultDoy(dow),
        ordinal: spec.ordinal || plainOrdinal
    });
}

// Locale data for the desktop's language: the bundled locale when there is
// one, otherwise English names (moment's default). The week starts on the
// desktop's first day of the week (0 = Sunday); when that differs from the
// bundled rules, the first-week rule follows it too (en_GB: Monday, ISO-like).
function forSystem(name, firstDayOfWeek) {
    const base = bundled(name) || EN;
    const dow = Number.isInteger(firstDayOfWeek) ? ((firstDayOfWeek % 7) + 7) % 7 : base.dow;
    if (dow === base.dow) {
        return base;
    }
    return make({
        name: base.name,
        months: base.months,
        monthsShort: base.monthsShort,
        weekdays: base.weekdays,
        weekdaysShort: base.weekdaysShort,
        dow: dow,
        doy: defaultDoy(dow),
        ordinal: base.ordinal
    });
}

// Same as the Calendar plugin's week-start override: moment merges
// `{week: {dow}}` into the locale, so `doy` is kept as is.
function withWeekStart(locale, dow) {
    if (!Number.isInteger(dow) || dow === locale.dow) {
        return locale;
    }
    return Object.freeze(Object.assign({}, locale, { dow: dow }));
}
