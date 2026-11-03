#!/bin/bash
# Runs the test bots on the stripped Godot (the engine cuts in build_conf/, on
# Linux), one after another, through tests/run_all.sh. The game comes from an
# exported pack, not the project folder, so the bots see what an export sees.
# bots.yml runs it with engine "stripped", one bot per job.
#
# usage:
#   .github/scripts/run_stripped_bots.sh [bot ...]     (as tests/run_all.sh; all by default)
#
# Env:
#   STRIPPED   the directory with godot.template_debug (the Linux debug
#              template from build-stripped-template.sh) and game.pck (the game,
#              from the stock editor's --export-pack); default build/stripped,
#              as bots.yml's pack job lays them out
#   and every variable tests/run_all.sh reads (OUT, TIMEOUT, RETRY, STOP, ...)
#   except GODOT, which this script sets.

set -euo pipefail
cd "$(dirname "$0")/../.."

stripped=$(cd "${STRIPPED:-build/stripped}" && pwd)
binary=$stripped/godot.template_debug
pack=$stripped/game.pck
for f in "$binary" "$pack"; do
	if [ ! -f "$f" ]; then
		echo "run_stripped_bots: $f is missing; see the header" >&2
		exit 1
	fi
done
chmod +x "$binary"

# run_all.sh and run_net_test.sh start Godot with "--path <project>"; this
# stand-in swaps that for "--main-pack <pack>" and passes everything else on.
wrapper_dir=$(mktemp -d)
trap 'rm -rf "$wrapper_dir"' EXIT
wrapper=$wrapper_dir/godot
cat > "$wrapper" <<WRAPPER
#!/bin/bash
args=()
while [ \$# -gt 0 ]; do
	if [ "\$1" = --path ]; then
		shift 2
		continue
	fi
	args+=("\$1")
	shift
done
exec "$binary" --main-pack "$pack" "\${args[@]}"
WRAPPER
chmod +x "$wrapper"

GODOT=$wrapper tests/run_all.sh "$@"
