---
paths:
  - "tests/**"
  - "tools/**"
---

# Tests, bots and tools

The procedure for running them is the `run-bots` skill. Rules for writing them:

- **No failing bots.** CI allows none, so a fix that breaks a bot is fixed in the same change. The one local exception is title_bot's frame-time check on this slow sandbox; it passes with `CI` set. Anything else failing is new. Don't record per-bot check counts anywhere: the bots print their own.
- **Run bots one at a time**, never in parallel (the user's rule). `tests/run_all.sh` runs them in sequence.
- **Judge timings relatively.** The sandbox runs GDScript roughly an order of magnitude slower than a normal PC. Machine-dependent timing checks are skipped when `CI` is set; set `CI=true` for local runs.
- **`await` every coroutine helper.** Keep waits shorter than whatever frees the game (the title backdrop swaps games on a timer).
- **Things that may be freed:** wait with `wait_until(when_gone(x, ...))` (bot_base holds a weak reference); compare instance ids.
- **"Real seconds" are frame time** (`get_process_delta_time() / Engine.time_scale`), as the game counts them, never the wall clock: headless frames come much faster than real time.
- **Fixed offsets from the village centre** can land in a clearing the woods close in. A bot that puts someone out there picks a tile the village can walk to (`find_spot`, rat_bot's `reachable_near`). Keep the other villagers home when a test needs one particular target (a raider hunts anyone outside).
- **Scenario tests** (`scenario_bot`) check the hand-edited maps' layout: see the scenarios-and-maps rules before editing a map.
- **Monster-camp guards** are enemies: filter them when counting a wave.
- **Library bot** checks that every kind has a library entry and every damage category has a `DAMAGE_INFO` entry; **military_bot** checks the specialisation rule; **save_bot**'s round trip catches missed save state; **title_bot** fails while the baked title maps are stale.
- **The balancing bot** plays whole games and writes a JSON line each; see the balance-sweep skill and `docs/balance-bot-design.md`. Its tunables are in `Config` (`BALANCE_BOT`, `BALANCE_PROFILES`).
- **Screenshots** of the UI: the ui-screenshots skill.
- Add a new bot to `tests/run_all.sh` and the CI workflow (`.github/workflows/bots.yml`), one job per bot.
