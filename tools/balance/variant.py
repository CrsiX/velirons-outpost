#!/usr/bin/env python3
"""Makes a copy of the project with some numbers of scripts/core/config.gd
changed, so a balance idea can be played by the bot without touching the real
config (docs/balance-bot-design.md §6).

    variant.py --src . --dst /tmp/v1 --set ENEMIES.goblin.hp=30 --set 'WAVE_HP_GROWTH*=0.9'
    variant.py --src . --dry --set MILITARY.archer.stats.hp=[40,120]

A --set is PATH=VALUE (the GDScript literal, put in as written) or PATH*=FACTOR
(multiplies a number, or every number of a flat array). PATH is a constant of
config.gd, then keys of its dictionaries and indexes of its arrays, with dots:
ENEMIES.goblin.hp, TOWER_LEVELS.1.cost.materials, MILITARY.archer.stats.hp.
Exits 1 and says why when a path isn't found, so a typo never plays as
"no change".
"""
import argparse
import re
import shutil
import sys
from pathlib import Path

CONFIG = "scripts/core/config.gd"
SKIP = {".git", "balance_runs", "exports", "maps", "venv", "bin"}


def skip_string(t, i):
    """Index after the string literal starting at t[i] (a quote)."""
    q = t[i]
    i += 1
    while i < len(t) and t[i] != q:
        i += 2 if t[i] == "\\" else 1
    return i + 1


def value_end(t, i, stop_at_newline):
    """End of the expression starting at t[i]: up to a comma / closing bracket
    at depth 0 (or the end of the line for a constant's value)."""
    depth = 0
    while i < len(t):
        c = t[i]
        if c in "\"'":
            i = skip_string(t, i)
            continue
        if c == "#" and depth == 0:
            break
        if c in "{[(":
            depth += 1
        elif c in "}])":
            if depth == 0:
                break
            depth -= 1
        elif c == "," and depth == 0:
            break
        elif c == "\n" and depth == 0 and stop_at_newline:
            break
        i += 1
    while i > 0 and t[i - 1] in " \t":
        i -= 1
    return i


def children(t, start, end):
    """The direct children of the container t[start:end] (starting at its
    bracket): [(key or index, value_start, value_end)]."""
    out = []
    i = start + 1
    is_dict = t[start] == "{"
    idx = 0
    while i < end - 1:
        while i < end and t[i] in " \t\r\n,":
            i += 1
        if i >= end - 1:
            break
        if t[i] == "#":
            while i < end and t[i] != "\n":
                i += 1
            continue
        key = idx
        if is_dict:
            ks = i
            if t[i] in "\"'":
                i = skip_string(t, i)
                key = t[ks + 1:i - 1]
            else:
                while i < end and t[i] not in ":":
                    i += 1
                key = t[ks:i].strip()
            while t[i] != ":":
                i += 1
            i += 1
            while t[i] in " \t\r\n":
                i += 1
        vs = i
        ve = value_end(t, vs, False)
        out.append((key, vs, ve))
        idx += 1
        i = ve
    return out


def find(text, path):
    """(start, end) of the value at `path` in config text."""
    name, *keys = path.split(".")
    m = re.search(r"^const %s\b[^=\n]*=[ \t]*" % re.escape(name), text, re.M)
    if not m:
        raise KeyError("no constant %s" % name)
    s = m.end()
    e = value_end(text, s, True)
    for k in keys:
        if text[s] not in "{[":
            raise KeyError("%s: %r is not a dictionary or array" % (path, text[s:e][:30]))
        found = None
        for key, vs, ve in children(text, s, e):
            if str(key) == k:
                found = (vs, ve)
                break
        if found is None:
            raise KeyError("%s: no key %s" % (path, k))
        s, e = found
    return s, e


def scale(literal, factor):
    def mul(m):
        v = float(m.group(0)) * factor
        return repr(round(v, 6)) if "." in m.group(0) or v != int(v) else str(int(v))
    if re.search(r"[A-Za-z_\"]", literal):
        raise ValueError("can't scale %r (not just numbers)" % literal)
    return re.sub(r"-?\d+\.?\d*", mul, literal)


def patch(text, spec):
    m = re.match(r"^([\w.]+?)(\*?)=(.*)$", spec)
    if not m:
        raise ValueError("bad --set %r (PATH=VALUE or PATH*=FACTOR)" % spec)
    path, mult, val = m.groups()
    s, e = find(text, path)
    old = text[s:e]
    new = scale(old, float(val)) if mult else val
    return text[:s] + new + text[e:], "%s: %s -> %s" % (path, old, new)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default=".")
    ap.add_argument("--dst")
    ap.add_argument("--set", action="append", default=[], dest="sets")
    ap.add_argument("--dry", action="store_true", help="only show what would change")
    a = ap.parse_args()
    src = Path(a.src).resolve()
    text = (src / CONFIG).read_text()
    for spec in a.sets:
        try:
            text, line = patch(text, spec)
        except (KeyError, ValueError) as ex:
            sys.exit("error: %s" % ex)
        print(line)
    if a.dry or not a.dst:
        return
    dst = Path(a.dst).resolve()
    if dst.exists():
        shutil.rmtree(dst)
    # (no dot-files but the import cache .godot: editor and tool settings aren't the game's)
    def ignore(d, names):
        top = Path(d) == src
        return [n for n in names if (n.startswith(".") and n != ".godot") or (top and n in SKIP)]
    shutil.copytree(src, dst, ignore=ignore)
    (dst / CONFIG).write_text(text)


if __name__ == "__main__":
    main()
