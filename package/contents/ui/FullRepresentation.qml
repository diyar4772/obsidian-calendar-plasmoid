/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

import "../code/paths.js" as Paths

// The calendar, or a message explaining why it can't be shown. Applies the
// widget's own color scheme, accent color and background when set.
Item {
    id: full

    required property VaultScanner scanner
    required property var today
    property bool inPanel: false
    // A vault path was entered but isn't absolute.
    property bool pathInvalid: false
    // Why the last click couldn't open Obsidian ("" when it worked).
    property string actionError: ""
    signal actionErrorDismissed()

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
    signal yearOverviewRequested()

    readonly property bool ownColors: schemeColors !== null || customAccent

    readonly property Translator tr: Translator {}

    Layout.minimumWidth: Kirigami.Units.gridUnit * 7
    Layout.minimumHeight: Kirigami.Units.gridUnit * 7
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    onVisibleChanged: if (visible) scanner.refresh()

    // Double-clicking the month title or anywhere around the days opens the
    // Year Overview. It lies under the calendar, whose day cells take their
    // own clicks, so opening a note stays a single click without delay.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        enabled: full.scanner.status === "ready"
        onDoubleClicked: full.yearOverviewRequested()
    }

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
        // A custom accent too close to the background (e.g. near-black on a
        // dark scheme) is blended toward the text color to stay visible.
        readonly property color highlightColor: {
            if (!full.customAccent) {
                return s ? s.highlightColor : full.Kirigami.Theme.highlightColor;
            }
            return readableAccent(full.accentColor, backgroundColor);
        }

        // Same hue and saturation, lightness moved away from the background
        // until the accent stands out (yellow stays yellow, only darker).
        function readableAccent(accent, background) {
            if (contrast(accent, background) >= 1.8) {
                return accent;
            }
            const darker = luminance(background) > 0.18;
            let lightness = accent.hslLightness;
            let color = accent;
            for (let i = 0; i < 20 && contrast(color, background) < 2.2; i++) {
                lightness = Math.max(0, Math.min(1, lightness + (darker ? -0.04 : 0.04)));
                color = Qt.hsla(accent.hslHue, accent.hslSaturation, lightness, 1);
            }
            return color;
        }

        // WCAG contrast ratio of two colors (1 to 21).
        function luminance(c) {
            const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
            return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
        }
        function contrast(a, b) {
            const la = luminance(a);
            const lb = luminance(b);
            return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
        }
        readonly property color highlightedTextColor: {
            if (!full.customAccent) {
                return s ? s.highlightedTextColor : full.Kirigami.Theme.highlightedTextColor;
            }
            // Readable text on the custom accent: the scheme's light or dark end.
            const accentIsDark = Kirigami.ColorUtils.brightnessForColor(highlightColor) === Kirigami.ColorUtils.Dark;
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

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: full.actionError !== ""
                type: Kirigami.MessageType.Error
                showCloseButton: true
                text: full.actionError
                onVisibleChanged: if (!visible) full.actionErrorDismissed()

                Timer {
                    running: parent.visible
                    interval: 10000
                    onTriggered: full.actionErrorDismissed()
                }
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
                onYearOverviewRequested: full.yearOverviewRequested()
            }

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: full.scanner.status !== "ready"
                // No big icon when space is short, so the text and button fit.
                iconName: full.height < Kirigami.Units.gridUnit * 14 ? ""
                    : (full.scanner.status === "error" || full.pathInvalid) ? "dialog-warning" : "view-calendar-day"
                text: {
                    if (full.pathInvalid) {
                        return full.tr.ui18nc("@info", "Vault path isn't absolute");
                    }
                    switch (full.scanner.status) {
                    case "unconfigured": return full.tr.ui18nc("@info", "No vault selected");
                    case "loading": return full.tr.ui18nc("@info", "Reading vault…");
                    }
                    switch (full.scanner.errorCode) {
                    case "no-vault": return full.tr.ui18nc("@info", "Vault folder not found");
                    case "not-a-vault": return full.tr.ui18nc("@info", "Not an Obsidian vault");
                    case "timeout": return full.tr.ui18nc("@info", "The vault didn't respond");
                    default: return full.tr.ui18nc("@info", "Couldn't read the vault");
                    }
                }
                explanation: {
                    if (full.pathInvalid) {
                        return full.tr.ui18nc("@info", "Enter a path that starts with / or ~/, or use Browse… to choose the folder.");
                    }
                    if (full.height < Kirigami.Units.gridUnit * 11) {
                        return "";
                    }
                    switch (full.scanner.status) {
                    case "unconfigured": return full.tr.ui18nc("@info", "Choose the folder of your Obsidian vault to see your daily notes.");
                    case "loading": return "";
                    }
                    switch (full.scanner.errorCode) {
                    case "no-vault": return full.tr.ui18nc("@info %1 is a folder path", "%1 doesn't exist or can't be opened.", Paths.plainText(full.scanner.errorDetail));
                    case "not-a-vault": return full.tr.ui18nc("@info %1 is a folder path", "%1 has no .obsidian folder. Choose the vault's top folder.", Paths.plainText(full.scanner.errorDetail));
                    case "timeout": return full.tr.ui18nc("@info %1 is a folder path", "Reading %1 took too long. If it's on a network or external drive, check that it's available.", Paths.plainText(full.scanner.errorDetail));
                    default: return Paths.plainText(full.scanner.errorDetail);
                    }
                }
                helpfulAction: full.scanner.status === "loading" ? null : configureAction

                Kirigami.Action {
                    id: configureAction
                    icon.name: "configure"
                    text: full.tr.ui18nc("@action:button", "Choose Vault…")
                    onTriggered: Plasmoid.internalAction("configure").trigger()
                }
            }
        }
    }
}
