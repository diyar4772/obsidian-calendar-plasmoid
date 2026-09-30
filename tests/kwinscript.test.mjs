// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Runs the KWin script that brings Obsidian to the front against a fake
// KWin workspace.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = readFileSync(resolve(dirname(fileURLToPath(import.meta.url)),
    "../package/contents/kwin/activate-obsidian.js"), "utf8");

function window(resourceClass, extra = {}) {
    return { resourceClass, resourceName: resourceClass, desktopFileName: resourceClass,
             normalWindow: true, minimized: false, demandsAttention: false, ...extra };
}

function fakeWorkspace(stackingOrder) {
    const handlers = [];
    return {
        stackingOrder,
        activeWindow: null,
        handlers,
        windowAdded: {
            connect: (f) => handlers.push(f),
            disconnect: (f) => handlers.splice(handlers.indexOf(f), 1)
        }
    };
}

function runScript(workspace) {
    new Function("workspace", SCRIPT)(workspace);
}

test("activates the topmost Obsidian window, native or Flatpak", () => {
    for (const cls of ["obsidian", "md.obsidian.Obsidian"]) {
        const a = window(cls);
        const b = window(cls);
        const ws = fakeWorkspace([window("org.kde.konsole"), a, b, window("org.kde.dolphin")]);
        runScript(ws);
        assert.equal(ws.activeWindow, b, cls);
    }
});

test("prefers the Obsidian window that asks for attention and restores it", () => {
    const wanted = window("obsidian", { demandsAttention: true, minimized: true });
    const ws = fakeWorkspace([wanted, window("obsidian")]);
    runScript(ws);
    assert.equal(ws.activeWindow, wanted);
    assert.equal(wanted.minimized, false);
});

test("ignores other applications, dialogs and similar names", () => {
    const ws = fakeWorkspace([window("obsidian", { normalWindow: false }), window("obsidian-notes"),
                              window("org.kde.kwrite")]);
    runScript(ws);
    assert.equal(ws.activeWindow, null);
});

test("waits for a starting Obsidian's first window", () => {
    const ws = fakeWorkspace([window("org.kde.konsole")]);
    runScript(ws);
    assert.equal(ws.handlers.length, 1);
    ws.handlers[0](window("org.kde.dolphin"));
    assert.equal(ws.activeWindow, null);
    const started = window("md.obsidian.Obsidian");
    ws.handlers[0](started);
    assert.equal(ws.activeWindow, started);
    assert.equal(ws.handlers.length, 0);
});
