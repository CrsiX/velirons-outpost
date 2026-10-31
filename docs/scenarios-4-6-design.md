# Scenarios 4 to 6: The Split, The Betrayal, The Dead

Part of the scenario design; index in scenarios-design.md. Numbers, waves, texts and tile positions live in `scripts/scenarios/scenario_<n>.gd` (the source of truth); this page gives the story and the reasons. Neighbours: `scenarios-1-3-design.md`, `scenarios-7-9-design.md`, `scenarios-10-11-design.md`; the generic system is `scenario-system-design.md`. All cutscene dialogue is marked for human review and is not copied here.

In all three, Brenna is away from home: **no revive** (`hero_revives` false), so the hero leaving the village is a real risk.

## Scenario 4: The Split

**Story and intent.** A walled guild market town on the coast: Wenna, master of the Silver Thread Guild (Pell's neutral guild), holds it with a small garrison and little gold. The scenario tells how the guild broke apart (each master picked a heir or tried to stay out) and gives the first hard evidence that **spies of the neighbouring countries** paid Rhodri's side: coins and a ledger from three mints (Karmere, Lyrenne, Aurelith). It never says whose they were. Intro: the harbour, half closed off by a rival guild's chains; Pell shows Brenna his old guild house. Outro: the convoy leaves; Pell reads the ledger (payments to a quartermaster of Rhodri's army, "someone bought him"); Brenna decides to go to the fort where she served and learn why her company was left behind.

**Why it is built this way.**
- **The objective is to hold the town until the Silver Thread convoy is loaded and leaves.** The convoy loads in the last waves, so the player must hold on through the whole scenario, not just survive a number of waves.
- **A small town that can't grow far, with a rival guild leaning on it.** In the story the rival guild's caravans block the south road and its hired fighters raid the warehouse. That is flavour for the pressure: the code sends only thieves after the warehouse. Brenna is exposed and can't be revived.
- **Two threats, two targets.** Raids from the wilderness go for the huts as always, but **thieves** go only for the guild warehouse. That gives two things to defend on one small, hard-to-grow map. The warehouse must stand (`must_stand`: defeat when it falls) and Wenna and Pell must live.
- **The warehouse is not repairable or tear-down-able.** Plundered goods are gone, so it is a depleting stake, not a building to patch.
- **The coin clue has a price.** Once the foreign coins are found the paymasters send more thieves: the reward for the clue is a harder fight, as the story says.
- **Water monsters out of the sea only** (`amphibians_from_water`): the first crabs and one siren, so the harbour is a front. They need a water body and water spawns (`aquatic-design.md`).
- **The rival master's offer is a choice and taking the gold loses.** It tests the player, and Brenna's loyalty is the story.
- **Hints:** the warehouse (tap it), guarding the harbour with a manned tower, the warehouse plundered, Brenna hurt (no revive: send her to rest).
- Map: `data/maps/guildtown.json`, a Coast map with the village on a sea inlet, started by `tools/make_scenario_map.gd -- 4` and hand-edited in the map editor since.

**What it added to the engine, and why.**
- **`Warehouse`** (campaign-only, prebuilt) with the thieves' special behaviour (`ThiefBehavior`): they take their road to where it passes nearest, cross over, plunder and run back. Tunables in `Config.WAREHOUSE`.
- **`must_stand`** on `Scenario`: kinds that must not fall.
- **`GuildMaster`**, the first resident who never leaves her hut (safe while it stands, dies with it), and `Scenario.homes` / `Hut.look` so a named villager's hut can look like a guild house.

## Scenario 5: The Betrayal

**Story and intent.** Brenna's old fort, a citadel in the only pass through the mountain range that splits the land. Whoever holds it holds the way between the halves. It stands whole and empty when Brenna and Pell arrive, which is the eerie point: nobody is there. This is where she learns she was **betrayed**. Rhodri ordered the pass held with no relief so her company could be given to the crown's ritual; she watched from the ridge, too late and alone, and the ritual did not kill them but **bound them to Rhodri**. She was spared only because her captain **Lysa**, uneasy about the order, had sent her down the pass the night before to plead for relief. She was thought dead (the roll of the fallen lists her), nobody would believe a deserter against the crown, and her company became the core of the **Dread Legion**. Lysa saved her and is bound herself, which is why Brenna will want to free them (scenario 10). Brenna stops being neutral here (`story-design.md`).

Outro: she reads Rhodri's order aloud; the only one left who can stand against him is his sister Fiona. Pell knows the court fled east, across the field where the armies met, and Brenna says the dead of this pass were never buried either, which hands over to scenario 6.

