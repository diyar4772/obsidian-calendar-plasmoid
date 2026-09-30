/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../code/dateformat.js" as DateFormat
import "../code/dates.js" as Dates
import "../code/locales.js" as Locales
import "../code/obsidianconfig.js" as Config
import "../code/paths.js" as Paths

KCM.SimpleKCM {
    id: page

    property alias cfg_customDaily: customDaily.checked
    property alias cfg_dailyFolder: dailyFolder.text
    property alias cfg_dailyFormat: dailyFormat.text
    property alias cfg_customWeekly: customWeekly.checked
    property alias cfg_weeklyFolder: weeklyFolder.text
    property alias cfg_weeklyFormat: weeklyFormat.text
    property string cfg_noteLanguage
    property string cfg_emptyDayAction

    readonly property var systemLocale: Locales.forSystem(Qt.locale().name, Qt.locale().firstDayOfWeek)
    readonly property var today: Dates.fromJsDate(new Date())

    // Reads the saved vault to show what Obsidian is configured to use.
    VaultScanner {
        id: detector
        vaultPath: Paths.localPath(Plasmoid.configuration.vaultPath,
            Paths.localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString(), ""))
        systemLocale: page.systemLocale
        overrides: ({})
        dotSource: "none"
    }

    // Locale the widget formats names with: what the vault and desktop say,
    // this page's language choice and the saved week-start setting.
    readonly property var previewLocale: {
        let base = detector.settings ? detector.settings.locale : systemLocale;
        if (cfg_noteLanguage !== "") {
            base = Object.assign({}, Locales.bundled(cfg_noteLanguage) || Locales.EN, { dow: base.dow, doy: base.doy });
        }
        const weekStart = Plasmoid.configuration.weekStart;
        return weekStart >= 0 ? Locales.withWeekStart(base, weekStart) : base;
    }

    function sourceText(source) {
        switch (source) {
        case "periodic-notes": return i18nc("@info settings source", "Periodic Notes plugin");
        case "daily-notes": return i18nc("@info settings source", "core Daily notes plugin");
        case "calendar": return i18nc("@info settings source", "Calendar plugin");
        default: return i18nc("@info settings source", "Obsidian defaults");
        }
    }

    function detectedText(which) {
        if (detector.status === "unconfigured") {
            return i18nc("@info", "Choose a vault on the General page first.");
        }
        if (detector.status !== "ready") {
            return detector.status === "loading" ? i18nc("@info", "Reading vault…") : i18nc("@info", "The vault couldn't be read.");
        }
        const s = detector.settings;
        const notes = which === "daily" ? s.daily : s.weekly;
        if (!notes) {
            return i18nc("@info", "No weekly notes are configured in Obsidian.");
        }
        return i18nc("@info %1 folder, %2 format, %3 plugin name", "Folder “%1”, format %2, from the %3.",
                     notes.folder || i18nc("@info the top folder of the vault", "vault root"), notes.format,
                     sourceText(which === "daily" ? s.sources.daily : s.sources.weekly));
    }

    // Example path for a custom format, or the problem with it.
    function preview(folder, format, date) {
        if (format.trim() === "") {
            return "";
        }
        const problems = Config.formatProblems(format);
        const messages = [];
        if (Config.normalizeFolder(folder) === null) {
            messages.push(i18nc("@info", "The folder must be inside the vault."));
        }
        if (problems.indexOf("unsupported-token") !== -1) {
            messages.push(i18nc("@info %1 lists tokens", "Unsupported tokens: %1", DateFormat.compile(format).unsupported.join(", ")));
        }
        if (problems.indexOf("invalid-format") !== -1) {
            messages.push(i18nc("@info", "This format doesn't give a valid file name inside the folder."));
        }
        if (messages.length > 0) {
            return messages.join("\n");
        }
        return i18nc("@info %1 is a file path", "Example: %1",
                     Paths.notePath(Config.normalizeFolder(folder), DateFormat.format(date, format, previewLocale)));
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Daily notes")
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: i18nc("@label", "Detected:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.detectedText("daily")
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "Read from the vault saved on the General page. After choosing another vault, apply the change to update this.")
        }

        QQC2.CheckBox {
            id: customDaily
            text: i18nc("@option:check", "Use a different folder and format")
        }
        QQC2.TextField {
            id: dailyFolder
            Kirigami.FormData.label: i18nc("@label:textbox", "Folder:")
            enabled: customDaily.checked
            placeholderText: i18nc("@info:placeholder", "Vault root")
        }
        QQC2.TextField {
            id: dailyFormat
            Kirigami.FormData.label: i18nc("@label:textbox", "Format:")
            enabled: customDaily.checked
            placeholderText: "YYYY-MM-DD"
        }
        QQC2.Label {
            visible: customDaily.checked
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            textFormat: Text.PlainText
            text: page.preview(dailyFolder.text, dailyFormat.text, page.today)
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Weekly notes")
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: i18nc("@label", "Detected:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.detectedText("weekly")
        }

        QQC2.CheckBox {
            id: customWeekly
            text: i18nc("@option:check", "Use a different folder and format")
        }
        QQC2.TextField {
            id: weeklyFolder
            Kirigami.FormData.label: i18nc("@label:textbox", "Folder:")
            enabled: customWeekly.checked
            placeholderText: i18nc("@info:placeholder", "Vault root")
        }
        QQC2.TextField {
            id: weeklyFormat
            Kirigami.FormData.label: i18nc("@label:textbox", "Format:")
            enabled: customWeekly.checked
            placeholderText: "gggg-[W]ww"
        }
        QQC2.Label {
            visible: customWeekly.checked
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            textFormat: Text.PlainText
            text: page.preview(weeklyFolder.text, weeklyFormat.text, Dates.startOfWeek(page.today, page.previewLocale.dow))
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Names and clicks")
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Language of note names:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox note name language", "Automatic"), value: "" },
                { text: "English", value: "en" },
                { text: "Türkçe", value: "tr" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_noteLanguage))
            onActivated: page.cfg_noteLanguage = currentValue
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "Automatic follows the Calendar plugin or the desktop language. Only matters for formats with month or day names (MMMM, dddd…); the week start isn't affected. Other languages use English names, like Obsidian's default.")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Clicking a day without a note:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox", "Does nothing"), value: "none" },
                { text: i18nc("@item:inlistbox", "Creates the note"), value: "create" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_emptyDayAction))
            onActivated: page.cfg_emptyDayAction = currentValue
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "Today always opens or creates today's note with your template. Notes created for other days start empty: Obsidian doesn't apply templates to them.")
        }
    }
}
