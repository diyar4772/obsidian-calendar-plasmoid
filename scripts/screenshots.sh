#!/bin/bash
# SPDX-FileCopyrightText: 2026 Samed Yolcu
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Renders the README screenshots into docs/screenshots/ from the fictional
# fixture vaults, without opening any window: each shot installs the package
# into a temporary data dir, runs plasmoidviewer offscreen with a Breeze
# color scheme and grabs the widget.
#
#   scripts/screenshots.sh            all screenshots
#   scripts/screenshots.sh --one <light|dark> <native|journal> <locale> <WxH> <out.png> [key=value;...]
#
# Needs plasmoidviewer (plasma-sdk), kpackagetool6, ImageMagick and ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
OUT_DIR=docs/screenshots
# Rendered at twice the size so they stay sharp on HiDPI screens.
SCALE=${SCALE:-2}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A fixed "today" late in a month keeps the shots reproducible and full.
export TODAY=${TODAY:-2026-09-24}
node scripts/make-fixtures.mjs --out "$WORK/vaults" --today "$TODAY" >/dev/null

# One screenshot. $6: config overrides as "key=value;key=value" (keys from main.xml).
shot() {
    local scheme=$1 variant=$2 lang=$3 size=$4 out=$5 overrides=${6:-}
    local run target=applet
    # "@year" in the overrides grabs the Year Overview window instead.
    if [[ $overrides == *@year* ]]; then
        target=year
        overrides=${overrides//@year/}
    fi
    run=$(mktemp -d "$WORK/run.XXXX")
    mkdir -p "$run/cfg" "$run/data"
    cp -r package "$run/pkg"

    # Config defaults for this shot
    node - "$run/pkg/contents/config/main.xml" "vaultPath=$WORK/vaults/Örnek Vault;designVariant=$variant;$overrides" <<'JS'
const fs = require("fs");
const [file, spec] = process.argv.slice(2);
let xml = fs.readFileSync(file, "utf8");
for (const kv of spec.split(";").filter(Boolean)) {
    const [key, ...rest] = kv.split("=");
    const re = new RegExp(`(<entry name="${key}"[^>]*>[\\s\\S]*?<default>)([\\s\\S]*?)(</default>)`);
    if (!re.test(xml)) throw new Error(`unknown config key ${key}`);
    xml = xml.replace(re, (_, a, _b, c) => a + rest.join("=").replace(/&/g, "&amp;").replace(/</g, "&lt;") + c);
}
fs.writeFileSync(file, xml);
JS

    # Grab the applet container once it has been resized and has settled.
    local w=${size%x*} h=${size#*x}
    node - "$run/pkg/contents/ui/main.qml" "$out" "$w" "$h" "$target" <<'JS'
const fs = require("fs");
const [file, out, w, h, target] = process.argv.slice(2);
let qml = fs.readFileSync(file, "utf8").trimEnd();
const [ty, tm, td] = process.env.TODAY.split("-").map(Number);
const todayLine = "property var today: Dates.fromJsDate(new Date())";
if (!qml.includes(todayLine)) throw new Error("main.qml: today property not found");
qml = qml.replace(todayLine, `property var today: ({ y: ${ty}, m: ${tm}, d: ${td} })`);
qml = qml.slice(0, qml.lastIndexOf("}")) + `
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            if (${JSON.stringify(target)} === "year") {
                root.openYearOverview();
                const win = yearOverview.item;
                win.width = ${w}; win.height = ${h};
                screenshotTimer.target = win.contentItem;
                screenshotTimer.start();
                return;
            }
            let item = root;
            while (item && !String(item).startsWith("BasicAppletContainer")) {
                item = item.parent;
            }
            item.x = 10; item.y = 10; item.width = ${w}; item.height = ${h};
            screenshotTimer.target = item;
            screenshotTimer.start();
        }
    }
    Timer {
        id: screenshotTimer
        property Item target
        interval: 2500
        onTriggered: target.grabToImage(result => { result.saveToFile(${JSON.stringify(out)}); Qt.quit(); })
    }
}
`;
fs.writeFileSync(file, qml);
JS

    case $scheme in
        light) cp /usr/share/color-schemes/BreezeLight.colors "$run/cfg/kdeglobals"; printf '\n[General]\nColorScheme=BreezeLight\n' >> "$run/cfg/kdeglobals" ;;
        dark) cp /usr/share/color-schemes/BreezeDark.colors "$run/cfg/kdeglobals"; printf '\n[General]\nColorScheme=BreezeDark\n' >> "$run/cfg/kdeglobals" ;;
    esac
    printf '[Theme]\nname=default\n' > "$run/cfg/plasmarc"

    XDG_DATA_HOME="$run/data" kpackagetool6 -t Plasma/Applet -i "$run/pkg" >/dev/null
    LANG=$lang LC_ALL=$lang LANGUAGE=${lang%%_*} XDG_DATA_HOME="$run/data" XDG_CONFIG_HOME="$run/cfg" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR=$SCALE \
        timeout 30 plasmoidviewer -a io.github.diyar4772.obsidiancalendar -f planar -s 1200x1000 >/dev/null 2>&1 || true
    [ -f "$out" ] || { echo "failed: $out" >&2; return 1; }
}

