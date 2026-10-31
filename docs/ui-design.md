# Veliron's Outpost: the interface (design)

Status: **built; describes the current code**.
Scope: everything the player sees and touches outside the map simulation. That covers the
title screen, the HUD (top bar, dock, panels, dialogs, warnings, log), placing buildings,
stationing units, the camera, the speed and pause rules, and the portrait / landscape layouts.
The tutorial card and its highlights are in docs/tutorial-design.md. The multiplayer join page,
lobby and co-op dialogs are in docs/multiplayer-design.md.

The whole UI is built in code (no `.tscn` layouts): `scripts/ui/hud.gd` (class `Hud`, a
CanvasLayer) for the game, `scripts/ui/title_screen.gd` for the title, plus the files named below.
Layout constants (sizes, margins, timings of the interface) live in those files; balance numbers
live in `scripts/core/config.gd`. This document does not copy either: it says why.

## 1. Principles

- **One UI for mouse, keyboard and touch.** Targets are finger-sized everywhere, so the same
  controls work on a phone and on a desktop. A press only counts as a drag after it moves
  `DRAG_THRESHOLD` (one value shared by `Hud`, `Game` and `CameraController`, so a tap is a tap
  everywhere). A press that turns into a scroll or a drag never fires a button.
- **Two layouts, chosen by shape, not device** (§11): landscape and portrait. A narrow desktop
  window should behave like a phone, and a tablet like a desktop. Every screen listens to
  `Layout.changed` or the viewport's `size_changed` and rearranges.
- **Costs and XP as icons.** Texts hold tokens (`{gold}`, `{food}`, `{materials}`, `{xp}`, `{hp}`)
  that `Hud.set_rich_text` / `Hud.icon_bbcode` draw as icons: players read the icon faster than the
  word, and the text stays translatable. Plain words stay readable through `Hud.button_text(b)`
  (tests use it). "HP" stays a word in sentences.
- **Theme:** `scripts/ui/ui_theme.gd` (`UiTheme.build()` and the button styles).

## 2. Title screen (`title_screen.gd`, `title_backdrop.gd`)

- **Main page:** one button per entry (Campaign, Singleplayer, Multiplayer, Tutorial, Library, Map
  Editor, Exit), each with its own icon at the same size. Exit is hidden in the browser, since a
  page can't close its tab.
- **Singleplayer page:** Continue comes first and is the primary button when a save exists, with a
  line saying what it would load, because coming back to a game is the common case. Without a save,
  Play is primary. Difficulty and map type cycle on one button each (a fixed small set); a map file
  is chosen from the map picker. The choices live in the `Settings` autoload: they carry over into
  the game and back but last only until the app closes. Only the multiplayer name and colour are
  saved to disk. Saves: docs/save-design.md.
- **Multiplayer page:** `MultiplayerMenu` (docs/multiplayer-design.md). The title screen opens on it
  when a LAN session is still open (coming back from a game).
