#!/usr/bin/env python3
"""Runs the balancing bot over many cases, several Godot processes at once,
for the project as it is and for variants of its config (docs/balance-bot-design.md §5).

    sweep.py --godot gd --jobs 3 --map temperate,coast --seeds 1-10 --difficulty normal \\
             --policy balanced --out balance_runs/base.jsonl
    sweep.py ... --variant goblin30 --set ENEMIES.goblin.hp=30 --out balance_runs/goblin.jsonl
    sweep.py ... --report balance_runs/report     # and make the report at the end

Everything not named here goes to the bot as it is (--max-waves=20 and so on).
--variant NAME with --set PATH=VALUE (several allowed, see variant.py) plays a
copy of the project with those numbers changed; the label and the changes are
in every record. Without --variant the project is played as it is.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent.parent


def find_godot(given):
    for c in [given, os.environ.get("GODOT"), str(PROJECT / "bin/Godot_v4.7.2-stable_linux.x86_64"),
              "/home/user/velirons-outpost/bin/Godot_v4.7.2-stable_linux.x86_64", shutil.which("godot")]:
        if c and (shutil.which(c) or Path(c).exists()):
            return c
    sys.exit("no Godot found: --godot PATH or the GODOT variable")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot")
    ap.add_argument("--jobs", type=int, default=3, help="Godot processes at once (each takes ~300 MB)")
    ap.add_argument("--out", default="balance_runs/runs.jsonl")
    ap.add_argument("--variant", help="label of the variant (default: base)")
    ap.add_argument("--set", action="append", default=[], dest="sets")
    ap.add_argument("--report", help="make the report in this directory afterwards")
    ap.add_argument("--keep", action="store_true", help="keep the variant's project copy")
    args, bot_args = ap.parse_known_args()

    joined = []  # `--map coast` -> `--map=coast` (the bot only knows the second)
    for tok in bot_args:
        if joined and joined[-1].startswith("--") and "=" not in joined[-1] and not tok.startswith("--"):
            joined[-1] += "=" + tok
        else:
            joined.append(tok)
    bot_args = joined
    godot = find_godot(args.godot)
    project = PROJECT
    label = args.variant or "base"
    tmp = None
    if args.sets:
        if not args.variant:
            sys.exit("--set needs --variant NAME")
        tmp = Path(tempfile.mkdtemp(prefix="balance-variant-"))
        project = tmp / "project"
        cmd = [sys.executable, str(HERE / "variant.py"), "--src", str(PROJECT), "--dst", str(project)]
        for s in args.sets:
            cmd += ["--set", s]
        if subprocess.run(cmd).returncode != 0:
            sys.exit(1)
        # the copy has to import its scripts once
        subprocess.run([godot, "--headless", "--path", str(project), "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    out = Path(args.out)
    if not out.is_absolute():
        out = Path.cwd() / out
    out.parent.mkdir(parents=True, exist_ok=True)

    procs = []
    for i in range(args.jobs):
        cmd = [godot, "--headless", "--fixed-fps", "60", "--path", str(project), "res://tools/balance_bot.tscn", "--",
               "--out=%s" % out, "--label=%s" % label, "--overrides=%s" % ";".join(args.sets),
               "--shard=%d/%d" % (i, args.jobs)] + bot_args
        log = open("%s.job%d.log" % (out, i), "w")
        procs.append((subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT), log, i))
    rc = 0
    for p, log, i in procs:
        rc |= p.wait()
        log.close()
        tail = Path("%s.job%d.log" % (out, i)).read_text().splitlines()
        done = [l for l in tail if l.startswith("BALANCE DONE")]
        print("job %d: %s" % (i, done[-1] if done else "no result (see %s.job%d.log)" % (out, i)))
    if tmp and not args.keep:
        shutil.rmtree(tmp, ignore_errors=True)
    print("results: %s" % out)
    if args.report:
        subprocess.run([sys.executable, str(HERE / "report.py"), str(out), "--out", args.report])
    sys.exit(rc)


if __name__ == "__main__":
    main()