# Puts a widget screenshot on a soft background with padding.
frame() {
    local in=$1 out=$2 top=$3 bottom=$4
    local w h
    w=$(magick identify -format '%w' "$in"); h=$(magick identify -format '%h' "$in")
    magick -size $((w + 96 * SCALE))x$((h + 96 * SCALE)) xc: -sparse-color barycentric "0,0 $top 0,%h $bottom" \
        \( "$in" \( +clone -background '#00000055' -shadow 60x$((10 * SCALE))+0+$((6 * SCALE)) \) +swap -background none -layers merge +repage \) \
        -gravity center -composite -strip "$out"
}

if [ "${1:-}" = "--one" ]; then
    shift
    shot "$@"
    exit
fi

mkdir -p "$OUT_DIR"
cd "$WORK"
scripts=$ROOT/scripts
declare -a jobs=(
    "dark native en_US.UTF-8 380x440 native-dark.png"
    "light native en_US.UTF-8 380x440 native-light.png"
    "dark journal en_US.UTF-8 380x440 journal-dark.png"
    "light journal en_US.UTF-8 380x440 journal-light.png"
    "dark native tr_TR.UTF-8 380x420 native-dark-tr.png"
    "dark journal en_US.UTF-8 380x440 journal-accent.png accentMode=custom;customAccent=#8e6ceb;tileShape=circle"
    "light native en_US.UTF-8 380x420 native-scheme.png colorScheme=/usr/share/color-schemes/BreezeDark.colors;backgroundOpacity=80"
    "dark native en_US.UTF-8 400x420 periodic.png vaultPath=$WORK/vaults/Periodic Vault"
    "light native en_US.UTF-8 380x300 error.png vaultPath=$WORK/vaults/Broken Vault"
    "dark native en_US.UTF-8 980x600 year-dark.png @year"
    "light journal en_US.UTF-8 980x600 year-light.png @year;dotSource=size"
)
cd "$ROOT"
for job in "${jobs[@]}"; do
    read -r scheme variant lang size name overrides <<<"$job"
    shot "$scheme" "$variant" "$lang" "$size" "$WORK/$name" "${overrides:-}" &
    while [ "$(jobs -r | wc -l)" -ge 4 ]; do sleep 0.5; done
done
wait
for job in "${jobs[@]}"; do
    read -r scheme _ _ _ name _ <<<"$job"
    if [ "$scheme" = dark ]; then
        frame "$WORK/$name" "$OUT_DIR/$name" '#2b3a55' '#1b1e24'
    else
        frame "$WORK/$name" "$OUT_DIR/$name" '#dfe8f5' '#f4f6fa'
    fi
done
# Hero image: both designs side by side
magick "$OUT_DIR/native-dark.png" "$OUT_DIR/journal-light.png" -background none -gravity center +append -strip "$OUT_DIR/hero.png"
# Short tour of the designs and colors (ffmpeg makes a proper palette GIF)
tour=$(mktemp -d "$WORK/tour.XXXX")
i=0
for f in native-dark journal-dark journal-accent native-light; do
    cp "$OUT_DIR/$f.png" "$tour/$(printf '%02d' $i).png"
    i=$((i + 1))
done
ffmpeg -loglevel error -y -framerate 0.6 -i "$tour/%02d.png" \
    -vf "split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=none" \
    -loop 0 "$OUT_DIR/tour.gif"
ls -1 "$OUT_DIR"