- **Campaign map** (`CampaignMap`, `scripts/ui/campaign_map.gd`): *Campaign* opens an old fantasy
  map of the kingdom filling the whole screen, so the campaign scales to any number of scenarios
  and any screen without a list of cards. The geography is in docs/story-design.md §4a.
  - *One layout file serves picture and route* (`data/campaign_map.json`, `Campaign.layout()` /
    `places()` / `route()`), so the drawn roads and the route Brenna walks always match. The
    picture (`campaign_map`) is made by `gen_art.py` from it.
  - *The picture has no writing.* Region names are labels laid over it (`Campaign.REGIONS`), so they
    stay sharp at any zoom and can be translated.
  - *The view* always covers the screen, so no edge ever shows. Choosing a place glides the map to
    it, a drag pans it (by position differences, as the game's camera), a tap on the map rolls the
    scroll up, and a turned or resized screen keeps the chosen place in view.
  - *Places, not scenarios, are the pins:* scenarios on the same map share a place (`Scenario.place`).
    A pin is at least a finger's size.
  - *Brenna's route* runs along the roads from each scenario's place to the next one's
    (`Campaign.route`): a trail where done, dashes ahead, and the stretch to the next scenario draws
    itself in when the map opens, so the player sees where the story goes next.
  - *Progress on the map:* places not yet open aren't shown at all (no pin, no hint of a spoiler);
    a place whose scenarios are all completed carries a wax seal; the next one pulses.
  - *Choosing:* a tap on a pin unrolls a parchment scroll (landscape: on the right; portrait: a
    sheet along the bottom) with the place's scenarios, the chosen one's portrait and line, and
    **Play**. It opens on the next scenario to play. Arrow keys step, Enter plays, Esc rolls the
    scroll up, then closes the map.
  - **Progress** (`Campaign.completed`, `user://campaign.json`) is remembered by scenario *title*,
    on this device. Release builds open a scenario only once unlocked (the first, one after a
    completed one, or one before a completed one, so a scenario added later never locks out what was
    already played); debug builds open them all. The file carries a format number, and another format
    is read as no progress rather than migrated.
- **In a scenario** (docs/scenario-system-design.md): its **card** sits top left where the tutorial's
  does (`ScenarioCard`): a heading that folds the card, the teaching card, an orange hint when one
  comes up, and the objectives with their progress. The highlight is the tutorial's. **Cutscenes**
  (`Cutscene`, a layer over everything) hide the HUD and use black bars and a dialogue box at the
  bottom so they read as film, with *Skip* always at hand. A **journal page** (`Journal`) is a
  parchment panel over a dimmed, paused game (single player) with *Close* (a HUD popup, so Esc too).
  The **trade stall's panel** shows its goods, whether the merchant is there, rats, and one *Buy*
  per lot.
- **Tutorial** sets `Settings.tutorial_next` and starts the game scene (docs/tutorial-design.md).
- **Library** opens the same `Library` control the game uses (§9). There is no game to pause here.
- **Keys:** Enter opens the Singleplayer page, and on it continues the newest save (or, without
  one, starts a new game). Esc goes back to the main page, or leaves the online session from the
  multiplayer pages. F11 does nothing here (it only works in the game, §11).
- **Layout:** in landscape the title is on top and the menu sits on the left over the backdrop. In
  portrait the title is smaller and the menu is centred lower down. The menu moves up so it never
  runs off the bottom, but never over the title; on short screens the buttons shrink.
- **The backdrop** (`TitleBackdrop`, settings in `Config.TITLE_BACKDROP`): a real game plays itself
  behind the menu, so the title screen shows what the game is rather than a still picture.
  - Each scene is a fresh `Game` with `backdrop = true` on a fixed map, with its own posts, manned
    units, timed enemy groups and a drifting camera; the scene list and every number are in
    `Config.TITLE_BACKDROP`. With `random` on, each next scene is random, never the one just played.
  - **Timing:** slow motion, faded in from and out to black, shaded so the menu reads. The screen is
    black until the first scene is made.
  - **Making a scene must never freeze the menu.** The menu shows first, over black; only then is
    the first scene made. Between two scenes it fades to black, frees the old game, makes the next
    one and fades in.
    - The map is baked (`tools/bake_title_maps.tscn` into `data/title_maps/`, `BakedMap`) because
      generating one takes seconds. `prepare` hands it over as `Game.preset_map`; a missing bake is
      generated. title_bot checks that the bake matches the generator.
    - The game is built over many frames: `Game.build_step()` (called from `Game._ready`,
      `World.setup`, `GroundLayer.setup`, `Hud.setup`) yields to the next frame once the current one
      has spent `build_slice`; for any other game it returns at once. Meanwhile the game is
      `PROCESS_MODE_DISABLED` and its SubViewport doesn't render.
    - A `play(i)` while a scene is still being made waits for it, then makes scene `i`.
  - **What is off:** the game renders into its own SubViewport with `gui_disable_input`, so it gets
    no input (Space doesn't pause it). It has no HUD, fog, sound, raids or defeat. Its clock and
    tweens run in real time, whatever `Engine.time_scale` is.
  - Leaving the title screen ends the backdrop and puts speed and sound back to normal.
  - The SubViewport is sized by the final canvas transform (`_fit`), or it would be blurry.
- **Build version** (`BuildInfo`): shown small in the bottom right, only the part that is known
  (nothing in the editor and in any build made without `tools/export.sh` or CI); the numbers come
  from a stamp file written while a build is exported.

## 3. The top bar

- **Contents.** The left group holds the resources and the hero; the right group the wave controls
  and the buttons for map, library, statistics and settings. See `Hud` for the exact list.
  - Food shows its rate next to the amount and turns red while the village starves: the rate is the
    number the player manages, the colour says it is too late.
  - The material counter is a button that opens the trade dialog, since "I need material" is
    when the player looks at it.
  - The hero's button carries her health bar along its bottom edge (`HERO_HP_BAR`), so she can be
    watched without opening her panel.
  - The wave text and call button say what the wave is doing ("Fighting...", "Not yet" while the
    tutorial holds the wave).
- **Landscape:** one row. If it doesn't fit the width, `_fit_topbar` gives up the least useful
  things first: spacing, then the wave text (the call button and enemy count still say enough),
  then the food rate. It refits whenever its content grows, not only on a resize.
- **Portrait:** two rows: the wave controls on top, the resources and hero below.
- **The top-left panels** (hero panel, villager list, trade dialog) share a corner. Opening one
  closes the others, so they never stack over each other.

## 4. The dock: sidebar and bottom sheet

- The dock has three tabs, Build, Village and Army. Army shows the units in stock on top and the
  units to recruit below, because stationing is the frequent action; locked kinds stay hidden until
  unlocked. Each entry has an icon, a title, a description and an action button.
- **Landscape: the sidebar** on the right, with a toggle that folds it to the edge for more map.
- **Portrait: the bottom sheet.** The tabs always show along the bottom edge, where the thumb is; a
  page slides up above them.
  - **Height:** as tall as the page needs, but at most about half the screen (`SHEET_MAX`), so the
    map stays visible, and never so short that it shows less than a few entries
    (`SHEET_MIN_CONTENT`).
  - **Tap:** a tab or the chevron opens the sheet. Tapping the open tab, the chevron or the handle
    folds it. A tap on another tab only switches the tab.
  - **Drag:** the handle, any tab, the gaps between tabs and the chevron all pull the sheet along
    with the finger, because a thumb doesn't aim at one small handle. On release a flick
    (`SHEET_FLICK`) decides the direction, otherwise the nearer end wins.
  - **Scrolling:** entries scroll by finger from anywhere on them. Buttons pass drags on to the
    scroll container, and a press that became a scroll doesn't fire its button on release.
  - **Folding by itself:** the sheet folds away while you place a building, station a unit or drag a
    unit card, and comes back afterwards (`_auto_collapse` / `_auto_restore`), so it never covers
    where you are working. A new selection folds it too, so the info panel has room above it.
- The layout constants are in `hud.gd`, not `config.gd`, because they aren't balance numbers. The
  warning delays are tunables, so they are in config (`NO_BUILDER_DELAY`, `STARVATION_WARNING`).

## 5. Placing buildings (`Game.begin_build` and friends)

- **One building per pick.** Tapping a Build entry picks it, and tapping the same entry again puts
  it away (`Game.toggle_build`). Once a building is placed, build mode ends: a stuck mode is the
  worst mistake on touch.
- While picking, a hint names the building, and a big red Cancel button sits in the bottom corner,
  where the thumb is.
- **Cancel paths:** the Cancel button, the picked entry again, Esc, right-click, and Android's back
  button (while placing or stationing, `quit_on_go_back` is off and the back request cancels
  instead of quitting).
- **Mouse** (`Layout.touch` false): the building follows the pointer, green where it can go and red
  where it can't. A click builds it. A refusal shows as a toast and it stays picked.
- **Touch** (`Layout.touch` true: the last press came from a finger): there is no hover, so the
  first tap shows the building there with **Build** and a cross under it
  (`Hud.show_place_confirm`). A finger can't preview and commit in one touch without fat-finger
  mistakes. Build is disabled where it can't go, with the reason as its tooltip and in the hint.
  Tapping Build or the building builds it; tapping elsewhere moves it. The buttons follow the
  building when the map pans and stay on screen.
- Check and cross are icons (`icon_yes`, `icon_no`), not the characters, which mobile browsers'
  fonts lack.
- **Drag from the Build tab:** pull an entry out of the dock onto the map and let go to build it
  there. Under a finger it shows a little above the finger, so the finger doesn't hide it. Let go
  over the dock to put it away. A drag inside the dock only scrolls, or you could never scroll a
  list of entries. If it can't go where it was dropped, it stays picked.

## 6. Stationing and moving units

- **From the reserve:** tap a unit card, then a finished post (`Game.begin_station`), or drag the
  card onto a post. Free posts are highlighted and a hint names the unit. A refusal shows as a toast.
- **Stationed units:** tapping a unit's figure on its tower selects it (`Game.select_unit`). The
  camera's `press_filter` (`Game._claim_press`) gives such a press to the unit, so the map doesn't
  pan when the finger meant the unit (§7, Picking).
- **Dragging a unit off its post:** the figure on the old post is ghosted and a copy follows the
  pointer, offset above it so a finger doesn't hide it. Every post the unit could go to (or swap
  with a unit on) lights up, the one under the pointer turns green, and a dashed arrow runs from the
  old post, so the player sees the move before committing.
  - **Dropped on a free post:** the unit walks straight over (`move_unit`).
  - **Dropped on another unit:** the two swap posts (`swap_units`, `Army.swap`) if each fits the
    other's post (an archer on a tower and an acolyte in barracks can; a shield bearer in barracks
    and a healing mage on a tower can't), they are on different posts, neither is out on a sortie
    (its figure isn't on the bench then, so it can't be grabbed or dropped on) and a path joins
    them. The partner (`Game.swap_partner`) is the unit whose figure is under the pointer; on a post
    with no free slot, the nearest figure there. While a drop would swap, the single arrow becomes
    two curved arrows, one each way (`WorldOverlay._curved_arrow`), so swap and move look different
    before the drop. Arrows are drawn over the buildings with a dark rim so they read on stone.
  - **Dropped on the dock:** it is withdrawn. The dock turns green and a hint says so, because
    "let go over the menu" is otherwise not discoverable.
  - **Dropped anywhere else:** nothing happens. A slip of the finger must never move an army.

## 7. Panels and dialogs

- **Info panel:** opens when you tap a building, a stationed unit or a map object, with title,
  lines and action buttons; it refreshes on a short tick. It sits just above the bottom edge (in
  portrait above the sheet) and grows upwards, away from the thumb.
  - Towers and barracks also draw their range on the map.
  - Tapping the selected thing again where nothing else is behind it deselects it (Picking, below).
  - Other villages' buildings can be looked at but not ordered.
  - Every building's panel (not huts) shows HP and, when hurt, *Repair* with its cost; gates and
    walls have panels of their own with level and *Upgrade*. A hurt building also shows a thin HP bar
    on the map (docs/siege-design.md §7).
- **Upgrade dialog** (`Hud.open_upgrade`): one button per `MilitaryUnit.upgrade_options()`, so the
  dialog and the rules can't disagree about what is offered.
- **Confirmations** (`Hud._confirm_panel`): used where an action can't be undone cheaply (the Spatial
  Archmage, retiring a villager). The confirm button is red when dangerous; Cancel is always there.
