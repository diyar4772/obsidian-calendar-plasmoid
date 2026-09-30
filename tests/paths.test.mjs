// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { load } from "./qmljs.mjs";

const P = load("paths.js");
const CONFIG_FILES = load("obsidianconfig.js").configFiles();

// Every shell the command might run under.
const SHELLS = ["/bin/sh", "/bin/bash", "/bin/dash", "/usr/bin/dash"].filter(existsSync);

function run(shell, command) {
    const r = spawnSync(shell, ["-c", command], { encoding: "utf8" });
    return { status: r.status, stdout: r.stdout };
}

const NASTY = [
    "plain",
    "with space",
    "Örnek Vault",
    "it's",
    "''",
    "$(touch PWNED)",
    "`touch PWNED`",
    "a;touch PWNED",
    "\"double\" & | > <",
    "back\\slash",
    "new\nline",
    "tab\there",
    "-dash-first",
    "日本語 ノート",
    "emoji 📓",
    "*glob?[x]"
];

test("shellQuote() round-trips through every shell", () => {
    for (const shell of SHELLS) {
        for (const s of NASTY) {
            const out = execFileSync(shell, ["-c", `printf '%s' ${P.shellQuote(s)}`], { encoding: "utf8" });
            assert.equal(out, s, `${shell}: ${JSON.stringify(s)}`);
        }
    }
});

test("shellQuote() escapes single quotes and rejects NUL", () => {
    assert.equal(P.shellQuote("it's"), "'it'\\''s'");
    assert.equal(P.shellQuote("Örnek Vault"), "'Örnek Vault'");
    assert.equal(P.shellQuote("a\0b"), null);
});

test("joinPath() and notePath()", () => {
    assert.equal(P.joinPath("/home/u/Vault/", "/70 - Journal//71 - Daily/", "x.md"), "/home/u/Vault/70 - Journal/71 - Daily/x.md");
    assert.equal(P.joinPath("", "x.md"), "x.md");
    assert.equal(P.notePath("", "2024-03-09"), "2024-03-09.md");
    assert.equal(P.notePath("Daily", "2024/03/2024-03-09"), "Daily/2024/03/2024-03-09.md");
    assert.equal(P.notePath("Daily", "2024-03-09.md"), "Daily/2024-03-09.md");
});

test("localPath() accepts paths, ~ and file:// URLs", () => {
    assert.equal(P.localPath("/home/u/Vault/", "/home/u"), "/home/u/Vault");
    assert.equal(P.localPath("~/Masaüstü/Örnek Vault", "/home/u"), "/home/u/Masaüstü/Örnek Vault");
    assert.equal(P.localPath("file:///home/u/Masa%C3%BCst%C3%BC/%C3%96rnek%20Vault", "/home/u"), "/home/u/Masaüstü/Örnek Vault");
    assert.equal(P.localPath("relative/path", "/home/u"), "");
    assert.equal(P.localPath("file:///bad%E0%A4%A", "/home/u"), "");
    assert.equal(P.localPath("", "/home/u"), "");
});

test("fileUrl() round-trips through localPath()", () => {
    const path = "/home/u/Masaüstü/Örnek Vault/it's #1 ?%";
    assert.equal(P.fileUrl("/home/u/Örnek Vault"), "file:///home/u/%C3%96rnek%20Vault");
    assert.equal(P.localPath(P.fileUrl(path), "/home/u"), path);
});

test("vaultName()", () => {
    assert.equal(P.vaultName("/home/u/Masaüstü/Örnek Vault"), "Örnek Vault");
    assert.equal(P.vaultName("/home/u/Vault/"), "Vault");
});

test("searchDepth() follows slashes in the format", () => {
    assert.equal(P.searchDepth("YYYY-MM-DD"), 1);
    assert.equal(P.searchDepth("YYYY/MM/YYYY-MM-DD"), 3);
    assert.equal(P.searchDepth("[Journal/]YYYY-MM-DD"), 2);
    assert.equal(P.searchDepth("YYYY/[W]ww"), 2);
});

test("URIs percent-encode spaces, slashes and non-ASCII", () => {
    assert.equal(P.openUri("/home/u/Masaüstü/Örnek Vault/70 - Journal/2024-03-09.md"),
        "obsidian://open?path=%2Fhome%2Fu%2FMasa%C3%BCst%C3%BC%2F%C3%96rnek%20Vault%2F70%20-%20Journal%2F2024-03-09.md");
    assert.equal(P.dailyUri("Örnek Vault"), "obsidian://daily?vault=%C3%96rnek%20Vault");
    assert.equal(P.vaultUri("Örnek Vault"), "obsidian://open?vault=%C3%96rnek%20Vault");
    assert.equal(P.newUri("Örnek Vault", "70 - Journal/71 - Daily/2024-03-09.md"),
        "obsidian://new?vault=%C3%96rnek%20Vault&file=70%20-%20Journal%2F71%20-%20Daily%2F2024-03-09.md");
    assert.equal(P.openUri("/v/a&b=c?#%.md"), "obsidian://open?path=%2Fv%2Fa%26b%3Dc%3F%23%25.md");
    // Round trip
    const path = "/home/u/日本語 ノート/it's #1 & 100%.md";
    assert.equal(decodeURIComponent(P.openUri(path).split("path=")[1]), path);
});

