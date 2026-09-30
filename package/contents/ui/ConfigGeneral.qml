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

import "../code/paths.js" as Paths

KCM.SimpleKCM {
    id: page

    property string cfg_vaultPath
    property alias cfg_refreshInterval: refreshInterval.value

    readonly property string homePath: Paths.localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString(), "")

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
