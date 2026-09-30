/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

// The calendar, or a message explaining why it can't be shown.
Item {
    id: full

    required property VaultScanner scanner
    required property var today
    property bool inPanel: false

    signal dayActivated(var date)
    signal weekActivated(var weekStart)

    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    onVisibleChanged: if (visible) scanner.refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: full.inPanel ? Kirigami.Units.smallSpacing : 0
        spacing: Kirigami.Units.smallSpacing

        StatusMessage {
            Layout.fillWidth: true
            scanner: full.scanner
        }

        CalendarView {
            id: calendar
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: full.scanner.status === "ready"
            scanner: full.scanner
            today: full.today
            variant: Plasmoid.configuration.designVariant
            showFooter: Plasmoid.configuration.showFooter
            isoWeekNumbers: Plasmoid.configuration.isoWeekNumbers
            focus: true
            onDayActivated: date => full.dayActivated(date)
            onWeekActivated: weekStart => full.weekActivated(weekStart)
        }

        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing
            visible: full.scanner.status !== "ready"
            iconName: {
                switch (full.scanner.status) {
                case "unconfigured": return "view-calendar-day";
                case "loading": return "view-calendar-day";
                default: return "dialog-warning";
                }
            }
            text: {
                switch (full.scanner.status) {
                case "unconfigured": return i18nc("@info", "No vault selected");
                case "loading": return i18nc("@info", "Reading vault…");
                }
                switch (full.scanner.errorCode) {
                case "no-vault": return i18nc("@info", "Vault folder not found");
                case "not-a-vault": return i18nc("@info", "Not an Obsidian vault");
                default: return i18nc("@info", "Couldn't read the vault");
                }
            }
            explanation: {
                switch (full.scanner.status) {
                case "unconfigured": return i18nc("@info", "Choose the folder of your Obsidian vault to see your daily notes.");
                case "loading": return "";
                }
                switch (full.scanner.errorCode) {
                case "no-vault": return i18nc("@info %1 is a folder path", "%1 doesn't exist or can't be opened.", full.scanner.errorDetail);
                case "not-a-vault": return i18nc("@info %1 is a folder path", "%1 has no .obsidian folder. Choose the vault's top folder.", full.scanner.errorDetail);
                default: return full.scanner.errorDetail;
                }
            }
            helpfulAction: full.scanner.status === "loading" ? null : configureAction

            Kirigami.Action {
                id: configureAction
                icon.name: "configure"
                text: i18nc("@action:button", "Choose Vault…")
                onTriggered: Plasmoid.internalAction("configure").trigger()
            }
        }
    }
}
