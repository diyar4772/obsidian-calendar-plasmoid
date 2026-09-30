/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

import "../code/obsidianconfig.js" as Config
import "../code/paths.js" as Paths
import "../code/translate.js" as Translate

KCM.SimpleKCM {
    id: page

    property string cfg_vaultPath
    property alias cfg_refreshInterval: refreshInterval.value
    property string cfg_uiLanguage

    readonly property string homePath: Paths.localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString(), "")

    // Vaults listed in Obsidian's own obsidian.json: [{ path, name }]
    property var knownVaults: []

    CommandRunner {
        id: runner
    }

    Component.onCompleted: {
        const configDir = Paths.localPath(StandardPaths.writableLocation(StandardPaths.GenericConfigLocation).toString(), "");
        const files = [Paths.joinPath(configDir, "obsidian/obsidian.json")]
            .concat(Config.OBSIDIAN_JSON.map(rel => Paths.joinPath(homePath, rel)));
        const command = Paths.readFilesCommand(files);
        if (command !== null) {
            runner.run(command, (exitCode, stdout) => {
                const contents = Paths.parseReadOutput(stdout);
                page.knownVaults = Config.knownVaults(Object.keys(contents).map(k => contents[k]));
            });
        }
    }

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18nc("@label:textbox", "Vault folder:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: vaultField
                Layout.minimumWidth: Kirigami.Units.gridUnit * 16
                placeholderText: i18nc("@info:placeholder", "Folder that contains .obsidian")
                text: page.cfg_vaultPath
                onTextEdited: page.cfg_vaultPath = text
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                text: i18nc("@action:button", "Browse…")
                onClicked: folderDialog.open()
            }
        }

        QQC2.ComboBox {
            id: knownBox
            Kirigami.FormData.label: i18nc("@label:listbox", "Or pick a vault:")
            visible: page.knownVaults.length > 0
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            textRole: "text"
            valueRole: "value"
            model: [{ text: i18nc("@item:inlistbox", "Vaults Obsidian knows…"), value: "" }]
                .concat(page.knownVaults.map(v => ({ text: Paths.plainText(v.name + " — " + v.path), value: v.path })))
            onActivated: {
                if (currentValue !== "") {
                    page.cfg_vaultPath = currentValue;
                    vaultField.text = currentValue;
                }
                currentIndex = 0;
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            visible: page.cfg_vaultPath.trim() !== "" && Paths.localPath(page.cfg_vaultPath, page.homePath) === ""
            text: i18nc("@info", "Enter a path that starts with / or ~/, or use Browse… to choose the folder.")
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "The widget only reads the vault. Daily and weekly note settings are taken from Obsidian (core Daily notes, Periodic Notes and Calendar plugins); you can change them on the Notes page.")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: refreshInterval
            Kirigami.FormData.label: i18nc("@label:spinbox", "Check for new notes every:")
            from: 10
            to: 3600
            stepSize: 10
            textFromValue: (value, locale) => i18ncp("@item:valuesuffix", "%1 second", "%1 seconds", value)
            valueFromText: (text, locale) => parseInt(text, 10)
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Language:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            textRole: "text"
            valueRole: "value"
            // Languages are listed by their own names.
            model: [{ text: i18nc("@item:inlistbox language", "System default"), value: "" }]
                .concat(Translate.LANGUAGES.map(l => ({ text: l.name, value: l.code })))
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_uiLanguage))
            onActivated: page.cfg_uiLanguage = currentValue
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "Month and day names, dates and the calendar's texts. This settings window always follows the desktop language. The language of note names is set on the Notes page.")
        }
    }

    Dialogs.FolderDialog {
        id: folderDialog
        title: i18nc("@title:window", "Choose Obsidian Vault")
        currentFolder: Paths.fileUrl(Paths.localPath(page.cfg_vaultPath, page.homePath) || page.homePath)
        onAccepted: {
            page.cfg_vaultPath = Paths.localPath(selectedFolder.toString(), "");
            vaultField.text = page.cfg_vaultPath;
        }
    }
}
