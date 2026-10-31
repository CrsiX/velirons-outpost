# Veliron's Outpost: the balancing bot (design)

Status: **built**. Code: `tools/balance_bot.gd` (runner), `tools/balance/balance_player.gd`
(the player), `tools/balance/balance_recorder.gd` (the record), `tools/balance/{sweep,variant,report}.py`.
Tunables: `Config.BALANCE_BOT` and `Config.BALANCE_PROFILES` (every key documented there).

## 1. Purpose

A bot that plays whole single-player games like a player would, and answers:
**for a map type, seed, difficulty (and playing style): how many waves does the
village survive, and why?** Every run leaves a JSON line with the result and all of the
game's statistics, so balance questions become queries:

- "Is the goblin too weak?" -> the report's enemy section: does it ever reach the gate, how far
  along its road does it get, what share of a wave's HP is it?
- "Does enemy HP scale with the economy?" -> the scaling section: growth per wave of enemy HP, army
  damage, army HP and income, and the seconds of full fire a wave needs.
- "Did my change help?" -> run the same cases on a variant of the config and read the
  survival delta with its 95 % interval (§6).

It is a tool, not a test: nothing in it passes or fails. It lives in `tools/`.

## 2. Running it

The command lines and options (maps, seeds, difficulty, policy, caps, speed, shards, output)
are documented at the top of `tools/balance_bot.gd` and `tools/balance/sweep.py`
(`--help`), with defaults in `Config.BALANCE_BOT`; the procedure belongs in a skill, not here.
What matters for design:

- **Run ends.** By **defeat** (the result), or by a cap: waves, game time, real time, or a
  wave that never ends (`stalled`). A run that hits the wave cap is *censored*: the true
  answer is higher, and reports must not average it as if it were a defeat.
  `waves_survived` is the number of finished waves, like the defeat screen's.
- **Reproducible.** The global dice and the waves' dice are seeded from map, seed, difficulty and
  policy, so the same code and config give the same game (up to floating-point order). A change
  in the numbers is then the only difference between two runs.
- **Speed 4 by default,** so a run's timing is what a player can get; higher speeds make frames
  coarse and change the game.
- **Several processes** (`sweep.py`) because a game is slow and the bot is single-threaded.

## 3. The player

`BalancePlayer` thinks at a fixed interval of game time and acts only through `Game.command`
(the commands the UI sends), so it can't do anything a player can't; a refused command is counted
(`refusals`) to show where the bot got stuck. It is "a decent average player, not an optimal
one": compare runs with each other, not with a human.

**Priorities** (the order of a round, `balance_player.gd`): cheats a profile asks for, hero, repairs
and restoring, recruiting, farms and camps, military buildings, units onto posts, tower upgrades,
unit upgrades, gold into material (essentials only), calling the wave. The reasoning:

- **Repairs come first,** and while something waits for material nothing else spends any:
  a village that builds new things on top of a broken wall isn't playing like a player who wants
  to survive. Gold buys material only for these and for a missing farm (`_want_critical`);
  everything else waits for the foresters, so gold goes to the army, as it does for a player.
- **Economy first.** Before wave 1 the profile's camps (and their foresters) come before any new
  post; later one more camp whenever the foresters bring in less than the profile wants
  (`material_rate`). Food: a farm schedule by wave, more while upkeep outgrows the farms. A farm
  without its farmer gets one before any other recruit; a full village retires its explorer, else
  a second gatherer, to make room.
- **Where it builds.** Towers and barracks go where they cover road near a gate that no post of
  their own sort covers yet. With `barracks_support` the two cooperate (a barracks where towers
  shoot over its fighting ground, towers over a barracks upgraded first), because that is how a
  good player uses them; switched off, each covers the road alone, to measure the difference.
  Farms go on meadow and by water, away from roads (rats), camps by trees. While no farm stands it
  comes before everything. It never builds a new post while two stand empty.
- **The hero** explores for a profile-set number of waves (only while no enemy is near the walls
  during one), then trains the unit at the grounds (which then swaps into the field), and defends
  during waves. Below a share of her HP she rests until she has recovered, because being downed
  loses all her XP.
- **Units:** each post class takes the profile's kinds in turn, and the turn moves on only once one
  is bought (else the cheaper kind would always win while gold is short); unit upgrades leave the
  gold of the unit an empty post waits for.

**What it doesn't do** (unless a profile key switches it on): attack camps, send caravans, use
light stones, tear down, move units between posts beyond the training swap, call waves early,
replace units already on their posts by other kinds. Each omission is a skill a player might use;
the bot's survival numbers are therefore a floor for a good player, comparable across variants.