- **Buttons that cost something follow the resources while their popup is open:** what can't be paid
  is greyed out and turns on as soon as enough is earned. A dialog that only checked the money when
  it opened would make the player close and reopen it. The refresh paths are `Hud._refresh_dialogs`
  (on every economy change), `Hud._refresh`, the info panel's tick and the HUD tick.
- **Hero panel** (top-left): its title names the mode with the mode's icon, then level, HP and XP,
  one icon button per mode (the current one framed; Support only in co-op), a hint for the mode
  (`HERO_MODE_HINTS`), *Level up* and a status line, training progress, and *Go to hero*, which also
  works while she is down (the view goes to where she fell).
- **Villager list** (the people button): every villager by role with what they are doing (and their
  HP when hurt), *View* (moves the camera to them) and *Retire* (after a confirmation; frees the hut;
  the last villager can't retire). With ruined huts it offers *Rebuild all huts*.
- **Trade dialog** (the material button): buy building material with gold.
- **Toasts:** short coloured messages under the top bar for refusals and notices. They never catch
  taps, so they can't block play.
- **Picking** (`World.pick_all`, `Game._tap_select`, `Config.PICK`): what is under a tap, front to
  back (the y-sorted drawing order), is every stationed unit's figure (just before its post) and
  every building and found map object whose picture has an opaque pixel there
  (`Building.covers`) or whose footprint the tap is on. No bounding boxes: a tap on the visible
  part of a gate behind a church picks the gate, as the player expects.
  - **Tapping through:** a tap selects the front-most; a tap on the selection selects the one behind
    it, and after the last one nothing. So everything is reachable, also what is hidden behind a
    tall building. While the same things are under the taps, they keep the order of the first tap
    (`Game._stack`), though what was in front turns see-through meanwhile. With several there, the
    panel's last line says so ("2 of 3 here").
  - **See-through:** a building or map object drawn in front of the selection that hides enough of
    its picture is drawn see-through (`World.show_through`, `Building.see_through`) and comes last
    in the picking order, so what shows through it can be tapped directly. The thresholds are in
    `Config.PICK`.
  - Stationing a unit and dropping one onto a post take the front-most post there
    (`World.pick_post`), not whatever is in front of it.

## 8. Warnings

- Both warnings are red text, centred under the top bar. They never catch taps.
- **No builder:** something waits in the build queue, there is no builder, and the hero is alive but
  not in Build mode. A silent queue that never moves is the most confusing state in the game, so
  after a delay (`NO_BUILDER_DELAY`) the warning says what to do.
- **Food shortage:** a countdown over the last seconds before a villager starves while the food is
  at 0 (`STARVATION_WARNING`; docs/village-design.md §2a), so a starvation is never a surprise. It
  sits right under the no-builder warning when that shows. `Hud.food_warning_text()` picks a tip for
  what is missing (no farm, a farm but no farmer, unassigned workers); when every farm is worked, the
  warning stands alone, since there is nothing to advise.
- Both count **game seconds** (4x runs them 4x as fast) and paused time doesn't count, so they match
  what the simulation is doing.

## 9. Settings and the library

- **Settings** (gear): pauses the game (single player, or the co-op host) and greys the game out
  behind the dialog, so it reads as a different mode.
  - **Continue** goes back to the speed it had before (Esc does the same).
  - **Save... / Load...** (docs/save-design.md §4.2): Save only between waves (else greyed out, the
    label says why), a name in use asks first; Load asks before leaving the game. Neither in the
    tutorial; a co-op client has neither, the host only Save; a game from the map editor's Play only
    Save.
  - **Log level** (F3 does the same), **UI size** (a factor on the automatic size, saved on the
    device, applied at once), **Language** (built but hidden: there is no other language yet), the
    map's type and seed (so the map can be played again).
  - **Back to editor:** only in a game the map editor's Play started; it returns to the editor with
    its map, unsaved changes and undo.
  - **Back to title:** red, asks first; "Leave game" in a networked game.
  - **Co-op client:** the dialog doesn't pause, and a note says so. **Co-op host:** pausing greys
    everything below the top bar for all players.
  - **Debug:** only in a debug build, never a release export; cheats are commands
    (`Commands._debug`), so they also work for a co-op client.
- **Library** (`scripts/ui/library.gd`; also on the title screen): tabs of reference pages (see
  `Library.TAB_NAMES`), each entry with its picture, a short text and its real numbers. Every entry
  is built from Config when its tab opens, so the numbers never go out of date, and it shows
  everything, including what hasn't been found yet. Design: docs/tutorial-design.md §4.
  - In single player it pauses and greys the game; closing returns to the earlier speed (paused
    before: stays paused). Not after game over; in co-op nobody pauses. Space does nothing while
    it is open.
- **Statistics** (`scripts/ui/stats_screen.gd` + `stats_graph.gd`; design: docs/statistics-design.md):
  built from `Game.stats`.
  - Greyed out before `Config.STATS["from_wave"]` (the tooltip says so, a tap only toasts).
  - The game-over screen stacks the retry / continue actions and *Statistics* under each other (a
    won scenario's offers *Next scenario*, or after the campaign's last one *Show campaign map*;
    docs/scenario-system-design.md).
  - Pauses like the library and the settings, with the same exceptions.
- **The three top-right buttons behave alike:** settings, library and statistics each pause a
  single-player game, grey it out behind them, and go back to the speed before when closed. One
  rule is easier to learn than three.

## 10. Speed and pause

- `Game.SPEEDS` is the cycle the one speed button steps through, ending in pause. Every change is a
  `set_speed` command, so a co-op host's speed goes through the same path as everything else.
- **Applying:** `Game.apply_speed` sets `Engine.time_scale` for a running speed. Speed 0 pauses the
  scene tree (`get_tree().paused`) and leaves `time_scale` as it was, so un-pausing returns to the
  speed before.
- **Space** pauses and remembers the speed; pressed again it goes back to it, or to 1x if the game
  was paused with the button. Number keys set the speeds directly. Both are ignored while the
  settings, library, statistics or game-over screen are open.
- **Co-op:** only the host sets the speed or pauses (`Game.is_host_player()`). A client's speed
  button shows the host's speed and is disabled.
- **Real time:** code that must run in real time (UI animations, `train_pause`, the title backdrop,
  the event log's lifetime) divides by `time_scale` or ignores it; see CLAUDE.md.

## 11. Camera, layout and full screen

- **Camera** (`scripts/ui/camera_controller.gd`):
  - **Pan:** drag with the left button or one finger past `DRAG_THRESHOLD`; keys and trackpad
    gestures pan too, independent of game speed and zoom. **Zoom:** wheel (towards the pointer),
    pinch, trackpad magnify, and +/- keys (towards the middle of the screen), within
    `Config.CAMERA_MIN_ZOOM` .. `CAMERA_MAX_ZOOM`.
  - **Over the dock** (open or folded) the wheel and trackpad gestures belong to the dock: they
    scroll its list, and at either end nothing happens. They never zoom or pan the map there
    (`CameraController.wheel_filter`, set by `Game` to `Hud.is_over_dock`), or scrolling a list
    would swing the map.
  - **Tap:** a short press without a drag emits `tapped`. Right-click emits `cancelled`.
  - **Firefox rule:** panning goes by the change of the pointer's position since the last event
    (`_last_pos`), never by the event's `relative`. Firefox reports `movementX/Y` wrongly for
    touch-made mouse events, which used to fling the map away. After a pinch, the next motion only
    re-anchors the pointer (`_repoint`), because it may be another finger.
- **Esc** (`Hud.escape`): the HUD keeps a stack of its open popups (`register_popup`); Esc closes
  the newest one the way its Close / Cancel does (a confirmation is cancelled, never accepted). The
  library and the statistics close themselves. With no popup open, Esc pauses and opens the
  settings; Esc again closes them and the game goes on at its speed before. On the game-over screen
  Esc does nothing.
- **Hotkeys.** The list is `Hud.KEYS_HELP` (F1 shows it); keep it in step when a key is added. The
  design rules behind the keys:
  - Hero modes have one key each, mirroring her panel's buttons (their tooltips name the key);
    Support has none, being co-op only.
  - Keys that act on a selection (upgrade, repair, withdraw) mirror the panel buttons and toast why
    they refuse.
  - Shift turns a key into its bulk or "at once" form: Shift+Q repairs every damaged building and
    destroyed hut (`Hud.hotkey_repair_all`: the same commands as Q, nearest the village centre
    first so the build queue's age favours the nearest, until the material runs out), Shift+X
    levels the hero up when she has the XP (her panel's *Level up*).
  - Keys that find things (Tab through posted units, N for a workplace without its worker, H for the
    hero, Z for the village) move the view as well as selecting, because finding is the point. Tab
    order is clockwise round the village from the north so it is predictable.
  - **H** held down follows the hero every frame (`Hud._follow_hero`).
  - F2 saves a screenshot (`Screenshot`, `Config.SCREENSHOT`; the web build downloads it), F3 steps
    the log level, a key calls the next wave like *Call now*.
  - The game keys do nothing while the settings or game-over screen are open (`Hud._game_key`).
- **Layout autoload** (`scripts/core/screen_layout.gd`, "Layout"):
  - **Orientation:** the window is portrait while it is taller than wide. The logical canvas then
    becomes portrait-shaped (`content_scale_size`, stretch `canvas_items`, aspect `expand`), so the
    UI keeps the same physical size in both orientations.
  - **UI scale** (`Layout.ui_scale`, `Config.UI_SCALE`): phones and tablets stretch the base canvas
    over the screen so the UI fills it at finger size. A desktop sizes it by its screen instead (a
    fixed number of canvas rows per screen height, bounded below, times the player's UI size, never
    more than the plain stretch), so Full HD isn't drawn at a blown-up 1.5x. Headless runs (the
    bots) keep the plain base canvas.
  - **The map ignores the UI size:** `Layout.world_scale` multiplies the map cameras' zoom and
    limits (`CameraController.set_view_zoom`, `zoom_limits`), and a change of the UI size rescales
    the zoom (`Layout.ui_rescaled`), so the map looks and zooms as at the plain stretch. Code that
    sets `camera.zoom` directly sets the real zoom (bots, `ui_shots`).
  - **Rotation:** Android follows the rotation sensor; browsers and desktop windows just resize.
  - **Touch flag:** `Layout.touch` is true after a finger press and false after a real mouse click.
    It decides the touch way of placing (§5); a device with both works either way.
- **Full screen:** turned to landscape, a phone or tablet goes full screen: the Android app at once,
  a mobile browser on the next tap (browsers only allow it in answer to a gesture); iOS Safari has
  no full screen for pages. It happens once per turn to landscape, so leaving full screen sticks
  until the next turn. F11 toggles it in the game (also while the library or statistics are open),
  not on the title screen.
- **Camera cutouts and notches:** on a phone the parts of the screen a front camera or notch takes
  away (the safe area) stay free of controls. `Layout.insets` holds them in canvas units; they are
  read again on every resize and periodically (`SAFE_AREA_POLL`), since Android may report the new
  ones a moment after a turn, and a change emits `Layout.safe_area_changed`.
  - `Layout.inset(c)` keeps a full-rect control inside the safe area: the HUD's root (so the top
    bar, dock, panels, dialogs, log and tutorial card) and the map editor's root.
  - `Layout.bleed(c)` spreads a background inside such a control over the whole screen again: the
    greys, dims and veils, and the tutorial's highlight layer (it draws at screen positions). A dim
    that stopped at the cutout would look broken.
  - The map itself always fills the screen, cutout included.
  - HUD code mixing screen positions with its own uses `Hud.to_ui` and `Hud.ui_size`;
    `Hud.map_rect` is the safe area's map part.
  - The title screen and the lobby are centred with margins and need nothing. In the browser the
    page has no `viewport-fit=cover`, so the browser keeps it out of a cutout itself.

## 12. The tactical map (`scripts/ui/tactical_map.gd`, class `TacticalMap`)

An overview of the whole map from above, to read the situation at a glance: where the land is
watched, where the enemies are, which posts are manned and what is hurt. It is only an overview:
nothing is placed, stationed or upgraded on it, so it can never be a second, worse way to play.

- **Opening:** the map key or the map icon in the top bar; the same, Esc, the close button or a click
  on the map closes it. It is a HUD popup (`Hud.register_popup`), so Esc closes it before anything
  opened under it. Opening it ends placing a building or stationing a unit (`Game.cancel_mode`).
  Not in the title backdrop.
- **Live:** the game keeps running under it at its speed (nobody pauses; paused stays paused),
  because it is for watching a wave.
- **Where:** it covers the screen below the top bar, which stays visible and usable (speed, call
  wave). The dock, info panel and hero / villager panels are under it. Toasts, warnings, the log,
  the game-over screen, the settings, the library and the statistics are above it. Opening any other
  HUD popup closes the map, so two big overlays never fight.
- **Drawn as the game is:** the same isometric diamond, turned the same way, so up on the map is up
  on the screen. It opens on the land the village has explored (never smaller than the whole map
  fitted to its area); wheel, pinch and +/- zoom it, a drag or WASD / arrows pan it. A drag never
  counts as a click.
- **A click or tap** on a spot centres the game's view there (`CameraController.focus`) and closes
  the map. A building on that tile (a post rather than the unit on it) or a found map object is
  selected too, its panel open (`TacticalMap.building_on`). Shift+click, or a long press with a
  finger (`TACTICAL_MAP.long_press`), centres the view and keeps the map open, selecting nothing:
  that is how to look around without leaving. There is no outline of the view on the map.
- **Layers**, bottom to top, all from the local player's village (co-op: its own fog):
  1. *Ground* per tile, drawn when the map opens; a felled tree changes its tile at once.
  2. *Fog:* the game's three states (unexplored black, explored dimmed, watched clear), so the map
     never shows what the village doesn't know.
  3. *Buildings* on explored land, coloured by kind (another village's in its village colour),
     devastated ones dark red, sites lighter. Every post shows one dot per slot: filled while its
     unit sits there, an empty ring while the slot is free or its unit is away, so manned and empty
     posts are readable at a glance.
  4. *Map objects* found by the village.
  5. *Range rings* (toggle): every manned tower's range and every barracks' activation range with a
     unit on its benches.
  6. *Our people* (toggle): units in the field, summons, villagers outside the walls and the hero,
     in distinct colours; co-op allies' in their own (violet, lavender); downed, the hero's mark
     where she fell is grey.
  7. *Enemies* (toggle): only on watched land (`WarningLights.spots` as pulsing marks), because the
     fog rule holds here too.
  8. *HP bars* (toggle): over hurt units and heroes in the field, over a hurt unit's slot, and over
     every damaged building.
- **Toggles:** four icon buttons along the top edge (range rings, HP bars, our people, enemies),
  framed when on. All are on at first; their state is remembered on the device
  (`Settings.map_layers`).
- **Keys while it is open:** the game's hotkeys keep working where they don't need the view (speed,
  Space, hero modes, withdraw, call wave, F1 to F3, F11, Esc). +/- and WASD act on the map, not the
  game's camera (`CameraController.set_active`). The keys that move the view or open something
  close the map first (`Hud.MAP_CLOSING_KEYS` plus H, T).
- **Numbers:** `Config.TACTICAL_MAP` (colours, sizes, refresh times, zoom limits).

## 13. Event log and floating texts

- **Event log** (`scripts/systems/event_log.gd` for the data, `Hud` for the view):
  - **Levels:** Important (deaths, destroyed huts, with the cause), Info (waves, returns, finished
    buildings, training, finds, unlocks) and Debug (every action and event). The game starts at
    Info.
  - **Retention:** every message is kept whatever level is shown, so changing the level re-filters
    old ones too. Each level keeps its newest few and a message is dropped after a while in real
    time (`EventLog` constants), so the log stays short and current.
  - **View:** plain, slightly see-through text without a box, coloured by level, bottom left in
    landscape and across the bottom in portrait. It sits above the info panel when one is open,
    stays clear of the hero panel, and never catches taps.
- **Game log file** (`scripts/systems/game_log.gd`, `Config.GAME_LOG`): for debugging, every message
  at every level goes into one file per game in `user://game_logs` (not on the web, in the tutorial,
  the title backdrop or on a co-op client). Each line has fixed fields (in-game time, level, wave)
  so the files can be cut and searched by offset; co-op adds the village. A game loaded from a save
  appends to its own file and writes a "Game resumed" line and a snapshot per village, to the file
  only. The header and line format are in `GameLog`.
- **Floating texts** (`World.float_text`, `Unit.float_text`): a short text rises from a spot and
  fades ("+2 gold +8 food" as icons, "Level 4!", "Hero down!"), to show where a thing happened
  without a log line. The co-op host replicates them to clients.

