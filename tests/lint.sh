#!/bin/bash
# Runs gdlint over every GDScript file in the project.
#
#   tests/lint.sh                     # all of scripts/, tests/ and tools/
#   tests/lint.sh scripts/buildings   # only this path
#   GDLINT=~/.local/bin/gdlint tests/lint.sh
#
# gdlint comes from gdtoolkit, which is a Python package:
#
#   pip install gdtoolkit==4.5.0
#
# It reads .gdlintrc in the project root, so what counts as a problem is the
# same here as in the editor and in CI. Note that it checks style and shape
# only: GDScript's types are the engine's job, and a type error shows up when
# the bots run, not here.
#
# Exits 0 when nothing was found.
set -uo pipefail

cd "$(dirname "$0")/.."

# The pip console script if it is on the PATH, else the module (which works
# with nothing but PYTHONPATH set).
GDLINT="${GDLINT:-}"
if [ -z "$GDLINT" ]; then
	if command -v gdlint >/dev/null 2>&1; then
		GDLINT=gdlint
	elif python3 -c "import gdtoolkit.linter" >/dev/null 2>&1; then
		GDLINT="python3 -m gdtoolkit.linter"
	else
		echo "gdlint not found. Install it with:  pip install gdtoolkit==4.5.0" >&2
		exit 127
	fi
fi

paths=("$@")
if [ ${#paths[@]} -eq 0 ]; then
	paths=(scripts tests tools)
fi

echo "linting: ${paths[*]}"
$GDLINT "${paths[@]}"