**Why it is built this way.**
- **A fort, not a village.** The terrain does the design work: two walls closing the pass, gates at a higher level than walls so it reads as a citadel (`Scenario.piece_levels`), very few huts. It is hard to expand, so the hut count is a constraint. Only Brenna and Pell come: Pell sets up his wagon (a peddler's stall) outside the south gate, and there is no farm and no other villager, which is what makes the fort feel empty. Buildings may go inside the walls (`build_inside`) so what is torn down there makes room.
- **Enemies from both halves, camps only in the north.** North of the range is wilderness with every monster camp; south is the safer kingdom side. The evidence is therefore split: two pieces guarded in the north, one in the south, hidden and unmarked. The hero must leave the fort (no revive), and attacks a camp only on the player's order.
- **Objectives are evidence and holding the fort.** Sigmund is not evidence; he is a person.
- **Sigmund's roof.** He camps in the south because he would not sleep inside the fort. Finding him starts the waves (and wave 1 cannot be called before), and he joins as a builder (`ScenarioRunner.join_villager`). With the huts full, a builder is retired to make room; with none, the objective "Give Sigmund a roof over his head" appears until the player retires someone. The few huts become a decision, not a dead end. Merchant and residents can't retire, so Pell stays.
- **The hollow-tree lair** (the user's addition in the hand-edited map) sleeps until a late wave or until the village finds it, so exploring north is never punished before the player has seen it.
- **Evidence pages** (Journal popups over the greyed game): Rhodri's order, the roll of the fallen (one ink, one day, Brenna among them, no grave marked), and a foreign seal that matches a letter from a neighbouring court and, again, does not settle whose.
- **Sigmund tells the story in pieces over several waves** (Lysa's plea, Rhodri's crown, the company kneeling and standing up bound, no bodies). When a captain falls back, Brenna says they are alive and she will free them.
- **First Arcane enemies** (witches, gargoyles). In the last wave the first **Dread Legion** patrol comes down the pass with the named captains Lysa and Torben on horses, added to the running wave, while gargoyles wake on the rocks above the pass.
- Map: `data/maps/old_fort.json`, laid out by `tools/citadel_map.gd`, hand-edited since. What code ties to it (`SIGMUND_TENT`, prebuilt offsets, evidence by treasure tier, scenario_bot's layout checks) and how to edit it: `.claude/rules/scenarios-and-maps.md` and the `edit-handmade-map` skill.

**What it added to the engine, and why.**
- **The Dread Legion** (`Config.ENEMIES`, `"campaign": true`: only where a scenario sends them). A fallen Legion soldier is **released** (`"release"`: pale colour warms, a breath rises, no corpse), so every kill reads as freeing a person, not killing a monster. Kinds: footman, captain.
- **Captains never die** (`CaptainBehavior`, `Enemy.retreating`): below a share of their HP they fall back off the map, untargetable, because the story needs Lysa and Torben later (scenarios 9 and 10).
- **Named enemies** (`Enemy.set_identity`: a queue entry's `name` and `art`).
- **Adding to a running wave** (`ScenarioRunner.add_enemies`, `Waves.add_to_wave`), plus `spawn_near` and `keep_in_sight` helpers, so a scripted arrival counts for the wave in progress.
- **Join and home helpers:** `join_villager` for Sigmund.

## Scenario 6: The Dead

**Story and intent.** A village of survivors on a battlefield on dry open land where nothing decays quickly: the plain where the armies met. The war's scale: the unburied dead are why the Undead rise. They are Fiona's soldiers and mages and Rhodri's soldiers; the church tried to bury them and could not. The dead rising is not Rhodri's will alone: he feeds on the war, but everyone's dead rise. The priest **Anselm** asks for help and says the chapel is not dead, only sleeping. Intro: a plain of bones under a pale sky, the priest alone, digging a grave. Outro: the last grave is filled; Anselm tells Brenna that Fiona's court and the church went east to a valley where the druids keep their distance from the war, and gives her a token (a priest's word for a knight of Rhodri's army: it gets her in, but not trusted).

**Why it is built this way.**
- **Every corpse is a standing threat, not a timer.** The fallen are corpses that never rot and are never cleared after a wave; a necromancer raises one as a skeleton. The scenario is **won by burying enough** before too many rise, and **lost once too few remain** to reach the goal, so "too many have risen" has a clear moment instead of a slow grind. The waves repeat until enough are buried.
- **Gatherers go out into danger.** They carry the fallen, one per trip, to the **graveyard** by the chapel; enemy corpses still go home for gold. There are no gatherers at the start: the player recruits them. A hint points at recruiting one only if none was ever recruited after wave 2 and a hut is free, so the player is not told until the need is real.
- **The fallen lie in clusters within reach of the roads**, where necromancers pass, spread as far apart as the land allows, with their places uncovered at the start so the player sees the task.
- **The chapel answers the Undead.** Brenna wakes it by going there (Explore); the acolyte's holy damage is the counter, but the player must find and unlock it first. Only a level 1 archer and a level 1 shield bearer to start; Pell's wagon.
- **Poor food** on dry land, and army upkeep off for now (`army_upkeep` 0 in `scenario_6.gd`).
- **Undead waves** with necromancers from the third wave, Wilderness leftovers and a few thieves and witches. Pell and Anselm must not die.
- **Anselm stays home but walks rounds** (chapel, graveyard, home) once the intro is over; in the outro he, Brenna and Pell walk to the graveyard as actors (the real three hidden, talking on the way) and he plants a cross over the last grave (`grave_cross`).
- Map: `data/maps/battlefield.json` (Desert), the ruined chapel by the east road a little from the gate.

**What it added to the engine, and why.**
- **The fallen** (`Corpse.fallen`, `Corpses.spawn_fallen`): own look (Fiona's blue, Rhodri's crimson), kind `skeleton` so raising works unchanged.
- **The graveyard** (`Graveyard`, campaign-only, prebuilt, can't be torn down): while one stands, gatherers and the hero gathering fetch the fallen and bury them for no pay (`GatherJob` `TO_GRAVE`, `BURYING`). Without it nobody fetches them. Tunables in `Config.FALLEN`.
- **Residents** (`Resident`, `"stays_home"`): generalise the guild master to villagers who never leave their hut, with optional **rounds** (`Resident.rounds`). Roles `priest` and `princess`, neither recruitable.
- **Unlock sites in a scenario** (`Scenario.sites`, `Scenario.unlocked`, and `"near_site"` to put a prebuilt building beside a map site): shared with scenario 7.
