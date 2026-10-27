#!/usr/bin/env python3
"""Turns the balancing bot's results (JSON lines, docs/balance-bot-design.md §4)
into answers: tables for reading (report.md), charts for looking (report.html,
SVG, no dependencies) and CSV files for any plotting tool of your own.

    report.py balance_runs/base.jsonl [more.jsonl ...] --out balance_runs/report
    report.py runs.jsonl --label base            # only the records of one variant
    report.py runs.jsonl --policy balanced --map temperate --difficulty normal

What it answers
  1. survival         how many waves, per policy / map / difficulty / variant
                      (and what a variant changed against `base`, with a 95 % interval)
  2. enemies          per kind: how many came, how many got killed, how many got
                      through the gate, how far along their road they got before they
                      died (0 = at the spawn, 1 = at the gate)
  3. scaling          enemy HP per wave against what the army and the economy do:
                      growth per wave of each, and the seconds of full fire the army
                      needs for a wave's HP
  4. breaking point   what the last waves before a defeat looked like
  5. spending         where the gold, food and material went
  5c. food           what the village made and ate: villagers' and army's upkeep, time out of food
"""
import argparse
import csv
import html
import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path

SERIES_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
SERIES_DARK = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300", "#9085e9", "#e66767"]


# --- loading ---------------------------------------------------------------------------------

def load(paths, flt):
    runs = []
    for p in paths:
        for line in Path(p).read_text().splitlines():
            if not line.strip():
                continue
            r = json.loads(line)
            c = r["case"]
            if flt["label"] and r["label"] != flt["label"]:
                continue
            if flt["policy"] and c["policy"] != flt["policy"]:
                continue
            if flt["map"] and c["map_type"] != flt["map"]:
                continue
            if flt["difficulty"] and c["difficulty"] != flt["difficulty"]:
                continue
            runs.append(r)
    # A game played twice (the same run_id under the same numbers): the last one counts.
    last = {}
    for r in runs:
        last[(r["run_id"], r["config_hash"])] = r
    bad = [r for r in last.values() if r["case"].get("map_requested") not in (None, r["case"]["map_type"], "random")]
    if bad:
        print("note: %d record(s) dropped, their map type was not the one asked for" % len(bad), file=sys.stderr)
    return [r for r in last.values() if r not in bad]


def gkey(r):
    c = r["case"]
    return (r["label"], c["policy"], c["map_type"], c["difficulty"])


# --- statistics ---------------------------------------------------------------------------------

def mean(xs):
    return sum(xs) / len(xs) if xs else float("nan")


def sd(xs):
    return statistics.stdev(xs) if len(xs) > 1 else 0.0


def quantile(xs, q):
    s = sorted(xs)
    if not s:
        return float("nan")
    i = (len(s) - 1) * q
    lo, hi = math.floor(i), math.ceil(i)
    return s[lo] + (s[hi] - s[lo]) * (i - lo)


def ci95(xs):
    """Half width of the 95 % interval of the mean (t-ish for small samples)."""
    n = len(xs)
    if n < 2:
        return float("nan")
    return (1.96 + 2.5 / (n - 1)) * sd(xs) / math.sqrt(n)


def diff_ci(a, b):
    """Mean of a minus mean of b and the half width of its 95 % interval (Welch)."""
    if len(a) < 2 or len(b) < 2:
        return mean(a) - mean(b), float("nan")
    se = math.sqrt(sd(a) ** 2 / len(a) + sd(b) ** 2 / len(b))
    return mean(a) - mean(b), (1.96 + 2.5 / (min(len(a), len(b)) - 1)) * se


def slope_pct(points):
    """Growth per step (%) of y(x) by a log-linear fit; points = [(x, y)], y > 0."""
    pts = [(x, math.log(y)) for x, y in points if y > 0]
    if len(pts) < 3:
        return float("nan")
    mx, my = mean([p[0] for p in pts]), mean([p[1] for p in pts])
    den = sum((x - mx) ** 2 for x, _ in pts)
    if den == 0:
        return float("nan")
    b = sum((x - mx) * (y - my) for x, y in pts) / den
    return (math.exp(b) - 1) * 100


def f(x, d=1):
    return "-" if x is None or (isinstance(x, float) and math.isnan(x)) else f"{x:.{d}f}"


