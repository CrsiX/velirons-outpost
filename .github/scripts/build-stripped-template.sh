#!/bin/bash
# Builds one Godot export template with the engine cuts in build_conf/
# (godot-build-options.py and compilation_profile.gdbuild) and stores it under
# the file name the editor looks for in its export templates folder. CI's
# stripped-template action runs it (one cached template per job);
# export-stripped.sh exports the game with them, and the Linux debug one runs
# the bots (run_stripped_bots.sh).
#
# usage:
#   .github/scripts/build-stripped-template.sh <linux|windows|android|web> [template_release|template_debug]
#
# Env:
#   GODOT_SRC      Godot's source tree; cloned there when missing
#                  (default build/godot-src)
#   GODOT_TAG      the Godot tag to clone (default 4.7.2-stable, as in fdroid.yaml)
#   TEMPLATES      where the template goes (default build/stripped/templates)
#   SCONS_CACHE    a SCons cache directory, to make a rebuild fast (optional)
#   JOBS           parallel compile jobs (default nproc)
#
# Needs scons and a C++ compiler, and per platform what Godot's "Compiling
# for ..." pages list: windows MinGW-w64 (posix threads), android a JDK 17 and
# the Android SDK in ANDROID_HOME (the NDK is fetched with its sdkmanager), web
# an activated Emscripten (emsdk). Linux and Windows fetch Godot's prebuilt
# AccessKit (screen readers), Windows also ANGLE, as Godot's own builds do.

set -euo pipefail
cd "$(dirname "$0")/../.."
root=$PWD

usage="usage: .github/scripts/build-stripped-template.sh <linux|windows|android|web> [template_release|template_debug]"
platform=${1:?$usage}
target=${2:-template_release}
src=${GODOT_SRC:-build/godot-src}
tag=${GODOT_TAG:-4.7.2-stable}
templates=${TEMPLATES:-build/stripped/templates}
jobs=${JOBS:-$(nproc)}
options=$root/build_conf/godot-build-options.py
profile=$root/build_conf/compilation_profile.gdbuild

case "$target" in
	template_release) kind=release ;;
	template_debug) kind=debug ;;
	*) echo "$usage" >&2; exit 1 ;;
esac
for f in "$options" "$profile"; do
	if [ ! -f "$f" ]; then
		echo "build-stripped-template: $f is missing" >&2
		exit 1
	fi
done
command -v scons >/dev/null || { echo "build-stripped-template: scons not found" >&2; exit 1; }

if [ ! -d "$src/.git" ]; then
	echo "== cloning Godot $tag into $src"
	git clone -q --depth 1 --branch "$tag" https://github.com/godotengine/godot.git "$src"
fi
mkdir -p "$templates"
src=$(cd "$src" && pwd)
templates=$(cd "$templates" && pwd)

# What scons writes (in $src/bin) and the name the editor wants.
case "$platform" in
	linux)
		flags=(platform=linux arch=x86_64)
		built=(godot.linuxbsd.$target.x86_64)
		names=(linux_$kind.x86_64)
		deps=(accesskit)
		;;
	windows)
		flags=(platform=windows arch=x86_64 use_mingw=yes)
		built=(godot.windows.$target.x86_64.exe godot.windows.$target.x86_64.console.exe)
		names=(windows_${kind}_x86_64.exe windows_${kind}_x86_64_console.exe)
		deps=(accesskit angle)
		;;
	android)
		: "${ANDROID_HOME:?build-stripped-template: set ANDROID_HOME to the Android SDK}"
		flags=(platform=android arch=arm64 swappy=no generate_android_binaries=yes)
		built=(android_$kind.apk)
		names=(android_$kind.apk)
		deps=()
		;;
	web)
		command -v emcc >/dev/null || { echo "build-stripped-template: emcc not found (activate emsdk)" >&2; exit 1; }
		flags=(platform=web threads=no)
		built=(godot.web.$target.wasm32.nothreads.zip)
		names=(web_nothreads_$kind.zip)
		deps=()
		;;
	*)
		echo "$usage" >&2
		exit 1
		;;
esac

for d in "${deps[@]}"; do
	have=$src/bin/build_deps/$d
	[ "$d" = angle ] && have=$src/bin/build_deps/angle-x86_64-gcc
	if [ ! -d "$have" ]; then
		echo "== fetching Godot's prebuilt $d"
		(cd "$src" && python3 "misc/scripts/install_$d.py")
	fi
done

extra=()
[ "$kind" = release ] && extra+=(production=yes)
# Templates ignore --main-pack and a scene on the command line by default; the
# bots need both on the Linux debug template (only there: the Android and Web
# debug builds go to players). That switch changes the command line, not which
# engine parts are in.
[ "$kind" = debug ] && [ "$platform" = linux ] && extra+=(disable_path_overrides=no)
[ -n "${SCONS_CACHE:-}" ] && extra+=("cache_path=$SCONS_CACHE")

echo "== building $platform $target"
(cd "$src" && scons -j"$jobs" target="$target" "${flags[@]}" \
	profile="$options" build_profile="$profile" \
	verbose=no warnings=no progress=no "${extra[@]}")

for i in "${!built[@]}"; do
	if [ -f "$src/bin/${built[$i]}" ]; then
		cp "$src/bin/${built[$i]}" "$templates/${names[$i]}"
		echo "template: $templates/${names[$i]}"
	elif [ "$i" -eq 0 ]; then
		echo "build-stripped-template: scons left no $src/bin/${built[$i]}" >&2
		exit 1
	fi
done
