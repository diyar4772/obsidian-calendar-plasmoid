/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/calendar.js" as Calendar
import "../code/dates.js" as Dates

// Month calendar: header, weekday names, a scrollable month grid and a footer.
//
// Months scroll like Plasma's own calendar (org.kde.plasma.workspace.calendar):
// a vertical list of three pages snaps back to the middle one after every
// change, so touchpads flick (honoring natural scrolling), mouse wheels step
// one month per notch, and animation follows the global animation speed.
FocusScope {
    id: view

    required property VaultScanner scanner
    required property var today              // { y, m, d }
    property string variant: "native"         // "native" or "journal"
    property bool showFooter: true
    property bool isoWeekNumbers: false
    // { textScale, density, tileShape, ownHighlight }
    property var style: ({})

    readonly property real textScale: style.textScale || 1
    readonly property real densityFactor: style.density === "compact" ? 0.5 : style.density === "comfortable" ? 1.75 : 1
    // Small sizes drop the "Today" label and the footer.
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 14
    readonly property bool roomForFooter: height >= Kirigami.Units.gridUnit * 12
    // Very small: no navigation buttons (wheel and touchpad still work).
    readonly property bool tiny: width < Kirigami.Units.gridUnit * 11 || height < Kirigami.Units.gridUnit * 11

    // Header, weekday and footer text grow a little on large widgets.
    readonly property real sizeBoost: Math.max(1, Math.min(1.6, Math.min(width, height) / (Kirigami.Units.gridUnit * 24)))

    // Point sizes relative to the desktop font, times the text-size setting.
    function points(factor) {
        return Math.max(1, Kirigami.Theme.defaultFont.pointSize * factor * textScale * sizeBoost);
    }

    // Month on screen, { y, m }
    property var month: ({ y: today.y, m: today.m })

    readonly property var settings: scanner.settings
    readonly property var locale: settings ? settings.locale : scanner.systemLocale
    readonly property bool showWeekNumbers: settings !== null && settings.showWeekNumbers
    readonly property bool isCurrentMonth: month.y === today.y && month.m === today.m

    signal dayActivated(var date)
    signal weekActivated(var weekStart)

    Accessible.role: Accessible.Pane
    Accessible.name: i18nc("@info accessible name, %1 month %2 year", "Calendar, %1 %2", monthTitle(month.y, month.m), month.y)

    // Follow the date at midnight when showing the current month.
    property var lastToday: today
    onTodayChanged: {
        if (month.y === lastToday.y && month.m === lastToday.m) {
            month = { y: today.y, m: today.m };
        }
        lastToday = today;
    }

    // Keyboard focus moved past the grid: show that month and focus the day.
    function focusDate(date) {
        if (date.y !== month.y || date.m !== month.m) {
            month = { y: date.y, m: date.m };
        }
        Qt.callLater(() => {
            const page = pages.currentItem as MonthPage;
            if (page) {
                page.focusDate(date);
            }
        });
    }

    function previousMonth() {
        pages.finishChangeIfNeeded();
        pages.decrementCurrentIndex();
    }
    function nextMonth() {
        pages.finishChangeIfNeeded();
        pages.incrementCurrentIndex();
    }
    function goToToday() {
        month = { y: today.y, m: today.m };
    }
    function shiftMonth(delta) {
        const d = Dates.addMonths(Dates.make(month.y, month.m, 1), delta);
        month = { y: d.y, m: d.m };
    }

    onMonthChanged: scanner.loadWords(month.y, month.m)
    Component.onCompleted: scanner.loadWords(month.y, month.m)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp) {
            previousMonth();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            nextMonth();
            event.accepted = true;
        } else if (event.key === Qt.Key_Home && (event.modifiers & Qt.ControlModifier)) {
            goToToday();
            event.accepted = true;
        }
    }

    // Localized names follow the desktop language, like Plasma's calendar.
    readonly property var uiLocale: Qt.locale(Qt.locale().uiLanguages[0])

    function monthTitle(y, m) {
        return uiLocale.standaloneMonthName(m - 1, Locale.LongFormat);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: (view.variant === "journal" ? Kirigami.Units.largeSpacing : Kirigami.Units.smallSpacing) * view.densityFactor

        Loader {
            Layout.fillWidth: true
            sourceComponent: view.variant === "journal" ? journalHeader : nativeHeader
        }

        // Weekday names
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Item {
                visible: view.showWeekNumbers
                Layout.preferredWidth: pages.cellWidth
            }

            Repeater {
                model: Calendar.weekdayOrder(view.locale.dow)

                PlasmaComponents.Label {
                    required property int modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: pages.cellWidth
                    horizontalAlignment: Text.AlignHCenter
                    // Short names ("Pzt") when they fit; one letter is ambiguous in some languages.
                    text: pages.cellWidth < Kirigami.Units.gridUnit * 2
                        ? view.uiLocale.dayName(modelData, Locale.NarrowFormat)
                        : view.uiLocale.dayName(modelData, Locale.ShortFormat)
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pointSize: view.points(view.variant === "journal" ? 0.85 : 1)
                    font.weight: view.variant === "journal" ? Font.DemiBold : Font.Normal
                    opacity: view.variant === "journal" ? 0.6 : 0.75
                }
            }
        }

        ListView {
            id: pages

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3

            readonly property real cellWidth: width / (7 + (view.showWeekNumbers ? 1 : 0))
            property bool dragHandled: false

            clip: true
            model: 3
            currentIndex: 1
            orientation: ListView.Vertical
            highlightRangeMode: ListView.StrictlyEnforceRange
            snapMode: ListView.SnapToItem
            highlightMoveDuration: Kirigami.Units.longDuration
            highlightMoveVelocity: -1
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            focus: true

            // Mouse drags are left to Plasma (press and hold moves the
            // widget); touchpads, touch screens, the wheel, buttons and keys
            // change months. acceptedButtons exists since Qt 6.9.
            Component.onCompleted: {
                if ("acceptedButtons" in pages) {
                    pages["acceptedButtons"] = Qt.NoButton;
                }
            }

            delegate: MonthPage {
                required property int index

                width: pages.width
                height: pages.height
                scanner: view.scanner
                today: view.today
                variant: view.variant
                locale: view.locale
                showWeekNumbers: view.showWeekNumbers
                style: view.style
                isoWeekNumbers: view.isoWeekNumbers
                year: Dates.addMonths(Dates.make(view.month.y, view.month.m, 1), index - 1).y
                month: Dates.addMonths(Dates.make(view.month.y, view.month.m, 1), index - 1).m
                active: index === 1
                onDayActivated: date => view.dayActivated(date)
                onWeekActivated: weekStart => view.weekActivated(weekStart)
                onFocusBeyond: date => view.focusDate(date)
            }

            // Same approach as Plasma's InfiniteList.qml.
            function resetViewPosition() {
                currentIndex = 1;
                positionViewAtIndex(1, ListView.Beginning);
            }
            function handleDateChange(direction) {
                if (dragHandled) {
                    resetViewPosition();
                    return;
                }
                if (draggingVertically) {
                    dragHandled = true;
                }
                view.shiftMonth(direction);
                resetViewPosition();
            }
            function finishChangeIfNeeded() {
                if (verticalVelocity !== 0) {
                    handleDateChange(verticalVelocity < 0 ? -1 : 1);
                }
            }

            onAtYEndChanged: if (atYEnd && width > 0 && height > 0) handleDateChange(1)
            onAtYBeginningChanged: if (atYBeginning && width > 0 && height > 0) handleDateChange(-1)
            onDraggingVerticallyChanged: if (!draggingVertically) dragHandled = false

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse
                orientation: Qt.Vertical
                onWheel: wheel => {
                    // 15 degrees is one notch of a common mouse wheel
                    while (rotation >= 15) {
                        rotation -= 15;
                        view.previousMonth();
                    }
                    while (rotation <= -15) {
                        rotation += 15;
                        view.nextMonth();
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: view.showFooter && view.settings !== null && view.roomForFooter
            visible: active
            sourceComponent: view.variant === "journal" ? journalFooter : nativeFooter
        }
    }

    // --- Plasma Native ------------------------------------------------------

    Component {
        id: nativeHeader

        RowLayout {
            spacing: 0

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                level: 2
                font.pointSize: view.points(view.tiny ? 1 : 1.2)
                text: view.month.y === view.today.y
                    ? view.monthTitle(view.month.y, view.month.m)
                    : i18nc("@title month and year, e.g. March 2025", "%1 %2", view.monthTitle(view.month.y, view.month.m), view.month.y)
                textFormat: Text.PlainText
                font.capitalization: Font.Capitalize
                elide: Text.ElideRight
            }
            NavButtons {
                visible: !view.tiny
                showTodayText: !view.narrow
            }
        }
    }

    Component {
        id: nativeFooter

        PlasmaComponents.Label {
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: view.points(0.85)
            opacity: 0.75
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: view.footerText()
        }
    }

    // --- Journal ------------------------------------------------------------

    Component {
        id: journalHeader

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                spacing: 0

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: !view.tiny
                    text: String(view.month.y)
                    textFormat: Text.PlainText
                    font.pointSize: view.points(0.85)
                    font.weight: Font.DemiBold
                    color: Kirigami.Theme.highlightColor
                }
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    font.pointSize: view.points(view.tiny ? 1 : view.narrow ? 1.2 : 1.5)
                    text: view.monthTitle(view.month.y, view.month.m)
                    textFormat: Text.PlainText
                    font.capitalization: Font.Capitalize
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }
            NavButtons {
                visible: !view.tiny
                showTodayText: false
            }
        }
    }

    Component {
        id: journalFooter

        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            Item { Layout.fillWidth: true }
            FooterStat {
                icon: "view-calendar-day"
                text: i18ncp("@info notes in the visible month", "%1 note", "%1 notes",
                             view.scanner.revision >= 0 ? view.scanner.countInMonth(view.month.y, view.month.m) : 0)
            }
            FooterStat {
                icon: "games-achievements"
                text: {
                    const s = view.scanner.revision >= 0 ? view.scanner.streak(view.today) : { length: 0 };
                    return s.length > 0
                        ? i18ncp("@info current streak of consecutive days", "%1-day streak", "%1-day streak", s.length)
                        : i18nc("@info", "No streak yet");
                }
            }
            Item { Layout.fillWidth: true }
        }
    }

    function footerText() {
        if (scanner.revision < 0) {
            return "";
        }
        const count = scanner.countInMonth(month.y, month.m);
        const s = scanner.streak(today);
        return i18ncp("@info notes in the visible month", "%1 note this month", "%1 notes this month", count)
            + " · " + (s.length > 0
                ? i18ncp("@info current streak of consecutive days", "%1-day streak", "%1-day streak", s.length)
                : i18nc("@info", "No streak yet"));
    }

    component FooterStat: RowLayout {
        property string icon
        property string text
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: parent.icon
            implicitWidth: Math.round(Kirigami.Units.iconSizes.small * view.textScale)
            implicitHeight: implicitWidth
            color: Kirigami.Theme.highlightColor
            isMask: true
        }
        PlasmaComponents.Label {
            text: parent.text
            textFormat: Text.PlainText
            font.pointSize: view.points(0.85)
            opacity: 0.8
        }
    }

    component NavButtons: RowLayout {
        property bool showTodayText
        spacing: 0

        PlasmaComponents.ToolButton {
            id: previousButton
            text: i18nc("@action:button", "Previous Month")
            icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
            display: PlasmaComponents.AbstractButton.IconOnly
            onClicked: view.previousMonth()
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        PlasmaComponents.ToolButton {
            text: i18nc("@action:button reset calendar to today", "Today")
            icon.name: parent.showTodayText ? "" : "go-jump-today"
            display: parent.showTodayText ? PlasmaComponents.AbstractButton.TextOnly : PlasmaComponents.AbstractButton.IconOnly
            enabled: !view.isCurrentMonth
            onClicked: view.goToToday()
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered && !parent.showTodayText
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        PlasmaComponents.ToolButton {
            text: i18nc("@action:button", "Next Month")
            icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-previous" : "go-next"
            display: PlasmaComponents.AbstractButton.IconOnly
            onClicked: view.nextMonth()
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }
}