# --- analyses ---------------------------------------------------------------------------------------

def survival(runs):
    groups = defaultdict(list)
    for r in runs:
        groups[gkey(r)].append(r)
    rows = []
    for k, rs in sorted(groups.items()):
        w = [r["result"]["waves_survived"] for r in rs]
        rows.append({"label": k[0], "policy": k[1], "map": k[2], "difficulty": k[3], "n": len(rs), "mean": mean(w), "sd": sd(w),
                     "ci": ci95(w), "median": quantile(w, 0.5), "min": min(w), "max": max(w),
                     "censored": sum(1 for r in rs if r["result"]["censored"]), "waves": w,
                     "game_s": mean([r["result"]["game_seconds"] for r in rs])})
    return rows


def variant_deltas(rows):
    out = []
    base = {(r["policy"], r["map"], r["difficulty"]): r for r in rows if r["label"] == "base"}
    for r in rows:
        b = base.get((r["policy"], r["map"], r["difficulty"]))
        if r["label"] != "base" and b:
            d, ci = diff_ci(r["waves"], b["waves"])
            out.append({"label": r["label"], "policy": r["policy"], "map": r["map"], "difficulty": r["difficulty"], "delta": d, "ci": ci,
                        "clear": not math.isnan(ci) and abs(d) > ci})
    return out


def enemy_table(runs, bands):
    """Per kind and wave band: spawned, killed, reached, progress and life sums."""
    tab = defaultdict(lambda: defaultdict(float))
    for r in runs:
        for w in r.get("waves", []):
            band = next((b for b in bands if b[0] <= w["wave"] <= b[1]), None)
            for kind, e in w.get("by_kind", {}).items():
                for bk in (("all",), (band,) if band else ()):
                    t = tab[(kind, bk[0])]
                    for k in ("spawned", "killed", "reached", "gone", "progress", "life", "hp"):
                        t[k] += e.get(k, 0)
                    t["waves"] += 1
    return tab


def scaling(runs):
    """Per wave number, the mean over the runs that reached it."""
    by = defaultdict(lambda: defaultdict(list))
    for r in runs:
        total_gold = 0.0
        for w in r.get("waves", []):
            d = w.get("d", {})
            s = w["start"]
            a = s["army"]
            total_gold += d.get("earn.gold", 0)
            n = w["wave"]
            row = by[n]
            row["enemies"].append(w["enemies"])
            row["hp_total"].append(w["hp_total"])
            row["dps"].append(a["dps"])
            row["army_hp"].append(a["hp"])
            row["units"].append(a["units"])
            row["unit_levels"].append(a["level_sum"])
            row["gold_earned"].append(d.get("earn.gold", 0))
            row["gold_total"].append(total_gold)
            row["gold_spent_units"].append(d.get("spend.gold.units", 0) + d.get("spend.gold.upgrades", 0))
            row["duration"].append(w.get("duration", 0))
            row["hero_level"].append(s["hero"]["level"])
            row["leaks"].append(d.get("huts_burned", 0))
            row["lost_units"].append(d.get("units_downed", 0))
            if a["dps"] > 0:
                row["fire_s"].append(w["hp_total"] / a["dps"])
            if w["hp_total"] > 0:
                row["hp_per_gold"].append(w["hp_total"] / max(total_gold, 1))
            row["n"].append(1)
    return {n: {k: mean(v) for k, v in row.items() if k != "n"} | {"runs": len(row["n"])} for n, row in sorted(by.items())}


def breaking_point(runs):
    out = []
    for r in runs:
        if r["result"]["ended_by"] != "defeat" or not r.get("waves"):
            continue
        last = r["waves"][-1]
        prev = r["waves"][-2] if len(r["waves"]) > 1 else None
        reached = {k: e.get("reached", 0) for k, e in last["by_kind"].items() if e.get("reached", 0)}
        out.append({"run": r["run_id"], "wave": last["wave"], "defeat": r["result"]["defeat"], "reached": reached,
                    "hp_total": last["hp_total"], "dps": last["start"]["army"]["dps"],
                    "prev_leaks": (prev or {}).get("d", {}).get("huts_burned", 0), "leaks": last.get("d", {}).get("huts_burned", 0)})
    return out


