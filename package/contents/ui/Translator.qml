/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid

import "../code/catalogs.js" as Catalogs
import "../code/translate.js" as Translate

// Strings, month and day names and date formats in the language chosen in
// the widget's settings (see code/translate.js). ui18nc() and ui18ncp()
// work like i18nc() and i18ncp(); scripts/i18n.sh extracts them too.
QtObject {
    id: translator

    // "" (system), "en" or a bundled catalog's language.
    readonly property string language: Translate.normalize(Plasmoid.configuration.uiLanguage, Catalogs.CATALOGS)

    readonly property var localeNames: Translate.localeNames(language, Qt.locale().name, Qt.locale().uiLanguages[0])
    // Month and day names
    readonly property var nameLocale: Qt.locale(localeNames.names)
    // Long dates in tooltips
    readonly property var formatLocale: Qt.locale(localeNames.formats)

    function ui18nc(context, text, ...args) {
        return language === ""
            ? i18nc(context, text, ...args)
            : Translate.translate(Catalogs.CATALOGS, language, context, text, args);
    }

    function ui18ncp(context, singular, plural, n, ...args) {
        return language === ""
            ? i18ncp(context, singular, plural, n, ...args)
            : Translate.translatePlural(Catalogs.CATALOGS, language, context, singular, plural, n, args);
    }

    function longDate(jsDate) {
        return jsDate.toLocaleDateString(formatLocale, Locale.LongFormat);
    }
}
