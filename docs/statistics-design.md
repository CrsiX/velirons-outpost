# Veliron's Outpost: in-game statistics (design)

Status: **built** (decisions in §9). Tested by tests/stats_bot.gd.
Scope: a statistics screen during the game and at game over, like the
end-of-game screen in Age of Empires: totals, graphs over time, and a few
awards. Every number lives in `scripts/core/config.gd` (`STATS`).

## 1. Summary

- **What:** a "Statistics" screen with three tabs: a **Summary** table of
  totals, a **Timeline** of line graphs, and **Awards** (fun highlights,
  mainly for the game-over screen).
- **When:** from an early wave on (`STATS.from_wave`), from a top-bar button
  or a hotkey, and at game over from a button on the defeat screen.
- **How the data is gathered:** *samples* of the current state at a fixed
  game-time interval (for the graphs), and *counters* that add up events as
  they happen (for the table).
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
- Testable headless.

Non-goals:
- No saving of statistics across games (no career stats, no high-score
  list) for now. That could come later, see §8.
- No per-enemy damage log or replay.

## 3. Samples (the Timeline)

The host samples every village at a fixed interval of game time
(`STATS.sample_interval`; game speed counts, nothing is sampled while
paused), plus once at game start and once at game over. The series are
`Stats.SERIES`: the resource stocks, villagers and huts, army size and army
health (HP and max HP, so the graph can show "how healthy is the army" as a
share), buildings, explored tiles, the hero's XP, level and HP, the wave
number (for the wave marks on the graphs), enemies on the march and
gatherable corpses. They are the questions a player asks about the state of
the village over time; add a series only for a question the graphs can't
answer yet.

## 4. Counters (the Summary)

Counters add up from the start of the game, grouped as the screen shows them;
the keys are in `scripts/systems/stats.gd` and its hooks. What is counted and
why:

**Military**
- Kills, by kind and by whom (towers, barracks units, summons, the hero), so
  the player sees what the defence really rests on.
- Enemies that got in, huts burned, waves survived, the biggest and the
  fastest wave: the pressure the village was under.
- Units recruited, levels bought, specialised, trained, times downed: how
  the army was built and what it cost.

**Economy**
- Earned and spent by source and by purpose, so the player sees where
  resources came from and went, including food eaten by villagers and army
  (counted as eaten by `Population`, not through `Economy.spent`).
- Only income with a source counts as earned: the starting stock and the
  debug buttons don't.
- Losses (gold stolen, food eaten by rats) and time out of food
  (docs/village-design.md §2a) show what the raiders cost.

**Village**
- Villagers recruited and lost (by cause), buildings built, torn down and
  lost, damage and repairs (docs/siege-design.md), exploration and special
  objects found (dropped loot doesn't count).
- What comes with the start (starting villagers, farm, camp) isn't counted:
  the numbers show what the player did.

**Hero**
- Kills, XP, level, times downed, longest streak without being downed.

**Co-op** (shown only with 2+ villages)
- Caravans and units sent and received (after tax), and the hero's time and
  kills in Support mode.

## 5. Where the numbers come from (hooks)

The game already routes everything through a few places, so the counters
need only small hooks there (kills in `Waves`, gate breaches in `Game`,
earning and spending in `Economy` through an optional source / purpose
argument, recruits and losses in `Population`, buildings in `Construction`,
units in `Army`, the hero in `Hero`, co-op help in `Caravan` and
`Army.adopt`). Searching for `game.stats` or `Stats` finds every hook.

`scripts/systems/stats.gd` (`class_name Stats`, one per game, `Game.stats`)
holds samples and counters per village. Earnings and spending arrive through
the `Economy.earned` / `spent` signals. Counter keys are dotted strings.
Rules worth knowing:
- Kills are credited to the killer's village (a tower, a soldier, a summon,
  the hero), else to the village the enemy marched on; raised dead that
  crumbled count for nobody.
- The title backdrop counts nothing; counting begins once the villages are
  set up (`Stats.start`, so the start isn't counted) and stops at game over
  (one last sample).

## 6. The screen

- **Opening it:** a top-bar button (greyed out, not hidden, before the first
  wave it is available, so the player learns it exists; a tap then only says
  when it opens) and a hotkey; on the game-over screen a button with the same
  icon. (Hotkeys are listed by `Hud.KEYS_HELP`.)
  - It pauses the game in single player (like the library and the settings:
    back at the earlier speed when it closes, still paused if it was paused)
    and shows the game in grayscale behind it. In networked co-op and after
    game over nobody pauses and nothing greys.
  - It is modal: other keys don't reach the game, except fullscreen.
- **Summary tab:**
  - Sections can be folded, so the long list doesn't drown the interesting
    part.
  - Rows are counters, columns are villages, with icons for gold, food,
    material and HP as elsewhere.
  - In co-op the best value in a row is marked (the highest, or the lowest
    for losses; nothing on a tie).
  - Sub-rows (by kind, by source, by role ...) show only where some village
    has something, to keep the table short.
- **Timeline tab:**
  - A metric picker: a small button with the current metric's icon and its
    name beside it. A tap opens a grid of icons only (name on hover), placed
    so it is kept wholly on the screen and never needs scrolling, also on a
    phone (`StatsScreen.open_picker`). A name list would not fit a phone
    without scrolling.
  - Below it, a line graph: time along the bottom, faint vertical lines at
    each wave start, one line per village in its colour. Tapping or hovering
    shows the exact value.
  - Drawn with a simple custom `Control._draw()` (`scripts/ui/stats_graph.gd`);
    no chart library.
- **Awards tab:** a few cards with art: deadliest tower, busiest gatherer,
  best explorer, the hero's finest wave, closest call and, in co-op, best
  neighbour (support sent, resources plus `STATS.unit_sent_value` per unit).
  - An award nobody has earned yet isn't shown.
  - "Closest call" is the fewest intact huts left after a burn (`Stats.closest_call`
    from `hut_waves`). The wave in which a village fell doesn't count
    (`fell_waves`): it always ends at 0 huts or no villagers and would make
    every lost game's card the same. A hut counts as burned before its
    resident dies, so the last one counts although that death ends the game.
- Fits portrait and landscape like the other dialogs; scrolls.

## 7. Co-op

- The host keeps all statistics; clients don't count anything.
- A client that opens the screen asks the host for it (one RPC,
  `Net.request_stats`); the host sends the counters and samples of all
  villages once (`Stats.to_net`). While the screen stays open it asks again
  every `STATS.client_refresh`. Nothing is added to the regular snapshots:
  that is the point of asking on demand.
- Everyone sees every village's numbers, during the game too.
- At game over the host sends them to everyone with the game-over message.

## 8. Later (not in this design)

- Statistics saved after each game, with a "Best games" list on the title
  screen.
- Exporting a game's statistics (CSV) for players who like spreadsheets.

## 9. Decisions

1. All three tabs.
2. In co-op everyone sees every village's statistics, during the game too.
3. A top-bar button right of the library, and a hotkey (S is taken).
4. Before the first wave it is available, the button is greyed out (not hidden).
5. Samples at a fixed game-time interval.
6. It pauses in single player; it doesn't pause in networked co-op.
