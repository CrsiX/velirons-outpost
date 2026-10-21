# Veliron's Outpost: the interface (design)

Status: **built; describes the current code**.
Scope: everything the player sees and touches outside the map simulation. That covers the
title screen, the HUD (top bar, dock, panels, dialogs, warnings, log), placing buildings,
stationing units, the camera, the speed and pause rules, and the portrait / landscape layouts.
The tutorial card and its highlights are in docs/tutorial-design.md. The multiplayer join page,
lobby and co-op dialogs are in docs/multiplayer-design.md.

The whole UI is built in code (no `.tscn` layouts): `scripts/ui/hud.gd` (class `Hud`, a
CanvasLayer) for the game, `scripts/ui/title_screen.gd` for the title, plus the files named below.
Big touch targets everywhere, so mouse and fingers work the same.

## 1. Principles

- **One UI for mouse, keyboard and touch.** Buttons are at least 44 px high. A press only counts
  as a drag after it moves more than `DRAG_THRESHOLD` (12 px; the same value in `Hud`, `Game` and
  `CameraController`). A press that turns into a scroll or a drag never fires a button.
- **Two layouts, chosen by shape, not device** (§11): landscape (wider than tall) and portrait.
  Every screen listens to `Layout.changed` or the viewport's `size_changed` and rearranges.
- **Costs and XP as icons.** Texts hold tokens `{gold}` `{food}` `{materials}` `{xp}` `{hp}`.
  `Hud.set_rich_text` / `Hud.icon_bbcode` draw them as icons about as tall as the font. The plain
  words stay readable through `Hud.button_text(b)` (tests use it). "HP" stays a word in sentences.
- **Theme:** `scripts/ui/ui_theme.gd` (`UiTheme.build()`, colours `GOLD`, `INK`, `BAD`, `TEXT`,
  `MUTED`; `style_primary` / `style_good` / `style_danger` for buttons).

## 2. Title screen (`title_screen.gd`, `title_backdrop.gd`)

- **Main page:** Campaign, Singleplayer, Multiplayer, Tutorial, Library, Map Editor and Exit, each with its own
  icon at the same size (Campaign: a crimson banner, `icon_campaign`). Exit is hidden in the browser (`OS.has_feature("web")`), since a page can't
  close its tab. **Map Editor** opens `scenes/map_editor.tscn` (docs/map-editor-design.md).
- **Singleplayer page:** Continue (only with a single-player save: the newest one, autosave or
  manual, with a line under it saying what it is, "Wave 7 · Highlands · Normal"; then it is the
  primary button and Enter's), Play (primary style without a save), Load... (the save list,
  `SaveList`; docs/save-design.md), Difficulty (cycles Normal → Hard → Easy), Map (the map
  type: Temperate, Highlands, Coast, Desert, Volcanic, Random, then Custom...: a map file from the
  map picker, shown by its name; the next press goes back to Temperate), *Your village: n of m* (a map
  file with several villages), a seed field (empty: random; `Settings.parse_seed`; hidden for a map
  file), Back. The choices live in the `Settings` autoload: they carry over into the game and back,
  but last only until the app closes. Only the multiplayer name and colour are saved to disk
  (`user://player.cfg`).
- **Multiplayer page:** `MultiplayerMenu` (docs/multiplayer-design.md). The title screen opens on it
  when a LAN session is still open (coming back from a game).
