#!/usr/bin/env python3
"""Turns the test bots' logs into one summary of what they found.

    tests/summarize.py <log dir> [--markdown FILE] [--json FILE] [--source-dir DIR]

<log dir> is searched for *.log files (one per bot, named after it) and for the
results.tsv that tests/run_all.sh writes, so it works both on one machine and on
a pile of artifacts downloaded from a CI matrix.

Every failed check is traced back to the check() call that printed it, by
matching the fixed parts of its format string against the message, and is shown
with the section of the bot it sits in -- the point being that whoever reads the
summary (or whatever reads the JSON) can go straight to the line that broke.
The map generation bot's MAPGEN lines and the generator's own GEN_PROFILE stage
timings are turned into tables of hit rate, cost and what the maps look like.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import statistics
import sys
from collections import Counter, defaultdict

# "  ok   the hero heals" / "  FAIL the hero heals"
CHECK_RE = re.compile(r"^  (ok  |FAIL) (.*)$")
# Both spellings are in use: "CHECKS: 12  FAILURES: 0" and without the colons.
COUNT_RE = re.compile(r"^CHECKS:?\s+(\d+)\s+FAILURES:?\s+(\d+)")
ERROR_RE = re.compile(r"^(?:USER )?(SCRIPT ERROR|ERROR):\s*(.*)$")
WARNING_RE = re.compile(r"^(?:USER )?WARNING:\s*(.*)$")
AT_RE = re.compile(r"^\s+at: (.*)$")
# The map generation bot's lines.
MAPGEN_RE = re.compile(r"^MAPGEN (type=.*)$")
MAPGEN_WHY_RE = re.compile(r"^MAPGEN-(FAIL|SOFT) type=(\S+) players=(\d+) seed=(\d+) \| (.*)$")
MAPGEN_FAULT_RE = re.compile(r"^MAPGEN-FAULT (.*?) \| (.*)$")
# MapGenerator.run()'s own timings, printed when GEN_PROFILE is set.
STAGES = ["slices", "fields", "water", "relief", "zones", "villages", "roads", "fixes", "objects"]
PROFILE_RE = re.compile(r"^" + ", ".join(r"%s (\d+)" % s for s in STAGES) + r"\s*$")
# A format placeholder in a GDScript string: %d, %.2f, %s, %%, ...
FORMAT_RE = re.compile(r"%[-+ #0-9.*]*[a-zA-Z%]")
# "# --- the generator ------" above a block of functions.
SECTION_RE = re.compile(r"^#\s*-{2,}\s*(.*?)\s*-{2,}\s*$")
# A plain double quoted GDScript string on one line.
STRING_RE = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
DIGITS_RE = re.compile(r"[0-9]+(?:[.,][0-9]+)?")


# --- reading the logs -----------------------------------------------------------------------


def find_logs(root):
	"""Every *.log under `root`, newest wins if a name turns up twice."""
	out = {}
	for dirpath, _dirnames, filenames in os.walk(root):
		for name in sorted(filenames):
			if name.endswith(".log"):
				path = os.path.join(dirpath, name)
				bot = name[: -len(".log")]
				if bot not in out or os.path.getmtime(path) > os.path.getmtime(out[bot]):
					out[bot] = path
	return out


def read_results(root):
	"""The status rows tests/run_all.sh wrote, by bot."""
	out = {}
	for dirpath, _dirnames, filenames in os.walk(root):
		if "results.tsv" not in filenames:
			continue
		with open(os.path.join(dirpath, "results.tsv"), encoding="utf-8", errors="replace") as f:
			for line in f.read().splitlines()[1:]:
				parts = line.split("\t")
				if len(parts) >= 4:
					out[parts[0]] = {
						"status": parts[1],
						"exit": int(parts[2] or 0),
						"seconds": int(parts[3] or 0),
					}
	return out


def parse_log(path):
	"""One bot's log: its checks, its failures, engine errors and MAPGEN lines."""
	with open(path, encoding="utf-8", errors="replace") as f:
		lines = f.read().splitlines()
	bot = {
		"checks": 0,
		"ok": 0,
		"failures": [],
		"reported_checks": 0,
		"reported_failures": 0,
		"errors": [],
		"warnings": Counter(),
		"maps": [],
		"map_why": [],
		"map_faults": [],
		"stages": [],
		"lines": len(lines),
	}
	for i, line in enumerate(lines):
		m = CHECK_RE.match(line)
		if m:
			bot["checks"] += 1
			if m.group(1) == "FAIL":
				bot["failures"].append(m.group(2).strip())
			else:
				bot["ok"] += 1
			continue
		m = COUNT_RE.match(line)
		if m:  # net_bot reports twice, once for the host and once for the client
			bot["reported_checks"] += int(m.group(1))
			bot["reported_failures"] += int(m.group(2))
			continue
		m = ERROR_RE.match(line)
		if m:
			where = ""
			frames = []
			for nxt in lines[i + 1 : i + 8]:
				at = AT_RE.match(nxt)
				if at and not where:
					where = at.group(1).strip()
				elif nxt.strip().startswith("<Stack") or re.match(r"^\s+\d+ - ", nxt):
					frames.append(nxt.strip())
			bot["errors"].append(
				{"kind": m.group(1), "message": m.group(2).strip(), "at": where, "frames": frames[:6]}
			)
			continue
		m = WARNING_RE.match(line)
		if m:
			bot["warnings"][DIGITS_RE.sub("#", m.group(1).strip())] += 1
			continue
		m = MAPGEN_RE.match(line)
		if m:
			bot["maps"].append(parse_fields(m.group(1)))
			continue
		m = MAPGEN_WHY_RE.match(line)
		if m:
			bot["map_why"].append(
				{
					"hard": m.group(1) == "FAIL",
					"type": m.group(2),
					"players": int(m.group(3)),
					"seed": int(m.group(4)),
					"why": m.group(5).strip(),
				}
			)
			continue
		m = MAPGEN_FAULT_RE.match(line)
		if m:
			bot["map_faults"].append({"where": m.group(1), "what": m.group(2)})
			continue
		m = PROFILE_RE.match(line)
		if m:
			bot["stages"].append([int(v) for v in m.groups()])
	# The bots' own count is the one to trust; the ok/FAIL lines are a cross check.
	if bot["reported_checks"]:
		bot["checks"] = max(bot["checks"], bot["reported_checks"])
	return bot


