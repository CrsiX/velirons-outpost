# Veliron's Outpost: tutorial and library (design)

Status: **built**. Part A: `scripts/tutorial/`, `tests/tutorial_bot.gd`;
part B: `scripts/ui/library.gd`, `tests/library_bot.gd`. Every question is answered (§7 keeps the
decisions).
Scope: teaching a new player the game: a guided first game (single player)
and an in-game library. Every number lives in `scripts/core/config.gd`
(`TUTORIAL`); the step texts and their goals are in `scripts/tutorial/tutorial.gd`
(`_build_steps`), not here.

## 1. Summary

Two parts. They don't depend on each other and can ship one at a time:

| Part | What | Where the player finds it |
|---|---|---|
| A. Guided tutorial | A short scripted first game, one instruction at a time; then it goes on as a normal endless game on the same map | **Tutorial** on the title screen's main page |
| B. Library | Reference pages with tabs | Open-book icon in the game's top bar; a *Library* button on the title screen |

Order: A first, then B.

Dropped for now: one-time tips during normal games (rats, thieves, ...).
They might come back later; nothing in A or B depends on them.

## 2. Goals and non-goals

Goals:
- A new player understands the core loop in about 10 minutes: villagers work
  on their own, the player decides **where** things are built and **who**
  mans the towers, enemies come in waves along the roads.
- Works the same with mouse and touch, in landscape and portrait.
- Each step is learnt by **doing** it, not by reading: a step ends when the
  player has done the thing, never with a "Next" button. The only button
  step is the welcome's.
- Can be skipped at any moment, and played on as a normal game.
- Testable headless like the rest (`tests/tutorial_bot.gd` drives it).

Non-goals:
- No voice-over, no cutscenes (the campaign's scenarios have them, see
  scenarios-design.md §7; this tutorial stays without). New art: only the
  highlight (outline and arrow) and the open-book icon.
- No tutorial in co-op. The library works in co-op too.
- No change to the rules of a normal game.
- English only for now, like the rest of the game.

## 3. Part A: the guided tutorial

### 3.1 Setup

- Started from the title screen's main page. The difficulty chosen before is
  put back when the tutorial's game ends.
- **A fixed map** (`Config.TUTORIAL`: type, seed, difficulty): the cards point
  at places on it, and a fixed map means nothing surprising (a river across
  the first tower spot) happens in a first game. Easy, because the player is
  learning. Fog stays on so the player sees exploring work.
- **The village starts small:** a builder, a forester and their camp. Every
  other role is recruited during the steps, so each recruit is a lesson. No
  explorer at the start fits the hero step: the hero is the one who uncovers
  the fog, so the player sees it happen.
- **The hero starts in Rest mode**, not Defend, so the tower, not she, does
  the fighting in wave 1 and the player sees what a tower does.
- **Waves wait** (no countdown; the wave text says so): the player sets the
  pace, and a step is never interrupted by an enemy it didn't prepare for.
  After the tutorial, the normal countdown runs.
- **Corpses don't rot** during the tutorial, so the gatherer step always
  finds the first wave's corpses however long the player took.
- Starting resources cover every step without trading: nothing in the
  tutorial should be blocked by money.

### 3.2 How a step looks

- A **card** in the top-left corner below the top bar: title, one or two
  short sentences, a progress line, a small *Skip tutorial* link. It moves
  aside (portrait: below) while a top-left panel is open, so it never hides
  what the player is working with.
