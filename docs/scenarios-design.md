# Scenarios design

Status: **the whole campaign (scenarios 1 to 11) and the scenario system are built.** This page is the core and the index of the campaign
docs: how the campaign is put together, the arc in a few lines per scenario, how the tutorial is spread over the first three, and what is still
open. The story it tells is in `story-design.md` (read that first: names, places, the cause of the war). The scenarios' own content and numbers
(baselines, waves, texts, cards, objectives) live in `scripts/scenarios/scenario_<n>.gd`, never in `config.gd` and never copied into the docs.
*Open* means not decided.

## Index

| Topic | File |
|---|---|
| Scenarios 1 to 3 (Homecoming, The Old Friend, The Wardline): story and as built, Pell's stall and trade | `scenarios-1-3-design.md` |
| Scenarios 4 to 6 (The Split, The Betrayal, The Dead) | `scenarios-4-6-design.md` |
| Scenarios 7 to 9 (The Exile, The Pale Court, The Drowned Abbey) | `scenarios-7-9-design.md` |
| Scenarios 10 and 11 (The Last Wardline, The Crown) | `scenarios-10-11-design.md` |
| The scenario system, cutscenes, and why the engine needed what it got | `scenario-system-design.md` |
| Riders (mounts, cavalry, captains on horses) | `enemies-design.md` §15e |
| Story, characters, monster categories, trade | `story-design.md` |
| The standalone tutorial | `tutorial-design.md` |

**Older citations** (code comments, notes) use the numbering from before the split. Map them like this: §1 and §2 stay here; the old §4 tutorial is §3 here and the old §5 open questions §4 here. Each scenario's outline (old §3.1 to §3.11) and as-built notes (old §7.3 to §7.19, and §9a for scenario 9) now sit in that scenario's own section:

