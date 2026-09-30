#!/bin/bash
# SPDX-FileCopyrightText: 2026 Samed Yolcu
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Loads the installed widget in plasmoidviewer (offscreen) with the fixture
# vaults and both designs, and fails on any QML error or warning from the
# package. Used by CI; needs plasmoidviewer (plasma-sdk) and kpackagetool6.
set -euo pipefail

# plasmoidviewer needs a session bus (missing in CI containers).
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null; then
    exec dbus-run-session -- "$0" "$@"
fi
export LANG=${LANG:-C.UTF-8} LC_ALL=${LC_ALL:-C.UTF-8}

cd "$(dirname "$0")/.."
ROOT=$PWD
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

node scripts/make-fixtures.mjs --out "$WORK/vaults" >/dev/null
failed=0

run() {
    local name=$1 spec=$2
    local run="$WORK/$name"
    mkdir -p "$run/cfg" "$run/data"
    cp -r "${PACKAGE_DIR:-$ROOT/package}" "$run/pkg"
    node - "$run/pkg/contents/config/main.xml" "$spec" <<'JS'
const fs = require("fs");
const [file, spec] = process.argv.slice(2);
let xml = fs.readFileSync(file, "utf8");
for (const kv of spec.split(";").filter(Boolean)) {
    const [key, ...rest] = kv.split("=");
    const re = new RegExp(`(<entry name="${key}"[^>]*>[\\s\\S]*?<default>)([\\s\\S]*?)(</default>)`);
    if (!re.test(xml)) throw new Error(`unknown config key ${key}`);
    xml = xml.replace(re, (_, a, _b, c) => a + rest.join("=") + c);
}
fs.writeFileSync(file, xml);
JS
    # Optionally open the Year Overview window once the vault is read.
    if [ -n "${3:-}" ]; then
        node - "$run/pkg/contents/ui/main.qml" <<'JS'
const fs = require("fs");
const file = process.argv[2];
const qml = fs.readFileSync(file, "utf8").trimEnd();
fs.writeFileSync(file, qml.slice(0, qml.lastIndexOf("}"))
    + "    Timer { interval: 3000; running: true; onTriggered: root.openYearOverview() }\n}\n");
JS
    fi
    XDG_DATA_HOME="$run/data" kpackagetool6 -t Plasma/Applet -i "$run/pkg" >/dev/null
    XDG_DATA_HOME="$run/data" XDG_CONFIG_HOME="$run/cfg" HOME="$run" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
        QT_LOGGING_RULES="*.debug=false;qml.debug=true" \
        timeout 12 plasmoidviewer -a io.github.diyar4772.obsidiancalendar -f planar -s 600x600 \
        > "$run/log" 2>&1 || true
    # Only messages about our own files count.
    if grep -E "obsidiancalendar/contents/.*(Error|error|TypeError|ReferenceError|is not defined|Cannot read|Binding loop|Unable to assign|not declared|Warning)" "$run/log"; then
        echo "FAIL: $name" >&2
        failed=1
    elif ! grep -q "View QML loaded\|New Containment" "$run/log"; then
        echo "FAIL: $name (plasmoidviewer didn't start)" >&2
        cat "$run/log" >&2
        failed=1
    else
        echo "ok: $name"
    fi
}

V="$WORK/vaults"
run native-example "vaultPath=$V/Örnek Vault;designVariant=native"
run year-overview "vaultPath=$V/Örnek Vault;dotSource=size" year
run journal-periodic "vaultPath=$V/Periodic Vault;designVariant=journal;tileShape=circle"
run broken "vaultPath=$V/Broken Vault;dotSource=size"
run missing "vaultPath=/nonexistent/vault"
run scheme "vaultPath=$V/Örnek Vault;colorScheme=/usr/share/color-schemes/BreezeLight.colors;accentMode=custom;customAccent=#202020"
exit $failed
