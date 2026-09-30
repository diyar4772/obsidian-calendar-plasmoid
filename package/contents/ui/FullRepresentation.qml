/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

// The calendar, or a message explaining why it can't be shown. Applies the
// widget's own color scheme, accent color and background when set.
Item {
    id: full

    required property VaultScanner scanner
    required property var today
    property bool inPanel: false

    // Colors from ColorSchemeLoader, or null to follow Plasma.
    property var schemeColors: null
    property bool customAccent: false
    property color accentColor
    // Draw our own background (instead of Plasma's) with this opacity.
    property bool drawBackground: false
    property real backgroundOpacity: 1
    // { textScale, density, tileShape }
    property var style: ({})

    signal dayActivated(var date)
    signal weekActivated(var weekStart)

    readonly property bool ownColors: schemeColors !== null || customAccent

    Layout.minimumWidth: Kirigami.Units.gridUnit * 7
    Layout.minimumHeight: Kirigami.Units.gridUnit * 7
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    onVisibleChanged: if (visible) scanner.refresh()

    Rectangle {
        anchors.fill: parent
        visible: full.drawBackground
        radius: Kirigami.Units.largeSpacing
        color: Qt.rgba(themed.backgroundColor.r, themed.backgroundColor.g, themed.backgroundColor.b, full.backgroundOpacity)
        border.width: 1
        border.color: Qt.rgba(themed.textColor.r, themed.textColor.g, themed.textColor.b, 0.12 * Math.max(0.3, full.backgroundOpacity))
    }

    Item {
        id: themed

        anchors.fill: parent
        anchors.margins: full.drawBackground ? Kirigami.Units.largeSpacing : (full.inPanel ? Kirigami.Units.smallSpacing : 0)

        readonly property var s: full.schemeColors

        // Computed here, not from this item's own Kirigami.Theme, to avoid binding loops.
        readonly property color textColor: s ? s.textColor : full.Kirigami.Theme.textColor
        readonly property color backgroundColor: s ? s.backgroundColor : full.Kirigami.Theme.backgroundColor
        readonly property color highlightColor: full.customAccent ? full.accentColor
            : (s ? s.highlightColor : full.Kirigami.Theme.highlightColor)
        readonly property color highlightedTextColor: {
            if (!full.customAccent) {
                return s ? s.highlightedTextColor : full.Kirigami.Theme.highlightedTextColor;
            }
            // Readable text on the custom accent: the scheme's light or dark end.
            const accentIsDark = Kirigami.ColorUtils.brightnessForColor(full.accentColor) === Kirigami.ColorUtils.Dark;
            const backgroundIsLight = Kirigami.ColorUtils.brightnessForColor(backgroundColor) === Kirigami.ColorUtils.Light;
            return accentIsDark === backgroundIsLight ? backgroundColor : textColor;
        }

        // Children use Kirigami.Theme (Plasma components too), so overriding
        // it here recolors the whole calendar.
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: full.Kirigami.Theme.colorSet
        Kirigami.Theme.textColor: textColor
        Kirigami.Theme.disabledTextColor: s ? s.disabledTextColor : full.Kirigami.Theme.disabledTextColor
        Kirigami.Theme.backgroundColor: backgroundColor
        Kirigami.Theme.alternateBackgroundColor: s ? s.alternateBackgroundColor : full.Kirigami.Theme.alternateBackgroundColor
        Kirigami.Theme.highlightColor: highlightColor
        Kirigami.Theme.highlightedTextColor: highlightedTextColor
        Kirigami.Theme.focusColor: highlightColor
        Kirigami.Theme.hoverColor: highlightColor

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            StatusMessage {
                Layout.fillWidth: true
                scanner: full.scanner
            }

            CalendarView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: full.scanner.status === "ready"
                scanner: full.scanner
                today: full.today
                variant: Plasmoid.configuration.designVariant
                showFooter: Plasmoid.configuration.showFooter
                isoWeekNumbers: Plasmoid.configuration.isoWeekNumbers
                style: Object.assign({ ownHighlight: full.ownColors }, full.style)
                focus: true
                onDayActivated: date => full.dayActivated(date)
                onWeekActivated: weekStart => full.weekActivated(weekStart)
            }

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: full.scanner.status !== "ready"
                iconName: full.scanner.status === "error" ? "dialog-warning" : "view-calendar-day"
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
}
