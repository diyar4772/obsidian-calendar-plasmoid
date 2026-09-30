import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./qmljs.mjs";

const W = load("wordcount.js");

// Expected counts match the Calendar plugin's getWordCount().
test("countWords() matches the Calendar plugin", () => {
    assert.equal(W.countWords(""), 0);
    assert.equal(W.countWords("Hello world"), 2);
    assert.equal(W.countWords("Bugün çalışma günlüğü yazdım."), 4);
    assert.equal(W.countWords("well-known e-mail"), 2);
    assert.equal(W.countWords("3.14 1,000,000 x2"), 3);
    // The list marker "-" counts as a word in the plugin too.
    assert.equal(W.countWords("- [ ] task #tag [[Link|alias]] **bold**"), 6);
    assert.equal(W.countWords("Привет мир αβγ"), 3);
    assert.equal(W.countWords("  \n\t "), 0);
});

test("countWords() keeps the plugin's CJK behavior", () => {
    // The plugin's kana/CJK alternative lacks [brackets], so it doesn't match.
    assert.equal(W.countWords("日本語"), 0);
    assert.equal(W.countWords("日本語 and English"), 2);
});

test("stripFrontmatter()", () => {
    assert.equal(W.stripFrontmatter("---\ntags: [a, b]\ndate: 2024-03-09\n---\nBody text"), "Body text");
    assert.equal(W.stripFrontmatter("---\r\ntitle: x\r\n---\r\nBody"), "Body");
    assert.equal(W.stripFrontmatter("﻿---\nx: 1\n...\nBody"), "Body");
    assert.equal(W.stripFrontmatter("---\n---\nBody"), "Body");
    assert.equal(W.stripFrontmatter("---\ntitle: x\n---"), "");
    // Not frontmatter: not on the first line, or never closed
    assert.equal(W.stripFrontmatter("Intro\n---\nx: 1\n---\n"), "Intro\n---\nx: 1\n---\n");
    assert.equal(W.stripFrontmatter("---\nno end"), "---\nno end");
    // A horizontal rule later in the body stays
    assert.equal(W.stripFrontmatter("---\na: 1\n---\nText\n\n---\n\nMore"), "Text\n\n---\n\nMore");
});

test("noteWords() ignores frontmatter", () => {
    assert.equal(W.noteWords("---\ntags: [daily, journal]\nmood: good\n---\nThree words here"), 3);
});
