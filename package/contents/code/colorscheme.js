.pragma library
.import "paths.js" as Paths

// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// KDE color schemes (*.colors, as in /usr/share/color-schemes), so the widget
// can use a different scheme than the desktop, e.g. Breeze Light on a dark
// desktop. Only reads files; nothing is changed system-wide.

// Parses INI text into { "Group": { key: value } }. Later groups/keys win.
function parseIni(text) {
    // Prototype-free maps: a "[__proto__]" group must stay a plain group.
    const result = Object.create(null);
    let group = null;
    const lines = String(text).split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line === "" || line.charAt(0) === "#" || line.charAt(0) === ";") {
            continue;
        }
        const header = /^\[(.*)\]$/.exec(line);
        if (header) {
            group = header[1];
            if (!Object.prototype.hasOwnProperty.call(result, group)) {
                result[group] = Object.create(null);
            }
            continue;
        }
        const eq = line.indexOf("=");
        if (group !== null && eq > 0) {
            result[group][line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
        }
    }
    return result;
}

function hex2(n) {
    return ("0" + Math.max(0, Math.min(255, Math.round(n))).toString(16)).slice(-2);
}

// "61,174,233", "61,174,233,128" or "#3daee9" -> "#3daee9" (or "#803daee9"
// with alpha, Qt's #AARRGGBB). Returns "" for anything else.
function parseColor(value) {
    const s = String(value || "").trim();
    if (/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s)) {
        return s.toLowerCase();
    }
    const parts = s.split(",");
    if (parts.length < 3 || parts.length > 4) {
        return "";
    }
    const n = [];
    for (let i = 0; i < parts.length; i++) {
        if (!/^\s*\d{1,3}\s*$/.test(parts[i])) {
            return "";
        }
        n.push(parseInt(parts[i], 10));
    }
    const rgb = hex2(n[0]) + hex2(n[1]) + hex2(n[2]);
    return n.length === 4 && n[3] !== 255 ? "#" + hex2(n[3]) + rgb : "#" + rgb;
}

// Localized scheme name: Name[tr_TR], Name[tr], then Name.
function schemeName(ini, language) {
    const general = ini["General"] || Object.create(null);
    const lang = String(language || "").replace("-", "_");
    return general["Name[" + lang + "]"] || general["Name[" + lang.split("_")[0] + "]"] || general["Name"] || "";
}

// Colors the widget needs from a scheme, as "#rrggbb" strings, or null if
// the text isn't a usable color scheme.
function parse(text, language) {
    const ini = parseIni(text);
    const empty = Object.create(null);
    const view = ini["Colors:View"] || empty;
    const win = ini["Colors:Window"] || empty;
    const sel = ini["Colors:Selection"] || empty;
    const general = ini["General"] || empty;
    const background = parseColor(view.BackgroundNormal) || parseColor(win.BackgroundNormal);
    const text_ = parseColor(view.ForegroundNormal) || parseColor(win.ForegroundNormal);
    if (!background || !text_) {
        return null;
    }
    const highlight = parseColor(general.AccentColor) || parseColor(sel.BackgroundNormal)
        || parseColor(view.DecorationFocus) || "#3daee9";
    return {
        name: schemeName(ini, language),
        backgroundColor: background,
        alternateBackgroundColor: parseColor(view.BackgroundAlternate) || background,
        textColor: text_,
        disabledTextColor: parseColor(view.ForegroundInactive) || text_,
        highlightColor: highlight,
        highlightedTextColor: parseColor(sel.ForegroundNormal) || background,
        windowBackgroundColor: parseColor(win.BackgroundNormal) || background
    };
}

// Prints every *.colors file in `dirs` as "path\0contents\0" pairs.
// Earlier directories win for identical file names (user dir first).
function listCommand(dirs) {
    const quoted = [];
    for (let i = 0; i < dirs.length; i++) {
        const q = Paths.shellQuote(dirs[i]);
        if (q === null) {
            return null;
        }
        quoted.push(q);
    }
    if (quoted.length === 0) {
        return null;
    }
    return "for d in " + quoted.join(" ") + "; do "
        + "[ -d \"$d\" ] || continue; "
        + "for f in \"$d\"/*.colors; do "
        + "[ -f \"$f\" ] || continue; "
        + "printf '%s\\0' \"$f\"; head -c 65536 -- \"$f\" | tr -d '\\000'; printf '\\0'; "
        + "done; done; exit 0";
}

// Parses listCommand() output into [{ path, file, name }], sorted by name,
// skipping files that aren't color schemes and duplicate file names.
function parseList(text, language) {
    const pairs = String(text).split("\0");
    const seen = {};
    const list = [];
    for (let i = 0; i + 1 < pairs.length; i += 2) {
        const path = pairs[i];
        const file = path.substring(path.lastIndexOf("/") + 1);
        if (seen[file]) {
            continue;
        }
        const scheme = parse(pairs[i + 1], language);
        if (scheme) {
            seen[file] = true;
            list.push({ path: path, file: file, name: scheme.name || file.replace(/\.colors$/, "") });
        }
    }
    list.sort(function (a, b) { return a.name.localeCompare(b.name); });
    return list;
}

function readCommand(path) {
    const q = Paths.shellQuote(path);
    return q === null ? null : "head -c 65536 -- " + q + " | tr -d '\\000'";
}
