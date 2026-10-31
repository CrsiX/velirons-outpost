---
name: balance-sweep
description: Run the balancing bot (whole single-player games) over many seeds or config variants and make a report. Use for balance questions.
---

# Balancing bot sweep

Reasoning, the record's schema and the player policy: `docs/balance-bot-design.md`. Tunables: `Config.BALANCE_BOT` and `BALANCE_PROFILES`.

- Sweep: `python3 tools/balance/sweep.py --godot <gd> --jobs 3 --map temperate --seeds 1-10 --out balance_runs/base.jsonl --report balance_runs/report`
- Config variants (a project copy with numbers changed): `tools/balance/variant.py`, e.g. `--set ENEMIES.goblin.hp=30`; `sweep.py` takes the variants.
- Report only: `tools/balance/report.py` (tables, charts, CSVs; stdlib only).
- Run one process set at a time (the user's no-parallel rule applies to bots; the sweep's own `--jobs` is the sanctioned concurrency). CI's manual `balance.yml` runs full games on many machines.
