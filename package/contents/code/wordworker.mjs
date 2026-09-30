// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// Counts words off the GUI thread (a WorkerScript). Long notes take a while
// in QML's JavaScript engine, and the widget must stay responsive.
//
// In:  { id, output }  output of paths.readCommand(): "path\0contents\0"...
// Out: { id, words }   { "relative/path.md": words } for every file read

import { noteWords } from "./wordcount.mjs";

WorkerScript.onMessage = function (message) {
    const words = {};
    const fields = String(message.output).split("\0");
    for (let i = 0; i + 1 < fields.length; i += 2) {
        words[fields[i]] = noteWords(fields[i + 1]);
    }
    WorkerScript.sendMessage({ id: message.id, words: words });
};