def parse_fields(text):
	"""`a=1 b=x` -> {"a": 1, "b": "x"}, numbers where they look like numbers."""
	out = {}
	for part in text.split(" "):
		if "=" not in part:
			continue
		key, value = part.split("=", 1)
		try:
			out[key] = int(value)
		except ValueError:
			try:
				out[key] = float(value)
			except ValueError:
				out[key] = value
	return out


# --- tracing a failure back to its check() --------------------------------------------------


class Source:
	"""A bot's source, for looking up where a message was printed."""

	def __init__(self, path):
		self.path = path
		self.strings = []  # (line, section, [fixed fragments])
		section = ""
		start = 0  # the line a check() call that is still open began on
		depth = 0
		with open(path, encoding="utf-8", errors="replace") as f:
			for n, line in enumerate(f.read().splitlines(), start=1):
				m = SECTION_RE.match(line.strip())
				if m:
					section = m.group(1)
					continue
				rest = line
				if not depth:
					at = line.find("check(")
					if at < 0:
						continue
					start, rest = n, line[at + len("check(") :]
					depth = 1
				# Only what a check() prints, so the maps and tables the bots
				# also carry around cannot be mistaken for a message.
				for hit in STRING_RE.finditer(rest):
					text = hit.group(1)
					if text.startswith("res://") or len(text) < 8:
						continue
					bits = [b for b in FORMAT_RE.split(text) if len(b.strip()) >= 4]
					if bits:
						self.strings.append((start, section, bits, text))
				bare = STRING_RE.sub("", rest)
				depth = max(0, depth + bare.count("(") - bare.count(")"))

	def find(self, message):
		"""The line whose string literal best explains `message`."""
		best = None
		best_score = 0
		ties = 0
		for line, section, bits, text in self.strings:
			at = 0
			score = 0
			for bit in bits:
				found = message.find(bit, at)
				if found < 0:
					score = 0
					break
				at = found + len(bit)
				score += len(bit)
			if score > best_score:
				best_score = score
				best = (line, section, text)
				ties = 0
			elif score == best_score and score > 0:
				ties += 1
		if best is None or best_score < 10:
			return None
		return {"line": best[0], "section": best[1], "score": best_score, "others": ties}


