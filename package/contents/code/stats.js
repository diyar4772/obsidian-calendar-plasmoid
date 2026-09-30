.pragma library
.import "dates.js" as Dates

const MAX_DOTS = 5;

function clamp(n, lo, hi) {
    return Math.min(Math.max(lo, n), hi);
}

// Dots for a note, as in the Calendar plugin's getWordLengthAsDots(): one dot
// per `wordsPerDot` words, at least 1 and at most 5. A non-positive
// `wordsPerDot` turns dots off (0).
function dotsForWords(words, wordsPerDot) {
    if (!(wordsPerDot > 0)) {
        return 0;
    }
    return clamp(Math.floor(words / wordsPerDot), 1, MAX_DOTS);
}

// Alternative to word counts: 1-5 dots from file size on a log scale, relative
// to the largest of `sizes` (usually the notes in the visible month).
// Returns an array parallel to `sizes`.
function dotsForSizes(sizes) {
    let max = 0;
    for (let i = 0; i < sizes.length; i++) {
        max = Math.max(max, sizes[i]);
    }
    const scale = Math.log(1 + max);
    return sizes.map(function (size) {
        return scale > 0 ? clamp(Math.ceil(MAX_DOTS * Math.log(1 + size) / scale), 1, MAX_DOTS) : 1;
    });
}

// Current streak of consecutive days with a note, ending today. When today
// has no note yet, the streak ending yesterday still counts (it can go on).
// `hasNote(date)` tells whether a day has a note; `limit` caps the search.
// Returns { length, includesToday }.
function streak(hasNote, today, limit) {
    const max = limit === undefined ? 36600 : limit;
    const includesToday = hasNote(today);
    let day = includesToday ? today : Dates.addDays(today, -1);
    let length = 0;
    while (length < max && hasNote(day)) {
        length++;
        day = Dates.addDays(day, -1);
    }
    return { length: length, includesToday: includesToday };
}

// Number of days in month (y, m) that have a note.
function countInMonth(hasNote, y, m) {
    let count = 0;
    const days = Dates.daysInMonth(y, m);
    for (let d = 1; d <= days; d++) {
        if (hasNote(Dates.make(y, m, d))) {
            count++;
        }
    }
    return count;
}
