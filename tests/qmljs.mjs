// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Loads QML JavaScript resources (`.pragma library` files) in Node.
//
// QML JS files aren't ES modules: they start with `.pragma library`, pull in
// other files with `.import "file.js" as Name`, and expose every top-level
// declaration. This loader strips those directives, loads the imports
// recursively and returns the file's top-level functions and constants.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const CODE_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "../package/contents/code");

const cache = new Map();

export function load(name) {
    const path = join(CODE_DIR, name);
    if (cache.has(path)) {
        return cache.get(path);
    }

    const source = readFileSync(path, "utf8");
    const imports = [];
    const body = source.split("\n").map((line) => {
        if (/^\.pragma\s+library\s*$/.test(line)) {
            return "";
        }
        const imp = /^\.import\s+"([^"]+\.js)"\s+as\s+(\w+)\s*$/.exec(line);
        if (imp) {
            imports.push({ file: imp[1], alias: imp[2] });
            return "";
        }
        if (line.startsWith(".")) {
            throw new Error(`${name}: unsupported directive: ${line}`);
        }
        return line;
    }).join("\n");

    const names = new Set();
    for (const m of body.matchAll(/^(?:function\s+(\w+)|(?:var|let|const)\s+(\w+))/gm)) {
        names.add(m[1] ?? m[2]);
    }

    const factory = new Function(
        ...imports.map((i) => i.alias),
        `"use strict";\n${body}\nreturn { ${[...names].join(", ")} };`
    );
    const module = Object.freeze(factory(...imports.map((i) => load(i.file))));
    cache.set(path, module);
    return module;
}