def locate(failures, source_dir, bot):
	"""Each failure with the tests/<bot>_bot.gd line that printed it."""
	path = os.path.join(source_dir, "%s_bot.gd" % bot)
	src = Source(path) if os.path.isfile(path) else None
	out = []
	for message in failures:
		item = {"message": message}
		hit = src.find(message) if src else None
		if hit:
			item["source"] = "tests/%s_bot.gd:%d" % (bot, hit["line"])
			item["section"] = hit["section"]
			if hit["others"]:
				item["others"] = hit["others"]
		out.append(item)
	return out


# --- the map generation tables ----------------------------------------------------------------


def mapgen_report(maps, whys, faults, stages):
	"""Everything the sweep said, grouped into something worth reading."""
	if not maps:
		return None
	cases = defaultdict(list)
	for row in maps:
		cases[(row.get("type", "?"), row.get("players", 0))].append(row)
	by_case = []
	for (map_type, players), rows in sorted(cases.items()):
		ms = sorted(r.get("ms", 0) for r in rows)
		by_case.append(
			{
				"type": map_type,
				"players": players,
				"maps": len(rows),
				"first_try": sum(1 for r in rows if not r.get("hard")) / len(rows),
				"soft": sum(1 for r in rows if r.get("soft")),
				"ms_p50": pct(ms, 0.5),
				"ms_p95": pct(ms, 0.95),
				"tiles": rows[0].get("size", 0),
			}
		)
	hard = Counter()
	soft = Counter()
	examples = {}
	for why in whys:
		key = DIGITS_RE.sub("#", why["why"])
		(hard if why["hard"] else soft)[key] += 1
		examples.setdefault(key, "%s, %d players, seed %d" % (why["type"], why["players"], why["seed"]))
	makeup = defaultdict(lambda: defaultdict(list))
	for row in maps:
		for key in ("terrain", "zones", "objects"):
			for bit in str(row.get(key, "")).split(","):
				if ":" in bit:
					name, value = bit.split(":", 1)
					try:
						makeup[row.get("type", "?")]["%s.%s" % (key, name)].append(float(value))
					except ValueError:
						pass
	return {
		"maps": len(maps),
		"first_try": sum(1 for r in maps if not r.get("hard")) / len(maps),
		"by_case": by_case,
		"hard": [{"why": w, "count": n, "example": examples.get(w, "")} for w, n in hard.most_common()],
		"soft": [{"why": w, "count": n, "example": examples.get(w, "")} for w, n in soft.most_common()],
		"faults": [{"what": w, "count": n} for w, n in Counter(f["what"] for f in faults).most_common()],
		"makeup": {t: {k: round(statistics.fmean(v), 3) for k, v in d.items()} for t, d in makeup.items()},
		"stages": stage_costs(stages),
	}


def stage_costs(stages):
	"""GEN_PROFILE's running totals turned into what each stage costs."""
	if not stages:
		return []
	per_stage = defaultdict(list)
	for marks in stages:
		last = 0
		for name, total in zip(STAGES, marks):
			per_stage[name].append(max(0, total - last))
			last = total
	whole = sum(statistics.fmean(v) for v in per_stage.values()) or 1.0
	return [
		{
			"stage": name,
			"mean_ms": round(statistics.fmean(per_stage[name]), 1),
			"p95_ms": pct(sorted(per_stage[name]), 0.95),
			"share": statistics.fmean(per_stage[name]) / whole,
			"runs": len(per_stage[name]),
		}
		for name in STAGES
		if name in per_stage
	]


