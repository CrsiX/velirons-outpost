# Veliron's Outpost: in-game statistics (design)

Status: **built** (decisions in §9). Tested by tests/stats_bot.gd.
Scope: a statistics screen during the game and at game over, like the
end-of-game screen in Age of Empires: totals, graphs over time, and a few
awards. Every number lives in `scripts/core/config.gd`.

## 1. Summary

- **What:** a "Statistics" screen with three tabs:
  - **Summary:** a table of totals.
  - **Timeline:** line graphs over time.
  - **Awards:** fun highlights, mainly for the game-over screen.
- **When:** the screen can be opened from **wave 2** on (`STATS.from_wave`)
  with a button right of the library button and left of the settings gear
  (icon `icon_stats`, four bars of a bar chart) or **T**, and at game over
  with a *Statistics* button on the defeat screen.
- **How the data is gathered:**
  - **samples** of the current state, every **15 s** of game time, for the
    graphs;
  - **counters** that add up events as they happen, for the table.
- **Per village:** in co-op every village has its own numbers, one column or
  one line each.

## 2. Goals and non-goals

Goals:
- After a game, the player can see what went well and what didn't: when the
  food ran out, which wave broke through, what killed the most enemies.
- During a game, a quick look at "how am I doing" compared to earlier, and to
  the other villages in co-op.
- Cheap: no frame drops, little memory, nothing extra in each network
  snapshot.
- Testable headless (`tests/stats_bot.gd`).

Non-goals:
- No saving of statistics across games (no career stats, no high-score
  list) for now. That could come later, see §8.
- No per-enemy damage log or replay.

## 3. Samples (the Timeline)

Every `STATS.sample_interval` (15 s of game time: game speed counts, nothing
is sampled while paused), the host records for each village (`Stats.SERIES`):

| Key | What |
|---|---|
| `gold`, `food`, `materials` | in the bank right now |
| `villagers` | number of villagers (huts in use) |
| `huts` | intact huts |
| `units` | military units (on duty, in the reserve, walking; downed ones too) |
| `units_hp` | their HP together, and `units_max_hp` (to show "how healthy is the army", in %) |
| `buildings` | finished buildings outside the walls |
| `explored` | explored tiles (that village's fog) |
| `hero_xp`, `hero_level`, `hero_hp` | the hero |
| `wave` | the wave number at that moment (for the wave marks on the graphs) |
| `enemies` | enemies alive right now and marching on the village |
| `corpses` | number of corpses lying around that could be gathered |

Plus one sample at game start (time 0) and one at game over.

## 4. Counters (the Summary)

Counters add up from the start of the game. They are grouped as in the table.

**Military**
- Enemies killed, total and by kind (goblin, skeleton, ork, witch, rat,
  thief, gargoyle, necromancer, raised dead and all others), and by whom: towers, barracks
  units, summons, the hero.
- Enemies that got through a gate; huts burned.
- Waves survived; the biggest wave; the fastest wave cleared.
- Units recruited, levels bought, specialised, levels trained at the
  training grounds; times a unit was downed.

**Economy**
- Gold earned, by source: kills, corpses, mines, treasure, wave call bonus,
  caravans received.
- Food earned, by source: farms, corpses, treasure, caravans.
- Material earned, by source: foresters, trade, tear-down refunds,
  treasure, caravans.
- Spent, by what: buildings, units, upgrades, villagers, trade, caravans.
- Only income with a source counts as earned: the starting stock and the
  debug buttons don't.
- Losses: gold stolen by thieves, food eaten by rats at the gates and on
  farms.

**Village**
- Villagers recruited, by role.
- Villagers lost, by cause: killed by enemies, starved, hut burned.
- Buildings built, torn down and lost; huts rebuilt. Only huts can be lost
  (enemies burn nothing else), so "lost" is the huts burned.
- Tiles explored; special objects found (treasures, ruined watchtowers,
  mines, camps, lairs, unlock sites; dropped loot doesn't count).
- What comes with the start (starting villagers, farm, camp) isn't counted.

**Hero**
- Kills, XP earned in total, the highest level, times downed, the longest
  time without being downed.

**Co-op** (shown only with 2+ villages)
- Caravans sent and received: gold, food and material, after tax.
- Units sent and received.
- Time the hero spent in Support mode, and kills he made there.

## 5. Where the numbers come from (hooks)

Everything already goes through a few places, so the counters need small
hooks:

| Counter | Hook |
|---|---|
| Kills, kill gold | `Waves._on_enemy_killed` (the killer is known: `game.village_of(killer)`) |
| Gate breaches, huts burned | `Game.on_enemy_reached_gate`, `Hut.destroy` |
| Thief / rat losses | `Game.thief_steals`, the rat parts of `on_enemy_reached_gate`, `RatBehavior._on_farm` |
| Earned by source | `Economy.add(res, value, source := "")`: an optional `source` argument, passed at the existing call sites (farmer, forester, gatherer, mine, Treasure.pay, caravan, wave call bonus) |
| Spent by what | `Economy.spend(cost, what := "")`, the same way |
| Recruits, losses | `Population.recruit` / `Population.kill(civ, reason)` (the reason is there already) |
| Buildings | `Construction.complete`, `_torn_down`, building destruction |
| Units | `Army.recruit`, `Army.upgrade`, `Army.down` |
| Hero | `Hero.on_action`, `Hero.level_up`, `Hero._downed` |
| Co-op | `Caravan` arrival, `Army.adopt`, the hero's Support time in `Hero._process` |

`scripts/systems/stats.gd` (`class_name Stats`, one per game, `Game.stats`,
under Game/Systems) holds samples and counters per village. It offers
`count(village, key, amount := 1)`, `set_max` / `set_min`, `credit` (the
award tables) and `on_kill` / `on_hut_burned` / `on_village_fell` / `on_hero_down` /
`on_hero_back`; the hooks call those. Earnings and spending come from the
`Economy.earned` / `spent` signals. Counter keys are dotted strings
(`kill.goblin`, `kill_by.tower`, `earn.gold.mines`, `spend.food.villagers`,
`lost.starved`, `found.camp`, `hero.xp` ...). `Population.kill` takes a
`cause` ("enemies", "starved", "hut", "other") besides its log reason.
Kills are credited to the killer's village (a tower, a soldier, a summon,
the hero), else to the village the enemy marched on ("other"); raised dead
that crumbled count for nobody. The title backdrop counts nothing; counting
begins once the villages are set up (`Stats.start`) and stops at game over
(one last sample).

## 6. The screen

- **Opening it:**
  - a **Statistics** button in the top bar between the library and the
    gear, with the bar-chart icon, active from wave 2 (greyed out before,
    with "Available in wave 2" as its tooltip; a tap then only says so in a
    toast); **T** opens and closes it too (T does nothing while the
    settings or the library are open);
  - on the game-over screen, a **Statistics** button with the same icon,
    stacked under *Try again* and *Main menu*.
  - The game pauses while it's open in single player (like the
    library and the settings: back at the earlier speed when it closes,
    still paused if it was paused) and shows in grayscale behind it. In
    networked co-op and after game over nobody pauses and nothing greys.
  - Esc or T closes it. It is modal: other keys (Space, ...) don't reach
    the game, except F11.
