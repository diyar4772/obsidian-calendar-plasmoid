/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nc("@title", "General")
        icon: "view-calendar-day"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Notes")
        icon: "document-edit"
        source: "ConfigNotes.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Calendar")
        icon: "view-calendar-month"
        source: "ConfigCalendar.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
}