test("parseListOutput() handles every byte a file name may contain", () => {
    const names = ["a b.md", "new\nline.md", "sp ace/x.md", "Günlük/2024-03-09.md", "0 1 2.md"];
    const text = names.map((n, i) => `${100 + i} 1709643845.5 ${n}\0`).join("");
    const files = P.parseListOutput(text);
    assert.deepEqual(Object.keys(files), names);
    assert.deepEqual(files["0 1 2.md"], { size: 104, mtime: 1709643845.5 });
    assert.deepEqual(P.parseListOutput(""), {});
});

test("commands work on hostile directory names and never run injected code", (t) => {
    const root = mkdtempSync(join(tmpdir(), "obsidian-calendar-"));
    t.after(() => rmSync(root, { recursive: true, force: true }));

    for (const shell of SHELLS) {
        for (const name of NASTY) {
            const vault = join(root, shell.replace(/\//g, "_"), name);
            const folder = join(vault, "70 - Journal", "71 - Daily");
            mkdirSync(join(vault, ".obsidian", "plugins", "calendar"), { recursive: true });
            mkdirSync(join(folder, "2024", "03"), { recursive: true });
            writeFileSync(join(vault, ".obsidian", "daily-notes.json"), '{"folder": "70 - Journal/71 - Daily"}');
            writeFileSync(join(vault, ".obsidian", "plugins", "calendar", "data.json"), '{"wordsPerDot": 100}');
            writeFileSync(join(folder, "2024-03-09.md"), "---\ntags: [a]\n---\nHello Günlük world");
            writeFileSync(join(folder, `${name.replace(/\//g, "_")}.md`), "odd name");
            writeFileSync(join(folder, "2024", "03", "2024-03-10.md"), "nested");
            writeFileSync(join(folder, "ignored.txt"), "not markdown");

            const config = run(shell, P.configCommand(vault, CONFIG_FILES));
            assert.equal(config.status, 0, `${shell} ${name}`);
            assert.deepEqual(P.parseConfigOutput(config.stdout), {
                "daily-notes.json": '{"folder": "70 - Journal/71 - Daily"}',
                "plugins/calendar/data.json": '{"wordsPerDot": 100}'
            });

            const list = run(shell, P.listCommand(folder, 3));
            assert.equal(list.status, 0);
            const files = P.parseListOutput(list.stdout);
            assert.deepEqual(Object.keys(files).sort(),
                ["2024-03-09.md", "2024/03/2024-03-10.md", `${name.replace(/\//g, "_")}.md`].sort());
            assert.equal(files["2024-03-09.md"].size, Buffer.byteLength("---\ntags: [a]\n---\nHello Günlük world"));

            const shallow = P.parseListOutput(run(shell, P.listCommand(folder, 1)).stdout);
            assert.ok(!("2024/03/2024-03-10.md" in shallow), "depth limit");

            const read = run(shell, P.readCommand(folder, ["2024-03-09.md", "2024/03/2024-03-10.md", "missing.md"]));
            assert.deepEqual(P.parseReadOutput(read.stdout), {
                "2024-03-09.md": "---\ntags: [a]\n---\nHello Günlük world",
                "2024/03/2024-03-10.md": "nested",
                "missing.md": ""
            });
        }
        assert.ok(!existsSync(join(process.cwd(), "PWNED")) && !existsSync(join(root, "PWNED")), "injection");
    }
});

test("commands report missing vault, missing .obsidian and missing folder", (t) => {
    const root = mkdtempSync(join(tmpdir(), "obsidian-calendar-"));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    mkdirSync(join(root, "not a vault"));

    assert.equal(run("/bin/sh", P.configCommand(join(root, "missing"), CONFIG_FILES)).status, P.EXIT_NO_VAULT);
    assert.equal(run("/bin/sh", P.configCommand(join(root, "not a vault"), CONFIG_FILES)).status, P.EXIT_NOT_A_VAULT);
    assert.equal(run("/bin/sh", P.listCommand(join(root, "missing"), 1)).status, P.EXIT_NO_FOLDER);
    assert.equal(run("/bin/sh", P.readCommand(join(root, "missing"), ["a.md"])).status, P.EXIT_NO_FOLDER);
});

test("NUL bytes inside files can't break parsing", (t) => {
    const root = mkdtempSync(join(tmpdir(), "obsidian-calendar-"));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    writeFileSync(join(root, "a.md"), "one\0two");
    writeFileSync(join(root, "b.md"), "three");
    const out = run("/bin/sh", P.readCommand(root, ["a.md", "b.md"])).stdout;
    assert.deepEqual(P.parseReadOutput(out), { "a.md": "onetwo", "b.md": "three" });
});

test("builders refuse NUL in paths and clamp depth", () => {
    assert.equal(P.configCommand("/a\0b", CONFIG_FILES), null);
    assert.equal(P.configCommand("/a", ["x\0"]), null);
    assert.equal(P.listCommand("/a\0b", 1), null);
    assert.equal(P.readCommand("/a", ["x\0.md"]), null);
    assert.equal(P.readCommand("/a", []), null);
    assert.match(P.listCommand("/a", 99), /-maxdepth 8 /);
    assert.match(P.listCommand("/a", 0), /-maxdepth 1 /);
});
