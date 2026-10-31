# Scenarios 1 to 3: Homecoming, The Old Friend, The Wardline

Part of the scenario design; index in `scenarios-design.md`. Siblings: `scenarios-4-6-design.md`, `scenarios-7-9-design.md`, `scenarios-10-11-design.md`; the scenario system and cutscenes: `scenario-system-design.md`.

All numbers, waves, texts and tile positions live in `scripts/scenarios/scenario_<n>.gd` (source of truth). Cutscene dialogue is not copied here. Maps are hand-edited: the rules for touching them are in `.claude/rules/scenarios-and-maps.md` and the `edit-handmade-map` skill.

Scenarios 1 to 3 also carry the old tutorial. Its steps are spread across them and the cards and highlights are reused: 1 teaches watchtower, builders, archer, farm and food, calling a wave, gatherer and unit levels (plus rebuilding and why nobody may die); 2 teaches the hero (exploring, levelling), barracks with a shield bearer, tower upgrades and trade; 3 teaches specialising, the training grounds with Train mode, and claiming ruins. The standalone tutorial (`tutorial-design.md`) stays for now, since the scenarios cover all its steps and it could be retired if the user decides.

## Scenario 1: Homecoming

**Story.** Brenna Hale, a royal knight, wakes in a small tent on the south road, having slept on the way home. She walks to a half-burned outpost and her father Einar, the village lumberjack. The kingdom is in trouble, but the village is remote and the war is only a rumour. The outro ends on a figure with a lit lantern and a cart on the road: Pell, her old friend. The intro sets the scene from the road, with the village far off, broken and smoking.

**Intent: easy-ish to play, harsh if done wrong.** It must teach at once: care for your villagers, care for the economy. The easy side is deliberate. Enemies are weaker than Easy (`Settings.enemy_scale`), wave 1 waits until the player calls it (so tower and archer come first, as in the old tutorial), and the first waves are small. The harsh side is that any villager's death is a defeat. Every way to lose is a lesson:
- Starvation kills a villager when food stays at 0, so the farm comes early.
- A builder, farmer or forester left outside during a wave is hurt, so watch the roads.
- The village is open (broken walls, gates only hold a while), so enemies must be stopped before they reach people or burn a hut.
- Rats bite at the farm, so it needs cover.
- Spending all gold on one thing leaves nothing for the next repair.

A defeat is quick to retry and its screen names the cause. One-time hints fire at the moment the lesson applies (a villager fleeing, hurt, food falling, enemies inside the walls).

