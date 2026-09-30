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
    property string cfg_designVariant

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

        QQC2.SpinBox {
            id: refreshInterval
            Kirigami.FormData.label: i18nc("@label:spinbox", "Rescan every:")
            from: 10
            to: 3600
            stepSize: 10
            textFromValue: (value, locale) => i18ncp("@item:valuesuffix", "%1 second", "%1 seconds", value)
            valueFromText: (text, locale) => parseInt(text, 10)
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Design:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox design direction", "Plasma Native"), value: "native" },
                { text: i18nc("@item:inlistbox design direction", "Journal"), value: "journal" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_designVariant))
            onActivated: page.cfg_designVariant = currentValue
        }
    }

    Dialogs.FolderDialog {
        id: folderDialog
        title: i18nc("@title:window", "Choose Obsidian Vault")
        currentFolder: page.cfg_vaultPath !== ""
            ? "file://" + page.cfg_vaultPath
            : StandardPaths.writableLocation(StandardPaths.HomeLocation)
        onAccepted: {
            page.cfg_vaultPath = Paths.localPath(selectedFolder.toString(), "");
            vaultField.text = page.cfg_vaultPath;
        }
    }
}
