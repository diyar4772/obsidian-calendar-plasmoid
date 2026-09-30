#!/bin/bash
# SPDX-FileCopyrightText: 2026 Samed Yolcu
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds build/obsidian-calendar-<version>.plasmoid (a zip of package/ with
# compiled translations), the file uploaded to the KDE Store and releases.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(node -p 'require("./package/metadata.json").KPlugin.Version')
OUT="build/obsidian-calendar-${VERSION}.plasmoid"

scripts/i18n.sh compile
mkdir -p build
rm -f "$OUT"
(cd package && zip -q -r -X "../$OUT" metadata.json contents)
echo "Built $OUT"
unzip -l "$OUT" | tail -n 1