**Why it is built this way.**
- Start: one builder, one farmer, one forester (Einar). Little resource, enough for a first archer and the first repairs. Gold comes only from kills and corpses, so repairs, food and gold compete.
- Units: archers only, levelling allowed, no specialising, no barracks or training grounds. The first scenario stays a tower-and-archer lesson.
- Brenna starts outside, and the player has no command to move her, so a scripted walk after the intro takes her home. She takes no orders meanwhile.
- Repairs cost less than new buildings, and the player picks the order. The rebuilt state (every hut, gate, wall and wall tower, more villagers than at the start, food not falling) is the objective; how much of the walls is the scenario's call. Smoke over ruined huts shows what is left to do.
- The wave mix is overridden: Wilderness only, goblins first, rats from wave 2, an orc from wave 3, slimes in the last wave as a final test. Five scripted waves (`Waves.scripted`).
- One broken watchtower lies on a road. It is unused here and exists for scenario 2's claim and restore cards.
- The outro (Pell's cart on the south road) hands over to scenario 2.

**Map.** `data/maps/homecoming.json`, hand-made and deliberately small. The code is tied to it (Brenna's start and tent, the south road's end, the lake road's end for scenario 2's stranger, the single ruin); the list is in CLAUDE.md.

## Scenario 2: The Old Friend

**Story.** The same village a few weeks later, repaired. Pell has helped rebuild and now asks for a place for his wares. In the reunion he is tired and thinner than Brenna remembers, and they do not talk about what happened, only that she was not at the capital. Between waves Pell tells of the old king's death, the war, and how his two children fought over the crown (Fiona and Rhodri are named for the first time). A stranger from a rival guild asks questions (flavour that foreshadows scenario 4). Pell flies the Silver Thread's colours and the stranger calls them the Leftovers. The guild split into pieces allied with Fiona's court, Rhodri's army and each other, and only the few who stayed neutral are the Silver Thread Merchant Guild. The border towers stand empty. The outro: the road to the border town is cut where the Wardline's towers stood, and if Brenna restores it, his guild can bring caravans.

**Intent.** Teach placing a building (the stall), the hero (exploring claims the broken watchtower, levelling), a barracks with a shield bearer, tower upgrades, and trade. Pressure comes from food (more mouths with Pell's party, so farms matter), rats going for farms and the stall's goods (a scripted rat pack mid-scenario tests the farm defence), and gold turning into material through Pell.

**Why it is built this way.**
- Baseline: village repaired, farm, camp, two archer towers, no barracks, specialisations still locked. Same map as scenario 1; the ruin from scenario 1 still waits outside.
- **Pell and the stall** (`Merchant`, `Stall`, `Config.STALL_LEVELS`, `"campaign": true` in `Config.BUILDINGS`). The stall is campaign-only, buildable only where a scenario lists it. Its level is its stage (peddler, stall, guild market) and a scenario sets it (`prebuilt`), because there is no in-play upgrade. Pell lives in a hut and works the stall, and it is open and its goods refill only while he tends it. He flees enemies like any villager.
- Rats treat the stall as a farm (`Stall` extends `Farm`; its stored food is its goods), so barracks and the hero guard it as they do a farm. Farm-only rules check `kind == "farm"`, so the stall never counts as food production.
- Wave 1 cannot be called: its countdown starts once the stall stands, which makes placing it the first act.
- Pell must not die, and once the stall has stood, losing it loses the scenario. Nothing in its waves attacks buildings and rats only eat goods, so in practice only a tear-down loses it.
- Optional objectives: buy something from Pell, and the walls hold.
- The trade card waits until wave 2 is over and the open stall has goods for a lot (or something was already bought), and the stall is marked only while a lot can be bought. The player is never pointed at a closed shop.

## Scenario 3: The Wardline

**Story.** Brenna and Pell walk the road and find the first ruined tower. Pell explains the Wardline as the kingdom's border, which Brenna once served on. It failed because its knights were recalled for the war, and the Renegades (the first appear here) are deserters from those garrisons. Each restored watchtower gives up a page of its garrison's journal, six in all, in the order restored: the line falling quiet, the captain counting heads and writing down every name, what the light stones are for (rune stones the last garrison set along the road, whose glow shows what no tower sees), and that they have gone dark. After pages 2 and 4 Brenna and Pell talk. The restored barracks gives its logbook: the order to abandon the post, signed in both claimants' names, in the handwriting of Brenna's old captain, Lysa. This is the first piece of evidence about the wider war. The outro opens the road and the first guild caravan comes through. Word arrives that the guild's store in the border town is under pressure from rival guilds. Brenna leaves home with Pell, the village stays behind, and a message states the new rule: from here on no one can bring her back (the premise of scenario 4).

**Intent.** Teach specialising (the archer's branches), the training grounds with Train mode, and claiming ruins. Danger and tension: the towers lie outside the walls, so builders and the hero are exposed; fog hides the road; thieves steal the gold the market brings; material is tight because each restoration competes with the village's own upgrades. A bandit enemy kind was considered and rejected for now, so the first Renegades are thieves.

**Why it is built this way.**
- Baseline: the village at its best so far (all huts, barracks, several towers, Pell's stall; the home ruin starts restored since scenario 2 restored it). Specialisations unlocked, training grounds allowed.
- **Objective.** Claim, restore and man the ruined watchtowers and the ruined barracks along the border road. The hero claims in Explore mode and a builder restores each for half price. The road must also be lit: every road tile from the village to every ruin is watched by one of the village's buildings (`ScenarioRunner.lit`, which counts what towers and light stones see, not where people walk). The light card waits until a stretch is explored and still dark, so the dark road itself shows where a stone goes and no spot is marked.
- Waves repeat (`repeat_last`) until the objectives are met, because restoring a far line takes as long as the player takes. Thieves start in wave 3.
- **Ruined barracks.** A ruin can have been a watchtower or a barracks (`"building"` in the map file, format version 3; `RuinedTower.building()`). Claiming and restoring work the same, and no new object kind was needed.
- Hints: thieves, a monster camp found (its guards keep explorers and Brenna away, while towers and barracks in range fight them unaided), and no explorer once wave 3 is over.

**Map.** `data/maps/wardline.json`: the home map grown larger, then hand-edited. It holds the home map tile for tile in its middle, and the border road runs across the north with the ruins. Code ties (ruin count and place, journal pages, talks, the checks in `scenario_bot`) are listed in CLAUDE.md.
