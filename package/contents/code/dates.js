.pragma library

// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Calendar-date arithmetic on plain {y, m, d} objects (m is 1-12).
//
// All math goes through a day number (days since 1970-01-01, proleptic
// Gregorian) computed with integer arithmetic, so results never depend on
// the local time zone or daylight-saving transitions.

function isLeapYear(y) {
    return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

function daysInMonth(y, m) {
    if (m === 2) {
        return isLeapYear(y) ? 29 : 28;
    }
    return (m === 4 || m === 6 || m === 9 || m === 11) ? 30 : 31;
}

function daysInYear(y) {
    return isLeapYear(y) ? 366 : 365;
}

function make(y, m, d) {
    return { y: y, m: m, d: d };
}

function isValid(date) {
    return date !== null && typeof date === "object"
        && Number.isInteger(date.y) && Number.isInteger(date.m) && Number.isInteger(date.d)
        && date.m >= 1 && date.m <= 12
        && date.d >= 1 && date.d <= daysInMonth(date.y, date.m);
}

// Howard Hinnant's days_from_civil / civil_from_days.
function toDayNumber(date) {
    const y = date.m <= 2 ? date.y - 1 : date.y;
    const era = Math.floor(y / 400);
    const yoe = y - era * 400;
    const mp = (date.m + 9) % 12;
    const doy = Math.floor((153 * mp + 2) / 5) + date.d - 1;
    const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
    return era * 146097 + doe - 719468;
}

function fromDayNumber(n) {
    const z = n + 719468;
    const era = Math.floor(z / 146097);
    const doe = z - era * 146097;
    const yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
    const doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
    const mp = Math.floor((5 * doy + 2) / 153);
    const d = doy - Math.floor((153 * mp + 2) / 5) + 1;
    const m = mp < 10 ? mp + 3 : mp - 9;
    return make(m <= 2 ? yoe + era * 400 + 1 : yoe + era * 400, m, d);
}

// 0 = Sunday ... 6 = Saturday (same as Date.getDay()).
function dayOfWeek(date) {
    // 1970-01-01 was a Thursday.
    return ((toDayNumber(date) + 4) % 7 + 7) % 7;
}

// 1-based day of the year.
function dayOfYear(date) {
    return toDayNumber(date) - toDayNumber(make(date.y, 1, 1)) + 1;
}

function addDays(date, n) {
    return fromDayNumber(toDayNumber(date) + n);
}

// Moves by whole months, clamping the day (Jan 31 + 1 month = Feb 28/29).
function addMonths(date, n) {
    const index = date.y * 12 + (date.m - 1) + n;
    const y = Math.floor(index / 12);
    const m = index - y * 12 + 1;
    return make(y, m, Math.min(date.d, daysInMonth(y, m)));
}

function compare(a, b) {
    return toDayNumber(a) - toDayNumber(b);
}

function equals(a, b) {
    return a.y === b.y && a.m === b.m && a.d === b.d;
}

// Stable map key, e.g. "2024-03-09".
function key(date) {
    return String(date.y).padStart(4, "0") + "-"
        + String(date.m).padStart(2, "0") + "-"
        + String(date.d).padStart(2, "0");
}

// First day of the week containing `date`, for a week starting on `weekStart` (0-6).
function startOfWeek(date, weekStart) {
    return addDays(date, -((dayOfWeek(date) - weekStart + 7) % 7));
}

// Reads the local calendar date from a JS Date (e.g. `new Date()` for today).
function fromJsDate(jsDate) {
    return make(jsDate.getFullYear(), jsDate.getMonth() + 1, jsDate.getDate());
}

// Builds a JS Date at local noon, which is safe to hand to Qt date formatting.
function toJsDate(date) {
    // The Date constructor maps years 0-99 to 1900-1999; set the year explicitly.
    const js = new Date(2000, 0, 1, 12, 0, 0);
    js.setFullYear(date.y, date.m - 1, date.d);
    return js;
}
