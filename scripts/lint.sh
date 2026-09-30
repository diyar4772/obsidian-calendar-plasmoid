#!/bin/bash
# SPDX-FileCopyrightText: 2026 Samed Yolcu
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Lints the QML and JavaScript with qmllint (settings in .qmllint.ini) and
# checks that the translation template is up to date.
set -euo pipefail
cd "$(dirname "$0")/.."

QMLLINT=${QMLLINT:-$(command -v qmllint6 || command -v qmllint || echo /usr/lib64/qt6/bin/qmllint)}
"$QMLLINT" --max-warnings 0 \
    package/contents/ui/*.qml package/contents/config/*.qml package/contents/code/*.js package/contents/code/*.mjs
echo "qmllint: OK"

node -e 'JSON.parse(require("fs").readFileSync("package/metadata.json", "utf8"))'
echo "metadata.json: OK"

scripts/i18n.sh check
