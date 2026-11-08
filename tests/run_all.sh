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
#   RETRY      bots (space separated) that get a second run when the first fails,
#              or "all" (CI: all). The second run decides: failed again, the bot
#              fails, and the log says whether with the same error; passed, the
#              bot counts as passed but as "flaky" in results.tsv and the
#              summary, with a warning that carries the first run's whole error
#              (a GitHub annotation too under GITHUB_ACTIONS). The first run's
#              log stays as <bot>.first.txt.
#
# Examples:  tests/run_all.sh              every bot
#            tests/run_all.sh mapgen world just those two
#            STOP=1 tests/run_all.sh       stop at the first failure
#
# Exits 0 only when every bot passed (a flaky one on its second run): exit code 0
# and no script or parse error in its log.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot=${GODOT:-$(command -v godot || command -v godot4 || true)}
if [[ -z "$godot" ]]; then
	echo "Godot not found: set GODOT=/path/to/godot" >&2
	exit 1
fi

# Cheap ones first, so a broken build shows up in seconds and not in an hour.
all=(build library stats save map_format editor mapgen world title coop net tutorial scenario military enemy aqua siege advancement market rat hud sim)
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

# Everything log $3 of a run that ended as $1 with exit code $2 says about why:
# every failed check and every engine error with the lines under it (where, the
# stack), or the end of the log when it has neither (a crash, a timeout).
failure_text() {
	echo "$1 (exit code $2)"
	local found
	found=$(grep -E -A6 "^  FAIL |SCRIPT ERROR|Parse Error|^(USER )?ERROR:" "$3")
	if [[ -n "$found" ]]; then
		echo "$found"
	else
		echo "(no failed check or engine error in the log; its last lines:)"
		tail -n 40 "$3"
	fi
}

# A GitHub Actions warning annotation: title $1, message $2 (newlines kept).
gh_warning() {
	[[ "${GITHUB_ACTIONS:-}" == true ]] || return 0
	local msg=$2
	msg=${msg//'%'/'%25'}
	msg=${msg//$'\r'/'%0D'}
	msg=${msg//$'\n'/'%0A'}
	echo "::warning title=$1::$msg"
}

rc=0
flaky=()
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
	if [[ "$status" != ok && ( "${RETRY:-}" == all || " ${RETRY:-} " == *" $bot "* ) ]]; then
		first="$out/$bot.first.txt"
		mv "$log" "$first"
		first_error=$(error_of "$status" "$first")
		first_text=$(failure_text "$status" "$code" "$first")
		echo "  first run:"
		printf '%s\n' "$first_text" | head -20 | sed 's/^/    /'
		echo "  (RETRY: running it again; first log in $first)"
		run_bot "$bot" "$log"
		if [[ "$status" == ok ]]; then
			status=flaky
			flaky+=("$bot")
			echo "  WARNING: $bot passed on the second try; the first run failed with:"
			printf '%s\n' "$first_text" | sed 's/^/    /'
			gh_warning "$bot bot passed on the second try (flaky)" \
				"The first run failed; the second passed, so the bot counts as passed. First run: $first_text"
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
	if [[ "$status" != ok && "$status" != flaky ]]; then
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

if (( ${#flaky[@]} )); then
	echo
	echo "WARNING: passed only on the second try (flaky): ${flaky[*]}; see the first runs' errors above"
fi

exit $rc
