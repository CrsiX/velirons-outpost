# Veliron's Outpost: tutorial and library (design)

Status: **built**. Part A: `scripts/tutorial/`, `tests/tutorial_bot.gd`;
part B: `scripts/ui/library.gd`, `tests/library_bot.gd`. Every question is answered (§7 keeps the
decisions).
Scope: teaching a new player the game: a guided first game (single player)
and an in-game library. Every number lives in `scripts/core/config.gd`.

## 1. Summary

Two parts. They don't depend on each other and can ship one at a time:

| Part | What | Where the player finds it |
|---|---|---|
| A. Guided tutorial | A short scripted first game, one instruction at a time; then it goes on as a normal endless game on the same map | **Tutorial** on the title screen's main page |
| B. Library | Reference pages with tabs: enemies, units, buildings, villagers, hero, places | Open-book icon in the game's top bar (left of the statistics icon, which is left of the gear); a *Library* button on the title screen |

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
  step is the welcome's *Let's go*.
- Can be skipped at any moment, and played on as a normal game.
- Testable headless like the rest (`tests/tutorial_bot.gd` drives it).

Non-goals:
- No voice-over, no cutscenes (the campaign's scenarios have them, see
  scenarios-design.md §7; this tutorial stays without). New art: only the highlight (outline and
  arrow) and the open-book icon.
- No tutorial in co-op. The library works in co-op too.
- No change to the rules of a normal game.
- English only for now, like the rest of the game.

## 3. Part A: the guided tutorial

### 3.1 Setup

- Started from the title screen's main page: **Tutorial** (under Multiplayer).
- The map: **Highlands, seed 1337**. Easy difficulty (the difficulty chosen
  before is put back when the tutorial's game ends). Fog on, so the player
  sees exploring work.
- **The village starts small:** a builder and a forester, the forester's
  camp, and nothing else. No farm, no farmer, no explorer, no gatherer.
  Every other role is recruited during the steps.
- **The hero starts in Rest mode**, not Defend. She stays in the village
  centre, so the tower does the fighting in wave 1.
- **Waves wait:** there's no countdown (the wave text says "Wave N waits").
  Wave 1 starts when the player calls it (step 6), and wave 2 when step 10
  is done. After the tutorial, the normal countdown runs.
- **Corpses don't rot** during the tutorial (normally they do after
  `CORPSE_LIFETIME`, 240 s). Then the gatherer in step 7 always finds the
  goblins from wave 1.
- Starting resources: 200 gold, 150 food, 150 material, enough for every
  step without trading. They're in `Config.TUTORIAL`, along with the seed,
  the map type, the difficulty and the tutorial waves.

### 3.2 How a step looks

- A **card** in the top-left corner, below the top bar (360 px wide in
  landscape; in portrait the screen width less 20 px, at most 520): a
  title, one or two short sentences, a progress line ("Step 4 of 13"), and
  a small **Skip tutorial** link. While a top-left panel is open (hero
  panel, villager list, trade dialog), the card moves beside it (portrait:
  under it), and in portrait it also stays under the placing hint.
