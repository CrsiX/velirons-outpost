#!/usr/bin/env bash
# Generates a map for <players> villages and saves a picture of the whole map
# as maps/map_<players>_<n>.png, where n is one higher than the last one
# there. Call it again and again to get a series of maps to compare.
#
#   tools/map_shot.sh <players> [seed] [scale] [iso] [map type]
#
#   players  1-8
#   seed     optional; random if left out or "" (printed either way, to regenerate a map)
#   scale    optional; plan: pixels per tile (default 6);
#            iso: image size vs. the game at 100 % zoom (default 0.35)
#   iso      optional; the isometric picture, drawn like the game, instead of
#            the top-down plan (maps/iso_<players>_<n>.png); "" or "plan" for the plan
#   map type optional; temperate (default), highlands, coast, desert, volcanic
#
# Examples:  tools/map_shot.sh 4            a plan of a random 4-player map
#            tools/map_shot.sh 4 12345      the same map again, by its seed
#            tools/map_shot.sh 4 12345 "" iso   its isometric picture
#
# Needs Godot 4: set GODOT to its path, or have `godot` on the PATH.
# Rendering is done on the CPU (headless): no GPU or display needed.
set -euo pipefail

if [[ $# -lt 1 || ! "$1" =~ ^[1-8]$ ]]; then
	echo "usage: $0 <players 1-8> [seed] [scale] [iso] [map type]" >&2
	exit 2
fi
players=$1
seed=${2:-}
scale=${3:-}
mode=${4:-plan}
map_type=${5:-temperate}
prefix=map
if [[ "$mode" == iso ]]; then
	prefix=iso
	scale=${scale:-0.35}
else
	mode=plan
	scale=${scale:-6}
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot=${GODOT:-$(command -v godot || command -v godot4 || true)}
if [[ -z "$godot" ]]; then
	echo "Godot not found: set GODOT=/path/to/godot" >&2
	exit 1
fi

mkdir -p "$root/maps"
touch "$root/maps/.gdignore"  # (keep Godot from importing the pictures)
last=0
shopt -s nullglob
for f in "$root/maps/${prefix}_${players}_"*.png; do
	n=${f##*_}
	n=${n%.png}
	[[ "$n" =~ ^[0-9]+$ ]] && (( n > last )) && last=$n
done
out="$root/maps/${prefix}_${players}_$((last + 1)).png"

"$godot" --headless --path "$root" res://tools/map_shot.tscn -- "$players" "$out" "$seed" "$scale" "$mode" "$map_type" 2>&1 \
	| grep -vE "^Godot Engine|^$" || true
[[ -f "$out" ]] || { echo "no picture was written" >&2; exit 1; }