**Profiles** (`BALANCE_PROFILES`, the `policy` of a case) are playing styles: `balanced` (the
default player), `archers`, `swift`, `melee`, `mages`, `holy`. Some unlock their units by cheat.
A profile lists villager targets, building counts by wave, tower levels, units per post class,
the specialisation per kind and the hero's orders. Several profiles exist because a change that
helps one style can break another; balance is judged across them.

## 4. The record

One JSON line per run. The schema is whatever `balance_recorder.gd` writes (it carries a
`schema` number; read the code, not a copy here). The shape and why:

- **Identification:** a config fingerprint (`config_hash`) and the overrides, so two runs can be
  compared only when they differ in what was meant to differ.
- **The case and the result:** how the run ended, censored or not, the defeat cause.
- **Every counter of the game's own `Stats`** (kills by kind and source, earned and spent by source,
  villagers lost by cause...), because the bot should measure with the same instruments the
  statistics screen gives a player.
- **Per wave:** what came (HP total after difficulty and growth, composition), snapshots at its
  start and end, the change of every counter during it, and per enemy kind how many spawned, were
  killed, reached the gate or vanished, how far along their road they got and how long they
  lived. This is what answers "is this kind a threat in this band".
- **A timeline** sampled at a fixed interval (economy, army, hero), for charts of growth.
- **The bot's own actions and refusals**, the gold that went into the army by what it bought,
  and the last important log events (what killed the village).

Notes on definitions that would otherwise mislead:
- Raised dead are tallied as `raised_<kind>`. Camp guards are not recorded. A wrathwood (never part
  of a wave) is tallied in the row of the wave running when it woke; the timeline's enemy count
  leaves it out, as it does camp guards.
- *Nominal DPS* of a unit is damage / cooldown from its curves (a summoner: its cap of elementals
  x their damage / the elementals' cooldown). It ignores range, misses, splash and healing, so it
  is a growth indicator, not a prediction.

## 5. The report (`tools/balance/report.py`)

Writes a Markdown report (for reading and for Claude), an HTML one with charts, and CSVs for any
tool. What to read, and its traps:

1. **Survival:** mean, 95 % interval, spread and range per variant / policy / map / difficulty, and
   the delta of each variant against `base`; "clear" only when the interval excludes 0. Use enough
   seeds: a run's waves vary by a couple of waves from the waves' dice alone.
2. **Enemies:** per kind and wave band, how many came, killed %, reached the gate %, mean progress
   along the road, life time and the kind's share of all HP. A kind that never reaches the gate
   and dies early is not a threat in that band. Rates only mean something for kinds with enough
   samples.
3. **Scaling:** per wave the growth of enemy HP against army damage and HP, units, hero level,
   income and the real wave length, and a verdict line. Later waves are only reached by the
   stronger runs (survivor bias), so the table shows how many runs each wave has.
4. **Breaking point:** fatal waves, causes, who got through.
5. **Money and food:** earned / spent by source; the army's gold by what it bought; food earned,
   eaten by villagers and army, and the time spent hungry (docs/village-design.md §2a).

## 6. Testing a balance change without touching the config

`variant.py` makes a copy of the project with config numbers changed, and `sweep.py --variant`
runs the bot on that copy, with the label and the changes in every record, so base and variant
share seeds and the report can compare them. Paths address a constant of config.gd then dictionary
keys / array indexes with dots; `=` puts a GDScript literal in, `*=` multiplies. A path that doesn't
exist is an error, never a silent "no change" (a typo must not look like "no effect"). Once a
change is good, make it in config.gd for real. Command examples belong in the balance-sweep skill
and the scripts' `--help`.

## 7. Decisions

- A tool in `tools/`, not a bot in `tests/`: it measures, nothing fails.
- It plays through `Game.command` and reads the game's own `Stats`; the recorder only hooks signals
  and never changes the game. Nothing in `scripts/` knows about it except the config. That keeps
  the measurement honest: the game under test is the game players get.
- Single player only (co-op balance is another question). No rendering is needed: headless.
- The bot does not use the debug commands unless a profile says so (`cheats`), so the baseline
  finds unlock sites like a player does.

## 8. In GitHub CI

- **Smoke test** (`bots.yml`, job `balance-smoke`, on every push and pull request, and before the
  Pages deploy): a handful of short games that must reach a low wave count, some fixed, some on a
  random seed and map (the seed is printed so a failure can be rerun). Unlike the other bots, a
  failed game fails the job. It catches the bot or a profile breaking against the game's code,
  and an early game that stopped working at all. Hard difficulty is left out: the bot often dies
  before the target wave there, so it would only test the dice.
- **Balance run** (`balance.yml`, started by hand): full games without a wave limit, spread over
  several machines by `--shard`, optional `overrides` with a `label` to test a config change.
  The last job merges the results into the report artifact.
