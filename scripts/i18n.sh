#!/bin/bash
# SPDX-FileCopyrightText: 2026 Samed Yolcu
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Translation workflow.
#   scripts/i18n.sh extract   update po/<domain>.pot and merge it into po/*.po
#   scripts/i18n.sh compile   build package/contents/locale/<lang>/LC_MESSAGES/<domain>.mo
#                             and package/contents/code/catalogs.js
#   scripts/i18n.sh check     fail if the template or catalogs.js is out of date (CI)
# With no argument: extract, then compile.
set -euo pipefail
cd "$(dirname "$0")/.."

ID=$(node -p 'require("./package/metadata.json").KPlugin.Id')
VERSION=$(node -p 'require("./package/metadata.json").KPlugin.Version')
DOMAIN="plasma_applet_${ID}"
POT="po/${DOMAIN}.pot"
CATALOGS="package/contents/code/catalogs.js"

extract_to() {
    # QML and JS parse fine as C for xgettext; the keywords are KDE's i18n family,
    # plus Translator.qml's ui18nc/ui18ncp (the widget's own language setting).
    # Only QML has strings; code/*.js is logic without i18n calls.
    find package -name '*.qml' | LC_ALL=C sort | xgettext \
        --files-from=- --from-code=UTF-8 -C --kde \
        -ci18n -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 -kui18nc:1c,2 -kui18ncp:1c,2,3 \
        --flag=ui18nc:2:kde-format --flag=ui18ncp:2:kde-format --flag=ui18ncp:3:kde-format \
        --package-name="$ID" --package-version="$VERSION" \
        --msgid-bugs-address="https://github.com/diyar4772/obsidian-calendar-plasmoid/issues" \
        --add-comments=TRANSLATORS --no-location \
        -o "$1"
    # Stable header: no creation date, so the template only changes with its strings.
    sed -i '/^"POT-Creation-Date:/d' "$1"
}

extract() {
    extract_to "$POT"
    for po in po/*.po; do
        [ -e "$po" ] || continue
        msgmerge --quiet --update --backup=none --no-location "$po" "$POT"
    done
    echo "Updated $POT"
    catalogs
}

# Translations for the widget's language setting (see code/translate.js).
catalogs() {
    node scripts/po2js.mjs "$CATALOGS" po/*.po
    echo "Updated $CATALOGS"
}

compile() {
    for po in po/*.po; do
        [ -e "$po" ] || continue
        lang=$(basename "$po" .po)
        out="package/contents/locale/${lang}/LC_MESSAGES/${DOMAIN}.mo"
        mkdir -p "$(dirname "$out")"
        msgfmt --check -o "$out" "$po"
        echo "Compiled $out ($(msgfmt --statistics -o /dev/null "$po" 2>&1))"
    done
    catalogs
}

check() {
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    extract_to "$tmp"
    if ! diff -q <(grep -v '^"Project-Id-Version' "$POT") <(grep -v '^"Project-Id-Version' "$tmp") >/dev/null; then
        echo "$POT is out of date; run scripts/i18n.sh extract" >&2
        diff -u "$POT" "$tmp" | head -40 >&2
        exit 1
    fi
    node scripts/po2js.mjs "$tmp" po/*.po
    if ! diff -q "$CATALOGS" "$tmp" >/dev/null; then
        echo "$CATALOGS is out of date; run scripts/i18n.sh compile" >&2
        exit 1
    fi
    for po in po/*.po; do
        [ -e "$po" ] || continue
        msgfmt --check -o /dev/null "$po"
        untranslated=$(msgattrib --untranslated --no-obsolete "$po" | grep -c '^msgid ' || true)
        fuzzy=$(msgattrib --only-fuzzy --no-obsolete "$po" | grep -c '^msgid ' || true)
        echo "$po: $untranslated untranslated, $fuzzy fuzzy"
    done
}

case "${1:-all}" in
    extract) extract ;;
    compile) compile ;;
    check) check ;;
    all) extract; compile ;;
    *) echo "usage: $0 [extract|compile|check]" >&2; exit 2 ;;
esac
