/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property int cfg_weekStart
    property string cfg_weekNumbers
    property alias cfg_isoWeekNumbers: isoWeekNumbers.checked
    property string cfg_dotSource
    property int cfg_wordsPerDot
    property alias cfg_showFooter: showFooter.checked
    property alias cfg_showDateInPanel: showDateInPanel.checked

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Week starts on:")
            textRole: "text"
            valueRole: "value"
            model: {
                const days = [{ text: i18nc("@item:inlistbox week start", "Automatic"), value: -1 }];
                for (let i = 0; i < 7; i++) {
                    const day = (Qt.locale().firstDayOfWeek + i) % 7;
                    days.push({ text: Qt.locale().dayName(day, Locale.LongFormat), value: day });
                }
                return days;
            }
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_weekStart))
            onActivated: page.cfg_weekStart = currentValue
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "Automatic uses the Calendar plugin's setting, or the desktop's first day of the week.")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Week numbers:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox week numbers", "Automatic"), value: "auto" },
                { text: i18nc("@item:inlistbox", "Show"), value: "on" },
                { text: i18nc("@item:inlistbox", "Hide"), value: "off" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_weekNumbers))
            onActivated: page.cfg_weekNumbers = currentValue
        }
        QQC2.CheckBox {
            id: isoWeekNumbers
            text: i18nc("@option:check", "Use ISO 8601 week numbers")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18nc("@info", "Automatic shows week numbers when “Show week number” is on in the Calendar plugin.")
            enabled: page.cfg_weekNumbers !== "off"
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Notes on the calendar")
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:listbox", "Note length shown by:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox note length", "Word count"), value: "words" },
                { text: i18nc("@item:inlistbox note length", "File size"), value: "size" },
                { text: i18nc("@item:inlistbox note length", "Not shown"), value: "none" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_dotSource))
            onActivated: page.cfg_dotSource = currentValue
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:spinbox", "Words per dot:")
            enabled: page.cfg_dotSource === "words"
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                id: autoWords
                text: i18nc("@option:check", "From the Calendar plugin")
                checked: page.cfg_wordsPerDot < 0
                onToggled: page.cfg_wordsPerDot = checked ? -1 : wordsPerDot.value
            }
            QQC2.SpinBox {
                id: wordsPerDot
                enabled: !autoWords.checked
                from: 10
                to: 5000
                stepSize: 50
                value: page.cfg_wordsPerDot < 0 ? 250 : page.cfg_wordsPerDot
                onValueModified: page.cfg_wordsPerDot = value
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            visible: page.cfg_dotSource === "words"
            text: i18nc("@info", "Like the Calendar plugin: one dot per this many words, up to five. Counts are approximate: frontmatter is skipped and only the beginning of very long notes is read.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showFooter
            Kirigami.FormData.label: i18nc("@label", "Show:")
            text: i18nc("@option:check", "Notes this month and current streak")
        }
        QQC2.CheckBox {
            id: showDateInPanel
            text: i18nc("@option:check", "Today's date next to the panel icon")
        }
    }
}
