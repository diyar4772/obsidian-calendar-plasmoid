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

// First day of the week and of the year ([dow, doy]) of every moment.js 2.x
// locale, so week numbers match Obsidian for regional locales too (en-gb
// weeks start on Monday, en-us on Sunday). Generated from moment's locale data
// and copied verbatim: "dv" really has dow 7 (Sunday), which the week math
// and "% 7" everywhere else handle exactly like moment does.
const WEEK_RULES = {
    "af": [1, 4], "am-et": [0, 6], "ar": [6, 12], "ar-dz": [0, 4], "ar-kw": [0, 12],
    "ar-ly": [6, 12], "ar-ma": [1, 4], "ar-ps": [0, 6], "ar-sa": [0, 6], "ar-tn": [1, 4],
    "az": [1, 7], "be": [1, 7], "bg": [1, 7], "bm": [1, 4], "bn": [0, 6], "bn-bd": [0, 6],
    "bo": [0, 6], "br": [1, 4], "bs": [1, 7], "ca": [1, 4], "cs": [1, 4], "cv": [1, 7],
    "cy": [1, 4], "da": [1, 4], "de": [1, 4], "de-at": [1, 4], "de-ch": [1, 4], "dv": [7, 12],
    "el": [1, 4], "en": [0, 6], "en-au": [0, 4], "en-ca": [0, 6], "en-gb": [1, 4], "en-ie": [1, 4],
    "en-il": [0, 6], "en-in": [0, 6], "en-nz": [1, 4], "en-sg": [1, 4], "eo": [1, 7], "es": [1, 4],
    "es-do": [1, 4], "es-mx": [0, 4], "es-us": [0, 6], "et": [1, 4], "eu": [1, 7], "fa": [6, 12],
    "fi": [1, 4], "fil": [1, 4], "fo": [1, 4], "fr": [1, 4], "fr-ca": [0, 6], "fr-ch": [1, 4],
    "fy": [1, 4], "ga": [1, 4], "gd": [1, 4], "gl": [1, 4], "gom-deva": [0, 3], "gom-latn": [0, 3],
    "gu": [0, 6], "he": [0, 6], "hi": [0, 6], "hr": [1, 7], "hu": [1, 4], "hy-am": [1, 7],
    "id": [0, 6], "is": [1, 4], "it": [1, 4], "it-ch": [1, 4], "ja": [0, 6], "jv": [1, 7],
    "ka": [1, 7], "kk": [1, 7], "km": [1, 4], "kn": [0, 6], "ko": [0, 6], "ku": [6, 12],
    "ku-kmr": [1, 4], "ky": [1, 7], "lb": [1, 4], "lo": [0, 6], "lt": [1, 4], "lv": [1, 4],
    "me": [1, 7], "mi": [1, 4], "mk": [1, 7], "ml": [0, 6], "mn": [0, 6], "mr": [0, 6],
    "ms": [1, 7], "ms-my": [1, 7], "mt": [1, 4], "my": [1, 4], "nb": [1, 4], "ne": [0, 6],
    "nl": [1, 4], "nl-be": [1, 4], "nn": [1, 4], "oc-lnc": [1, 4], "pa-in": [0, 6], "pl": [1, 4],
    "ps": [6, 12], "pt": [1, 4], "pt-br": [0, 6], "ro": [1, 7], "ru": [1, 4], "sd": [1, 4],
    "se": [1, 4], "si": [0, 6], "sk": [1, 4], "sl": [1, 7], "sq": [1, 4], "sr": [1, 7],
    "sr-cyrl": [1, 7], "ss": [1, 4], "sv": [1, 4], "sw": [1, 7], "ta": [0, 6], "te": [0, 6],
    "tet": [1, 4], "tg": [1, 7], "th": [0, 6], "tk": [1, 7], "tl-ph": [1, 4], "tlh": [1, 4],
    "tr": [1, 7], "tzl": [1, 4], "tzm": [6, 12], "tzm-latn": [6, 12], "ug-cn": [1, 7], "uk": [1, 4],
    "ur": [1, 4], "uz": [1, 7], "uz-latn": [1, 7], "vi": [1, 4], "x-pseudo": [1, 4], "yo": [1, 4],
    "zh-cn": [1, 4], "zh-hk": [0, 6], "zh-mo": [0, 6], "zh-tw": [0, 6]
};

function normalizeName(name) {
    return String(name || "").toLowerCase().replace(/_/g, "-").split(".")[0].split("@")[0];
}

// Week rules [dow, doy] for a locale name ("en_GB", "de-AT"…): the exact
// locale, then its language, or null.
function weekRules(name) {
    const n = normalizeName(name);
    if (Object.prototype.hasOwnProperty.call(WEEK_RULES, n)) {
        return WEEK_RULES[n];
    }
    const base = n.split("-")[0];
    return Object.prototype.hasOwnProperty.call(WEEK_RULES, base) ? WEEK_RULES[base] : null;
}

// Returns bundled locale data for a BCP 47 / moment name ("en-US" -> en), or null.
function bundled(name) {
    if (!name) {
        return null;
    }
    const base = normalizeName(name).split("-")[0];
    return Object.prototype.hasOwnProperty.call(BUNDLED, base) ? BUNDLED[base] : null;
}

// Locale data for a moment locale name as Obsidian would use it: names from
// the bundled language (English otherwise) and the locale's own week rules.
function forName(name) {
    const names = bundled(name) || EN;
    const rules = weekRules(name);
    if (!rules || (rules[0] === names.dow && rules[1] === names.doy)) {
        return names;
    }
    return Object.freeze(Object.assign({}, names, { dow: rules[0], doy: rules[1] }));
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
    const base = forName(name);
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
