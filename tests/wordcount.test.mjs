// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";
import * as WordCount from "../package/contents/code/wordcount.mjs";



// Expected counts match the Calendar plugin's getWordCount().
test("countWords() matches the Calendar plugin", () => {
    assert.equal(WordCount.countWords(""), 0);
    assert.equal(WordCount.countWords("Hello world"), 2);
    assert.equal(WordCount.countWords("Bugün çalışma günlüğü yazdım."), 4);
    assert.equal(WordCount.countWords("well-known e-mail"), 2);
    assert.equal(WordCount.countWords("3.14 1,000,000 x2"), 3);
    // The list marker "-" counts as a word in the plugin too.
    assert.equal(WordCount.countWords("- [ ] task #tag [[Link|alias]] **bold**"), 6);
    assert.equal(WordCount.countWords("Привет мир αβγ"), 3);
    assert.equal(WordCount.countWords("  \n\t "), 0);
});

test("countWords() keeps the plugin's CJK behavior", () => {
    // The plugin's kana/CJK alternative lacks [brackets], so it doesn't match.
    assert.equal(WordCount.countWords("日本語"), 0);
    assert.equal(WordCount.countWords("日本語 and English"), 2);
});

test("stripFrontmatter()", () => {
    assert.equal(WordCount.stripFrontmatter("---\ntags: [a, b]\ndate: 2024-03-09\n---\nBody text"), "Body text");
    assert.equal(WordCount.stripFrontmatter("---\r\ntitle: x\r\n---\r\nBody"), "Body");
    assert.equal(WordCount.stripFrontmatter("﻿---\nx: 1\n...\nBody"), "Body");
    assert.equal(WordCount.stripFrontmatter("---\n---\nBody"), "Body");
    assert.equal(WordCount.stripFrontmatter("---\ntitle: x\n---"), "");
    // Not frontmatter: not on the first line, or never closed
    assert.equal(WordCount.stripFrontmatter("Intro\n---\nx: 1\n---\n"), "Intro\n---\nx: 1\n---\n");
    assert.equal(WordCount.stripFrontmatter("---\nno end"), "---\nno end");
    // A horizontal rule later in the body stays
    assert.equal(WordCount.stripFrontmatter("---\na: 1\n---\nText\n\n---\n\nMore"), "Text\n\n---\n\nMore");
});

test("noteWords() ignores frontmatter", () => {
    assert.equal(WordCount.noteWords("---\ntags: [daily, journal]\nmood: good\n---\nThree words here"), 3);
});