def spending(runs):
    keys = defaultdict(list)
    for r in runs:
        for k, v in r["counters"].items():
            if k.startswith(("earn.", "spend.")) and k.count(".") == 2:
                keys[k].append(v)
    return {k: mean(v) for k, v in sorted(keys.items())}


def food(runs):
    """Rows of what fed and what ate the village, per run: food made, eaten by
    the villagers and by the army (upkeep), spent on recruits, the seconds out
    of food (the army hungry) and the villagers who starved."""
    def m(key):
        return mean([float(r["counters"].get(key, 0)) for r in runs]) if runs else 0.0
    return [
        ["food earned", f(m("earn.food"), 0)],
        ["eaten by the villagers", f(m("spend.food.upkeep_villagers"), 0)],
        ["eaten by the army", f(m("spend.food.upkeep_army"), 0)],
        ["spent on villagers", f(m("spend.food.villagers"), 0)],
        ["seconds out of food (army hungry)", f(m("hungry_time"), 0)],
        ["villagers starved", f(m("lost.starved"), 2)],
    ]


def army_gold(runs):
    """(what, mean times, mean gold) per run, most gold first: recruits, levels
    and specialisations by unit kind (records with `army_gold` only)."""
    with_ag = [r for r in runs if "army_gold" in r]
    if not with_ag:
        return []
    tot = defaultdict(lambda: [0, 0])
    for r in with_ag:
        for k, v in r["army_gold"].items():
            tot[k][0] += v["n"]
            tot[k][1] += v["gold"]
    n = len(with_ag)
    return sorted(((k, (v[0] / n, v[1] / n)) for k, v in tot.items()), key=lambda kv: -kv[1][1])


# --- charts (SVG, written with CSS variables for light and dark) ----------------------------------------

def esc(s):
    return html.escape(str(s))


def nice_ticks(lo, hi, n=5):
    if hi <= lo:
        hi = lo + 1
    step = 10 ** math.floor(math.log10((hi - lo) / n))
    for m in (1, 2, 5, 10):
        if (hi - lo) / (step * m) <= n:
            step *= m
            break
    t = math.floor(lo / step) * step
    out = []
    while t <= hi + step * 0.5:
        out.append(t)
        t += step
    return out


