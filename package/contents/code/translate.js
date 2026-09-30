.pragma library

// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// The widget's own language setting ("Language: System default / English /
// Türkçe").
//
// KI18n's language is global to plasmashell, so the widget can't switch it
// without changing every other widget. Instead, the calendar's strings go
// through Translator.qml: "System default" uses KI18n as usual, "English"
// uses the untranslated strings, and any other language looks the string up
// in catalogs.js, which scripts/i18n.sh generates from po/*.po. The same
// setting picks the locale for month and day names and date formats.

// Languages offered in the settings, by their own names.
const LANGUAGES = [
    { code: "en", name: "English" },
    { code: "tr", name: "Türkçe" }
];

// gettext keys: context and message joined by EOT, like in .mo files.
function key(context, text) {
    return context + "\u0004" + text;
}

// Replaces %1 … %99 with `args` (0-based) like KI18n; placeholders
// without an argument are left alone.
function substitute(text, args) {
    return String(text).replace(/%(\d{1,2})/g, function (match, digits) {
        const i = Number(digits) - 1;
        return i >= 0 && i < args.length && args[i] !== undefined ? String(args[i]) : match;
    });
}

// English plural rule, used for the untranslated strings.
function englishPlural(n) {
    return n === 1 ? 0 : 1;
}

// Translation of `text` in `catalog` ({ plural, messages }), or `text`.
function lookup(catalog, context, text) {
    const entry = catalog ? catalog.messages[key(context, text)] : undefined;
    return entry !== undefined && entry[0] ? entry[0] : text;
}

function lookupPlural(catalog, context, singular, plural, n) {
    const entry = catalog ? catalog.messages[key(context, singular)] : undefined;
    if (entry !== undefined) {
        const form = entry[catalog.plural(n)];
        if (form) {
            return form;
        }
    }
    return englishPlural(n) === 0 ? singular : plural;
}

// i18nc() for a forced language: "en" or a key of `catalogs`.
function translate(catalogs, language, context, text, args) {
    const catalog = language === "en" ? null : catalogs[language];
    return substitute(lookup(catalog, context, text), args || []);
}

// i18ncp(): %1 is `n`, the other arguments follow as %2, %3 …
function translatePlural(catalogs, language, context, singular, plural, n, args) {
    const catalog = language === "en" ? null : catalogs[language];
    return substitute(lookupPlural(catalog, context, singular, plural, n), [n].concat(args || []));
}

// The setting as stored: "" for the system language, or a language code
// the widget can show (English or a bundled catalog). Anything else counts
// as the system language.
function normalize(setting, catalogs) {
    const s = String(setting || "");
    return s === "en" || Object.prototype.hasOwnProperty.call(catalogs, s) ? s : "";
}

// Qt locale names for the calendar: `names` for month and day names,
// `formats` for long dates. The system language keeps the desktop's
// choices; a forced language keeps the desktop's region when it's the same
// language (en_GB stays en_GB), otherwise Qt picks the language's main
// region ("en" is en_US, "tr" is tr_TR).
function localeNames(language, systemName, uiLanguage) {
    const system = String(systemName || "C");
    if (language === "") {
        return { names: String(uiLanguage || system), formats: system };
    }
    if (system.split(/[_.@-]/)[0].toLowerCase() === language) {
        return { names: system, formats: system };
    }
    return { names: language, formats: language };
}