- A **highlight** on what to use: a pulsing outline around a HUD control or
  stationed units' figures, or a pulsing diamond on a map tile ("build
  here"). An arrow points at it when it can't be seen: off screen, or under
  the top bar or the open sidebar / bottom sheet (those count as solid UI;
  folded, what they'd cover is map again). The diamond is clipped to the map
  area, never drawn over the bars. The dock turns to the tab a step needs;
  folded, the outline is on its open button first, because that is the
  first thing to tap.
- When a step is done: a tick and "Well done!" on the card, a chime, and a
  short pause before the next, so the player registers the success.
- Steps poll the game state rather than hook events, so a goal reached in
  any way counts. No input is blocked: the player may do other things in
  between. A step only waits for its own goal.

### 3.3 The steps

The list (titles, texts, goals) is `Tutorial._build_steps`; it has welcome,
watchtower, builders, archer, farm and farmer, the first wave, gatherer, hero
exploring, hero level, barracks, unit level, tower upgrade, end. Why they come in
this order and are worded as they are:

- **Every step has what it needs from the steps before it:** the tower before
  the archer, the archer before wave 1, wave 1's corpses before the
  gatherer, the hero's XP from exploring before her level-up, the barracks
  before wave 2.
- **The welcome** is the one button step; the dock starts folded so opening it
  is the first tap, teaching where everything lives.
- **Goals are generous** so a player who does it their own way still
  finishes: any unit on any tower (a wall tower too), any unit on a barracks
  bench, any tower upgrade, any level gain of a unit however it came (gold,
  training, specialising). The unit-level step only mentions the training
  grounds, so a player who builds them and trains a unit also finishes it.
- **The farm step** points at a free field; the new farmer goes to the farm on
  their own, so no "assign" step is needed.
- **The gatherer step waits** until wave 1 has left a corpse (the card says
  to watch the archer meanwhile), so the wave is seen before the gatherer is
  introduced. If the goblins got through and left none, two corpses are put
  by the road so the step can't get stuck.
- **The hero level step** tops her XP up to what one level needs, so a player
  who explored little isn't stuck.
- **The end card** offers *Play on* or *Back to title*.

### 3.4 The two tutorial waves

- **Wave 1** (called by the player): a couple of goblins on the road next to
  the tower, so the archer clearly wins.
- **Wave 2** (starts when the barracks step is done): a bigger group with an
  orc on the barracks' road, so the shield bearer has something to do.
- **Once wave 1 has started,** *Call now* is locked until the tutorial is
  over, so a player can't pile waves up before the tools are in place.
- **After the end card** (Play on): the same map goes on as a normal endless
  game with the normal countdown and wave sizes.

### 3.5 Skipping and failing

- **Skip tutorial** asks first, offering *Play on* (like the end card: a
  normal game from the next wave), *Back to title* (red) and *Back to the
  tutorial* (the dialog is one of the HUD's popups, so Esc closes it).
- The player can't really fail in the two tutorial waves: they're tuned to
  lose to one archer. Should the village fall anyway, the defeat screen
  offers *Try the tutorial again*.
- Nothing is remembered about a finished or skipped tutorial: no tick on
  the Tutorial button, and it can be played again any time.

## 4. Part B: the library

- **A sub-menu with tabs** (`Library.TAB_NAMES`: enemies, units, buildings,
  villagers, hero, places, damage). No Basics tab: the tutorial teaches the
  basics, the library is for looking things up.
- **Opened by an open-book icon** (`icon_book`) in the game's top bar and from
  the title screen's main page. It opens on the tab shown last.
- **Pausing:** in single player, opening it pauses the game and greys it out
  behind it (as the settings dialog does), and closing it resumes at the old
  speed. In co-op it doesn't pause anyone, the same as a client's settings
  dialog.
- **Each entry:** the art, a short text, and the real numbers, read from
  `Config`. The pages never go out of date, which is why nothing is copied
  here.
  - Enemy numbers are for the chosen difficulty, in wave 1; unit values go
    from level 1 to the top level.
  - Enemy texts are `Config.ENEMIES` "desc"; the places' texts live in
    `library.gd`.
  - The damage tab is built from the damage data (who deals a category, who
    resists it), so a changed attack, resistance or category shows up by
    itself; see the standing rule in CLAUDE.md.
- It scrolls, and fits portrait and landscape like the other dialogs.
- **Everything is shown, always** (for now): units and villagers that have
  to be found first and every kind of place, whether the player has met it
  or not. Hiding them would need per-player discovery tracking, and a
  reference is more useful complete.

## 5. Code sketch

- `scripts/tutorial/tutorial.gd` (a Node, child of Game while the tutorial
  runs): the steps, the card, the highlight; it holds the waves
  (`Waves.hold`) and stops corpses rotting.
- A step is a Dictionary with a title, text, a polled "done" check and a
  "point" (what to highlight), plus optional hooks for the steps that need
  to wait or react (see `_build_steps` for the keys).
- `scripts/tutorial/highlight.gd`: the pulsing outline over a Control or a
  tile, and the arrow.
- `scripts/ui/library.gd`: the tabbed dialog, built from `Config`, used by the
  HUD and the title screen.
- **Spots are picked on the map** (`RoadSpots`, `scripts/tutorial/road_spots.gd`,
  which the scenarios' cards use too), so a change to the world generator
  can't put them in a river: they are chosen by distance along the road the
  waves come down (tower nearer the gate than the barracks), the farm by the
  village. A tile set in `Config.TUTORIAL` overrides the pick.
  - If something gets built on a spot before its step, the step marks the
    nearest free spot nearby instead, and if there's none, the original
    anyway.
  - The forester's camp has a fixed tile, west of the village in plain view,
    where no wall or tower hides it on screen.
- `tests/tutorial_bot.gd` plays the tutorial by doing each step with commands
  and taps and checks Skip and Play on. `tests/library_bot.gd` checks pausing,
  an entry for every kind, and fitting the screen.

## 6. Effort

| Part | Rough size |
|---|---|
| A. Tutorial (steps, card, highlight, tutorial waves, tests) | the biggest: like the rat feature and the villager list together |
| B. Library (tabs built from config, book icon, tests) | medium |

## 7. Decisions

From two rounds of review:

1. Parts: the tutorial, and a library instead of "How to play". No
   one-time tips for now.
2. After the tutorial, the same map goes on as an endless game.
3. The tutorial is single player only.
4. The upgrade step is split into two, one for units and one for towers.
5. The card goes top-left for now; to be checked in play.
6. No tips.
7. English only.
8. A fixed Highlands map.
9. The unit-level step only mentions the training grounds. It is done when a
   unit goes up a level, by gold or by training.
10. The library has a book icon in game and a *Library* button on the title
    screen's main page. It pauses single player, has no Basics tab, and has
    a Places tab. It shows all units and places, always (for now).