def pct(values, q):
	if not values:
		return 0
	return values[min(len(values) - 1, max(0, round(q * (len(values) - 1))))]


# --- putting it together ----------------------------------------------------------------------


def build(log_dir, source_dir):
	logs = find_logs(log_dir)
	results = read_results(log_dir)
	bots = []
	maps, whys, faults, stages = [], [], [], []
	for name in sorted(set(logs) | set(results)):
		parsed = parse_log(logs[name]) if name in logs else parse_log(os.devnull)
		row = results.get(name, {})
		status = row.get("status")
		if not status:
			status = "failed" if parsed["failures"] or parsed["errors"] else "ok"
		bots.append(
			{
				"name": name,
				"status": status,
				"exit": row.get("exit", 0),
				"seconds": row.get("seconds", 0),
				"checks": parsed["checks"],
				"passed": parsed["checks"] - len(parsed["failures"]),
				"failures": locate(parsed["failures"], source_dir, name),
				"errors": parsed["errors"],
				"warnings": [{"text": t, "count": n} for t, n in parsed["warnings"].most_common(10)],
				"log": os.path.relpath(logs[name], log_dir) if name in logs else "",
			}
		)
		maps += parsed["maps"]
		whys += parsed["map_why"]
		faults += parsed["map_faults"]
		stages += parsed["stages"]
	report = {
		"generated": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
		"bots": bots,
		"totals": {
			"bots": len(bots),
			"passed": sum(1 for b in bots if b["status"] == "ok"),
			"checks": sum(b["checks"] for b in bots),
			"failures": sum(len(b["failures"]) for b in bots),
			"errors": sum(len(b["errors"]) for b in bots),
			"seconds": sum(b["seconds"] for b in bots),
		},
		"mapgen": mapgen_report(maps, whys, faults, stages),
	}
	# No logs at all means something went wrong before the bots ever ran, not that
	# everything is fine.
	report["ok"] = (
		bool(bots)
		and report["totals"]["passed"] == report["totals"]["bots"]
		and not report["totals"]["errors"]
	)
	return report


# --- the markdown -------------------------------------------------------------------------------


def table(header, rows):
	out = ["| " + " | ".join(header) + " |", "|" + "|".join(["---"] * len(header)) + "|"]
	for row in rows:
		out.append("| " + " | ".join(str(c) for c in row) + " |")
	return out


