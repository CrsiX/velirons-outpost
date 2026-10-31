---
name: run-bots
description: Run the project's headless test bots, lint, or the net test in this sandbox (Godot wrapper, filters, one at a time). Use when asked to run tests or verify a change.
---

# Run the test bots

1. Create the `gd` wrapper once in the scratchpad (the sandbox can't write `~/.local/share/godot`). `$SCRATCH` is the absolute scratchpad path:
```
#!/bin/bash
export XDG_DATA_HOME=$SCRATCH/xdg/data XDG_CONFIG_HOME=$SCRATCH/xdg/config XDG_CACHE_HOME=$SCRATCH/xdg/cache
mkdir -p $XDG_DATA_HOME $XDG_CONFIG_HOME $XDG_CACHE_HOME
/home/user/velirons-outpost/bin/Godot_v4.7.2-stable_linux.x86_64 "$@" &
pid=$!; trap 'kill -9 $pid 2>/dev/null' TERM INT; wait $pid; rc=$?
rm -rf $XDG_DATA_HOME/velirons_outpost/logs; exit $rc
```
2. After adding a `class_name`: `gd --headless --path . --import` once.
3. One bot, in a background shell, one at a time (never several in parallel):
`export CI=true; timeout 2700 gd --headless --path . --fixed-fps 60 res://tests/<bot>.tscn 2>&1 | grep -E "FAIL|CHECKS|SCRIPT ERROR|Parse Error"`
   A bot that fails to parse hangs until its timeout, so watch for `Parse Error`.
4. Net: `tests/run_net_test.sh <path to gd>`. Everything in sequence: `GODOT=<gd> tests/run_all.sh`.
5. Lint: `HOME=$TMPDIR GDLINT=venv/bin/gdlint tests/lint.sh` (if it can't execute, point `GDLINT` at a script running `venv/bin/python3 -m gdtoolkit.linter "$@"`).
6. Baseline: everything passes; the only local exception is title_bot's frame-time check without `CI`. Game creation takes several seconds headless and the sandbox is slow: judge timings relatively.
