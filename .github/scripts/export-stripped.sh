#!/bin/bash
# Exports the game for one platform with the stripped templates that
# build-stripped-template.sh made (the engine cuts in build_conf/). The
# editor reads them from a temporary export templates folder (XDG_DATA_HOME),
# so the official templates you have installed are left alone. Stamps the
# version like every export (tools/export.sh). CI exports this way
# (.github/workflows/build.yml).
#
# usage:
#   .github/scripts/export-stripped.sh <linux|windows|android|web> [release|debug] [output file]
#
# Env:
#   GODOT       the stock Godot editor that exports (else `godot`)
#   TEMPLATES   where the stripped templates are (default build/stripped/templates)
#
# Default outputs, in build/stripped/export/<platform>/: velirons-outpost.x86_64,
# velirons-outpost.exe, velirons-outpost.apk, index.html (with the rest of the
# web build beside it). Android uses the "Android" preset: it needs the
# editor's Android SDK and Java paths, and a keystore for the kind exported
# (GODOT_ANDROID_KEYSTORE_DEBUG_* / _RELEASE_*), as for any export.

set -euo pipefail
cd "$(dirname "$0")/../.."

usage="usage: .github/scripts/export-stripped.sh <linux|windows|android|web> [release|debug] [output file]"
platform=${1:?$usage}
kind=${2:-release}
godot=${GODOT:-godot}
templates=${TEMPLATES:-build/stripped/templates}
templates=$(cd "$templates" && pwd)

case "$kind" in
	release) mode="" ;;
	debug) mode="--debug" ;;
	*) echo "$usage" >&2; exit 1 ;;
esac
case "$platform" in
	linux) preset="Linux"; file=velirons-outpost.x86_64; need=linux_$kind.x86_64 ;;
	windows) preset="Windows Desktop"; file=velirons-outpost.exe; need=windows_${kind}_x86_64.exe ;;
	android) preset="Android"; file=velirons-outpost.apk; need=android_$kind.apk ;;
	web) preset="Web"; file=index.html; need=web_nothreads_$kind.zip ;;
	*) echo "$usage" >&2; exit 1 ;;
esac
out=${3:-build/stripped/export/$platform/$file}
if [ ! -f "$templates/$need" ]; then
	echo "export-stripped: no $templates/$need; run .github/scripts/build-stripped-template.sh $platform template_$kind first" >&2
	exit 1
fi

# The folder the editor looks in is named after its version: 4.7.2.stable from
# "4.7.2.stable.official.<hash>".
version=$("$godot" --version | head -1 | sed -E 's/\.[^.]+\.[^.]+$//')
data=$(mktemp -d)
trap 'rm -rf "$data"' EXIT
mkdir -p "$data/godot/export_templates/$version"
cp "$templates"/* "$data/godot/export_templates/$version/"

echo "== exporting $preset ($kind) with the stripped template ($version)"
XDG_DATA_HOME=$data GODOT=$godot tools/export.sh "$preset" "$out" $mode
test -s "$out"
ls -lh "$(dirname "$out")"
