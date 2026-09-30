/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtCore
import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../code/dates.js" as Dates
import "../code/locales.js" as Locales
import "../code/paths.js" as Paths

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        || Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // Today as { y, m, d }; checked every minute so the view rolls over at midnight.
    property var today: Dates.fromJsDate(new Date())

    readonly property VaultScanner scanner: VaultScanner {
        vaultPath: Paths.localPath(root.cfg.vaultPath,
            Paths.localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString(), ""))
        systemLocale: Locales.forSystem(Qt.locale().name, Qt.locale().firstDayOfWeek)
        dotSource: root.cfg.dotSource
        overrides: ({
            dailyFolder: root.cfg.customDaily ? root.cfg.dailyFolder : null,
            dailyFormat: root.cfg.customDaily ? root.cfg.dailyFormat : null,
            weeklyFolder: root.cfg.customWeekly ? root.cfg.weeklyFolder : null,
            weeklyFormat: root.cfg.customWeekly ? root.cfg.weeklyFormat : null,
            weekStart: root.cfg.weekStart >= 0 ? root.cfg.weekStart : null,
            wordsPerDot: root.cfg.wordsPerDot >= 0 ? root.cfg.wordsPerDot : null,
            showWeekNumbers: root.cfg.weekNumbers === "auto" ? null : root.cfg.weekNumbers === "on",
            locale: root.cfg.noteLanguage !== "" ? root.cfg.noteLanguage : null
        })
    }

    // The widget's own color scheme (null: follow Plasma).
    readonly property ColorSchemeLoader scheme: ColorSchemeLoader {
        path: root.cfg.colorScheme
    }

    // A widget color scheme needs a matching background, so Plasma's is
    // replaced by one drawn in the scheme's colors.
    readonly property string backgroundMode: cfg.background === "none" ? "none"
        : (scheme.colors !== null || cfg.background === "custom") ? "custom"
        : cfg.background

    Plasmoid.icon: inPanel ? "view-calendar-day-symbolic" : "view-calendar-day"
    Plasmoid.backgroundHints: {
        switch (backgroundMode) {
        case "translucent": return PlasmaCore.Types.TranslucentBackground | PlasmaCore.Types.ConfigurableBackground;
        case "custom": return PlasmaCore.Types.NoBackground;
        case "none": return PlasmaCore.Types.ShadowBackground;
        default: return PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground;
        }
    }

    // Strings and dates in the language chosen in the settings.
    readonly property Translator tr: Translator {}

    toolTipMainText: tr.longDate(Dates.toJsDate(today))
    toolTipSubText: {
        if (scanner.status !== "ready") {
            return tr.ui18nc("@info:tooltip", "Calendar for Obsidian");
        }
        const hasToday = scanner.revision >= 0 && scanner.hasNote(today);
        const streak = scanner.streak(today).length;
        const noteLine = hasToday ? tr.ui18nc("@info:tooltip", "Today's note is written") : tr.ui18nc("@info:tooltip", "No note for today yet");
        return streak > 0
            ? noteLine + "\n" + tr.ui18ncp("@info:tooltip", "%1-day streak", "%1-day streak", streak)
            : noteLine;
    }

    switchWidth: Kirigami.Units.gridUnit * 7
    switchHeight: Kirigami.Units.gridUnit * 7
    preferredRepresentation: inPanel ? compactRepresentation : fullRepresentation

    compactRepresentation: CompactRepresentation {
        scanner: root.scanner
        today: root.today
        expanded: root.expanded
        description: root.toolTipMainText
        onToggled: root.expanded = !root.expanded
    }
    fullRepresentation: FullRepresentation {
        scanner: root.scanner
        today: root.today
        inPanel: root.inPanel
        pathInvalid: root.cfg.vaultPath.trim() !== "" && root.scanner.vaultPath === ""
        actionError: root.actionError
        onActionErrorDismissed: root.actionError = ""
        schemeColors: root.scheme.colors
        customAccent: root.cfg.accentMode === "custom"
        accentColor: root.cfg.customAccent
        drawBackground: root.backgroundMode === "custom" && !(root.inPanel && root.scheme.colors === null)
        backgroundOpacity: root.cfg.backgroundOpacity / 100
        style: ({
            textScale: root.cfg.textScale / 100,
            density: root.cfg.density,
            tileShape: root.cfg.tileShape
        })
        onDayActivated: date => root.openDay(date)
        onWeekActivated: weekStart => root.openWeek(weekStart)
        onYearOverviewRequested: root.openYearOverview()
    }

    onExpandedChanged: {
        if (root.expanded) {
            scanner.refresh();
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: root.tr.ui18nc("@action", "Open Today's Note")
            icon.name: "go-jump-today"
            enabled: root.scanner.status === "ready"
            onTriggered: root.openDay(root.today)
        },
        PlasmaCore.Action {
            text: root.tr.ui18nc("@action", "Open Vault in Obsidian")
            icon.name: "document-open-folder"
            enabled: root.scanner.status === "ready"
            onTriggered: root.openUri(Paths.vaultUri(root.scanner.vaultName))
        },
        PlasmaCore.Action {
            text: root.tr.ui18nc("@action", "Year Overview")
            icon.name: "office-chart-bar"
            enabled: root.scanner.status === "ready"
            onTriggered: root.openYearOverview()
        },
        PlasmaCore.Action {
            text: root.tr.ui18nc("@action", "Rescan Vault")
            icon.name: "view-refresh"
            enabled: root.scanner.vaultPath !== ""
            onTriggered: root.scanner.refresh()
        }
    ]

    // Shown in the calendar when an obsidian:// link couldn't be opened.
    property string actionError: ""

    // Runs the KWin script that brings Obsidian to the front.
    readonly property CommandRunner runner: CommandRunner {}
    property int activations: 0

    function openUri(uri) {
        if (Qt.openUrlExternally(uri)) {
            actionError = "";
            activateObsidian();
        } else {
            actionError = tr.ui18nc("@info", "Couldn't open Obsidian. Check that it's installed and handles obsidian:// links.");
        }
    }

    // Obsidian can't raise its own window after a click here (focus stealing
    // prevention), so KWin is asked to activate it. Without KWin nothing
    // happens and Obsidian opens the note in the background as before.
    function activateObsidian() {
        const script = Paths.localPath(Qt.resolvedUrl("../kwin/activate-obsidian.js").toString(), "");
        const command = Paths.activateCommand(script,
            "io.github.diyar4772.obsidiancalendar.activate-" + Date.now() + "-" + (++activations), 20);
        if (command !== null) {
            runner.run(command, () => {});
        }
    }

    // Opens a day's note in Obsidian. Today without a note goes through
    // obsidian://daily so Obsidian applies the daily note template.
    function openDay(date) {
        if (scanner.status !== "ready") {
            return;
        }
        const rel = scanner.dailyPath(date);
        const absolute = Paths.joinPath(scanner.dailyFolderPath, rel);
        if (scanner.hasNote(date)) {
            root.openUri(Paths.openUri(absolute));
        } else if (Dates.equals(date, today) && scanner.settings.dailyUriAvailable
                   && scanner.settings.dailyMatchesObsidian) {
            // obsidian://daily creates the note where Obsidian's settings say,
            // so it's used only when the widget looks in the same place.
            root.openUri(Paths.dailyUri(scanner.vaultName));
        } else if (Dates.equals(date, today) || cfg.emptyDayAction === "create") {
            root.openUri(Paths.newUri(scanner.vaultName, Paths.joinPath(scanner.settings.daily.folder, rel)));
        }
    }

    // The Year Overview window, created the first time it's opened.
    Loader {
        id: yearOverview
        active: false
        sourceComponent: YearOverview {
            scanner: root.scanner
            today: root.today
            onDayActivated: date => root.openDay(date)
        }
    }

    function openYearOverview() {
        yearOverview.active = true;
        (yearOverview.item as YearOverview).open(root.today.y);
    }

    function openWeek(weekStart) {
        if (scanner.status !== "ready" || !scanner.settings.weekly) {
            return;
        }
        const rel = scanner.weeklyPath(weekStart);
        if (scanner.hasWeeklyNote(weekStart)) {
            root.openUri(Paths.openUri(Paths.joinPath(scanner.weeklyFolderPath, rel)));
        } else if (cfg.emptyDayAction === "create") {
            root.openUri(Paths.newUri(scanner.vaultName, Paths.joinPath(scanner.settings.weekly.folder, rel)));
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            const now = Dates.fromJsDate(new Date());
            if (!Dates.equals(now, root.today)) {
                root.today = now;
                root.scanner.refresh();
            }
        }
    }

    Timer {
        interval: Math.max(10, root.cfg.refreshInterval) * 1000
        repeat: true
        running: root.scanner.vaultPath !== ""
        onTriggered: root.scanner.refresh()
    }
}
