/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

import "../code/paths.js" as Paths

// Non-fatal problems shown above the calendar: broken config files,
// unsupported formats, a daily-notes folder that doesn't exist yet.
Kirigami.InlineMessage {
    id: message

    property VaultScanner scanner
    readonly property Translator tr: Translator {}

    readonly property var lines: {
        const out = [];
        if (!scanner || scanner.status !== "ready") {
            return out;
        }
        for (let i = 0; i < scanner.problems.length; i++) {
            out.push(problemText(scanner.problems[i]));
        }
        if (scanner.dailyFolderMissing) {
            out.push(message.tr.ui18nc("@info %1 is a folder inside the vault", "The daily notes folder “%1” doesn't exist yet.",
                           Paths.plainText(scanner.settings.daily.folder)));
        }
        return out;
    }

    // Values from the vault go through Paths.plainText(): the message label
    // would render text with "<" as rich text.
    function problemText(p) {
        const detail = Paths.plainText(p.detail);
        const file = Paths.plainText(p.file);
        switch (p.code) {
        case "malformed-json":
            return message.tr.ui18nc("@info %1 is a file name", "%1 isn't valid JSON, so it was ignored.", ".obsidian/" + file);
        case "invalid-config":
            return message.tr.ui18nc("@info %1 is a file name", "%1 has an unexpected structure, so it was ignored.", ".obsidian/" + file);
        case "unsupported-token":
            return p.file === "weekly"
                ? message.tr.ui18nc("@info %1 lists date format tokens", "The weekly note format uses tokens this widget doesn't support: %1", detail)
                : message.tr.ui18nc("@info %1 lists date format tokens", "The daily note format uses tokens this widget doesn't support: %1", detail);
        case "invalid-folder":
            return message.tr.ui18nc("@info %1 is a folder", "The folder “%1” is outside the vault.", detail);
        case "invalid-format":
            return message.tr.ui18nc("@info %1 is a date format", "The note format “%1” doesn't produce a valid file name.", detail);
        case "folder-outside-vault":
            return p.file === "weekly"
                ? message.tr.ui18nc("@info", "The weekly notes folder links to a place outside the vault, so it isn't read.")
                : message.tr.ui18nc("@info", "The daily notes folder links to a place outside the vault, so it isn't read.");
        case "list-incomplete":
            return message.tr.ui18nc("@info %1 is an error message", "Some notes couldn't be listed: %1", detail);
        default:
            return Paths.plainText(p.code);
        }
    }

    visible: lines.length > 0
    type: scanner && scanner.problems.length > 0 ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information
    text: lines.join("\n")
}
