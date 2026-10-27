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
#   RETRY      bots (space separated) that get a second run when the first fails
#              (flaky ones; CI: sim). The second run decides: passed, the bot
#              passes; failed again, it fails, and the log says whether with the
#              same error. The first run's log stays as <bot>.first.txt.
#
# Examples:  tests/run_all.sh              every bot
#            tests/run_all.sh mapgen world just those two
#            STOP=1 tests/run_all.sh       stop at the first failure
#
# Exits 0 only when every bot passed: exit code 0 and no script or parse error in its log.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot=${GODOT:-$(command -v godot || command -v godot4 || true)}
if [[ -z "$godot" ]]; then
	echo "Godot not found: set GODOT=/path/to/godot" >&2
	exit 1
fi

# Cheap ones first, so a broken build shows up in seconds and not in an hour.
all=(build library stats save map_format editor mapgen world title coop net tutorial scenario military enemy aqua siege rat hud sim)
bots=("$@")
if (( ${#bots[@]} == 0 )); then
	bots=("${all[@]}")
fi

out=${OUT:-${TMPDIR:-/tmp}/velirons-bots}
summary=${SUMMARY:-$out/summary.md}
report=${REPORT:-$out/report.json}
timeout_s=${TIMEOUT:-1800}
mkdir -p "$out"
rm -f "$out"/*.log "$out"/*.first.txt "$out/results.tsv"
printf 'bot\tstatus\texit\tseconds\n' > "$out/results.tsv"

# Runs bot $1 into log $2; sets code and status.
run_bot() {
	if [[ "$1" == net ]]; then
		# Two processes, one host and one client; its own script knows how.
		timeout "$timeout_s" "$root/tests/run_net_test.sh" "$godot" > "$2" 2>&1
	else
		timeout "$timeout_s" "$godot" --headless --fixed-fps 60 --path "$root" \
			"res://tests/$1_bot.tscn" > "$2" 2>&1
	fi
	code=$?
	status=ok
	if (( code == 124 )); then
		status=timeout
	elif (( code != 0 )); then
		status=failed
	elif grep -q -E "SCRIPT ERROR|Parse Error" "$2"; then
		status=failed  # (a script error fails it too, even with every check passed)
	fi
}

# What went wrong in log $2 of a run that ended as $1, numbers left out (they
# differ from run to run), to tell the same error from another one.
error_of() {
	{ echo "$1"; grep -E "^  FAIL |SCRIPT ERROR|Parse Error" "$2" | sed -E 's/[0-9]+(\.[0-9]+)?/N/g' | sort -u; }
}

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
	run_bot "$bot" "$log"
	if [[ "$status" != ok && " ${RETRY:-} " == *" $bot "* ]]; then
		first="$out/$bot.first.txt"
		mv "$log" "$first"
		first_error=$(error_of "$status" "$first")
		echo "  first run $status:"
		grep -E "^  FAIL |SCRIPT ERROR|Parse Error" "$first" | head -20 | sed 's/^/    /'
		echo "  (RETRY: running it again; first log in $first)"
		run_bot "$bot" "$log"
		if [[ "$status" == ok ]]; then
			echo "  second run passed: the first failure was flaky"
		elif [[ "$(error_of "$status" "$log")" == "$first_error" ]]; then
			echo "  second run $status with the same error"
		else
			echo "  second run $status with a different error"
		fi
	fi
	took=$((SECONDS - start))
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
