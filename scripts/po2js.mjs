// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Turns po/*.po into package/contents/code/catalogs.js, the translations the
// widget uses when its language setting differs from the desktop's (see
// package/contents/code/translate.js). Run by scripts/i18n.sh.
//
//   node scripts/po2js.mjs <out.js> <lang.po>...

import { readFileSync, writeFileSync } from "node:fs";
import { basename } from "node:path";
import { pathToFileURL } from "node:url";

function unquote(s) {
    return JSON.parse(s.replace(/\\([^"\\nt])/g, (m, c) => (c === "'" || c === "?" ? c : m)));
}

// Parses a .po file into entries { context, id, idPlural, strings, fuzzy }.
// Obsolete (#~) entries are skipped.
export function parsePo(text) {
    const entries = [];
    let entry = null;
    let field = null;
    let fuzzy = false;
    const finish = () => {
        if (entry) {
            entries.push(entry);
        }
        entry = null;
        field = null;
    };
    for (const raw of text.split("\n")) {
        const line = raw.trim();
        if (line === "") {
            finish();
            fuzzy = false;
            continue;
        }
        if (line.startsWith("#~")) {
            continue;
        }
        if (line.startsWith("#")) {
            if (line.startsWith("#,") && /\bfuzzy\b/.test(line)) {
                fuzzy = true;
            }
            continue;
        }
        const m = /^(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+(".*")$/.exec(line);
        if (m) {
            if (m[1] === "msgctxt" || (m[1] === "msgid" && entry && entry.id !== null)) {
                finish();
            }
            entry = entry || { context: null, id: null, idPlural: null, strings: [], fuzzy };
            const value = unquote(m[3]);
            if (m[1] === "msgctxt") {
                entry.context = value;
                field = { name: "context" };
            } else if (m[1] === "msgid") {
                entry.id = value;
                field = { name: "id" };
            } else if (m[1] === "msgid_plural") {
                entry.idPlural = value;
                field = { name: "idPlural" };
            } else {
                const index = m[2] === undefined ? 0 : Number(m[2]);
                entry.strings[index] = value;
                field = { name: "strings", index };
            }
        } else if (line.startsWith("\"") && field) {
            const value = unquote(line);
            if (field.name === "strings") {
                entry.strings[field.index] += value;
            } else {
                entry[field.name] += value;
            }
        } else {
            throw new Error(`unexpected line: ${raw}`);
        }
    }
    finish();
    return entries;
}

// The C expression of a Plural-Forms header, checked to be plain arithmetic
// on n so it can be emitted as JavaScript.
export function pluralExpression(header) {
    const m = /plural=([^;\n]+);?/.exec(header);
    const expr = m ? m[1].trim() : "n != 1";
    if (!/^[n0-9\s()<>=!&|?:%+\-*/]+$/.test(expr)) {
        throw new Error(`unsupported plural formula: ${expr}`);
    }
    return expr;
}

// { plural, messages } for one language: fuzzy and untranslated entries are
// left out, so the widget falls back to English for them like KI18n does.
export function catalogFor(text) {
    const entries = parsePo(text);
    const header = entries.find((e) => e.id === "" && e.context === null);
    const messages = {};
    for (const e of entries) {
        if (e.id === "" || e.fuzzy || e.strings.length === 0 || e.strings.some((s) => !s)) {
            continue;
        }
        messages[(e.context ?? "") + "\u0004" + e.id] = e.strings;
    }
    return { plural: pluralExpression(header ? header.strings[0] : ""), messages };
}

export function generate(files) {
    // REUSE-IgnoreStart
    const lines = [
        ".pragma library",
        "",
        "// SPDX-FileCopyrightText: 2026 Samed Yolcu",
        "// SPDX-License-Identifier: GPL-2.0-or-later",
        // REUSE-IgnoreEnd
        "",
        "// Generated from po/*.po by scripts/i18n.sh (scripts/po2js.mjs); don't edit.",
        "// Translations used when the widget's language differs from the desktop's.",
        "",
        "const CATALOGS = {"
    ];
    const langs = Object.keys(files).sort();
    langs.forEach((lang, i) => {
        const catalog = catalogFor(files[lang]);
        const keys = Object.keys(catalog.messages).sort();
        lines.push(`    ${JSON.stringify(lang)}: {`);
        lines.push(`        plural: function (n) { return Number(${catalog.plural}); },`);
        lines.push("        messages: {");
        keys.forEach((k, j) => {
            lines.push(`            ${JSON.stringify(k)}: ${JSON.stringify(catalog.messages[k])}${j < keys.length - 1 ? "," : ""}`);
        });
        lines.push("        }");
        lines.push(`    }${i < langs.length - 1 ? "," : ""}`);
    });
    lines.push("};", "");
    return lines.join("\n");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    const [out, ...pos] = process.argv.slice(2);
    const files = {};
    for (const po of pos) {
        files[basename(po, ".po")] = readFileSync(po, "utf8");
    }
    writeFileSync(out, generate(files));
}
