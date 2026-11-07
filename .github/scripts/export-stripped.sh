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
# web build beside it).
#
# Android is exported exactly as fdroid.yaml does it, so the APKs match
# F-Droid's build (reproducible builds): the "F-Droid" preset, unsigned, with
# the template as ./android_<kind>.apk (the preset's custom template), then
# fdroid.yaml's postbuild: strip-nondeterminism (Godot dates every zip entry
# with the export time) and reproducible-apk-tools' zipalign.py, with
# SOURCE_DATE_EPOCH set to the commit's time as F-Droid's build server sets
# it. Last, signed here with apksigner from the Android SDK (ANDROID_HOME or
# ANDROID_SDK_ROOT, newest build-tools) and the keystore for the kind
# exported: GODOT_ANDROID_KEYSTORE_DEBUG_* / _RELEASE_* (_PATH, _USER,
# _PASSWORD), the same variables Godot reads.
#
# Android also needs: strip-nondeterminism (Debian/Ubuntu package) and
# REPRO_APK_TOOLS, a checkout of reproducible-apk-tools at the tag
# fdroid.yaml's srclib names.

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
	android) preset="F-Droid"; file=velirons-outpost.apk; need=android_$kind.apk ;;
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
custom=""
trap 'rm -rf "$data"; [ -z "$custom" ] || rm -f "$custom"' EXIT
mkdir -p "$data/godot/export_templates/$version"
cp "$templates"/* "$data/godot/export_templates/$version/"

if [ "$platform" = android ]; then
	kind_uc=$(echo "$kind" | tr a-z A-Z)
	for v in PATH USER PASSWORD; do
		var=GODOT_ANDROID_KEYSTORE_${kind_uc}_$v
		[ -n "${!var:-}" ] || { echo "export-stripped: set $var" >&2; exit 1; }
	done
	sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
	apksigner=$(ls -d "$sdk"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1 || true)
	[ -n "$apksigner" ] || { echo "export-stripped: no apksigner in the Android SDK (ANDROID_HOME)" >&2; exit 1; }
	command -v strip-nondeterminism >/dev/null || { echo "export-stripped: strip-nondeterminism not found" >&2; exit 1; }
	[ -f "${REPRO_APK_TOOLS:-}/zipalign.py" ] || { echo "export-stripped: set REPRO_APK_TOOLS to a reproducible-apk-tools checkout" >&2; exit 1; }
	export SOURCE_DATE_EPOCH
	SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)
	# The preset's custom template, where fdroid.yaml puts it too.
	custom=android_$kind.apk
	cp "$templates/$need" "$custom"
	final=$out
	out=$(dirname "$final")/unsigned-$(basename "$final")
fi

echo "== exporting $preset ($kind) with the stripped template ($version)"
mkdir -p "$(dirname "$out")"
XDG_DATA_HOME=$data GODOT=$godot tools/export.sh "$preset" "$out" $mode
test -s "$out"

if [ "$platform" = android ]; then
	ks=GODOT_ANDROID_KEYSTORE_${kind_uc}_PATH
	alias=GODOT_ANDROID_KEYSTORE_${kind_uc}_USER
	pass=GODOT_ANDROID_KEYSTORE_${kind_uc}_PASSWORD
	# fdroid.yaml's postbuild, the same commands.
	strip-nondeterminism -t zip "$out"
	unaligned=$(dirname "$out")/unaligned-$(basename "$out")
	mv "$out" "$unaligned"
	python3 "$REPRO_APK_TOOLS/zipalign.py" --page-size 16 --pad-like-apksigner \
		--replace "$unaligned" "$out"
	rm -f "$unaligned"
	echo "== signing with $apksigner"
	KS_PASS=${!pass} "$apksigner" sign --ks "${!ks}" --ks-key-alias "${!alias}" \
		--ks-pass env:KS_PASS --key-pass env:KS_PASS --out "$final" "$out"
	rm -f "$out" "$final.idsig"
	"$apksigner" verify "$final"
	out=$final
	test -s "$out"
fi
ls -lh "$(dirname "$out")"