- **Campaign map** (`CampaignMap`, `scripts/ui/campaign_map.gd`): *Campaign* opens an old fantasy map of the kingdom filling the
  whole screen (the title and menu hidden meanwhile), so it scales to any number of scenarios and any screen. The geography is in
  docs/story-design.md §4a.
  - *The layout* (`data/campaign_map.json`, `Campaign.layout()` / `places()` / `route()`): the picture's size, the places (a name in
    Title Case, a spot in map units, a pin symbol), unnamed towns (drawn as a walled ring of houses, no pin), the road crossings and
    the ends where roads leave the map into the neighbours, and the roads (from one of those to another, through points).
    The one file serves both the picture and the route, so they always match.
  - *The picture* (`campaign_map`, made by `gen_art.py` from that file): ragged coasts with ripple lines, islands, a ship and a sea
    serpent in the western ocean; the dark wilderness beyond the Wardline's wall and towers in the north; mountain ranges along
    ridgelines with hills, dense forest clumps, meandering rivers into the great lake and the sea; the roads (dashed, each smoothed
    by corner cutting, `chaikin` / `Campaign.smooth`), with hamlets and fields along them; the neighbours washed in sepia behind
    hand-drawn borders; a compass rose, specks, folds and darkened edges. No writing on it: region names (Veliron, the neighbours, the
    ocean, the wilderness, the Wardline: `Campaign.REGIONS`) are labels laid over it, so they stay sharp and can be translated.
  - *The view:* the map always covers the screen (`zoom` at least the covering scale, `center` kept so no edge shows). Choosing a
    place glides the map (`glide_to`, 0.45 s) so the place sits in the middle of the part the scroll leaves free, a little closer
    (`FOCUS_ZOOM`); a drag pans it (by position differences, as the game's camera); a tap on the map rolls the scroll up. A turned or
    resized screen keeps the chosen place in view.
  - *Places:* each scenario names its place (`Scenario.place`); scenarios on the same map share one (the outpost: 1, 2, 3 and 10; the
    capital: 8 and 11). A place is a round pin (`pin_<symbol>`, at least a finger's size) with its name and its scenarios' numbers
    under it.
  - *Brenna's route* runs from each scenario's place to the next one's along the roads (`Campaign.route`: the shortest way through
    the road network): a red dotted trail where the later scenario is completed, red dashes ahead (fainter beyond the next one). When
    the map opens, the stretch to the next scenario draws itself in (`DRAW_IN`).
  - *Progress on the map:* a place none of whose scenarios is unlocked isn't shown at all: no pin, no name, no route to it, just the
    empty map there (release builds; debug builds show everything); a place whose scenarios are all completed carries a red wax seal
    (`map_seal`); the place of the next scenario to play pulses.
  - *Choosing:* a tap on a pin unrolls a parchment scroll between two wooden rods (landscape: on the right, unrolling downwards; portrait:
    a sheet along the bottom, unrolling upwards; the moving rod stays at the parchment's edge): the place, its scenarios as rows ("3. The Wardline", a check when completed, "Locked" when not yet open), and for the
    chosen one its portrait (`Scenario.portrait`), its line (`Scenario.blurb`) and **Play** ("Play again" when completed; sets
    `Settings.scenario_next` and starts the game scene). It opens on the next scenario to play. The arrow keys step through the open
    scenarios in order, Enter plays, Esc rolls the scroll up, then closes the map; *Back* in the corner.
  - **Progress** (`Campaign.completed`, `user://campaign.json`): a won scenario is remembered as completed, by its title, on this
    device. Completed ones carry a check (`icon_check`); the scroll opens on the next to play (the one after the highest completed,
    `next_to_play`). In a release build a scenario opens only once it is unlocked (`Campaign.unlocked`: the first, one after a completed
    one, or one before a completed one, so a scenario added later never locks out what was played); debug builds open them all. The file holds `format` (`PROGRESS_FORMAT`; another format is read as no progress), `campaign`
    (the titles in order when it was written) and `completed`.
- **In a scenario** (docs/scenarios-design.md §7): its **card** sits top left where the tutorial's does
  (`ScenarioCard`): a heading ("Scenario 1: Homecoming ▾", a tap folds the card to it), the teaching
  card (title, text, a tick when done), a hint in orange when one comes up (14 s), and the objectives,
  each with a dot or a tick and its progress ("4 / 9"). The highlight is the tutorial's. **Cutscenes**
  (`Cutscene`, a CanvasLayer over everything): black bars top and bottom (9 % each), the HUD hidden, a
  dialogue box at the bottom (at most 900 px wide; portrait 112 px, 80 px on narrow screens; the
  speaker's name in their colour; "Tap to go on"), title cards in the middle, *Skip* top right. A **journal page**
  (`Journal`, a found journal, letter or logbook) is a parchment panel in the middle over a dimmed, paused game
  (single player), with *Close* (Esc too: a HUD popup). The **trade stall's panel** shows its goods (n / max),
  whether the merchant is there, rats, and one *Buy* button per lot (material, food) with its price.
- **Tutorial** sets `Settings.tutorial_next` and starts the game scene (docs/tutorial-design.md).
- **Library** opens the same `Library` control the game uses (§9). There is no game to pause here.
- **Keys:** Enter opens the Singleplayer page, and on it continues the newest save (or, without
  one, starts a new game; not on the multiplayer pages). Esc goes back to the main page, or leaves the online session from the multiplayer pages.
  F11 does nothing here (it only works in the game, §11).
- **Layout:** in landscape the title is on top and the menu sits on the left over the backdrop. In
  portrait the title is smaller and the menu is centred lower down. The lobby (two panes) is centred
  and wider. The menu moves up so it never runs off the bottom, but never over the title. On short
  screens the buttons shrink from 64 to 52 px with less spacing.
- **The backdrop** (`TitleBackdrop`, settings in `Config.TITLE_BACKDROP`): a real game plays itself
  behind the menu.
  - Each scene is a fresh `Game` with `backdrop = true` on a fixed map (`map_type`, `seed`). It has
    its own posts, manned units, timed enemy groups down one road, and a camera drifting from `from`
    to `to`.
  - The scenes are: Archers hold the gate, Fire on the farm, The barracks turn out, Summoner and witch,
    Flyers over the swamp, Slimes split, A quiet day. With `random` on, each next scene is a random one,
    never the one just played.
  - **Timing:** each scene plays `duration` (40 s) at `speed` 0.33 (slow motion). It fades in from black
    over `fade_in` (2.5 s) and out over `fade_out` (1.5 s). The screen is black until the first scene
    is made. `shade` (0.3) darkens the game so the menu reads.
  - **Making a scene:** the menu shows first, over black; only then is the first scene made. Between
    two scenes it fades to black, frees the old game, makes the next one and fades in, with at least
    `black` (0.3 s) of black in between.
    - The map is baked: `tools/bake_title_maps.tscn` saves each scene map (`MapData.to_bytes`) into
      `data/title_maps/<type>_<seed>.res` (`BakedMap`), and `prepare` hands it over as
      `Game.preset_map`. A missing one is generated. title_bot checks that the bake matches the
      generator.
    - The game is built over many frames. `Game._ready`, `World.setup`, `GroundLayer.setup` and
      `Hud.setup` call `Game.build_step()`, which waits for the next frame once the current one has
      spent `build_slice` (0.05 s); for any other game it returns at once. Heavy first draws (the
      ground's passes) get a frame each. Meanwhile the game is `PROCESS_MODE_DISABLED` and the
      SubViewport doesn't render; `start` then lets it run and fades it in (`playing`).
    - A `play(i)` while a scene is still being made waits for it, then makes scene `i`.
  - **What is off:** the game renders into its own SubViewport with `gui_disable_input`, so it gets no
    input (Space doesn't pause it). It has no HUD, no fog, no sound, no raids and no defeat. Its clock
    and tweens run in real time, whatever `Engine.time_scale` is.
  - Leaving the title screen ends the backdrop and puts speed and sound back to normal.
  - The SubViewport is sized by the final canvas transform (`_fit`), or it would be blurry.

## 3. The top bar

- **Contents.** The left group holds the resources and the hero:
  - **Gold**: amount.
  - **Food**: amount and rate, "123 (+4/min)", the rate smaller and grey. The amount turns red while the village starves.
  - **Material** (a button): opens the trade dialog to buy material with gold.
  - **People**: "civilians / huts", a button that opens the villager list (§7).
  - **Hero**: `{xp}` and her XP, with a health bar along its bottom edge (`HERO_HP_BAR` 7 px). It is
    green from 50 %, yellow from 20 %, red below, and empty while she is downed. The button opens the
    hero panel.

  The right group holds the wave controls:
  - **Enemies**: on the map plus still to come this wave.
  - **Wave text**: "Wave N in m:ss", "Wave N attacking", or in the tutorial "Wave N waits" /
    "Wave N: not yet".
  - **Call button**: "Call now +X {gold}" while waiting, "Fighting..." during a wave, "Not yet" while
    the tutorial holds the wave.
  - **Speed button** (§10).
  - **Library** (book icon), **statistics** (bar chart) and **settings** (gear), in that order.
- **Landscape:** one row, `TOPBAR_H` 64 px. If it doesn't fit the width, `_fit_topbar` first shrinks
  the spacing, then hides the wave text (the call button and enemy count still say enough).
- **Portrait:** two rows. The wave controls (enemies, wave text, call, speed, library, statistics,
  settings) are on top; the resources and hero are below.
- **The top-left panels** (hero panel, villager list, trade dialog) share a corner. Opening one closes
  the others.

## 4. The dock: sidebar and bottom sheet

- The dock has three tabs:
  - **Build**: the buildings, with costs.
  - **Village**: civilians to recruit; co-op: Send resources.
  - **Army**: units in stock (the reserve) on top, units to recruit below. Locked kinds stay hidden
    until unlocked. Upgrade selected; co-op: Send....
  - Each entry has an icon, a title, a description and an action button. Entries sit in two columns
    on a wide enough portrait screen.
- **Landscape: the sidebar** is `SIDEBAR_W` 320 px wide, on the right. A toggle beside it folds it to
  the right edge, for more map.
- **Portrait: the bottom sheet.** The tabs always show along the bottom edge. A page slides up above
  them.
  - **Height:** as tall as the page needs, but at most `SHEET_MAX` (half) of the screen. It always
    shows at least `SHEET_MIN_CONTENT` (150 px) of entries, and the rest scrolls.
  - **Tap:** a tab or the chevron opens the sheet. Tapping the open tab, the chevron or the handle
    folds it. A tap on another tab only switches the tab.
  - **Drag:** the handle, any tab, the gaps between tabs and the chevron all pull the sheet with the
    finger. On release, a flick faster than `SHEET_FLICK` (600 px/s) decides the direction; otherwise
    the nearer end wins. The sheet then glides there.
  - **Scrolling:** entries scroll by finger from anywhere on them. Buttons pass drags on to the scroll
    container, and a press that became a scroll doesn't fire its button on release.
  - **Folding by itself:** the sheet folds away while you place a building, station a unit or drag a
    unit card, and comes back afterwards (`_auto_collapse` / `_auto_restore`). A new selection folds
    it too, so the info panel has room above it.
- `SIDEBAR_W`, `SHEET_MAX`, `SHEET_MIN_CONTENT`, `SHEET_FLICK` and `DRAG_THRESHOLD` are layout
  constants in `hud.gd`, not balance numbers, so they aren't in `config.gd`. (The warning delays
  are tunables, so they are: `Config.NO_BUILDER_DELAY`, `Config.FOOD_SHORTAGE_DELAY`.)

## 5. Placing buildings (`Game.begin_build` and friends)

- **One building per pick.** Tapping a Build entry picks it, and tapping the same entry again puts it
  away (`Game.toggle_build`). Once a building is placed, build mode ends.
- While picking, a hint names the building ("Tap explored grass to place a Farm"). It is centred over
  the map in landscape and full width under the top bar in portrait. A big red **✕ Cancel** button
  sits in the bottom corner, where the thumb is.
- **Cancel paths:** the Cancel button, the picked entry again, Esc, right-click, and Android's back
  button. While placing or stationing, `quit_on_go_back` is off and `NOTIFICATION_WM_GO_BACK_REQUEST`
  cancels instead of quitting.
- **Mouse** (`Layout.touch` false): the building follows the pointer, green where it can go and red
  where it can't. A click builds it. A refusal shows as a toast and it stays picked.
- **Touch** (`Layout.touch` true: the last press came from a finger): the first tap shows the building
  there, with **✓ Build** and **✕** under it (`Hud.show_place_confirm`). Build is disabled where it
  can't go, with the reason as its tooltip and in the hint. Tapping Build or the building builds it.
  Tapping elsewhere moves it. The buttons follow the building when the map pans and stay on screen.
- The check and cross on Build, ✕ and Cancel (and on the lobby's Ready) are icons (`icon_yes`,
  `icon_no`, both `YES_NO_ICON` px), not the ✓ / ✕ characters, which mobile browsers' fonts lack.
- **Drag from the Build tab:** pull an entry out of the dock onto the map and let go to build it there.
  Under a finger it shows a little above the finger, so the finger doesn't hide it. Let go over the
  dock to put it away. A drag inside the dock only scrolls. If it can't go where it was dropped, it
  stays picked (on touch, with Build / ✕ to move it).

## 6. Stationing and moving units

- **From the reserve:** tap a unit card, then a finished tower, training grounds or barracks
  (`Game.begin_station`). Free posts are highlighted and a hint names the unit. Or drag the card onto
  a post. A refusal shows as a toast. On success, the post is selected and a toast says "The archer is
  marching out".
- **Stationed units:** tapping a unit's figure on its tower selects it (`Game.select_unit`: a panel
  with Upgrade and Withdraw). The camera's `press_filter` (`Game._claim_press`) gives such a press to
  the unit, so the map doesn't pan.
- **Dragging a unit off its post:** past the drag threshold, the figure on the old post is ghosted.
  A copy follows the pointer, 30 px above it. Every free post the unit could go to (or swap with a
  unit on) lights up, the one under the pointer turns green, and a dashed arrow runs from the old post.
  - **Dropped on a free post:** the unit walks straight over (`move_unit`).
  - **Dropped on another unit:** the two swap posts (`swap_units`, `Army.swap`), if each fits the
    other's post (an archer on a tower and an acolyte in barracks can; a shield bearer in barracks
    and a healing mage on a tower can't), they are on different posts, neither is out on a sortie
    (its figure isn't on the bench then, so it can't be grabbed or dropped on either) and a path
    joins them. Each
    walks over and takes the other's slot. The partner (`Game.swap_partner`) is the unit whose figure
    is under the pointer; on a post with no free slot for the dragged unit, the pointer anywhere on
    it picks the nearest figure there. While a drop would swap, the single arrow becomes two curved
    arrows between the two figures, one each way, bowed apart like a recycling sign
    (`WorldOverlay._curved_arrow`). Both kinds of arrow are drawn over the buildings, with a dark
    rim so they read on stone.
  - **Dropped on the dock:** it is withdrawn. While the drag is over the dock, the dock turns green
    and a hint says so.
  - **Dropped anywhere else:** nothing happens.

## 7. Panels and dialogs

- **Info panel:** opens when you tap a building, a stationed unit or a map object. It shows the title,
  lines and action buttons, and refreshes about every 0.25 s.
  - **Position:** its bottom edge sits 10 px above the screen bottom (portrait: above the sheet), and
    it grows upwards.
  - **Overlay:** towers and barracks also draw their range (barracks: the activation range) on the map.
  - **Closing:** tapping the selected building again deselects it.
  - **Other villages:** their buildings can be looked at but not ordered.
  - **HP and repairs:** every building's panel (not huts) has an HP line ("{hp} 60 / 80") and,
    when hurt, *Repair (cost)*; while it is repaired, the progress and *Cancel repair*. A
    devastated building's title starts with "Devastated". Gates and walls have panels of their
    own: level, HP, *Upgrade gate / wall*. A hurt building shows a thin HP bar on the map (green,
    yellow below 50 %, red below 25 %) under its work bar (docs/siege-design.md §7).
  - **Map objects** have their own lines, e.g. a mine's gold rate with two decimals ("Gold: 0.25 per
    second while a miner works it").
- **Upgrade dialog** (`Hud.open_upgrade`, from the Army tab, a tower's panel or a bench's line): one
  button per `MilitaryUnit.upgrade_options()`, which means the level-up and, from level 3, each
  specialisation with its cost. It is 420 px wide (less on narrow screens), centred and kept on screen.
- **Confirmations** (`Hud` `_confirm_panel`): a title, a text, a confirm button (red when dangerous)
  and Cancel. They are used for the Spatial Archmage (shows its gold cost) and for retiring a villager.
- **Buttons that cost something follow the resources while their popup is open:** what can't be
  paid is greyed out, and turns on as soon as enough is earned (and off again when spent). The
  upgrade dialog, the Archmage confirmation and the trade dialog (`Hud._refresh_dialogs`, on every
  economy change), the Build / Village / Army entries and the send dialog (`Hud._refresh`), the
  info panel's actions (every 0.25 s), the villager list's *Rebuild all huts* and the hero's
  *Level up* (the HUD tick).
- **Hero panel** (top-left): its title names the mode with the mode's icon ("Hero: defending"), then:
  - level, HP and XP;
  - one icon button per mode, the current one framed (Support only in co-op, with its village toggle);
  - a hint for the mode (`HERO_MODE_HINTS`; Rest: "Walks back to the village centre and rests there,
    fighting nobody, healing as she idles.");
  - *Level up* and a status line;
  - training progress (when training);
  - *Go to hero* (or H): the view moves to her; while she is down, to where she fell (she stays there,
    unseen, until she revives).
- **Villager list** (the people button): the title "Villagers n / cap". Every villager is listed by
  role (`Config.CIVILIAN_ORDER`) and number, with what they are doing (and their HP when hurt), and:
  - *View*: moves the camera to them (to the village centre for those at home);
  - *Retire*: after a confirmation the villager leaves and frees their hut. The last villager can't
    retire.

  With ruined huts it also offers *Rebuild all huts (n)* with the total cost. Buttons keep their size
  and sit centred in their row.
- **Trade dialog** (the material button): buy building material with gold.
- **Toasts:** short coloured messages under the top bar: refusals, "Paused", "marching out". They
  never catch taps.

## 8. Warnings

- Both warnings are red text, centred under the top bar. They never catch taps.
- **No builder** (`NO_BUILDER_DELAY` 5 s): something waits in the build queue, there is no builder,
  and the hero is alive but not in Build mode. It says "No builder: nothing will be built. Recruit a
  builder (Village tab) or set the hero to Build."
- **Food shortage** (`FOOD_SHORTAGE_DELAY` 5 s): the food has been at 0 with a negative rate for
  that long. It sits right under the no-builder warning when that shows, else in its place.
  `Hud.food_warning_text()` picks the tip:
  - no farm → build one;
  - a farm but no farmer → recruit one;
  - a farm without a farmer and a farmer without a farm → assign them;
  - every farm worked → the warning alone, no tip.
- Both are checked in the HUD's 0.25 s refresh tick (`_process`). The delays are **real seconds**,
  whatever the game speed (4× doesn't shorten them), and time while the game is paused doesn't count.

## 9. Settings and the library

- **Settings** (gear): pauses the game (single player, or the co-op host) and greys the game out
  behind the dialog. The grey is a full-size rect that turns everything drawn before it grey.
  - **Continue:** goes back to the speed it had before. Esc does the same.
  - **Save... / Load...** (docs/save-design.md §4.2): Save opens a page with the save's name
    (prefilled "<map> · wave N"; a name in use asks first: *Save over it*), only between waves (else
    "Save... (between waves)", greyed out); Load opens the save list and asks before leaving the
    game. Neither in the tutorial; a co-op client has neither, the host only Save; a game from the
    map editor's Play only Save.
  - **Log level:** cycles Info / Important / Debug.
  - **Language:** built (shows the flag) but hidden (`visible = false`): there is no other language yet.
  - **Map type and seed:** shown so the map can be played again; for a map from a file its name and
    type instead.
  - **Back to editor:** only in a game the map editor's Play started (`Settings.editor_play`); back
    to the editor with its map, unsaved changes and undo (`Game.go_to_editor`).
  - **Back to title:** red, no confirmation; "Leave game" in a networked game.
  - **Co-op client:** the dialog doesn't pause, and a note says so.
  - **Co-op host:** pausing greys everything below the top bar for all players ("Paused by the host").
  - **Debug:** in a debug build (`OS.is_debug_build()`: a debug export, or run from the editor; never
    a release export), a *Debug...* page offers cheats and *Spawn enemy...*, all sent as commands
    (`Commands._debug`).
- **Library** (`scripts/ui/library.gd`, the book icon left of the statistics icon and the gear; also on the title screen):
  - **Tabs:** Enemies, Units, Buildings, Villagers, Hero, Places. Each entry has its picture, a short
    text and its real numbers.
  - **Built from Config:** every entry is built when its tab opens, so the numbers never go out of
    date. It shows everything, including what hasn't been found yet.
  - **Pausing:** in single player it pauses, shows the game in grayscale behind it like the settings
    (`_lib_gray`), and goes back to the earlier speed when closed (*Close* or Esc); paused before,
    it stays paused. Not after game over, and in co-op nobody pauses (no grey). Space does nothing
    while it is open.
- **Statistics** (`scripts/ui/stats_screen.gd` + `stats_graph.gd`, the bar-chart icon right of the
  book, or T; docs/statistics-design.md): Summary, Timeline and Awards tabs, built from `Game.stats`.
  - Greyed out before wave 2 (`Config.STATS["from_wave"]`; the tooltip says so, a tap only toasts).
  - The game-over screen stacks *Try again* (or *Try the tutorial again*; networked: *Main menu*),
    *Load last save* (single player, when this game has a save), *Main menu* (not networked) and
    *Statistics* under each other.
  - Pauses like the library and the settings (single player; not networked co-op, not after game
    over), and then shows the game in grayscale behind it (`_stats_gray`). Closing it goes back to
    the earlier speed; paused before, it stays paused.
    Esc or T closes it; Space does nothing while it is open.
- **The three top-right buttons behave alike:** settings, library and statistics each pause a
  single-player game, grey it out behind them, and go back to the speed before when closed.

## 10. Speed and pause

- `Game.SPEEDS` = [1, 2, 4, 0]. The single speed button cycles through them, with the icons play,
  fast, fastest and pause. Every change is a `set_speed` command.
- **Applying:** `Game.apply_speed` sets `Engine.time_scale` for a running speed. Speed 0 pauses the
  scene tree (`get_tree().paused`) and leaves `time_scale` as it was. "Paused" shows as a toast.
- **Space** (or **P**) pauses and remembers the speed. Pressed again it goes back to it, or to 1× if
  the game was paused with the button. Ignored while the settings, the library or the statistics are
  open.
- **1 / 2 / 3** (also on the keypad) set 1×, 2× and 4× (`Hud.hotkey_speed`); ignored while the
  settings, the library, the statistics or the game-over screen are open.
- **Co-op:** only the host sets the speed or pauses (`Game.is_host_player()`). A client's speed button
  shows the host's speed and is disabled.
- **Real time:** code that must run in real time (UI animations, `train_pause`, the title backdrop,
  the event log's lifetime, the HUD warnings' delays) divides by `time_scale` or ignores it.

## 11. Camera, layout and full screen

- **Camera** (`scripts/ui/camera_controller.gd`, `CameraController`):
  - **Pan:** drag with the left button or one finger, past `DRAG_THRESHOLD`. WASD and the arrow keys
    pan too, at `KEY_PAN_SPEED` 900 px/s, independent of game speed and zoom. A trackpad pan gesture
    also pans.
  - **Zoom:** the wheel (×1.12 per notch, towards the pointer), pinch and trackpad magnify, and
    **+** / **-** (also `=` and the keypad's; ×`Config.CAMERA_KEY_ZOOM` 1.12 per press, towards the
    middle of the screen, repeating while held; not while the settings are open), between
    `Config.CAMERA_MIN_ZOOM` 0.22 and `Config.CAMERA_MAX_ZOOM` 1.6.
  - **Over the dock** (the sidebar, or the bottom sheet in portrait, open or folded) the wheel and
    trackpad gestures belong to the dock: they scroll its list, and at either end of it nothing
    happens. They never zoom or pan the map there (`CameraController.wheel_filter`, set by `Game`
    to `Hud.is_over_dock`).
  - **Tap:** a short press without a drag emits `tapped`. Right-click emits `cancelled`.
- **Esc** (`Hud.escape`): the HUD keeps a stack of its open popups (`register_popup`: the placing
  mode's Cancel, the info panel, the hero panel, the villager list, the trade, send and upgrade
  dialogs, the confirmations, the settings, the Debug page, the tutorial's skip dialog). Esc closes
  the newest one open, the way its Close / Cancel does (a confirmation is cancelled, never
  accepted; the info panel deselects; placing is put away). The library and the statistics close
  themselves on Esc. With no popup open, Esc pauses and opens the settings; Esc again closes them,
  and the game goes on at its speed before (paused before: it stays paused). On the game-over
  screen Esc does nothing.
- **H** moves the view to the hero (see the hero panel's *Go to hero*).
  - **Firefox rule:** panning goes by the change of the pointer's position since the last event
    (`_last_pos`), never by the event's `relative`. Firefox reports `movementX/Y` wrongly for
    touch-made mouse events, which used to fling the map away. After a pinch, the next motion only
    re-anchors the pointer (`_repoint`), because it may be another finger.
- **Layout autoload** (`scripts/core/screen_layout.gd`, "Layout"):
  - **Orientation:** the window is portrait while it is taller than wide. The logical canvas then
    becomes 720×1280 instead of 1280×720 (`content_scale_size`, stretch `canvas_items`, aspect
    `expand`), so the UI keeps the same physical size in both orientations.
  - **Rotation:** Android follows the rotation sensor (`display/window/handheld/orientation = sensor`).
    Browsers and desktop windows just resize.
  - **Touch flag:** `Layout.touch` is true after a finger press and false after a real mouse click. It
    decides the touch way of placing (§5).
- **Full screen:** turned to landscape, a phone or tablet goes full screen. The Android app does it at
  once; a mobile browser does it on the next tap (a JS listener, since browsers only allow it in
  answer to a gesture). iOS Safari has no full screen for pages. It happens once per turn to
  landscape, so leaving full screen sticks until the next turn. F11 toggles full screen in the game
  (`Hud._unhandled_key_input`; also while the library or statistics are open), not on the title screen.
- **Camera cutouts and notches:** on a phone (Android, iOS) the parts of the screen a front camera
  or notch takes away (Godot's safe area, `DisplayServer.get_display_safe_area`) stay free of
  controls. `Layout.insets` holds them in canvas units (left, top, right, bottom). It is read again
  on every resize and every `SAFE_AREA_POLL` (0.5 s), since Android may report the new one a moment
  after a turn, and a change emits `Layout.safe_area_changed`.
  - `Layout.inset(c)` keeps a full-rect control inside the safe area: the HUD's root (so the top bar,
    the dock, panels, dialogs, the log, the tutorial card) and the map editor's root.
  - `Layout.bleed(c)` spreads a background inside such a control over the whole screen again: the
    greys of the settings, library, statistics and co-op pause, the dims of the library and the
    statistics, the game-over veil, and the tutorial's highlight layer (it draws at screen positions).
  - The map itself always fills the screen, cutout included.
  - HUD code that mixes screen positions with its own uses `Hud.to_ui` and `Hud.ui_size`, and
    `Hud.map_rect` is the safe area's map part.
  - The title screen and the lobby are centred with margins and need nothing. In the browser the page
    has no `viewport-fit=cover`, so the browser keeps it out of a cutout itself.
  - The top bar fits itself again (`_fit_topbar`: less spacing, then no wave text) whenever its content
    grows wider than the room it has, not only on a resize.

## 12. Event log and floating texts

- **Event log** (`scripts/systems/event_log.gd` for the data, `Hud` for the view):
  - **Levels:** Important (deaths and destroyed huts, with the cause), Info (waves, returns, finished
    buildings and upgrades, training, finds, unlocks) and Debug (every action and event). The game
    starts at Info.
  - **Retention:** every message is kept whatever level is shown, so changing the level re-filters old
    ones too. Each level keeps its newest `MAX_PER_LEVEL` (10), at most `MAX_SHOWN` (10) lines show,
    and a message is dropped `LIFETIME` (30 s, real time) after it was logged.
  - **View:** plain, slightly see-through text without a box, coloured by level. It is bottom left in
    landscape and across the bottom in portrait. It sits above the info panel when one is open, else
    above the sheet or the screen edge, and stays clear of the hero panel. It never catches taps.
- **Floating texts** (`World.float_text`, `Unit.float_text`): a short text rises from a spot and fades,
  for example "+2 {gold} +8 {food}" (loot brought home, drawn as icons), "+N {materials}" from
  foresters, "Enemies!", "Level 4!", "Hero down!". The co-op host replicates them to clients.

## 13. Tests

| Part | Bot |
|---|---|
| Title menu, portrait title, map drag (Firefox rule), wheel zoom, portrait top bar / sheet basics, trade dialog, log placement and levels, settings pause and dialog, dragging stationed units (ghost, highlights, arrow, withdraw on the sidebar) | tests/sim_bot.gd |
| One building per pick, Cancel, touch preview with Build / ✕, dragging from the Build tab, Android's back button; the portrait sheet (height cap, finger scrolling, dragging by handle / tabs / chevron, flicks); a faked camera cutout (left, right, on top in portrait: top bar, dock and settings box clear of it, the grey over the whole screen) | tests/build_bot.gd |
| Space and the speed button, the hotkeys (1 / 2 / 3, P, + / -, H, the Esc stack), the villager list, icons in texts, the no-builder and food-shortage warnings | tests/rat_bot.gd |
| The library: an entry for every kind in Config with its numbers, pausing (not in co-op), the book icon, the title button and icons, fitting the screen | tests/library_bot.gd |
| The statistics: counters, samples in game time, the button from wave 2, T, pausing, the tabs, folding, the game-over button, a column per village, the client copy | tests/stats_bot.gd |
| The title backdrop: made over many frames on its baked (up-to-date) map, each scene's posts, units and enemies, slow motion, starts black, fades via black, no input, speed and sound restored after | tests/title_bot.gd |
| The upgrade dialog and the Spatial Archmage confirmation (fit on screen, taps) | tests/military_bot.gd |
| The tutorial card, highlights and arrows | tests/tutorial_bot.gd |
| Co-op dialogs (send resources / units), host-only speed | tests/coop_bot.gd, tests/net_bot.gd |