| Old citation | Now |
|---|---|
| §3.1 to §3.3, §7.3 to §7.6 (incl. Pell's stall and trade, §7.4) | `scenarios-1-3-design.md` |
| §3.4 to §3.6, §7.7 (warehouse, guild master, captains), §7.8, §7.9, §7.11 | `scenarios-4-6-design.md` |
| §3.7 to §3.9, §7.10 (grove, graveyard, residents), §7.12 to §7.15, §9a | `scenarios-7-9-design.md` |
| §3.10, §3.11, §7.16 (caravans, commanders), §7.17, §7.18 | `scenarios-10-11-design.md` |
| §6, §7.1, §7.2, and a bare "§7" about the system | `scenario-system-design.md` |
| §7.19 | `enemies-design.md` §15e |

## 1. Structure

- The campaign is **eleven scenarios played in order**. Each has its own scripted baseline (map, village, units, resources, hero level, what is
  unlocked). **Nothing carries over**, so any scenario can be replayed alone. Only the story carries over.
- Every scenario has an **intro cutscene** and an **outro cutscene** (when the objective is met), both skippable. Between them the game plays as
  usual, with the story told through the library, treasures, the event log and a few scripted events.
- The hero is **Brenna Hale**. Her being downed is a **defeat** in every scenario except 1 to 3, where she revives as in a normal game.
  Scenario 10 is at home but has no revive: she cannot leave her post, which is the point of it.
- Scenario 1 alone also fails if **any villager dies**: it teaches caring for the villagers.
- **Pell must not die** in scenarios 4 to 11. **Fiona's death** is a defeat wherever she appears (7 and 11), as is Brenna's where she cannot
  revive.
- The **tutorial is merged into scenarios 1 to 3**, piece by piece (section 3).
- **Any building can start ruined** in a baseline, and repairing a ruin is **cheaper than building new**.
- Scenarios 1 to 3 and 10 are at the **home village**, the others are **away**: Pell asks Brenna to come, and each away scenario has its own
  place. Home bookends the campaign: she rebuilds it, leaves, and defends it at the end.
- **Pell's market** is present from scenario 2. At home it grows (peddler, stall, guild market); away it is his wagon, a smaller stall (the full
  market only in the guild's town of scenario 4).
- **Monsters arrive by category** (`story-design.md`), so the campaign also introduces the library's categories one after another: Wilderness
  (1, 2), with sea monsters (crabs in 4, octopus and leviathan in 9), Renegades (3, 4), Arcane (the siren in 4, witches and gargoyles in 5), the
  Dread Legion (first patrol in 5), Undead (6, with the first necromancers, an Evil kind) and Evil (vampires from 8). The Dread Legion is
  Rhodri's organised army; it leads scenarios 10 and 11 and every other category joins it there.

## 2. Overview and arc

| # | Name | Where | Map | Hero revives | Objective |
|---|---|---|---|---|---|
| 1 | Homecoming | Home (ruined) | Temperate | Yes | Rebuild, grow the economy, survive; no villager may die |
| 2 | The Old Friend | Home | Temperate | Yes | Survive, keep Pell's stall, trade |
| 3 | The Wardline | Home | Temperate | Yes | Restore the ruined towers |
| 4 | The Split | The guild's trading town | Coast | No | Hold until the convoy leaves |
| 5 | The Betrayal | Brenna's old fort | Highlands | No | Find the evidence, hold the fort |
| 6 | The Dead | A battlefield village | Desert | No | Bury the dead |
| 7 | The Exile | Fiona's refuge | Temperate | No | Hold the refuge |
| 8 | The Pale Court | The capital's outskirts | Volcanic | No | Clear the crypts |
| 9 | The Drowned Abbey | A drowned abbey on a shore | Coast | No | Retrieve the First King's Hand, slay the leviathan |
| 10 | The Last Wardline | Home | Temperate | No | Survive the Legion |
| 11 | The Crown | The capital | Capital city (a new zone) | No | Defeat Rhodri, survive the last wave |

Hero level and starting units are part of each baseline: the hero starts low in scenario 1 and rises steadily to a high level in the last, and
the units match. Whether a scenario's units are unlocked from the start or must be found on the map is decided per scenario.

The arc, one scenario at a time:

1. **Homecoming:** Brenna walks home to a half-burned village and her father Einar. Teaches care for villagers and the economy, with weak
   Wilderness enemies and archers only; Pell appears on the road at the end.
2. **The Old Friend:** Pell comes with his wares and the player places his stall. Teaches trade, the hero's exploring and the barracks; the old
   king's dead and his children's quarrel are named for the first time.
3. **The Wardline:** claim and restore the border's ruined towers and light the road between them. Teaches specialising and training, brings the
   first Renegades and the first evidence of the wider war; at the end Brenna leaves home for good.
4. **The Split:** the guild's coast town, torn by a rival guild; Brenna cannot be revived any more. Holding a warehouse against thieves and the
   sea is the test, and the first foreign coins point at spies behind Rhodri.
5. **The Betrayal:** the old fort in the only pass of a mountain range. Three pieces of evidence and a siege tell how her company was given to
   the crown's ritual, and why she alone was spared; here Brenna stops being neutral.
6. **The Dead:** a battlefield where the unburied are raised. The gatherers' job turns grim (carry the fallen to the graveyard) and the acolyte's
   holy damage becomes the answer to the Undead.
7. **The Exile:** Fiona's refuge, where trust unlocks the player's commands in steps and the druids take no orders. Opens the apprentice and the
   summoner, and shows Fiona as the one who can stand against her brother.
8. **The Pale Court:** no army and no recruiting, only Brenna's band, clearing three crypts of the court's Evil. Introduces vampires and the
   Legion's organised kinds; Lothar's offer is a choice.
9. **The Drowned Abbey:** a harbour village, a sealed abbey on an island and a relic the Legion also wants. The one scenario with a story
   branch (the priest rescued or drowned), with the sea monsters as bosses.
10. **The Last Wardline:** home at its strongest, no revive, the Legion down every road. Brenna holds the border with everything the campaign
    gave her, and her old company is the enemy she wants to free.
11. **The Crown:** the capital, with Rhodri and Lothar in the last wave. The campaign ends open, with the curse on Fiona.

## 3. The tutorial inside scenarios 1 to 3

The steps of the standalone tutorial (`tutorial-design.md`) are spread over the first three scenarios. The cards and highlights are reused; a
step ends when the player has done the thing. The tutorial's *Let's go* button and its end step are replaced by the scenario's cutscenes.

| Scenario | Tutorial steps | New lessons the scenario adds |
|---|---|---|
| 1 | welcome, watchtower, builders, archer on a tower, farm and food, call the first wave, gatherer, unit levels (archers) | walking to the village, repairing ruins (huts first, then gates and wall towers), the food rate and starvation, why no villager may die |
| 2 | hero explores (claims the broken watchtower), hero levels, barracks and shield bearer, tower upgrades | trade through Pell |
| 3 | none from the old list | specialising a unit, training grounds and the hero's Train mode, claiming ruined towers (the objective) |

Waves wait for the player while a step needs it, as in the tutorial (the first wave of scenario 1 starts when called, and corpses don't rot
until the gatherer step is done). When a scenario's steps are over the normal countdown runs. The standalone tutorial stays: the scenarios cover
all its steps, so it could be retired if the user decides, but it is also the short way in for someone who skips the campaign.

## 4. Open questions

- Whether the tutorial cards can be switched off when a scenario is replayed (proposed: yes).
- Whether the cutscenes can be watched again (title screen, library).
- The druids (7): whether they come back later, and whether a grove can be found in a normal game.
- Who the guilds' foreign coins and seals belonged to, and who the "goldsmith" was: left unsettled by design, listed so nobody settles it by
  accident.
- Whether the rival guild hires Renegades (also open in `story-design.md`).
- What happens after the open ending (the curse on Fiona, the Legion, the kingdom).

Decided since the first outline, so no longer open: bandits are not a Renegade kind (thieves only); the Dread Legion's camps, ranks and
captains are built (`enemies-design.md`, the scenario files); water monsters appear wherever the water lets them reach a village, not only on
Coast maps (`aquatic-design.md`); the title screen's *Tutorial* button starts the standalone tutorial, not scenario 1.
