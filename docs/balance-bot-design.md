# Veliron's Outpost: the balancing bot (design)

Status: **built**. Code: `tools/balance_bot.gd` (runner), `tools/balance/balance_player.gd`
(the player), `tools/balance/balance_recorder.gd` (the record), `tools/balance/{sweep,variant,report}.py`.
Tunables: `Config.BALANCE_BOT` and `Config.BALANCE_PROFILES`.

## 1. Purpose

A bot that plays whole single-player games like a player would, and answers:
**for a map type, seed, difficulty (and playing style): how many waves does the
village survive, and why?** Every run leaves a JSON line with the result and
all of the game's statistics, so balance questions become queries:

- "Is the goblin too weak?" -> `report.md` §2: does it ever reach the gate, how far
  along its road does it get, what share of a wave's HP is it?
- "Does enemy HP scale with the economy?" -> §3: growth per wave of enemy HP, army
  damage, army HP and income, and the seconds of full fire a wave needs.
- "Did my change help?" -> run the same cases on a variant of the config and read the
  survival delta with its 95 % interval (§6).

It is a tool, not a test: nothing in it passes or fails. It lives in `tools/`.

## 2. Running it

```
godot --headless --fixed-fps 60 --path . res://tools/balance_bot.tscn -- \
    --map=temperate,coast --seeds=1-5 --difficulty=normal --policy=balanced --out=balance_runs/runs.jsonl
```

One game takes about 1-2 minutes in this sandbox (about 1000 game seconds per
real 30 s at speed 4). Options (`--name=value`, lists with commas, seeds as `1-5`, `all`):
`--map` (`temperate highlands coast desert volcanic random`), `--seeds`, `--difficulty`
(`easy normal hard`), `--policy` (§3), `--max-waves` (default 40), `--max-game-seconds`,
`--max-real-seconds`, `--speed` (default 4 = the game's fastest), `--out`, `--label`,
`--overrides`, `--rev`, `--shard=i/n`, `--no-detail`. Defaults: `Config.BALANCE_BOT`.

`tools/balance/sweep.py` runs a sweep over several processes (`--jobs`, about 300 MB each)
and, with `--report DIR`, writes the report at the end:

```
python3 tools/balance/sweep.py --jobs 3 --map temperate,coast --seeds 1-10 --policy balanced,archers \
    --out balance_runs/base.jsonl --report balance_runs/report
```

A run ends by **defeat** (the result), by `wave_cap` (survived `--max-waves`: *censored*, the
true answer is higher), `game_time_cap`, `real_time_cap`, or `stalled` (a wave that doesn't end,
`max_wave_seconds`). `waves_survived` is the number of finished waves, like the defeat screen's.
Runs are reproducible: the global dice and the waves' dice are seeded from map, seed, difficulty
and policy (the same code and config give the same game, up to floating-point order).

## 3. The player

`BalancePlayer` thinks every `think_interval` (2) game seconds and acts only through
`Game.command` (the commands the UI sends); a refused command is counted in `refusals`.
It is three parts (`tools/balance/`), each its own class, plus a ledger:

| part | class | what it decides | where its numbers are |
|---|---|---|---|
| economy | `BalanceEconomy` | repairs, the farm, villagers, farms and camps, gold into material | `Config.BALANCE_ECONOMY`: the same for every policy |
| hero | `BalanceHero` | her modes, levels, resting, camps | `Config.BALANCE_HERO`: the same for every policy |
| military | `BalanceMilitary` | towers, barracks, training grounds, units, upgrades, calling waves | `Config.BALANCE_PROFILES`: what a policy is |
| ledger | `BalanceLedger` | only looks: what got built and how it did (§4) | |

The parts share `BalancePart` (helpers, sending a command, placing a building where it is worth
most) and talk through the player's fields (`repair_wanted`, `no_farm`, `farm_unmanned`,
`want_materials`, `want_critical`). A round, in order of priority: cheats (debug commands a
profile asks for) -> economy, first part: repairs of gates, walls and wall towers -> **the farm**
-> ruined huts rebuilt -> every other repair, claimed ruins restored, idle villagers sent to
vacant workplaces -> hero -> economy, second part: recruit villagers, farms and camps ->
military: towers, barracks, training grounds -> units onto empty posts -> training grounds' unit
swapped into the field -> tower upgrades -> unit upgrades (lowest level first, the profile's
specialisation as soon as possible) -> economy: gold into material (essentials only) -> call the
wave -> ledger. While a repair waits for material, nothing else spends any (no building, camp,
ruin or upgrade), a farm included when it is a wall that waits. Gold buys material only for these
and for the farm; everything else waits for the foresters, so gold goes to the army. Tower
upgrades also wait while any building waits for material.

