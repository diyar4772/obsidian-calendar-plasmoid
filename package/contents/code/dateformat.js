.pragma library
.import "dates.js" as Dates

// A small formatter for the moment.js tokens that Obsidian users put in daily
// and weekly note formats. Tokenization uses moment's own regular expression,
// so brackets, backslash escapes and literal text behave the same way.
//
// Supported:
//   YYYY YY          year
//   Q                quarter
//   M MM MMM MMMM    month
//   D DD Do          day of month
//   DDD DDDD         day of year
//   d ddd dddd e E   day of week (number, short name, name, locale, ISO)
//   w ww gg gggg     locale week and week-year
//   W WW GG GGGG     ISO week and week-year
//   [text] \x        literal text
//
// Other moment tokens (time of day, time zones, ...) can't appear in a note
// name that is derived from a date alone. They are reported by compile() so
// the widget can show an error instead of silently looking for wrong files.

// moment.js 2.x `formattingTokens`.
const TOKEN_RE = /(\[[^\[]*\])|(\\)?([Hh]mm(ss)?|Mo|MM?M?M?|Do|DDDo|DD?D?D?|ddd?d?|do?|w[o|w]?|W[o|W]?|Qo?|N{1,5}|YYYYYY|YYYYY|YYYY|YY|y{2,4}|yo?|gg(ggg?)?|GG(GGG?)?|e|E|a|A|hh?|HH?|kk?|mm?|ss?|S{1,9}|x|X|zz?|ZZ?|.)/g;

// Tokens moment would format but this formatter doesn't.
const UNSUPPORTED = ["Mo", "DDDo", "dd", "do", "wo", "Wo", "Qo", "N", "NN", "NNN", "NNNN", "NNNNN",
    "YYYYYY", "YYYYY", "Y", "y", "yy", "yyy", "yyyy", "yo", "ggggg", "GGGGG",
    "a", "A", "h", "hh", "H", "HH", "k", "kk", "m", "mm", "s", "ss",
    "S", "SS", "SSS", "SSSS", "SSSSS", "SSSSSS", "SSSSSSS", "SSSSSSSS", "SSSSSSSSS",
    "x", "X", "z", "zz", "Z", "ZZ", "hmm", "hmmss", "Hmm", "Hmmss"];

function pad(n, width) {
    const s = String(Math.abs(n)).padStart(width, "0");
    return n < 0 ? "-" + s : s;
}

// moment's firstWeekOffset(): offset of the first day of week 1 from Jan 1.
function firstWeekOffset(year, dow, doy) {
    const fwd = 7 + dow - doy;
    const fwdlw = (7 + Dates.dayOfWeek(Dates.make(year, 1, fwd)) - dow) % 7;
    return -fwdlw + fwd - 1;
}

function weeksInYear(year, dow, doy) {
    const offset = firstWeekOffset(year, dow, doy);
    const offsetNext = firstWeekOffset(year + 1, dow, doy);
    return (Dates.daysInYear(year) - offset + offsetNext) / 7;
}

// Week number and week-year of `date` for week rules (dow, doy), as moment's
// weekOfYear(). ISO 8601 weeks are dow = 1, doy = 4.
function weekOfYear(date, dow, doy) {
    const offset = firstWeekOffset(date.y, dow, doy);
    const week = Math.floor((Dates.dayOfYear(date) - offset - 1) / 7) + 1;
    if (week < 1) {
        return { week: week + weeksInYear(date.y - 1, dow, doy), year: date.y - 1 };
    }
    const total = weeksInYear(date.y, dow, doy);
    if (week > total) {
        return { week: week - total, year: date.y + 1 };
    }
    return { week: week, year: date.y };
}

function isoWeek(date) {
    return weekOfYear(date, 1, 4);
}

function localeWeek(date, locale) {
    return weekOfYear(date, locale.dow, locale.doy);
}

function yearString(y) {
    return y <= 9999 ? pad(y, 4) : "+" + y;
}

const FORMATTERS = {
    "YYYY": function (d) { return yearString(d.y); },
    "YY": function (d) { return pad(((d.y % 100) + 100) % 100, 2); },
    "Q": function (d) { return String(Math.ceil(d.m / 3)); },
    "M": function (d) { return String(d.m); },
    "MM": function (d) { return pad(d.m, 2); },
    "MMM": function (d, l) { return l.monthsShort[d.m - 1]; },
    "MMMM": function (d, l) { return l.months[d.m - 1]; },
    "D": function (d) { return String(d.d); },
    "DD": function (d) { return pad(d.d, 2); },
    "Do": function (d, l) { return l.ordinal(d.d); },
    "DDD": function (d) { return String(Dates.dayOfYear(d)); },
    "DDDD": function (d) { return pad(Dates.dayOfYear(d), 3); },
    "d": function (d) { return String(Dates.dayOfWeek(d)); },
    "ddd": function (d, l) { return l.weekdaysShort[Dates.dayOfWeek(d)]; },
    "dddd": function (d, l) { return l.weekdays[Dates.dayOfWeek(d)]; },
    "e": function (d, l) { return String((Dates.dayOfWeek(d) - l.dow + 7) % 7); },
    "E": function (d) { return String(Dates.dayOfWeek(d) || 7); },
    "w": function (d, l) { return String(localeWeek(d, l).week); },
    "ww": function (d, l) { return pad(localeWeek(d, l).week, 2); },
    "gg": function (d, l) { return pad(((localeWeek(d, l).year % 100) + 100) % 100, 2); },
    "gggg": function (d, l) { return pad(localeWeek(d, l).year, 4); },
    "W": function (d) { return String(isoWeek(d).week); },
    "WW": function (d) { return pad(isoWeek(d).week, 2); },
    "GG": function (d) { return pad(((isoWeek(d).year % 100) + 100) % 100, 2); },
    "GGGG": function (d) { return pad(isoWeek(d).year, 4); }
};

// moment's removeFormattingTokens() for literal parts.
function literalText(match) {
    if (/^\[[\s\S]/.test(match)) {
        return match.replace(/^\[|\]$/g, "");
    }
    return match.replace(/\\/g, "");
}

// Splits a format into parts. Returns { parts, unsupported } where each part is
// { literal: "text" } or { token: "YYYY" } and `unsupported` lists the
// unsupported tokens found (empty when the format is usable).
function compile(format) {
    const parts = [];
    const unsupported = [];
    const source = String(format);
    TOKEN_RE.lastIndex = 0;
    let match;
    while ((match = TOKEN_RE.exec(source)) !== null) {
        const whole = match[0];
        const escaped = match[1] !== undefined || match[2] !== undefined;
        if (!escaped && FORMATTERS.hasOwnProperty(whole)) {
            parts.push({ token: whole });
        } else {
            if (!escaped && UNSUPPORTED.indexOf(whole) !== -1 && unsupported.indexOf(whole) === -1) {
                unsupported.push(whole);
            }
            const text = literalText(whole);
            const last = parts[parts.length - 1];
            if (last && last.literal !== undefined) {
                last.literal += text;
            } else {
                parts.push({ literal: text });
            }
        }
    }
    return { parts: parts, unsupported: unsupported };
}

function formatCompiled(compiled, date, locale) {
    let out = "";
    for (let i = 0; i < compiled.parts.length; i++) {
        const part = compiled.parts[i];
        out += part.token !== undefined ? FORMATTERS[part.token](date, locale) : part.literal;
    }
    return out;
}

// Formats `date` ({y, m, d}) with a moment.js format string and locale data
// (see locales.js). Unsupported tokens are left as literal text; call
// compile() first to detect them.
function format(date, fmt, locale) {
    return formatCompiled(compile(fmt), date, locale);
}
