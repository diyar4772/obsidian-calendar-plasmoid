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
import org.kde.kquickcontrols as KQuickControls

import "../code/colorscheme.js" as ColorScheme
import "../code/paths.js" as Paths

KCM.SimpleKCM {
    id: page

    property string cfg_designVariant
    property string cfg_colorScheme
    property string cfg_accentMode
    property alias cfg_customAccent: accentButton.color
    property string cfg_background
    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_textScale: textScale.value
    property string cfg_density
    property string cfg_tileShape

    // Installed color schemes: [{ path, file, name }]
    property var schemes: []

    CommandRunner {
        id: runner
    }

    Component.onCompleted: {
        const dirs = StandardPaths.standardLocations(StandardPaths.GenericDataLocation)
            .map(url => Paths.joinPath(Paths.localPath(url.toString(), ""), "color-schemes"));
        const command = ColorScheme.listCommand(dirs);
        if (command !== null) {
            runner.run(command, (exitCode, stdout) => {
                page.schemes = ColorScheme.parseList(stdout, Qt.locale().name);
            });
        }
    }

    Kirigami.FormLayout {
        ColumnLayout {
            Kirigami.FormData.label: i18nc("@label", "Design:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: i18nc("@option:radio design", "Plasma Native")
                checked: page.cfg_designVariant !== "journal"
                onToggled: if (checked) page.cfg_designVariant = "native"
            }
            QQC2.Label {
                Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                text: i18nc("@info", "Like Plasma's calendar, with word-count dots like the Calendar plugin")
            }
            QQC2.RadioButton {
                text: i18nc("@option:radio design", "Journal")
                checked: page.cfg_designVariant === "journal"
                onToggled: if (checked) page.cfg_designVariant = "journal"
            }
            QQC2.Label {
                Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                text: i18nc("@info", "Tiles tinted by note length, like an activity heatmap")
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Colors")
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: schemeBox
            Kirigami.FormData.label: i18nc("@label:listbox", "Color scheme:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            QQC2.ToolTip.text: currentText
            QQC2.ToolTip.visible: hovered && currentText.length > 0
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            textRole: "text"
            valueRole: "value"
            model: {
                const items = [{ text: i18nc("@item:inlistbox", "Same as Plasma"), value: "" }]
                    .concat(page.schemes.map(s => ({ text: Paths.plainText(s.name), value: s.path })));
                // Keep a saved scheme selectable even if its file is gone.
                const saved = page.cfg_colorScheme;
                if (saved !== "" && !page.schemes.some(s => s.path === saved)) {
                    items.push({ text: i18nc("@item:inlistbox %1 is a file name", "%1 (not found)", Paths.plainText(saved.substring(saved.lastIndexOf("/") + 1))), value: saved });
                }
                return items;
            }
            onModelChanged: currentIndex = Math.max(0, indexOfValue(page.cfg_colorScheme))
            onActivated: page.cfg_colorScheme = currentValue
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Accent color:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.ComboBox {
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18nc("@item:inlistbox accent color", "Automatic"), value: "auto" },
                    { text: i18nc("@item:inlistbox accent color", "Custom"), value: "custom" }
                ]
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_accentMode))
                onActivated: page.cfg_accentMode = currentValue
            }
            KQuickControls.ColorButton {
                id: accentButton
                visible: page.cfg_accentMode === "custom"
                showAlphaChannel: false
                dialogTitle: i18nc("@title:window", "Choose Accent Color")
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            visible: page.cfg_accentMode === "custom"
            text: i18nc("@info", "A color too close to the background is made lighter or darker so it stays visible.")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Background:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox background", "Plasma standard"), value: "plasma" },
                { text: i18nc("@item:inlistbox background", "Plasma translucent"), value: "translucent" },
                { text: i18nc("@item:inlistbox background", "Solid color, adjustable opacity"), value: "custom" },
                { text: i18nc("@item:inlistbox background", "None"), value: "none" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_background))
            onActivated: page.cfg_background = currentValue
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:slider", "Background opacity:")
            enabled: page.cfg_background === "custom" || (page.cfg_colorScheme !== "" && page.cfg_background !== "none")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: opacitySlider
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                from: 0
                to: 100
                stepSize: 5
            }
            QQC2.Label {
                text: i18nc("@item percentage", "%1%", opacitySlider.value)
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            visible: page.cfg_colorScheme !== "" && (page.cfg_background === "plasma" || page.cfg_background === "translucent")
            text: i18nc("@info", "With its own color scheme, the widget draws a background in that scheme's colors.")
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Size")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:slider", "Text size:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: textScale
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                from: 70
                to: 160
                stepSize: 5
            }
            QQC2.Label {
                text: i18nc("@item percentage", "%1%", textScale.value)
            }
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Spacing:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox spacing", "Compact"), value: "compact" },
                { text: i18nc("@item:inlistbox spacing", "Normal"), value: "normal" },
                { text: i18nc("@item:inlistbox spacing", "Comfortable"), value: "comfortable" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_density))
            onActivated: page.cfg_density = currentValue
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Day shape:")
            enabled: page.cfg_designVariant === "journal"
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox shape", "Rounded"), value: "rounded" },
                { text: i18nc("@item:inlistbox shape", "Circle"), value: "circle" },
                { text: i18nc("@item:inlistbox shape", "Square"), value: "square" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_tileShape))
            onActivated: page.cfg_tileShape = currentValue
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "Resize the widget on the desktop by dragging its edges in edit mode.")
        }
    }
}
