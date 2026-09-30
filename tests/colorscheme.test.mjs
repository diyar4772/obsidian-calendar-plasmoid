// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { load } from "./qmljs.mjs";

const C = load("colorscheme.js");

const SCHEME = `# comment
[Colors:Selection]
BackgroundNormal=61,174,233
ForegroundNormal=255,255,255

[Colors:View]
BackgroundAlternate=239,240,241
BackgroundNormal=252,252,252
ForegroundInactive=112,125,138
ForegroundNormal=35,38,41

[Colors:Window]
BackgroundNormal=239,240,241
ForegroundNormal=35,38,41

[General]
ColorScheme=Test
Name=Test Light
Name[tr]=Deneme Açık
`;

test("parseColor()", () => {
    assert.equal(C.parseColor("61,174,233"), "#3daee9");
    assert.equal(C.parseColor(" 0, 0 ,0 "), "#000000");
    assert.equal(C.parseColor("61,174,233,128"), "#803daee9");
    assert.equal(C.parseColor("61,174,233,255"), "#3daee9");
    assert.equal(C.parseColor("#3DAEE9"), "#3daee9");
    assert.equal(C.parseColor("300,0,0"), "#ff0000");
    assert.equal(C.parseColor("red"), "");
    assert.equal(C.parseColor("1,2"), "");
    assert.equal(C.parseColor(""), "");
    assert.equal(C.parseColor(undefined), "");
});

test("parseIni()", () => {
    const ini = C.parseIni("a=1\n[G]\nk = v=w\n; c\n[H]\r\nx=y\n[G]\nz=1\n");
    assert.deepEqual(JSON.parse(JSON.stringify(ini)), { G: { k: "v=w", z: "1" }, H: { x: "y" } });
});

test("parseIni() can't pollute Object.prototype", () => {
    const ini = C.parseIni("[__proto__]\nreviewProbe=present\n[constructor]\nprototype=x\n[G]\n__proto__=y\n");
    assert.equal(({}).reviewProbe, undefined);
    assert.equal(ini["__proto__"].reviewProbe, "present");
    assert.equal(ini.G["__proto__"], "y");
    assert.equal(C.parse("[__proto__]\nBackgroundNormal=1,2,3\n", "en"), null);
    assert.equal(({}).BackgroundNormal, undefined);
});

test("parse() extracts the widget's colors and localized name", () => {
    const s = C.parse(SCHEME, "tr_TR");
    assert.deepEqual(s, {
        name: "Deneme Açık",
        backgroundColor: "#fcfcfc",
        alternateBackgroundColor: "#eff0f1",
        textColor: "#232629",
        disabledTextColor: "#707d8a",
        highlightColor: "#3daee9",
        highlightedTextColor: "#ffffff",
        windowBackgroundColor: "#eff0f1"
    });
    assert.equal(C.parse(SCHEME, "en_US").name, "Test Light");
    assert.equal(C.parse(SCHEME + "AccentColor=146,110,228\n", "en").highlightColor, "#926ee4");
});

test("parse() rejects files that aren't color schemes", () => {
    assert.equal(C.parse("", "en"), null);
    assert.equal(C.parse("[General]\nName=x\n", "en"), null);
    assert.equal(C.parse("not ini at all", "en"), null);
});

test("installed Breeze schemes parse", { skip: !existsSync("/usr/share/color-schemes/BreezeDark.colors") }, () => {
    const out = spawnSync("/bin/sh", ["-c", C.listCommand(["/nonexistent", "/usr/share/color-schemes"])], { encoding: "utf8" });
    assert.equal(out.status, 0);
    const list = C.parseList(out.stdout, "en");
    const dark = list.find((s) => s.file === "BreezeDark.colors");
    assert.equal(dark.name, "Breeze Dark");
    const read = spawnSync("/bin/sh", ["-c", C.readCommand(dark.path)], { encoding: "utf8" });
    const scheme = C.parse(read.stdout, "en");
    assert.equal(scheme.highlightColor, "#3daee9");
    assert.equal(scheme.textColor, "#fcfcfc");
});

test("listCommand() lists user schemes first and skips duplicates and junk", (t) => {
    const root = mkdtempSync(join(tmpdir(), "obsidian-calendar-schemes-"));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    const user = join(root, "user dir 'ü'");
    const system = join(root, "system");
    mkdirSync(user);
    mkdirSync(system);
    writeFileSync(join(user, "Same.colors"), SCHEME.replace("Name=Test Light", "Name=Mine"));
    writeFileSync(join(system, "Same.colors"), SCHEME.replace("Name=Test Light", "Name=System"));
    writeFileSync(join(system, "Other.colors"), SCHEME.replace("Name=Test Light", "Name=Another"));
    writeFileSync(join(system, "Broken.colors"), "garbage");
    const out = spawnSync("/bin/sh", ["-c", C.listCommand([user, system])], { encoding: "utf8" });
    const list = C.parseList(out.stdout, "en");
    assert.deepEqual(list.map((s) => s.name), ["Another", "Mine"]);
    assert.equal(list[1].path, join(user, "Same.colors"));
    assert.equal(C.listCommand([]), null);
    assert.equal(C.listCommand(["a\0b"]), null);
    assert.equal(C.readCommand("a\0b"), null);
});
