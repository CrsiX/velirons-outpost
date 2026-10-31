#!/bin/bash
# Exports a build with its version stamped in (BuildInfo): the stamp is written,
# Godot exports, and the stamp is removed again, whatever happens, so no stale
# one can ever end up in a later build.
#
# usage:
#   tools/export.sh "<preset>" <output file> [--debug]
#
# example:
#   GODOT=~/godot tools/export.sh "Web" build/web/index.html

set -euo pipefail
cd "$(dirname "$0")/.."

preset=${1:?usage: tools/export.sh "<preset>" <output file> [--debug]}
out=${2:?usage: tools/export.sh "<preset>" <output file> [--debug]}
mode=--export-release
[ "${3:-}" = "--debug" ] && mode=--export-debug

stamp=scripts/core/build_stamp.gd
rm -f "$stamp" "$stamp.uid"
trap 'rm -f "$stamp" "$stamp.uid"' EXIT

tools/stamp_version.sh
mkdir -p "$(dirname "$out")"
"${GODOT:-godot}" --headless --import
"${GODOT:-godot}" --headless "$mode" "$preset" "$out"