The farm: every round first checks whether one stands (or is being built or repaired). A
devastated one is repaired (cheaper than a new one), none at all means a new one at once; it is
looked for every 4 s and given up on only after `farm_patience` (240 s) without a spot. Then it
checks the farm is *worked*: a farm that stands without a farmer (the farmer died, was never
assigned) gets one before any other recruit; a free farmer or forester is sent to a vacant
workplace (`assign_worker`).

Economy (`BALANCE_ECONOMY`, the same for every policy): the village starts with one farm and
one camp, and the schedule adds a second farm and a second camp (and forester) from wave 1, a
third camp from wave 3 and a third farm from wave 6 (`farms`, `camps`); one more camp while the
foresters bring in less than `material_rate` per minute (measured over `material_window`), up to
`max_camps`; more farms while upkeep (at `farm_efficiency`, 75 % of a farm's nominal rate)
outgrows them or the food runs out. A farmer comes as soon as the food pays for one
(`min_food` doesn't hold it back); a full village retires its explorer, else a second
gatherer, to make room. Before wave 1 the camps the schedule wants come before any new post.

Where it builds: towers and barracks where they cover most road within `approach_steps` of
a gate that no post of their own sort covers yet (near the village preferred, `tower_spacing`
apart). With `BALANCE_BOT.barracks_support` (on) the two work together: a barracks goes only
where towers shoot over its fighting ground (scored by the towers' levels; anywhere while there
is no tower), a tower scores extra for road a barracks fights on, and the towers over a
barracks are upgraded first, the barracks only once every tower has its level. Off, each sort
covers the road no post covers yet (towers and barracks apart). Farms
nearest, on meadow and by water, away from roads (rats) where any other spot fits
(`farm_road_penalty`); camps by trees. While no farm stands (a starting farm that found no
room), no defence building is placed and no other villager recruited until one is. The military
never builds a new post while two stand empty.

The hero (`BALANCE_HERO`, the same for every policy): she explores until `explore_waves`
(during a wave only while no enemy is near the walls) and defends during waves. Between waves,
with nothing else to do (nothing to explore, no unit to train), she gathers corpses, and rests
when there is no corpse to gather anywhere (on explored land, safe, nobody's). She spends her
XP on levels at once until `bank_xp_from_level` (6); from then on, with training grounds and a
unit that can still level, she keeps it for training. Below `rest_below` of her HP
(`careful_rest_below` while she holds `careful_xp` or more XP, which a downing would cost her)
she rests in the centre until she has `rest_until` again. Between waves she also explores while
an awake unlock site gives a unit the profile uses.

Training grounds (military and hero together): a unit goes there only when her XP covers
`train_levels` (2) of its levels completely: the weakest unit (the cheapest per level), from the
reserve or from its post, which stays free for that time (nobody else is sent to it). Only once
it stands there, and between waves, she switches to Train; when the unit has gained those levels
(or her XP no longer covers the next one, or a wave starts) she is back to her earlier choice
(explore / defend) and the unit goes back to its post (else a free one, else the place of a weaker
unit, which goes to the reserve). A unit her XP can't take through a whole level is not moved there.

Units: each post class takes the profile's kinds in turn, and the turn moves on only once one
is bought (else the cheaper kind would always win while gold is short); unit upgrades leave the
gold of the unit an empty post waits for.

What it doesn't do: attack camps (unless `attack_camps`), send caravans, use light stones,
tear down, move units between posts beyond the training swap, call waves early (unless
`call_early`), replace units already on their posts by other kinds. It is a decent
average player, not an optimal one: compare runs with each other, not with a human.

**Profiles** (`Config.BALANCE_PROFILES`, `--policy`): `balanced` (archers and apprentices on towers in
turn, barracks with shield bearers and archers, specialising into crossbowmen, fire mages and
warriors), `archers`, `swift`
(swiftbowmen), `melee` (the balanced economy; archers on the towers, barracks with shield
bearers who become warriors: tanks that hold enemies in the towers' ranges, not DPS), `mages` (apprentices and summoners, fire
mage / fire summoner; everything unlocked by cheat), `holy` (acolytes, inquisitors; unlocked
by cheat). A profile lists only the military: building counts by wave, tower levels, the
units for towers / wall towers / benches and the specialisation per unit kind; each key is
documented in config.gd.

## 4. The record (one JSON line per run, `schema` 1)

| key | content |
|---|---|
| `run_id`, `label`, `overrides`, `rev`, `config_hash`, `headline`, `when` | which game and which numbers: `config_hash` fingerprints every balance table, `headline` a few numbers at a glance, `overrides` what a variant changed |
| `case` | `map_type`, `seed`, `difficulty`, `policy`, `speed` |
| `result` | `waves_survived`, `wave_reached`, `ended_by`, `censored`, `defeat` (`no_villagers` / `no_huts`), `game_seconds`, `real_seconds`, `frames` |
| `counters` | every counter of the game's `Stats` (kills by kind and by source, earned / spent by source, villagers lost by cause, huts burned, hero numbers ...) |
| `final` | state at the end: resources, villagers by role, huts, working farms (`farms`), explored tiles, `army` (units, by kind `[count, level sum]`, nominal dps, HP, towers, barracks, free posts) and `hero` |
| `waves[]` | per wave: `enemies`, `hp_total` (the wave's HP after difficulty and growth), `hp_scale`, `comp` (kind -> count), `start` / `end` (a `final`-like snapshot), `duration`, `survived`, `d` (the change of every counter during the wave), `by_kind` (§4.1) |
| `timeline` | columns every `sample_interval` (15 s): `t wave in_wave gold food materials villagers huts explored units unit_levels army_hp army_dps towers barracks hero_level hero_xp enemies` |
| `stats_series` | the game's own Stats samples (`Stats.SERIES`) |
| `actions`, `refusals`, `early_calls` | the bot's commands (`ok` / `fail`) and the game's reasons for refusing, to see where the bot was stuck |
| `army_gold` | the gold that went into the army by what it bought: `recruit <kind>`, `level <kind>`, `branch <kind> -> <branch>`, each `{"n", "gold"}` |
| `important_log` | the last important events (what killed the village) |
| `buildings` | the ledger: a row per farm, camp, tower, wall tower, barracks, training grounds and light stone: `k` kind, `o` origin (`start` / `built`), `w` / `t0` wave and game second first seen (placed), `td` finished, `up` seconds working, `dv` / `dv_s` times devastated and seconds lying devastated, `idle` seconds a workplace stood without its worker, `slot_s` / `empty_s` a post's slot seconds and the empty ones, `out` what a workplace brought home, `kills` a tower's kills, `lv` level, `g` when gone |
| `hero` | `seconds` per mode (and `down`), `xp` by source, `kills`, `kills_by_wave`, `downed`, `level`, `idle_villager_s` (farmers and foresters without a workplace) |

4.1 `by_kind[kind]`: `spawned`, `hp` (their HP together), `killed`, `reached` (got to the gate),
`gone` (vanished: rats leaving, thieves escaping ...), `progress` (sum over the enemies that ended:
the share of their road covered, 1 at the gate), `life` (sum of seconds from spawn to the end).
Raised dead are `raised_<kind>`. Camp guards are not recorded. A wrathwood (never part of a
wave) is tallied in the row of the wave running when it woke (or the last one); the timeline's
enemy count leaves it out, as it does camp guards.

*Nominal DPS* of a unit is damage / cooldown from its curves (a summoner: its cap of elementals x
their damage / the elementals' cooldown). It ignores range, misses, splash and healing.

## 5. The report (`tools/balance/report.py`)

`report.py runs.jsonl [more] --out DIR [--label --policy --map --difficulty --bands]` writes
`report.md` (for reading and for Claude), `report.html` (the same with SVG charts), and CSVs for
any tool: `runs.csv` (a row per run, every counter a column), `waves.csv`, `kinds.csv`
(run x wave x kind), `timeline.csv`.

Reading it:
1. **Survival**: mean, 95 % interval, sd, median, range per variant / policy / map / difficulty,
   the delta of each variant against `base`; "clear" only when the interval excludes 0.
   Use at least 10 seeds: a run's waves vary by about +-2 (the waves' dice).
2. **Enemies**: per kind and wave band, how many came, killed %, reached the gate %, the
   mean progress along the road when they ended, life time, and the kind's share of all HP. A kind
   that never reaches the gate and dies early is not a threat in that band. Rates only mean
   something for kinds with enough samples.
3. **Scaling**: per wave the mean enemy HP, army dps / HP, units, hero level, gold earned, fire-seconds
   and the real wave length; the log-linear growth per wave of each, and a verdict line.
   Later waves are only reached by the stronger runs (survivor bias): the table shows how many
   runs each wave has.
4. **Breaking point**: fatal waves, causes, who got through.
5. **Money**: earned / spent by source; then the army's gold by what it bought (recruits, levels
   and specialisations per unit kind: the record's `army_gold`).
   **5c. Food**: food earned, eaten by the villagers and by the army (upkeep), spent on
   villagers, seconds out of food (the army hungry), villagers starved. Per wave the same
   counters are in waves.csv (`d.spend.food.upkeep_army`, `d.hungry_time`, ...).
   **5e. Buildings** (from the ledger): per kind how many were there at the start and built later,
   the wave they were placed in, the seconds from placing to finished, the share of their working
   time a workplace stood without its worker or a post's slots stood empty, output per working
   minute (food / material), a tower's kills per working minute, devastated and lost.
   **5f. The hero**: her time per mode, XP by source, kills, times downed, idle farmers and foresters.
   **5d. Witches and necromancers**: the witches' bolts on manned towers and the tower-seconds
   a unit was kept from acting (`witch.disabled_s`, by unit kind), their damage elsewhere
   (`witch.damage`); the necromancers' raises (`necro.raises`, by kind, HP raised), time
   channelling and waiting (`necro.channel_s`, `necro.held_s`), lost spells, raised dead that
   reached a gate (`necro.raised_gate`), necromancers and raised dead killed. All are game
   statistics (`Stats` counters), so they are in the record's `counters` and in waves.csv per wave.

## 6. Testing a balance change without touching the config

`variant.py --src . --dst DIR --set PATH=VALUE ...` copies the project and edits
`scripts/core/config.gd` there; `sweep.py --variant NAME --set ... ` does that and runs the
bot on the copy, with the label and the changes in every record:

```
python3 tools/balance/sweep.py --jobs 3 --map temperate --seeds 1-10 --out balance_runs/base.jsonl
python3 tools/balance/sweep.py --jobs 3 --map temperate --seeds 1-10 --out balance_runs/g.jsonl \
    --variant gob30 --set ENEMIES.goblin.hp=30 --set 'WAVE_HP_GROWTH*=0.9'
python3 tools/balance/report.py balance_runs/base.jsonl balance_runs/g.jsonl --out balance_runs/report
```

`PATH` is a constant of config.gd, then dictionary keys / array indexes with dots
(`TOWER_LEVELS.1.cost.materials`, `MILITARY.archer.stats.hp`). `=` puts a GDScript literal in as
written, `*=` multiplies a number or every number of a flat array. A path that doesn't exist is an
error, never a silent "no change". Once a change is good, make it in config.gd for real.

## 7. Decisions

- A tool in `tools/`, not a bot in `tests/`: it measures, nothing fails.
- It plays through `Game.command` and reads the game's own `Stats`; the recorder only
  hooks signals (`node_added`, enemies' `killed` / `reached_gate` / `vanished`, the waves'
  signals) and never changes the game. Nothing in `scripts/` knows about it except the config.
- Single player only (co-op balance is another question). No rendering is needed: headless.
- Speed 4 by default so a run's timing is what a player can get; higher speeds make the
  frames coarse (`--speed` allows them).
- The bot does not use the debug commands unless a profile says so (`cheats`), so the baseline
  finds unlock sites like a player does.

## 8. In GitHub CI

- **Smoke test** (`bots.yml`, job `balance-smoke`, so it runs on every push and pull request, and
  before the Pages deploy): five games with `--max-waves=5 --require-waves=5`, one job each: two fixed
  (temperate seed 1 / balanced / normal; coast seed 2 / archers / easy) and three with a random seed
  and map (melee / normal, mages / easy, holy / normal). The seed is printed in the job's summary:
  rerun it with the same `--map=random --seeds=N`. A game that doesn't survive wave 5 fails the job
  (`BALANCE FAIL` in the log), unlike the other bots, whose failures only show up in the summary.
  It catches the bot or a profile breaking against the game's code, and an early game that
  stopped working at all. Hard difficulty is left out: the bot dies before wave 5 in about a
  fifth of hard games, so there it would only test the dice.
- **Balance run** (`balance.yml`, started by hand: Actions > Balance > Run workflow): full games,
  no wave limit (`--max-waves=0`), spread over `machines` jobs (default 12) by `--shard`. Inputs: maps,
  seeds, difficulties, policies, and optionally `overrides` (one `PATH=VALUE` per line, as for
  `variant.py`) with a `label`, to test a config change. The last job merges the results and makes the
  report: artifact `balance-report` (`report.html`, `report.md`, the CSVs and `runs.jsonl`), and
  `report.md` as the run's summary. A full game takes a few minutes; the default (5 maps x 6 seeds on
  12 machines) is 30 games.