- A **highlight** on what to use: a pulsing gold outline around a HUD button
  or list entry, around stationed units' figures (step 11), or a pulsing
  diamond on a map tile ("build here"). An arrow
  points at it if it's off to the side: off screen, or hidden under the top
  bar or the open sidebar / bottom sheet (they count as solid UI; folded,
  the part they'd cover is map again). The diamond is clipped to the map
  area, never drawn over the bars. The open sidebar / bottom sheet
  turns to the right tab when a step needs it; folded, the outline is on
  its open button first.
- When a step is done: a tick and "Well done!" on the card (title turns
  green), a chime, and the next step `step_pause` (1 s) later.
- Steps check the game state every 0.25 s. No input is blocked: the player
  may do other things in between. A step only waits for its own goal.

### 3.3 The steps

| # | Teaches | Card text | Done when |
|---|---|---|---|
| 1 | Welcome | "This is your village. Enemies come in waves: keep them out. A few short steps show you how." (a *Let's go* button; the sidebar / bottom sheet starts folded, so opening it is the first tap) | *Let's go* is pressed |
| 2 | Building | "Enemies come along the roads. Build a watchtower on the marked spot by the road: open the menu, Build tab, Watchtower, then tap the spot." | a watchtower site is placed |
| 3 | Builders | "Your builder walks there and builds it. Villagers do their work on their own." | the watchtower is finished |
| 4 | Units | "Recruit an archer (Army tab) and drag it onto the tower." | any unit is stationed on any tower (wall towers too) |
| 5 | Food | "Villagers need to eat. Place a farm on the marked field, then recruit a farmer to work it. The top bar shows your food and how it changes per minute." | a farm is finished and a farmer works it |
| 6 | Waves | "Ready? Start the first wave now with Call now: calling early pays bonus gold." | wave 1 is called |
| 7 | Gatherer | (starts only once wave 1 has left its first corpse; meanwhile the card says "Here they come! Watch your archer on the tower.") "Enemies leave corpses. A gatherer brings them home for gold and food. Recruit one in the Village tab." | a gatherer is recruited and has brought a corpse home |
| 8 | Hero | "This is your hero. Tap her in the top bar and send her exploring: she uncovers the fog and earns XP." | the hero is in Explore mode and has earned XP (or a level) since the step began |
| 9 | Hero levels | "She has enough XP for a level: more HP and a harder sword. Level her up." (the tutorial tops up her XP to the 50 needed if she has less) | the hero reaches level 2 |
| 10 | Barracks | "Barracks send their units out to fight what comes near. Build one by the road and station a shield bearer." | any unit is stationed on a barracks bench |
| 11 | Unit levels | "Units get better with levels. Tap one and promote it with gold. (Later, training grounds let the hero pass on her XP to a unit instead.)" | any unit goes up a level (by gold or by training) or specialises |
| 12 | Tower upgrades | "Towers can be upgraded too: tap the watchtower and upgrade it. Your builder does the work." | a tower (watchtower or wall tower) reaches level 2 |
| 13 | End ("Well done!") | "That's all you need. Waves get bigger and new enemies show up. Survive as long as you can!" (Play on / Back to title) | a choice is made |

Notes on the list:
- **The order works.** Every step has what it needs from the steps before
  it: the tower before the archer, the archer before wave 1, wave 1's
  corpses before the gatherer, and the hero's XP from exploring before her
  level-up. The barracks come before wave 2.
- **No explorer at the start** fits step 8: the hero is the one who
  uncovers the fog, so the player sees it happen.
- **Step 5** points at a free 3x3 field outside the walls, chosen for
  seed 1337. The new farmer goes to the farm on their own, so the player
  needs no "assign" step.
- **Step 11** only mentions the training grounds: it is done when a unit
  goes up a level, however that happens, so a player who builds training
  grounds and trains a unit finishes it too.

### 3.4 The two tutorial waves

- **Wave 1** (called in step 6): 2 goblins on the road next to the tower, so
  the archer clearly wins. The hero rests in the village, so the tower does
  the work.
- **Wave 2** (starts when step 10 is done): 5 goblins and an orc on the
  barracks' road, so the shield bearer has something to do.
- **After the end card** (Play on): the same map goes on as a normal endless
  game from wave 3, with the normal countdown and wave sizes.

### 3.5 Skipping and failing

- **Skip tutorial:** a confirm dialog ("Skip the tutorial? You can play on in
  this village.") with *Play on*, *Back to title* (red) and *Back to the
  tutorial* (closes the dialog; so does Esc, as one of the HUD's popups).
  *Play on* works like the end card: a
  normal game from the next wave.
- The player can't really fail in the two tutorial waves: they're tuned to
  lose to one archer. Should the village fall anyway, the defeat screen
  offers *Try the tutorial again*.
- Nothing is remembered about a finished or skipped tutorial: no tick on
  the Tutorial button, and it can be played again any time.

## 4. Part B: the library

- **A sub-menu with tabs:** Enemies, Units, Buildings, Villagers, Hero,
  Places, Damage. No Basics tab.
- **Opened by an open-book icon** (new art: `icon_book`):
  - in a game: in the top bar, left of the statistics icon (which is left
    of the settings gear);
  - on the title screen: from the main page.
- **Pausing:** in single player, opening it pauses the game and greys it out
  behind it (as the settings dialog does), and closing it resumes at the old
  speed. In co-op it doesn't pause anyone, the same as a client's settings
  dialog.
- **Each entry:** the art, a short text, and the real numbers, read from
  `Config`: HP, speed, damage, cost, range, and from which wave. The pages
  never go out of date.
  - Enemies: every kind in `Config.ENEMIES`, with when it joins the waves
    and what's special about it (flies, steals, raises the dead, ...).
  - Units: every kind in `Config.MILITARY`, with its levels and
    specialisations.
  - Buildings: every kind in `Config.BUILDINGS`.
  - Villagers: every role in `Config.CIVILIANS`.
  - Hero: modes, levels (HP, damage, XP cost) and what earns XP
    (`HERO_XP_PER_ACTION`, "10 XP per treasure looted" among them).
  - Places: the things on the map: treasures (and relics), monster camps,
    monster lairs (when they wake, what they send, their loot), mines,
    ruined watchtowers, and the unit-unlock sites.
  - Damage: one entry per damage category (`Config.DAMAGE_CATEGORIES`; name,
    picture and text in `Config.DAMAGE_INFO`): who deals it (units by their
    `ATTACKS` category, not the healing mage; elementals by `SUMMONS`
    "category"; the hero by `HERO` "category"; enemies by "attack_category",
    melee by default), which enemies take more or less of it (`resist`), the
    raised's extra holy factor. All of it is read from Config, so a changed
    attack, resistance or category shows up by itself.
- It scrolls, and fits portrait and landscape like the other dialogs.
- As built: on the title screen it is a *Library* button (with the
  book icon) on the main page, under *Tutorial* and above *Exit*, on
  every platform, the web too. It opens on the tab shown last. Enemy numbers
  are for the chosen difficulty, in wave 1; unit values go from level 1 to
  the top level. The wall tower and the summoned elementals have entries
  too; an elemental's speed is `Config.SUMMONS[kind].speed` (earth 1.1,
  fire 1.8 tiles/s). Enemy texts are `Config.ENEMIES` "desc"; the places'
  texts live in `library.gd`.
- **Everything is shown, always** (for now): units and villagers that have
  to be found first (summoner, apprentice, acolyte, miner; `Config.LOCKED`) and every
  kind of place, whether the player has met it or not.

## 5. Code sketch

- `scripts/tutorial/tutorial.gd` (a Node, child of Game while the tutorial
  runs): the list of steps, the current step, the card, the highlight. It
  holds the waves (`Waves.hold`, the tutorial wave contents) and stops corpses
  rotting.
- A step is a Dictionary (`_build_steps`): "title", "text", "done"
  (Callable -> bool, polled every 0.25 s on the game state), "point"
  (Callable -> {"hud": control names, the first visible one outlined;
  "tab": the dock tab to open; "tiles": map tiles to mark; "units": unit
  figures to outline}), and optionally "start" (called when it begins),
  "ready" + "wait_text" (the card waits for "ready" before showing the step,
  saying "wait_text" meanwhile: step 7), "button" (a button that goes on:
  the welcome's *Let's go*) and "id" (for the steps the tutorial reacts to:
  "gatherers", "barracks").
- `scripts/tutorial/highlight.gd`: the pulsing outline over a Control or a
  tile, and the arrow.
- `scripts/ui/library.gd`: the tabbed dialog, built from `Config`. It
  is used by the HUD and by the title screen.
- `Config.TUTORIAL`: seed 1337, Highlands, Easy, start villagers and
  buildings, starting resources, the tile for step 2, the field for step 5,
  and the two waves.
  - As built, the spots are **picked on the map** (`RoadSpots`,
    `scripts/tutorial/road_spots.gd`, which the scenarios' cards use too), so a change to the world
    generator can't put them in a river: the waves' road is the last 18 road
    tiles before the gate, coming from the edge spawn nearest by road. The
    watchtower goes next to that road 3 to 7 tiles before the gate, the
    barracks 8 to 13 tiles before it, and the farm on the nearest free spot
    by the village. Their surroundings are uncovered at the start. A tile set in
    `Config.TUTORIAL` (instead of `Vector2i(-1, -1)`) overrides the pick.
  - If something gets built on a spot before its step (say a watchtower on
    the barracks spot), the step marks the nearest free spot within 6 tiles
    instead (and keeps it while it stays free). If there's none, it marks
    the original spot anyway.
  - The forester's camp stands on `Config.TUTORIAL["camp_tile"]` (32, 38),
    west of the village by the forest, where no wall or tower hides it on
    screen; `Vector2i(-1, -1)` there means the usual start-spot search.
    (In every game, the starting farm and camp now avoid spots right behind
    the walls, a corner tower or a tree.)
  - Both tutorial waves come down that road. Wave 2 starts as soon as
    step 10 is done. Once wave 1 has started, *Call now* is locked ("Not
    yet"; the wave text says "Wave N: not yet") until the tutorial is over.
  - Step 4 counts any unit on any tower (a wall tower too), step 10 any
    unit on a barracks bench, and step 12 a wall tower's upgrade too.
  - Step 7 waits after step 6 until wave 1 has left a corpse (or one was
    already brought home), so the wave is seen before the gatherer comes up.
  - If wave 1 left no corpses (the goblins got through), two goblin corpses
    are put by the road, so step 7 can't get stuck.
- `tests/tutorial_bot.gd`: plays the tutorial by doing each step with
  commands and taps. It checks that every card appears and finishes, that
  Skip and Play on lead to a normal game.
- `tests/library_bot.gd`: the library pauses single player (not
  co-op), lists every kind in `Config` with its numbers, and fits the screen.

## 6. Effort

| Part | Rough size |
|---|---|
| A. Tutorial (13 steps, card, highlight, tutorial waves, tests) | the biggest: like the rat feature and the villager list together |
| B. Library (6 tabs, built from config, book icon, tests) | medium |

## 7. Decisions

From two rounds of review:

1. Parts: the tutorial, and a library instead of "How to play". No
   one-time tips for now.
2. After the tutorial, the same map goes on as an endless game.
3. The tutorial is single player only.
4. The steps are the list in §3.3. The upgrade step is split into two, one
   for units and one for towers.
5. The card goes top-left for now; to be checked in play.
6. No tips.
7. English only.
8. Map: Highlands, seed 1337.
9. Step 11 only mentions the training grounds. It is done when a unit goes
   up a level, by gold or by training.
10. The library has a book icon, left of the statistics icon in game,
    and a *Library* button on the title screen's main page. It pauses single player, has no Basics tab,
    and has a Places tab. It shows all units and places, always (for now).