- **Summary tab:**
  - The section titles (Military, Economy, Village, Hero, Co-op) can be
    folded.
  - Rows are counters, columns are villages (one column in single player),
    with icons for gold, food, material and HP as elsewhere.
  - In co-op, the best value in a row is marked in gold (the highest, or
    the lowest for losses such as huts burned; nothing on a tie).
  - Sub-rows (by kind, by source, by role ...) show only where some village
    has something.
- **Timeline tab:**
  - A metric picker at the top (Gold, Food, Material, Villagers, Huts, Army,
    Army HP %, Buildings, Explored, Enemies, Corpses, Hero XP, Hero level,
    Hero HP): a small button with only the metric's icon and a chevron, its
    name beside it. A tap opens a grid of icons only (each the same small
    size; the name on hover), in as many columns as fit, placed under the
    button (above it when there's no room) and kept wholly on the screen, so
    it never needs scrolling, also on a phone. A tap on an icon picks it; a
    tap elsewhere or Esc closes it (`StatsScreen.open_picker`).
  - Below it, a line graph: time along the bottom, faint vertical lines at
    each wave start (labelled with the wave number), one line per village
    in its colour.
  - Tapping or hovering shows the exact value at that time.
  - Drawn with a simple custom `Control._draw()` (`scripts/ui/stats_graph.gd`); no chart library.
- **Awards tab:** a few cards with art:
  - "Deadliest tower" (most kills, with its level and unit);
  - "Busiest gatherer";
  - "Best explorer";
  - "Hero's finest wave" (most kills in one wave);
  - "Closest call" (the lowest number of intact huts left after a burn, and
    the wave; `Stats.closest_call` from `hut_waves`). The wave in which a
    village fell doesn't count (`fell_waves`, `Stats.on_village_fell`): it
    always ends at 0 huts or no villagers. A hut is counted as burned before
    its resident dies, so the last one counts although that death ends the game;
  - in co-op, "Best neighbour" (most support sent: resources sent by
    caravan, plus `STATS.unit_sent_value` per unit sent).
  - An award nobody has earned yet isn't shown ("Closest call" without a
    burned hut says "Not a single hut burned"; with huts burned only in the
    wave the village fell in, there is no card).
- Fits portrait and landscape like the other dialogs; scrolls.

## 7. Co-op

- The host keeps all statistics; clients don't count anything.
- A client that opens the screen asks the host for it (one RPC,
  `Net.request_stats`; "Loading…" until the answer). The host sends the
  counters and samples of all villages once (`Stats.to_net`). While the
  screen stays open (the game goes on) it asks again every
  `STATS.client_refresh` (5) real seconds. Nothing is added to the regular
  snapshots.
- Everyone sees every village's numbers.
- At game over the host sends them to everyone with the game-over message.

## 8. Later (not in this design)

- Statistics saved after each game, with a "Best games" list on the title
  screen.
- Exporting a game's statistics (CSV) for players who like spreadsheets.

## 9. Decisions

1. All three tabs.
2. In co-op everyone sees every village's statistics, during the game too.
3. A top-bar button right of the library, and the hotkey **T** (S is taken).
4. Before wave 2 the button is greyed out (not hidden).
5. Samples every 15 s of game time.
6. It pauses in single player; it doesn't pause in networked
   co-op.
