# The scenario system

Part of the scenario design; index in scenarios-design.md. The code is the source of truth for fields and cutscene steps (`scripts/scenarios/scenario.gd`, `cutscene.gd`, `scenario_runner.gd`); this page keeps why the system is shaped as it is and the rules every scenario must respect.

## Shape

- **One file per scenario** (`scripts/scenarios/scenario_<n>.gd`, extending `Scenario`) holds everything that scenario is: its data and its content (cutscenes, cards, hints, objectives, per-wave events). Its numbers stay there, not in `config.gd`, so the config stays about the normal game. `Campaign.SCENARIOS` lists them in order. Nothing carries over between scenarios, so any one can be replayed alone.
- **The runner** (`ScenarioRunner`, a child of `Game` while a scenario runs) plays it. Before the world exists it sets the map, difficulty and enemy scale (a scenario's own scale replaces the difficulty's multiplier, so it can be weaker than Easy). Once the world stands it applies the baseline (ruins, prebuilt posts), then the intro, cards, hints and objectives; the outro runs when every objective holds at once and no wave is running. Villagers wait at home through the intro so a cutscene is not played over a village at work.
- **A baseline is placed meaningfully:** prebuilt posts go by a road, a fixed tile or a map object, so the spot means something to the player.
- **Waves are scripted** and may end ("N waves") or repeat and grow until the objectives are met ("until done"). Wave 1 can wait for the player or for the scenario.
- **Between waves** a scenario can play short scenes, show a found journal page over the paused game, and hold a card back until the player can act on it, so a lesson only shows when it is usable.
- **Not built, by design:** saving a scenario (its campaign-only buildings and people are not in saves), carrying anything between scenarios, and upgrading the stall in play (no command does it; its stage is set by the scenario).

## Rules every scenario must respect

- **Every order passes one place.** `Commands.submit` asks the runner whether the command is allowed, so a rule cannot be bypassed by any input path (or a co-op-style client). The HUD hides what is not allowed so the player is not offered it, but the check is the command's, never the UI's.
- **Defeat and win are the scenario's to define:** a villager's death, a named person's death, or the hero being downed can each end it; the usual defeat does too. The defeat screen names the cause; the win screen leads on to the next scenario, whether or not this one was completed, or after the last to the campaign map. Completion is remembered by title; release builds show only unlocked scenarios.
- **Rules per scenario instead of global switches:** enemy strength, a custom wave mix, locked specialisation, whether the hero revives, who must live.
- **Campaign-only things live outside the normal game:** buildings, people and enemies flagged campaign-only are not buildable or recruitable except where a scenario lists them.

## Cutscenes

- In-engine, not video: the game runs on behind black bars, the HUD hidden and map input off; the camera moves between spots and people speak in a box with a portrait. The mission narrator (no portrait, italic) says what to do, never the story. Portraits are generated art (`tools/gen_art.py`).
- A cutscene is a list of steps. **Skip must be safe:** a skipped cutscene never runs the steps after the skip, so a scene cannot rely on a last step to clean up. Figures made for a cutscene vanish when it ends, played or skipped; one the scenario keeps is made explicitly.
- **A choice is a line with buttons.** Skip before a choice jumps to it (only the `do` steps on the way run), so the player always makes it, and at the choice Skip and Esc do nothing.

## What the engine needed

The campaign outline assumed these pieces; they are built. The reasons explain the system's shape:

- **A scenario system,** with a baseline per scenario, objectives, a win and an outro. The tutorial was the closest existing piece.
- **Destroyable, rebuildable buildings** with repair cheaper than new (`siege-design.md`), so a ruined home is a game, not a backdrop.
- **Breaches:** enemies walk through broken walls into the village but are held at a gate until it breaks. This replaced the rule that the inside is always safe, so walls and gates are real defences.
- **Water monsters** (`aquatic-design.md`): scenarios needed only maps with enough water and water spawns, a scripted stronger leviathan and a non-wave guard octopus.
- **A capital city** as a new zone, not a new map type, so the generator stays out of it.
- **Choices,** for offers the player may accept and lose by.
- **Guard mobs outside the wave count, a boss that is downed and flees, scripted caravans** where there are no farms.
- **A death effect for the Legion:** the pale colour fades, a human face shows, a breath goes out, so each kill reads as a release: they are alive and bound, and Brenna wants to free them.
- **Objectives, scripted events, skippable cutscenes and scenario text** (lore, journal fragments, log lines).
