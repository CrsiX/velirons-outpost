#!/usr/bin/env bash
# Runs the headless test bots (tests/*_bot.gd) one after another, keeps a log
# per bot and turns the whole lot into one summary of what they found.
#
#   tests/run_all.sh [bot ...]
#
#   bot   the name without "_bot": mapgen, world, sim, ...; all of them by default
#
# Env:
#   GODOT      the Godot 4 binary (else `godot` or `godot4` from the PATH)
#   OUT        where the logs go (default $TMPDIR/velirons-bots)
#   SUMMARY    where the markdown summary goes (default $OUT/summary.md)
#   REPORT     where the machine readable report goes (default $OUT/report.json)
#   TIMEOUT    seconds one bot may take before it is killed (default 1800)
#   STOP       1 to give up after the first bot that fails (default 0)
#
# Examples:  tests/run_all.sh              every bot
#            tests/run_all.sh mapgen world just those two
#            STOP=1 tests/run_all.sh       stop at the first failure
#
# Exits 0 only when every bot passed.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot=${GODOT:-$(command -v godot || command -v godot4 || true)}
if [[ -z "$godot" ]]; then
	echo "Godot not found: set GODOT=/path/to/godot" >&2
	exit 1
fi

# Cheap ones first, so a broken build shows up in seconds and not in an hour.
all=(build library stats mapgen world title coop net tutorial military enemy rat sim)
bots=("$@")
if (( ${#bots[@]} == 0 )); then
	bots=("${all[@]}")
fi

out=${OUT:-${TMPDIR:-/tmp}/velirons-bots}
summary=${SUMMARY:-$out/summary.md}
report=${REPORT:-$out/report.json}
timeout_s=${TIMEOUT:-1800}
mkdir -p "$out"
rm -f "$out"/*.log "$out/results.tsv"
printf 'bot\tstatus\texit\tseconds\n' > "$out/results.tsv"

rc=0
for bot in "${bots[@]}"; do
	scene="$root/tests/${bot}_bot.tscn"
	log="$out/$bot.log"
	if [[ ! -f "$scene" ]]; then
		echo "=== $bot: there is no tests/${bot}_bot.tscn ==="
		printf '%s\tmissing\t127\t0\n' "$bot" >> "$out/results.tsv"
		rc=1
		continue
	fi
	echo "=== $bot ==="
	start=$SECONDS
	if [[ "$bot" == net ]]; then
		# Two processes, one host and one client; its own script knows how.
		timeout "$timeout_s" "$root/tests/run_net_test.sh" "$godot" > "$log" 2>&1
	else
		timeout "$timeout_s" "$godot" --headless --fixed-fps 60 --path "$root" \
			"res://tests/${bot}_bot.tscn" > "$log" 2>&1
	fi
	code=$?
	took=$((SECONDS - start))
	status=ok
	if (( code == 124 )); then
		status=timeout
	elif (( code != 0 )); then
		status=failed
	fi
	printf '%s\t%s\t%d\t%d\n' "$bot" "$status" "$code" "$took" >> "$out/results.tsv"
	# Enough of the log to see what happened without opening it.
	grep -E "^  FAIL |SCRIPT ERROR|^CHECKS|^  - " "$log" | head -40 | sed 's/^/  /'
	echo "  -> $status in ${took}s ($log)"
	if [[ "$status" != ok ]]; then
		rc=1
		if [[ "${STOP:-0}" == 1 ]]; then
			echo "  (STOP=1: giving up here)"
			break
		fi
	fi
done

if command -v python3 > /dev/null; then
	python3 "$root/tests/summarize.py" "$out" --source-dir "$root/tests" \
		--markdown "$summary" --json "$report" && echo && cat "$summary"
else
	echo "no python3: skipping the summary" >&2
fi

exit $rc
