/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// Non-fatal problems shown above the calendar: broken config files,
// unsupported formats, a daily-notes folder that doesn't exist yet.
Kirigami.InlineMessage {
    id: message

    property VaultScanner scanner

    readonly property var lines: {
        const out = [];
        if (!scanner || scanner.status !== "ready") {
            return out;
        }
        for (let i = 0; i < scanner.problems.length; i++) {
            out.push(problemText(scanner.problems[i]));
        }
        if (scanner.dailyFolderMissing) {
            out.push(i18nc("@info %1 is a folder inside the vault", "The daily notes folder “%1” doesn't exist yet.",
                           scanner.settings.daily.folder));
        }
        return out;
    }

    function problemText(p) {
        switch (p.code) {
        case "malformed-json":
            return i18nc("@info %1 is a file name", "%1 isn't valid JSON, so it was ignored.", ".obsidian/" + p.file);
        case "invalid-config":
            return i18nc("@info %1 is a file name", "%1 has an unexpected structure, so it was ignored.", ".obsidian/" + p.file);
        case "unsupported-token":
            return p.file === "weekly"
                ? i18nc("@info %1 lists date format tokens", "The weekly note format uses tokens this widget doesn't support: %1", p.detail)
                : i18nc("@info %1 lists date format tokens", "The daily note format uses tokens this widget doesn't support: %1", p.detail);
        case "invalid-folder":
            return i18nc("@info %1 is a folder", "The folder “%1” is outside the vault.", p.detail);
        case "invalid-format":
            return i18nc("@info %1 is a date format", "The note format “%1” doesn't produce a valid file name.", p.detail);
        default:
            return p.code;
        }
    }

    visible: lines.length > 0
    type: scanner && scanner.problems.length > 0 ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information
    text: lines.join("\n")
}