def line_chart(title, series, xs, ylabel, logy=False, ymin=None, w=620, h=300):
    """series: [(name, [y or None per x])]; one axis; a legend; hover titles."""
    ml, mr, mt, mb = 52, 14, 16, 34
    vals = [y for _, ys in series for y in ys if y is not None and (y > 0 or not logy)]
    if not vals or not xs:
        return ""
    lo = ymin if ymin is not None else (min(vals) if logy else 0)
    hi = max(vals) * 1.05
    if logy:
        lo = 10 ** math.floor(math.log10(lo))
        hi = 10 ** math.ceil(math.log10(hi))
    ty = (lambda v: math.log10(max(v, lo))) if logy else (lambda v: v)
    y0, y1 = ty(lo), ty(hi)
    px = lambda x: ml + (w - ml - mr) * (xs.index(x) / max(len(xs) - 1, 1))
    py = lambda v: mt + (h - mt - mb) * (1 - (ty(v) - y0) / max(y1 - y0, 1e-9))
    o = [f'<svg viewBox="0 0 {w} {h}" role="img" aria-label="{esc(title)}">']
    ticks = [10 ** e for e in range(int(math.log10(lo)), int(math.log10(hi)) + 1)] if logy else nice_ticks(lo, hi)
    for t in ticks:
        if lo <= t <= hi * 1.001:
            o.append(f'<line class="grid" x1="{ml}" x2="{w - mr}" y1="{py(t):.1f}" y2="{py(t):.1f}"/><text class="tick" x="{ml - 6}" y="{py(t) + 4:.1f}" text-anchor="end">{t:g}</text>')
    step = max(1, len(xs) // 10)
    for x in xs[::step]:
        o.append(f'<text class="tick" x="{px(x):.1f}" y="{h - mb + 16}" text-anchor="middle">{x}</text>')
    o.append(f'<text class="tick" x="{ml}" y="{mt - 4}">{esc(ylabel)}{" (log)" if logy else ""}</text><text class="tick" x="{w - mr}" y="{h - 4}" text-anchor="end">wave</text>')
    for i, (name, ys) in enumerate(series):
        pts = [(x, y) for x, y in zip(xs, ys) if y is not None and (y > 0 or not logy)]
        if len(pts) > 1:
            o.append(f'<polyline class="s{i % 8}" fill="none" stroke-width="2" stroke-linejoin="round" points="{" ".join(f"{px(x):.1f},{py(y):.1f}" for x, y in pts)}"/>')
        for x, y in pts:
            o.append(f'<circle class="m{i % 8}" cx="{px(x):.1f}" cy="{py(y):.1f}" r="3"><title>{esc(name)}, wave {x}: {y:.3g}</title></circle>')
    o.append("</svg>")
    return f'<figure><figcaption>{esc(title)}</figcaption>{"".join(o)}{legend([n for n, _ in series])}</figure>'


def legend(names):
    return '<div class="legend">' + "".join(f'<span><i class="k{i % 8}"></i>{esc(n)}</span>' for i, n in enumerate(names)) + "</div>"


def strip_chart(title, rows, w=620):
    """One row per group: every run a dot, the mean a bar; waves survived on x."""
    rh, ml, mr, mt = 26, 190, 20, 14
    h = mt + rh * len(rows) + 30
    hi = max([max(r["waves"]) for r in rows] + [5]) + 1
    px = lambda v: ml + (w - ml - mr) * v / hi
    o = [f'<svg viewBox="0 0 {w} {h}" role="img" aria-label="{esc(title)}">']
    for t in nice_ticks(0, hi):
        o.append(f'<line class="grid" x1="{px(t):.1f}" x2="{px(t):.1f}" y1="{mt}" y2="{h - 26}"/><text class="tick" x="{px(t):.1f}" y="{h - 10}" text-anchor="middle">{t:g}</text>')
    for i, r in enumerate(rows):
        y = mt + rh * i + rh / 2
        name = f'{r["label"]} {r["policy"]} {r["map"]} {r["difficulty"]}'
        o.append(f'<text class="tick" x="{ml - 8}" y="{y + 4:.1f}" text-anchor="end">{esc(name[:30])}</text>')
        o.append(f'<rect class="s{i % 8}" x="{ml}" y="{y - 2:.1f}" width="{max(px(r["mean"]) - ml, 1):.1f}" height="4" rx="2"/>')
        for v in r["waves"]:
            o.append(f'<circle class="m{i % 8}" cx="{px(v):.1f}" cy="{y:.1f}" r="4" fill-opacity="0.75"><title>{esc(name)}: {v} waves</title></circle>')
    o.append("</svg>")
    return f'<figure><figcaption>{esc(title)}</figcaption>{"".join(o)}</figure>'


CSS = """
:root{color-scheme:light;--bg:#fcfcfb;--ink:#0b0b0b;--ink2:#52514e;--grid:#e3e2de;%s}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){color-scheme:dark;--bg:#1a1a19;--ink:#f0efec;--ink2:#c3c2b7;--grid:#34332f;%s}}
body{background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,sans-serif;max-width:900px;margin:0 auto;padding:16px}
h1,h2{font-weight:600}h2{margin-top:2em;border-bottom:1px solid var(--grid)}
table{border-collapse:collapse;margin:8px 0;font-size:13px;display:block;overflow-x:auto}td,th{padding:3px 10px;text-align:right;border-bottom:1px solid var(--grid)}th:first-child,td:first-child{text-align:left}
figure{margin:16px 0}figcaption{font-weight:600;color:var(--ink2)}svg{width:100%%;height:auto}
.grid{stroke:var(--grid);stroke-width:1}.tick{fill:var(--ink2);font-size:11px}
.legend{display:flex;flex-wrap:wrap;gap:4px 14px;font-size:12px;color:var(--ink2)}.legend i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:5px}
pre{background:color-mix(in srgb,var(--ink) 6%%,transparent);padding:8px;overflow-x:auto;font-size:12px}
%s"""


def css():
    def vars_(cols):
        return "".join(f"--c{i}:{c};" for i, c in enumerate(cols))
    cls = "".join(f".s{i}{{stroke:var(--c{i});fill:var(--c{i})}}.m{i}{{fill:var(--c{i});stroke:var(--bg);stroke-width:2}}.k{i}{{background:var(--c{i})}}" for i in range(8))
    return CSS % (vars_(SERIES_COLORS), vars_(SERIES_DARK), cls)


def table(headers, rows):
    return "<table><tr>" + "".join(f"<th>{esc(h)}</th>" for h in headers) + "</tr>" + "".join("<tr>" + "".join(f"<td>{esc(c)}</td>" for c in r) + "</tr>" for r in rows) + "</table>"


# --- the report -----------------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--out", default="balance_runs/report")
    ap.add_argument("--label")
    ap.add_argument("--policy")
    ap.add_argument("--map")
    ap.add_argument("--difficulty")
    ap.add_argument("--bands", default="1-5,6-10,11-15,16-99", help="wave bands of the enemy table")
    a = ap.parse_args()
    runs = load(a.files, {"label": a.label, "policy": a.policy, "map": a.map, "difficulty": a.difficulty})
    if not runs:
        sys.exit("no runs match")
    bands = [tuple(int(x) for x in b.split("-")) for b in a.bands.split(",")]
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    md = []
    sections = []  # (title, markdown lines, html)

    # 1 survival
    srows = survival(runs)
    md.append(f"# Balance report: {len(runs)} runs\n")
    hashes = sorted({r["config_hash"] for r in runs})
    md.append(f"Config hashes: {', '.join(hashes)}; revisions: {', '.join(sorted({r.get('rev', '') for r in runs}))}\n")
    over = sorted({(r["label"], r["overrides"]) for r in runs if r["overrides"]})
    for lab, ov in over:
        md.append(f"- variant `{lab}`: {ov}")
    md.append("\n## 1. Survival (waves survived)\n")
    head = ["variant", "policy", "map", "difficulty", "runs", "mean", "±95%", "sd", "median", "min", "max", "capped", "game min"]
    body = [[r["label"], r["policy"], r["map"], r["difficulty"], r["n"], f(r["mean"]), f(r["ci"]), f(r["sd"]), f(r["median"], 0), r["min"], r["max"], r["censored"], f(r["game_s"] / 60)] for r in srows]
    md.append(md_table(head, body))
    deltas = variant_deltas(srows)
    if deltas:
        md.append("\nVariants against `base` (waves survived, difference of the means, 95 % interval):\n")
        md.append(md_table(["variant", "policy", "map", "difficulty", "Δ waves", "±", "verdict"], [[d["label"], d["policy"], d["map"], d["difficulty"], f(d["delta"], 2), f(d["ci"], 2), ("clear" if d["clear"] else "within noise")] for d in deltas]))
    md.append("\nCapped runs reached `--max-waves` alive: their count is a lower bound.\n")
    html_parts = [strip_chart("Waves survived (bar: mean, dots: runs)", srows[:24])]
    hist = defaultdict(lambda: defaultdict(int))
    for r in runs:
        hist[r["label"] + " " + r["case"]["policy"]][r["result"]["waves_survived"]] += 1
    hx = list(range(0, max(r["result"]["waves_survived"] for r in runs) + 1))
    html_parts.append(line_chart("Runs by waves survived", [(k, [v.get(x, 0) or None for x in hx]) for k, v in list(hist.items())[:8]], hx, "runs"))
    sections.append(("1. Survival", html_parts, [table(head, body)] + ([table(["variant", "policy", "map", "difficulty", "Δ waves", "±", "verdict"], [[d["label"], d["policy"], d["map"], d["difficulty"], f(d["delta"], 2), f(d["ci"], 2), "clear" if d["clear"] else "within noise"] for d in deltas])] if deltas else [])))

    # Sections 2-5 describe one variant: `base` if there is one (or --label).
    all_runs = runs
    labels = sorted({r["label"] for r in runs})
    focus = a.label or ("base" if "base" in labels else labels[0])
    runs = [r for r in runs if r["label"] == focus]
    if len(labels) > 1:
        md.append(f"\n*Sections 2-5 are about variant `{focus}` only ({len(runs)} runs); use --label for another.*\n")

    # 2 enemies
    tab = enemy_table(runs, bands)
    kinds = sorted({k for k, _ in tab}, key=lambda k: -tab[(k, "all")]["hp"])
    md.append("\n## 2. Enemies (all runs shown; killed + reached + gone = spawned)\n")
    head2 = ["kind", "spawned", "avg HP", "killed %", "reached gate %", "avg progress at end", "avg life s", "share of all HP %"]
    total_hp = sum(tab[(k, "all")]["hp"] for k in kinds) or 1
    body2 = []
    for k in kinds:
        t = tab[(k, "all")]
        ended = max(t["killed"] + t["reached"] + t["gone"], 1)
        body2.append([k, int(t["spawned"]), f(t["hp"] / max(t["spawned"], 1)), f(100 * t["killed"] / max(t["spawned"], 1)), f(100 * t["reached"] / max(t["spawned"], 1)), f(t["progress"] / ended, 2), f(t["life"] / ended), f(100 * t["hp"] / total_hp)])
    md.append(md_table(head2, body2))
    md.append("\n*progress at end*: how far along its road an enemy got before it died or arrived (0 spawn, 1 gate; only killed enemies pull it below 1). An enemy that is always killed early and never reaches the gate is not a threat at that stage.\n")
    head3 = ["kind"] + [f"{b[0]}-{b[1]}: spawned / reached % / progress" for b in bands]
    body3 = []
    for k in kinds:
        row = [k]
        for b in bands:
            t = tab.get((k, b))
            if not t or not t["spawned"]:
                row.append("-")
                continue
            ended = max(t["killed"] + t["reached"] + t["gone"], 1)
            row.append(f"{int(t['spawned'])} / {f(100 * t['reached'] / t['spawned'], 0)} / {f(t['progress'] / ended, 2)}")
        body3.append(row)
    md.append("By wave band:\n")
    md.append(md_table(head3, body3))
    reach_series, rx = [], list(range(1, max((w["wave"] for r in runs for w in r.get("waves", [])), default=1) + 1))
    for k in kinds[:8]:
        ys = []
        for n in rx:
            sp = rc = 0
            for r in runs:
                for w in r.get("waves", []):
                    if w["wave"] == n and k in w["by_kind"]:
                        sp += w["by_kind"][k].get("spawned", 0)
                        rc += w["by_kind"][k].get("reached", 0)
            ys.append(100 * rc / sp if sp >= 3 else None)
        reach_series.append((k, ys))
    sections.append(("2. Enemies", [line_chart("Share of each kind that reached the gate (kinds by total HP, at least 3 spawned)", reach_series, rx, "% reached")], [table(head2, body2), table(head3, body3)]))

    # 3 scaling
    sc = scaling(runs)
    md.append("\n## 3. Scaling: enemy HP against army and economy (mean over the runs that reached the wave)\n")
    head4 = ["wave", "runs", "enemies", "enemy HP", "army dps", "army HP", "units", "unit lvls", "hero lvl", "gold earned", "gold total", "fire-seconds", "wave s", "huts burned"]
    body4 = [[n, s["runs"], f(s["enemies"], 0), f(s["hp_total"], 0), f(s["dps"], 0), f(s["army_hp"], 0), f(s["units"]), f(s["unit_levels"], 0), f(s["hero_level"]), f(s["gold_earned"], 0), f(s["gold_total"], 0), f(s.get("fire_s", float("nan"))), f(s["duration"], 0), f(s["leaks"], 1)] for n, s in sc.items()]
    md.append(md_table(head4, body4))
    md.append("\n*fire-seconds* = the wave's total HP / the army's nominal DPS (units' damage / cooldown, summoners' elementals included, hero not): how long everything would have to fire without a miss. Compare with *wave s*, how long the wave really took.\n")
    waves_n = [n for n in sc if sc[n]["runs"] >= max(2, len(runs) // 3)]
    growth = {}
    for name, key in [("enemy HP per wave", "hp_total"), ("enemy count", "enemies"), ("army dps", "dps"), ("army HP", "army_hp"), ("gold earned per wave", "gold_earned"), ("gold total", "gold_total"), ("unit levels", "unit_levels")]:
        growth[name] = slope_pct([(n, sc[n][key]) for n in waves_n if n >= 3])
    md.append("\nGrowth per wave (log-linear fit over waves 3+ with enough runs):\n")
    md.append(md_table(["what", "% per wave"], [[k, f(v, 1)] for k, v in growth.items()]))
    eh, gd, dp = growth["enemy HP per wave"], growth["gold earned per wave"], growth["army dps"]
    if not any(math.isnan(x) for x in (eh, gd, dp)):
        md.append(f"\nEnemy HP grows {f(eh)} %/wave; the army's damage {f(dp)} %/wave and the gold earned {f(gd)} %/wave. " + ("**Enemy HP outgrows both** the army and the income" if eh > max(dp, gd) + 1 else "Enemy HP does not outgrow army and income") + ".\n")
    base_idx = {k: sc[waves_n[0]][k] for k in ("hp_total", "dps", "army_hp", "gold_earned")} if waves_n else {}
    idx = []
    for name, key in [("enemy HP", "hp_total"), ("army dps", "dps"), ("army HP", "army_hp"), ("gold earned per wave", "gold_earned")]:
        idx.append((name, [sc[n][key] / base_idx[key] if base_idx.get(key) else None for n in waves_n]))
    fire = [("fire-seconds", [sc[n].get("fire_s") for n in waves_n]), ("wave duration s", [sc[n]["duration"] for n in waves_n])]
    sections.append(("3. Scaling", [line_chart(f"Growth, wave {waves_n[0] if waves_n else '?'} = 1", idx, waves_n, "index", logy=True), line_chart("Seconds of full fire the wave's HP needs, and the wave's real length", fire, waves_n, "seconds")] if waves_n else [], [table(head4, body4), table(["what", "% per wave"], [[k, f(v, 1)] for k, v in growth.items()])]))

    # 4 breaking point
    bp = breaking_point(runs)
    md.append("\n## 4. Breaking point (the wave a village fell in)\n")
    if bp:
        waves_fell = defaultdict(int)
        for b in bp:
            waves_fell[b["wave"]] += 1
        md.append("Fatal wave: " + ", ".join(f"{w}: {n}x" for w, n in sorted(waves_fell.items())) + "\n")
        causes = defaultdict(int)
        for b in bp:
            causes[b["defeat"]] += 1
        md.append("Defeat by: " + ", ".join(f"{k} {v}x" for k, v in causes.items()) + "\n")
        who = defaultdict(int)
        for b in bp:
            for k, v in b["reached"].items():
                who[k] += v
        md.append("Enemies that got through in the fatal wave: " + (", ".join(f"{k} {v}" for k, v in sorted(who.items(), key=lambda kv: -kv[1])) or "none") + "\n")
        md.append(f"Mean fatal wave: {f(mean([b['wave'] for b in bp]))}, its HP {f(mean([b['hp_total'] for b in bp]), 0)} against {f(mean([b['dps'] for b in bp]), 0)} army dps.\n")
    else:
        md.append("No defeats in these runs.\n")

    # 5 spending
    sp = spending(runs)
    md.append("\n## 5. Money (mean per run)\n")
    md.append(md_table(["flow", "amount"], [[k, f(v, 0)] for k, v in sp.items()]))
    sections.append(("5. Money", [], [table(["flow", "amount"], [[k, f(v, 0)] for k, v in sp.items()])]))
    ag = army_gold(runs)
    if ag:
        md.append("\n## 5b. Army gold by what it bought (mean per run)\n")
        rows = [[k, f(n, 1), f(g, 0)] for k, (n, g) in ag]
        md.append(md_table(["bought", "times", "gold"], rows))
        sections.append(("5b. Army gold", [], [table(["bought", "times", "gold"], rows)]))
    fd = food(runs)
    md.append("\n## 5c. Food (mean per run)\n")
    md.append(md_table(["what", "amount"], fd))
    sections.append(("5c. Food", [], [table(["what", "amount"], fd)]))
    refused = defaultdict(int)
    for r in runs:
        for k, v in r.get("refusals", {}).items():
            refused[k] += v
    if refused:
        md.append("\n## Commands the game refused (the bot's mistakes)\n")
        md.append(md_table(["command: reason", "times"], [[k, v] for k, v in sorted(refused.items(), key=lambda kv: -kv[1])[:15]]))

    (out / "report.md").write_text("\n".join(md) + "\n")
    page = [f"<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'><title>Balance report</title><style>{css()}</style><h1>Balance report: {len(runs)} runs</h1>"]
    for title, charts, tables in sections:
        page.append(f"<h2>{esc(title)}</h2>" + "".join(charts) + "".join(tables))
    page.append("<h2>Full text</h2><pre>" + esc("\n".join(md)) + "</pre>")
    (out / "report.html").write_text("".join(page))
    write_csvs(out, all_runs, sc)
    print("\n".join(md))
    print(f"\nwritten: {out}/report.md, report.html, runs.csv, waves.csv, kinds.csv, timeline.csv")


def md_table(headers, rows):
    lines = ["| " + " | ".join(str(h) for h in headers) + " |", "|" + "---|" * len(headers)]
    lines += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(lines)


def write_csvs(out, runs, sc):
    counter_keys = sorted({k for r in runs for k in r["counters"]})
    with open(out / "runs.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        head = ["run_id", "label", "overrides", "config_hash", "map_type", "seed", "difficulty", "policy", "waves_survived", "ended_by", "censored", "defeat", "game_seconds", "real_seconds", "final_units", "final_dps", "hero_level"]
        w.writerow(head + ["c." + k for k in counter_keys])
        for r in runs:
            c, res, fin = r["case"], r["result"], r["final"]
            w.writerow([r["run_id"], r["label"], r["overrides"], r["config_hash"], c["map_type"], c["seed"], c["difficulty"], c["policy"], res["waves_survived"], res["ended_by"], res["censored"], res["defeat"], res["game_seconds"], res["real_seconds"], fin["army"]["units"], round(fin["army"]["dps"], 1), fin["hero"]["level"]] + [r["counters"].get(k, 0) for k in counter_keys])
    delta_keys = sorted({k for r in runs for wv in r.get("waves", []) for k in wv.get("d", {})})
    with open(out / "waves.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["run_id", "label", "policy", "map_type", "seed", "difficulty", "wave", "survived", "enemies", "hp_total", "hp_scale", "duration", "gold", "food", "materials", "villagers", "huts", "units", "unit_levels", "army_hp", "army_dps", "towers", "barracks", "free_posts", "hero_level", "explored"] + ["d." + k for k in delta_keys])
        for r in runs:
            c = r["case"]
            for wv in r.get("waves", []):
                s, a = wv["start"], wv["start"]["army"]
                w.writerow([r["run_id"], r["label"], c["policy"], c["map_type"], c["seed"], c["difficulty"], wv["wave"], wv["survived"], wv["enemies"], wv["hp_total"], wv["hp_scale"], wv.get("duration"), round(s["gold"]), round(s["food"]), round(s["materials"]), sum(s["villagers"].values()), s["huts"], a["units"], a["level_sum"], round(a["hp"]), round(a["dps"], 1), a["towers"], a["barracks"], a["free_posts"], s["hero"]["level"], s["explored"]] + [wv.get("d", {}).get(k, 0) for k in delta_keys])
    with open(out / "kinds.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["run_id", "label", "policy", "map_type", "seed", "difficulty", "wave", "kind", "spawned", "killed", "reached", "gone", "hp", "progress_sum", "life_sum"])
        for r in runs:
            c = r["case"]
            for wv in r.get("waves", []):
                for kind, e in wv["by_kind"].items():
                    w.writerow([r["run_id"], r["label"], c["policy"], c["map_type"], c["seed"], c["difficulty"], wv["wave"], kind, e.get("spawned", 0), e.get("killed", 0), e.get("reached", 0), e.get("gone", 0), e.get("hp", 0), e.get("progress", 0), e.get("life", 0)])
    with open(out / "timeline.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        cols = ["t", "wave", "in_wave", "gold", "food", "materials", "villagers", "huts", "explored", "units", "unit_levels", "army_hp", "army_dps", "towers", "barracks", "hero_level", "hero_xp", "enemies"]
        w.writerow(["run_id", "label", "policy", "map_type", "seed", "difficulty"] + cols)
        for r in runs:
            c, tl = r["case"], r.get("timeline")
            if not tl:
                continue
            for i in range(len(tl["t"])):
                w.writerow([r["run_id"], r["label"], c["policy"], c["map_type"], c["seed"], c["difficulty"]] + [tl[k][i] for k in cols])


if __name__ == "__main__":
    main()
