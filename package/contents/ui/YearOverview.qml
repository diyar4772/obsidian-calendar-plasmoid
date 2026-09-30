/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/dates.js" as Dates
import "../code/yearview.js" as YearView

// A window with the whole year: a GitHub-style heatmap of the daily notes,
// and notes or words per month and per ISO week.
Window {
    id: win

    required property VaultScanner scanner
    required property var today              // { y, m, d }
    property int year: today.y

    signal dayActivated(var date)

    title: win.tr.ui18nc("@title:window", "Year Overview")
    // A normal top-level window, not tied to the desktop or panel.
    transientParent: null
    flags: Qt.Window
    width: Kirigami.Units.gridUnit * 52
    height: Kirigami.Units.gridUnit * 32
    minimumWidth: Kirigami.Units.gridUnit * 30
    minimumHeight: Kirigami.Units.gridUnit * 26
    color: background.color

    // Shows year y (the current one by default) and brings the window forward.
    function open(y) {
        if (!visible) {
            year = y;
        }
        show();
        raise();
        requestActivate();
    }

    onYearChanged: if (visible) scanner.loadYearWords(year)
    onVisibleChanged: scanner.loadYearWords(visible ? year : 0)

    readonly property bool ready: scanner.status === "ready" && scanner.settings !== null
    readonly property int weekStart: ready ? scanner.settings.locale.dow : scanner.systemLocale.dow
    readonly property Translator tr: Translator {}
    readonly property var uiLocale: win.tr.nameLocale

    readonly property var entries: {
        const revision = scanner.revision; // re-evaluate when the vault changes
        return ready && revision >= 0 ? scanner.yearEntries(year) : YearView.daysOfYear(year).map(date => ({ date: date, hasNote: false, words: -1, size: 0 }));
    }
    readonly property var levels: YearView.levels(entries, scanner.dotSource, ready ? scanner.settings.wordsPerDot : 0)
    readonly property var summary: YearView.summary(entries)
    readonly property var months: YearView.monthTotals(entries)
    readonly property var weeks: YearView.weekTotals(year, entries)
    readonly property var grid: YearView.yearGrid(year, weekStart)
    readonly property var monthColumns: YearView.monthColumns(year, weekStart)
    readonly property int currentStreak: ready && year === today.y ? scanner.streak(today).length : 0

    // Charts show words (true) or notes.
    property bool showWords: false

    // Tint strength per level, as in the Journal design.
    readonly property var tints: [0, 0.22, 0.36, 0.52, 0.7, 0.88]

    function cellColor(level) {
        if (level > 0) {
            const a = background.Kirigami.Theme.highlightColor;
            return Qt.rgba(a.r, a.g, a.b, tints[level]);
        }
        const t = background.Kirigami.Theme.textColor;
        return Qt.rgba(t.r, t.g, t.b, 0.08);
    }

    function number(n) {
        return Number(n).toLocaleString(win.tr.formatLocale, "f", 0);
    }
    function wordsText(n) {
        return win.tr.ui18ncp("@info %2 is the formatted number", "%2 word", "%2 words", n, number(n));
    }
    function notesText(n) {
        return win.tr.ui18ncp("@info", "%1 note", "%1 notes", n);
    }
    function longDate(date) {
        return Dates.toJsDate(date).toLocaleDateString(win.tr.formatLocale, Locale.LongFormat);
    }

    readonly property string summaryText: {
        const parts = [notesText(summary.notes)];
        if (summary.notes > 0) {
            parts.push(summary.counted < summary.notes ? win.tr.ui18nc("@info year summary", "counting words…") : wordsText(summary.words));
        }
        if (year === today.y) {
            parts.push(win.tr.ui18ncp("@info", "Current streak: %1 day", "Current streak: %1 days", currentStreak));
        }
        parts.push(win.tr.ui18ncp("@info", "Longest streak: %1 day", "Longest streak: %1 days", summary.longest));
        return parts.join("  ·  ");
    }

    // One tooltip for every cell and bar.
    PlasmaComponents.ToolTip {
        id: tip
        delay: Kirigami.Units.toolTipDelay
    }
    function showTip(item, text) {
        tip.parent = item;
        tip.text = text;
        tip.visible = true;
    }
    function hideTip(item) {
        if (tip.parent === item) {
            tip.visible = false;
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        focus: true
        color: Kirigami.Theme.backgroundColor
        Keys.onEscapePressed: win.close()
        Keys.onLeftPressed: win.year--
        Keys.onRightPressed: win.year++

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing

            // Year and navigation
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: String(win.year)
                    textFormat: Text.PlainText
                }
                PlasmaComponents.ToolButton {
                    text: win.tr.ui18nc("@action:button", "Previous Year")
                    icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: win.year--
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PlasmaComponents.ToolButton {
                    text: win.tr.ui18nc("@action:button", "This Year")
                    enabled: win.year !== win.today.y
                    onClicked: win.year = win.today.y
                }
                PlasmaComponents.ToolButton {
                    text: win.tr.ui18nc("@action:button", "Next Year")
                    icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-previous" : "go-next"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: win.year++
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: win.ready
                text: win.summaryText
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                opacity: 0.85
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !win.ready
                text: win.scanner.status === "loading" ? win.tr.ui18nc("@info", "Reading vault…") : win.tr.ui18nc("@info", "Couldn't read the vault")
            }

            // Heatmap
            Item {
                id: heat

                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                implicitHeight: monthRow.height + gridRow.height + legend.height + 2 * Kirigami.Units.smallSpacing
                visible: win.ready

                readonly property real gap: Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2))
                readonly property real labelWidth: dayLabels.implicitWidth + Kirigami.Units.smallSpacing
                readonly property real cell: Math.max(6, Math.min(Kirigami.Units.gridUnit * 1.2,
                    Math.floor((width - labelWidth) / win.grid.columns - gap)))
                readonly property real gridWidth: win.grid.columns * (cell + gap) - gap
                // Centered when the window is wider than the grid needs.
                readonly property real inset: Math.max(0, (width - labelWidth - gridWidth) / 2)

                Item {
                    id: monthRow
                    x: heat.inset + heat.labelWidth
                    width: heat.gridWidth
                    height: monthMetrics.height

                    PlasmaComponents.Label {
                        id: monthMetrics
                        visible: false
                        text: "M"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }

                    Repeater {
                        model: win.monthColumns
                        PlasmaComponents.Label {
                            required property var modelData
                            x: modelData.column * (heat.cell + heat.gap)
                            text: win.uiLocale.standaloneMonthName(modelData.m - 1, Locale.ShortFormat)
                            textFormat: Text.PlainText
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.capitalization: Font.Capitalize
                            opacity: 0.75
                        }
                    }
                }

                Row {
                    id: gridRow
                    x: heat.inset
                    y: monthRow.height + Kirigami.Units.smallSpacing
                    spacing: 0

                    Column {
                        id: dayLabels
                        width: heat.labelWidth
                        spacing: heat.gap

                        Repeater {
                            model: 7
                            Item {
                                id: dayLabel
                                required property int index
                                // Never 0 wide: Column skips empty items.
                                width: Math.max(1, label.implicitWidth)
                                height: heat.cell

                                PlasmaComponents.Label {
                                    id: label
                                    anchors.verticalCenter: parent.verticalCenter
                                    // Every other weekday, like GitHub.
                                    text: dayLabel.index % 2 === 1 ? win.uiLocale.dayName((win.weekStart + dayLabel.index) % 7, Locale.ShortFormat) : ""
                                    textFormat: Text.PlainText
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.75
                                }
                            }
                        }
                    }

                    Grid {
                        rows: 7
                        flow: Grid.TopToBottom
                        spacing: heat.gap

                        Repeater {
                            model: win.grid.cells

                            Rectangle {
                                id: day

                                required property var modelData
                                readonly property int index: modelData.inYear ? Dates.dayOfYear(modelData.date) - 1 : -1
                                readonly property var entry: index >= 0 ? win.entries[index] : null
                                readonly property int level: index >= 0 ? win.levels[index] : 0
                                readonly property bool isToday: Dates.equals(modelData.date, win.today)

                                width: heat.cell
                                height: heat.cell
                                radius: Math.max(1, heat.cell / 5)
                                // Hidden, but still taking its place in the grid.
                                opacity: modelData.inYear ? 1 : 0
                                enabled: modelData.inYear
                                color: win.cellColor(level)
                                border.width: isToday ? 2 : (mouse.containsMouse ? 1 : 0)
                                border.color: isToday ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

                                Accessible.role: Accessible.Button
                                Accessible.name: win.longDate(modelData.date)

                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.dayActivated(day.modelData.date)
                                    onContainsMouseChanged: {
                                        if (!containsMouse) {
                                            win.hideTip(day);
                                            return;
                                        }
                                        const e = day.entry;
                                        win.showTip(day, win.longDate(day.modelData.date) + "\n"
                                            + (!e || !e.hasNote ? win.tr.ui18nc("@info:tooltip", "No note")
                                               : e.words >= 0 ? win.wordsText(e.words)
                                               : win.tr.ui18nc("@info:tooltip a note whose words aren't counted yet", "Note")));
                                    }
                                }
                            }
                        }
                    }
                }

                // Less ▢▢▢▢▢▢ More
                Row {
                    id: legend
                    anchors.right: parent.right
                    anchors.rightMargin: heat.inset
                    y: gridRow.y + gridRow.height + Kirigami.Units.smallSpacing
                    spacing: heat.gap

                    PlasmaComponents.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: Kirigami.Units.smallSpacing
                        text: win.tr.ui18nc("@info heatmap legend: shorter notes", "Less")
                        textFormat: Text.PlainText
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.75
                    }
                    Repeater {
                        model: 6
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: heat.cell
                            height: heat.cell
                            radius: Math.max(1, heat.cell / 5)
                            color: win.cellColor(index)
                        }
                    }
                    PlasmaComponents.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: Kirigami.Units.smallSpacing
                        text: win.tr.ui18nc("@info heatmap legend: longer notes", "More")
                        textFormat: Text.PlainText
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.75
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                visible: win.ready
            }

            // Charts
            RowLayout {
                Layout.fillWidth: true
                visible: win.ready
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 3
                    text: win.showWords ? win.tr.ui18nc("@title", "Words per Month and Week") : win.tr.ui18nc("@title", "Notes per Month and Week")
                    textFormat: Text.PlainText
                }
                PlasmaComponents.ToolButton {
                    text: win.tr.ui18nc("@option:radio chart values", "Notes")
                    checkable: true
                    checked: !win.showWords
                    onClicked: win.showWords = false
                }
                PlasmaComponents.ToolButton {
                    text: win.tr.ui18nc("@option:radio chart values", "Words")
                    checkable: true
                    checked: win.showWords
                    onClicked: win.showWords = true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 7
                visible: win.ready
                spacing: Kirigami.Units.gridUnit * 2

                BarChart {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    title: win.tr.ui18nc("@title chart", "Per month")
                    values: win.months.map(t => win.showWords ? t.words : t.notes)
                    labels: win.months.map(t => win.uiLocale.standaloneMonthName(t.m - 1, Locale.NarrowFormat))
                    highlighted: win.year === win.today.y ? win.today.m - 1 : -1
                    tipFor: i => {
                        const t = win.months[i];
                        return win.uiLocale.standaloneMonthName(t.m - 1, Locale.LongFormat) + " " + win.year + "\n"
                            + win.notesText(t.notes) + "\n" + win.wordsText(t.words);
                    }
                }
                BarChart {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2
                    Layout.fillWidth: true
                    title: win.tr.ui18nc("@title chart", "Per ISO week")
                    values: win.weeks.map(t => win.showWords ? t.words : t.notes)
                    // Label every tenth week, and the first.
                    labels: win.weeks.map(t => t.week === 1 || t.week % 10 === 0 ? String(t.week) : "")
                    highlighted: {
                        for (let i = 0; i < win.weeks.length; i++) {
                            const start = win.weeks[i].start;
                            const diff = Dates.compare(win.today, start);
                            if (diff >= 0 && diff < 7) {
                                return i;
                            }
                        }
                        return -1;
                    }
                    tipFor: i => {
                        const t = win.weeks[i];
                        return win.tr.ui18nc("@info:tooltip %1 week number, %2 date the week starts", "Week %1, from %2", t.week,
                                     Dates.toJsDate(t.start).toLocaleDateString(win.tr.formatLocale, Locale.ShortFormat)) + "\n"
                            + win.notesText(t.notes) + "\n" + win.wordsText(t.words);
                    }
                }
            }
        }
    }

    // Vertical bars scaled to the largest value, with the maximum on top
    // and labels under the bars.
    component BarChart: ColumnLayout {
        id: chart

        property string title
        property var values: []
        property var labels: []
        property int highlighted: -1
        property var tipFor: i => ""

        readonly property real max: YearView.scaleMax(values)

        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: chart.title
                textFormat: Text.PlainText
                font.weight: Font.DemiBold
                opacity: 0.85
            }
            PlasmaComponents.Label {
                text: win.tr.ui18nc("@info largest value in a chart", "max %1", win.number(chart.max))
                textFormat: Text.PlainText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
            }
        }

        Item {
            id: plot
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real slot: width / Math.max(1, chart.values.length)
            readonly property real barWidth: Math.max(1, slot * (chart.values.length > 20 ? 0.7 : 0.6))

            // Baseline
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Kirigami.Theme.textColor
                opacity: 0.2
            }

            Repeater {
                model: chart.values.length

                Item {
                    id: slotItem
                    required property int index
                    readonly property real value: chart.values[index] || 0

                    x: index * plot.slot
                    width: plot.slot
                    height: plot.height

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: plot.barWidth
                        height: slotItem.value > 0 ? Math.max(2, (plot.height - 1) * slotItem.value / chart.max) : 0
                        radius: Math.min(width / 4, Kirigami.Units.smallSpacing / 2)
                        color: Kirigami.Theme.highlightColor
                        opacity: barMouse.containsMouse ? 1 : (slotItem.index === chart.highlighted ? 0.95 : 0.7)
                    }

                    MouseArea {
                        id: barMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: containsMouse ? win.showTip(slotItem, chart.tipFor(slotItem.index)) : win.hideTip(slotItem)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: labelMetrics.implicitHeight

            PlasmaComponents.Label {
                id: labelMetrics
                visible: false
                text: "M"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            Repeater {
                model: chart.labels.length

                PlasmaComponents.Label {
                    required property int index
                    x: (index + 0.5) * plot.slot - width / 2
                    text: chart.labels[index]
                    textFormat: Text.PlainText
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: index === chart.highlighted ? Font.Bold : Font.Normal
                    opacity: index === chart.highlighted ? 1 : 0.7
                }
            }
        }
    }
}