def markdown(report):
	t = report["totals"]
	out = []
	mark = "white_check_mark" if report["ok"] else "x"
	if not report["bots"]:
		return ":x: **No bot logs were found** -- the bots did not get far enough to say anything.\n"
	out.append(
		":%s: **%d of %d bots passed** -- %d checks, %d failed, %d engine errors, %s."
		% (mark, t["passed"], t["bots"], t["checks"], t["failures"], t["errors"], took(t["seconds"]))
	)
	out.append("")
	out.append("## Bots")
	out.append("")
	out += table(
		["bot", "status", "checks", "failed", "errors", "time"],
		[
			[
				b["name"],
				{"ok": ":white_check_mark: ok", "failed": ":x: failed", "timeout": ":hourglass: timeout"}.get(
					b["status"], b["status"]
				),
				b["checks"],
				len(b["failures"]),
				len(b["errors"]),
				took(b["seconds"]),
			]
			for b in report["bots"]
		],
	)

	broken = [b for b in report["bots"] if b["failures"] or b["errors"]]
	if broken:
		out += ["", "## What failed", ""]
	for b in broken:
		out.append("### %s" % b["name"])
		out.append("")
		for f in b["failures"]:
			where = f.get("source", "")
			section = f.get("section", "")
			tail = ""
			if where:
				more = " (or %d other line)" % f["others"] if f.get("others") == 1 else (
					" (or %d other lines)" % f["others"] if f.get("others") else ""
				)
				tail = "  \n  `%s`%s%s" % (where, more, " -- *%s*" % section if section else "")
			out.append("- %s%s" % (f["message"], tail))
		for e in b["errors"]:
			out.append("- **%s** %s" % (e["kind"], e["message"]))
			if e["at"]:
				out.append("  \n  `%s`" % e["at"])
			for frame in e["frames"]:
				out.append("  - `%s`" % frame)
		if b["warnings"]:
			out.append("")
			out.append(
				"<details><summary>%d kind%s of warning</summary>"
				% (len(b["warnings"]), "" if len(b["warnings"]) == 1 else "s")
			)
			out.append("")
			for w in b["warnings"]:
				out.append("- %dx %s" % (w["count"], w["text"]))
			out.append("")
			out.append("</details>")
		out.append("")

	mg = report.get("mapgen")
	if mg:
		out += ["", "## Map generation", ""]
		out.append(
			"%d maps, one attempt each (no MAP_TRIES retries): **%.0f%% met the generator's own checks first time**."
			% (mg["maps"], 100 * mg["first_try"])
		)
		out.append("")
		out += table(
			["map type", "players", "maps", "first try", "soft", "ms p50", "ms p95", "size"],
			[
				[
					c["type"],
					c["players"],
					c["maps"],
					"%.0f%%" % (100 * c["first_try"]),
					c["soft"],
					c["ms_p50"],
					c["ms_p95"],
					"%dx%d" % (c["tiles"], c["tiles"]),
				]
				for c in mg["by_case"]
			],
		)
		if mg["faults"]:
			out += ["", "**Maps that broke what the game relies on:**", ""]
			out += table(["maps", "what"], [[f["count"], f["what"]] for f in mg["faults"]])
		for title, key in (("First attempt failures", "hard"), ("Soft warnings", "soft")):
			if mg[key]:
				out += ["", "**%s**" % title, ""]
				out += table(
					["times", "what", "e.g."],
					[[w["count"], w["why"], w["example"]] for w in mg[key][:15]],
				)
		if mg["stages"]:
			out += ["", "**Where the time goes** (GEN_PROFILE, %d attempts)" % mg["stages"][0]["runs"], ""]
			out += table(
				["stage", "mean ms", "p95 ms", "share"],
				[[s["stage"], s["mean_ms"], s["p95_ms"], "%.0f%%" % (100 * s["share"])] for s in mg["stages"]],
			)
		if mg["makeup"]:
			out += ["", "<details><summary>What the maps are made of</summary>", ""]
			names = sorted({k for d in mg["makeup"].values() for k in d})
			out += table(
				["map type"] + [n.replace("terrain.", "").replace("zones.", "zone ").replace("objects.", "n ") for n in names],
				[[t] + [d.get(n, "") for n in names] for t, d in sorted(mg["makeup"].items())],
			)
			out += ["", "</details>"]
	out.append("")
	return "\n".join(out)


def took(seconds):
	if not seconds:
		return "-"
	if seconds < 90:
		return "%ds" % seconds
	return "%dm %02ds" % (seconds // 60, seconds % 60)


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("log_dir", help="the directory with the bots' *.log files")
	ap.add_argument("--markdown", help="write the summary here instead of stdout")
	ap.add_argument("--json", help="also write the whole thing as JSON here")
	ap.add_argument(
		"--source-dir",
		default=os.path.dirname(os.path.abspath(__file__)),
		help="where the *_bot.gd sources are, to trace failures back to them",
	)
	ap.add_argument("--fail-on-failures", action="store_true", help="exit 1 when a bot failed")
	args = ap.parse_args()

	report = build(args.log_dir, args.source_dir)
	text = markdown(report)
	if args.markdown:
		with open(args.markdown, "w", encoding="utf-8") as f:
			f.write(text)
	else:
		sys.stdout.write(text)
	if args.json:
		with open(args.json, "w", encoding="utf-8") as f:
			json.dump(report, f, indent=1, sort_keys=True)
	return 1 if args.fail_on_failures and not report["ok"] else 0


if __name__ == "__main__":
	sys.exit(main())
