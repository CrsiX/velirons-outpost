# Scenarios design

Status: **planned, nothing of it is built yet.** This page outlines the campaign: ten scenarios that tell the story in `story-design.md` (read that first; names, places and the cause of the war are explained there). Everything here is a draft. Numbers marked *target* are starting points to tune, and when built they go into `config.gd` like every other tunable. *Open* means not decided.

## 1. Structure

- The campaign is **ten scenarios played in order**. Each one has its own scripted baseline (map, village, units, resources, hero level, what is unlocked). **Nothing carries over** between scenarios, so any scenario can be replayed alone. Only the story carries over.
- Every scenario has an **intro cutscene** (at the start) and an **outro cutscene** (when the objective is fulfilled). Between them the game plays as usual, with the story told through the library, treasures, the event log and a few scripted events.
- The hero is **Brenna Hale**. Her being downed is a **defeat** in every scenario except 1 to 3 (home, she revives as in the normal game). Scenario 9 is at home but has no revive.
- Scenarios 1 to 3 and 9 are at the **home village**, the others are **away**: Pell asks Brenna to come with him, and each away scenario has its own place. Home bookends the campaign: she rebuilds it, leaves, and defends it at the end.
- **Pell's market** is present from scenario 2 on. At home it grows (peddler, stall, guild market, see `story-design.md` section 6). Away it is his wagon, a smaller stall (in the guild's town of scenario 4 it is the full market).
- **Monsters arrive by category** (`story-design.md` section 5), so the campaign also introduces the library's categories one after another: Wilderness (1, 2), Renegades (3, 4), Arcane (5, *open*), Undead (6), Evil (8). Scenarios 9 and 10 use all of them.

## 2. Overview

| # | Name | Where | Map (*target*) | Hero revives | New monsters | New units unlocked | Objective |
|---|---|---|---|---|---|---|---|
| 1 | Homecoming | Home | Highlands | Yes | Wilderness | none | Survive N waves |
| 2 | The Old Friend | Home | Highlands | Yes | none new | none | Survive N waves, trade |
| 3 | The Wardline | Home | Highlands | Yes | Renegades | none | Restore the ruined towers |
| 4 | The Split | The guild's trading town | Coast | No | more Renegades | none | Hold until the convoy leaves |
| 5 | The Betrayal | Brenna's old fort | Highlands | No | Arcane (*open*) | none | Find the evidence, hold the fort |
| 6 | The Dead | A battlefield village | Desert | No | Undead, the first necromancers | Acolyte (chapel) | Bury the dead |
| 7 | The Exile | Fiona's refuge | Temperate | No | none new | Apprentice (mage's tower), Summoner (stone circle) | Hold the refuge |
| 8 | The Pale Court | The capital's outskirts | Volcanic | No | Evil | none | Clear the crypts |
| 9 | The Last Wardline | Home | Highlands | No | all | none | Survive the host |
| 10 | The Crown | The capital | Volcanic | No | all | none | End Rhodri |

Hero level and the units the village starts with are part of each baseline (*target*: the hero from level 1 in scenario 1, rising by about two levels per scenario to about 16 in the last; units match). Whether a scenario's units are unlocked from the start, or must be found on the map as in the normal game, is stated per scenario.

## 3. Scenarios

### 1. Homecoming

**Where:** the home village, a small, ruined outpost. If the tutorial is merged (*open*, see section 4) this is the tutorial's fixed Highlands map.

**Starting point:** about half of the nine huts stand, the rest are ruins to rebuild. A builder and a forester with their camp, a little food, gold and material, no military units, nothing unlocked. Brenna starts in a destroyed hut, level 1.

**Objective:** survive *N* waves (*target* 5). Rebuilding the huts is optional but the village is only safe with them (the huts set the population).

**Monsters:** Wilderness: goblins, an ork from wave 3, then rats and slimes.

**Problems:** very little material and one builder, so every hut and tower is a choice. Wave 1 comes soon. The farm and camp are all the economy.

**Events:**
- Before the player takes control, a raid has just hit the village.
- The first corpses arrive and the gatherer role is introduced.
- Wave 3's ork is the first thing the village cannot just ignore.

**Story covered:** who Brenna is (a royal knight who came home), that the kingdom is in trouble and that this village is remote. The war is a rumour at most.

**Intro cutscene:** Brenna wakes in a destroyed hut at dawn, the sound of the raid just gone. She walks out and looks over what is left: burned huts, the broken wall tower, the few villagers. No dialogue about the war.

**Outro cutscene:** the last wave dies. A figure with a cart is on the road, lantern lit. Brenna says his name: **Pell**.

### 2. The Old Friend

**Where:** the home village again, now in a scripted state a few weeks later.

**Starting point:** most huts rebuilt, a farm, a camp, two towers with units (an archer unlocked), a barracks (*target*, so the player has done the basics). Pell arrives with his cart at the start. Hero level 2.

**Objective:** survive *N* waves (*target* 6) while keeping Pell's stall running. *Secondary:* buy something from him (a first use of trade).

**Monsters:** Wilderness: goblins, orks, rats, slimes.

**Problems:** food is short (more mouths with Pell's party), so farms matter. Rats go for the farms and the stall's goods. The player learns to spend gold on material through Pell.

**Events:**
- Pell sets up as a peddler. After a few waves he gets a stall (small trade).
- Wave 4's rat pack tests the farm defence.
- A scout from a rival guild turns up asking questions (flavour, foreshadows scenario 4).

**Story covered:** Pell and Brenna are old friends. The world outside: the old king is dead and his two children fought over the crown (Fiona and Rhodri are named for the first time). The merchant guild split. The border towers stand empty.

**Intro cutscene:** the reunion at the gate. Pell is tired and thinner than she remembers. They do not talk about what happened, only that she was not at the capital.

**Outro cutscene:** Pell tells Brenna what he needs: the road to the border town is cut where the Wardline's towers used to stand. If she helps him restore it, his guild can bring caravans.

### 3. The Wardline

**Where:** the home village and the road toward the border, all on one map.

**Starting point:** the village at a stable baseline (all huts, a barracks, several towers, a market stall). A few ruined watchtowers lie along the road. Hero level 4.

**Objective:** claim and restore *N* ruined watchtowers (*target* 3) along the road. The hero claims them in Explore mode, a builder restores each for half a watchtower's cost.

**Monsters:** Wilderness, and the first **Renegades**: thieves (and a new *bandit* later: *open*).

**Problems:** the towers lie outside the walls, so builders and the hero are exposed. Fog hides the road. Thieves steal the gold the market brings in. Material is tight because each restoration competes with the village's own upgrades.

**Events:**
- The first Renegades appear on the road in wave 3.
- Each restored tower logs a line and unlocks a journal fragment.
- The third tower holds the garrison's logbook. Its last entry is an order to abandon the post, signed in both claimants' names. Brenna recognises her old captain's handwriting.

**Story covered:** what the Wardline was and why it failed (knights recalled for the war). Where the Renegades come from (deserters of those garrisons). The first piece of evidence about the wider war.

**Intro cutscene:** Brenna and Pell walk the road and find the first ruined tower. Pell explains the Wardline as the kingdom's border; Brenna served on it once.

**Outro cutscene:** the road is open, the first guild caravan comes through. Word arrives from the border town: the guild's store there is under pressure from rival guilds. Brenna leaves home with Pell and the village stays behind. A message states the new rule: from here on, no one can bring her back.

### 4. The Split

**Where:** a guild trading town on the coast. A walled market town with warehouses and a harbour.

**Starting point:** a village of guild staff (several huts, a guild house, a warehouse). A small garrison (a few archers and a shield bearer), little gold. The full guild market is here. Brenna arrives with a few units, level about 5. **No revive.**

**Objective:** hold the town for *N* waves (*target* 8) until the neutral guild's convoy is loaded and leaves. The **warehouse** must survive (*open*: a defeat if it falls).

**Monsters:** Wilderness and **Renegades** in numbers: thieves, and possibly bandits hired by a rival guild (*open*).

**Problems:** two threats. Raids from the wilderness and Renegades on the roads, and a rival guild whose caravans block the south road and whose hired fighters raid the warehouse. Thieves go for the stock. The town is small and cannot grow far. Brenna is exposed and cannot be revived.

**Events:**
- At wave 4 a rival guild's master offers Brenna gold to leave (flavour).
- At wave 6 a captured Renegade carries coins of a foreign mint.
- The convoy loads in the last waves and the player must hold until it leaves.

**Story covered:** how the guild broke apart (each master picked a heir, or tried to stay out). The first hard evidence that **spies from the neighbouring countries** funded Rhodri's side: coins and a ledger from three different mints (Karmere, Lyrenne, Aurelith). The story does not say whose they were.

**Intro cutscene:** the harbour, one half of it closed off by a rival guild's chains. Pell shows Brenna his old guild house.

**Outro cutscene:** the convoy leaves. Pell reads the ledger with Brenna: payments to a quartermaster of Rhodri's army, from three sources. "Someone bought him." Brenna decides to go to the fort where she served and find out why her company was left behind.

### 5. The Betrayal

**Where:** Brenna's old fort, a hold in a mountain pass on the inner Wardline. Two walls stand and the rest is ruin.

**Starting point:** a ruined fortress with a few survivors (a veteran knight as flavour). A small barracks. Shield bearers and archers unlocked. The market is Pell's wagon. Hero level about 6. **No revive.**

**Objective:** find **three pieces of evidence** around the pass (treasures, some guarded by monster camps) *and* hold the fort for *N* waves (*target* 8).

**Monsters:** Wilderness, Renegades and the first **Arcane** (*open*: witches, gargoyles).

**Problems:** the evidence lies far away, so the hero must leave the fort, with no revive. Monster camps guard the farthest pieces (the hero attacks one only on the player's order). The fort is hard to expand because of the terrain.

**Events:**
- The veteran tells the story over the first waves, in pieces.
- The three finds: Rhodri's written order for the garrison, the roll of the fallen (her company), and a seal that matches a letter from one of the neighbouring courts (an object that does not settle whose).
- At the last wave the gargoyles of the fort's old gate come alive.

**Story covered:** how Brenna was **betrayed**. Rhodri ordered the pass held with no relief, so that her company would die there. She saw a ritual in which the deaths fed something in his keeping, and left to warn someone. She was thought dead. Her comrades were not buried, and the first trace of what the foreign gift is: it needed deaths.

**Intro cutscene:** Brenna sees the fort again for the first time since she left. The gate, the barracks, the field where the company stood.

**Outro cutscene:** she reads the order aloud: *"Hold until the last. Do not ask for relief."* Pell says nothing. Brenna says the dead of this pass were never buried, and the next place to go is the field where the armies met.

### 6. The Dead

**Where:** a village on a battlefield, on dry open land where nothing decays quickly. Gravediggers, a priest, and a ruined chapel.

**Starting point:** a small village of survivors (huts, grave diggers who work as gatherers, a priest). The chapel is a **ruined chapel** that unlocks the **acolyte**. Pell's wagon. Hero level about 8. **No revive.**

**Objective:** **bury N corpses** (*target*): gather the fallen before they can be raised. Awakening the chapel is part of it.

**Monsters:** **Undead** (skeletons), the first **necromancers** (from the middle waves), Wilderness leftovers.

**Problems:** every corpse is a threat because necromancers raise them, so the gatherers must go out into danger. Food is poor on this land. The acolyte's holy damage is the answer to the Undead, but the player must find and unlock it first.

**Events:**
- At the start the priest asks for help and says the chapel is not dead, only sleeping.
- Wave 3 brings the first necromancer.
- The chapel awakens when the hero visits it, and the acolyte becomes available.

**Story covered:** the war's scale. The unburied dead are why the Undead rise. These were Fiona's soldiers, who fell here, and Rhodri's. The church tried to bury them and could not. Why the dead rising is not Rhodri's will alone: he feeds on the war, but everyone's dead rise.

**Intro cutscene:** an open plain of bones under a pale sky. The priest, alone, digging a grave.

**Outro cutscene:** the last grave is filled. The priest tells Brenna that Fiona's court and the church went east, to a valley where the druids keep their distance from the war. He gives her a token that will get her through.

### 7. The Exile

**Where:** Fiona's refuge, a hidden forest valley with a druids' grove (the stone circle), a mage's tower, and a few houses.

**Starting point:** a small village of refugees, a few court mages and druids, Fiona herself in one house. The **mage's tower** unlocks the **apprentice**, the **stone circle** the **summoner**. Pell's wagon. Hero level about 10. **No revive.**

**Objective:** hold the refuge for *N* waves (*target* 10) while the court mages finish a working that hides the valley from the Evil. *Open:* a defeat if Fiona's house falls.

**Monsters:** Wilderness and Undead drawn by the magic, some Renegades.

**Problems:** the refuge is magical, so the monsters keep coming. The druids will defend their grove but will not take part in the succession. Fiona does not fight. Trust: she has reason to distrust a knight of Rhodri's army.

**Events:**
- At the start Brenna and Fiona meet, with little warmth.
- At wave 5 the druids' grove is attacked, and the summoner is unlocked.
- At the end of the waves the working completes.

**Story covered:** Fiona's side. Why the old king waited (the military's distrust of a woman ruling). What the court mages and the church saw: Rhodri changed after the **envoys came**, but Fiona cannot say from where. Why the druids stayed out. A parallel: two women, both rejected by the same side.

**Intro cutscene:** Brenna and Pell come out of the trees into the valley. Fiona waits at the gate with two mages.

**Outro cutscene:** Fiona gives Brenna the old king's seal ring: only someone of House Aldmoor can end what Rhodri has become, but she cannot go yet. She must keep the mages alive until the Crown is within reach. Brenna promises to bring her there.

### 8. The Pale Court

**Where:** the outskirts of the burned capital, a ruined court district on ash land near a volcano.

**Starting point:** a camp inside a ruined district (a few huts, Pell's wagon behind a wall). The army Brenna has gathered: archers, shield bearers, mages, acolytes, summoners (all unlocked by now, a baseline). Hero level about 12. **No revive.**

**Objective:** clear **the three crypt lairs** under the court. The hero does this on the player's order, while the camp holds.

**Monsters:** **Evil**: vampires and necromancers. Undead. Gargoyles (the palace's stone guardians, *open*). Witches.

**Problems:** the lairs wake one by one (the game's existing lair rule), so the pressure rises. Vampires heal from the hits they land. Flyers need ranged units. The hero cannot be downed, so each crypt is a real risk.

**Events:**
- Courtiers of the Pale Court greet Brenna by name.
- Rhodri speaks through a herald: an offer to come back.
- At the last lair the court's champion appears (the first hint of the 25-wave mid-boss idea in the README roadmap).

**Story covered:** what Rhodri has become and what surrounds him: the courtiers who stayed are now the Evil, drawn by the death. The **crown**: the gift that corrupted him was given as a circlet or crown (*open*, proposed). The corruption is gradual and he is still partly himself.

**Intro cutscene:** the capital by night, the palace dark against a red sky. A vampire courtier bows to Brenna.

**Outro cutscene:** the throne hall's gate stands open. Rhodri's host marches out of the city, not toward the palace, but toward Brenna's home. He knows where she came from.

### 9. The Last Wardline

**Where:** the home village, at its strongest. The same map as scenarios 1 to 3.

**Starting point:** a scripted baseline of a fully built village: all huts, a barracks at level 3, many towers including the restored Wardline towers, a good economy, high-level units, Pell's guild market with caravans bringing help. Hero level about 14. **No revive.**

**Objective:** survive *N* waves (*target* 15), ending with a **mid-boss wave** (Rhodri's marshal).

**Monsters:** everything: Wilderness, Renegades, Undead, Evil, Arcane, flyers, rats on the farms, thieves.

**Problems:** enemies arrive from every road at once, the economy is stretched, and the hero is the only one who cannot be revived. Brenna cannot leave her post.

**Events:**
- At fixed waves guild caravans arrive with gold and material (because she restored the road).
- Fiona's mages send word: they are coming.
- The mid-boss wave: Rhodri's marshal leads the host.

**Story covered:** what the outpost means. The villagers' loyalty. The first time the kingdom's last line holds against its fallen. Brenna's choice to stay and defend rather than chase Rhodri.

**Intro cutscene:** Brenna and Pell on the home wall at dusk, the horizon full of torches.

**Outro cutscene:** the host breaks. The marshal, dying, hands Brenna a sealed letter from Rhodri: *"You were the only one who said no."* Fiona's message: she and the mages ride for the capital.

### 10. The Crown

**Where:** the capital's throne hall district, a ruined palace city on ash land.

**Starting point:** Brenna's and Fiona's forces together in a final camp. Fiona is present but not under the player's control. Everything unlocked. Hero level about 16. **No revive.**

**Objective:** hold the camp for *N* waves (*target* 12) while Fiona and the mages work to break the crown's hold, then **defeat Rhodri**, the final mid-boss.

**Monsters:** everything, with Rhodri's court at its strongest.

**Problems:** the last waves are the hardest, the hero cannot be revived, and Rhodri attacks in phases (*open*, with the mid-boss design).

**Events:**
- Fiona's working advances with each wave.
- Rhodri speaks to Brenna during the fight and shows what is left of him.
- At the end Rhodri, freed from the crown, can speak a last time.

**Story covered:** the end of the war and the cost of it. What becomes of the crown, of Fiona, of Rhodri and of the Wardline. The spies' origin stays unsolved (a last clue is burned or lost).

**Intro cutscene:** the throne hall, Rhodri on a throne with the crown, and a pale court around him. He smiles at Brenna.

**Outro cutscene:** the ending (*open*): the choice of the crown (crown Fiona, destroy the crown, or leave it), what happens to the Wardline, a last scene between Brenna and Pell. May branch by the choice.

## 4. Open questions

- Does scenario 1 double as the tutorial? Proposed: yes, with the tutorial cards switchable on or off (on for the first play, off for replays).
- Each scenario's exact *N* and the other *target* numbers.
- Hero level and the units per baseline.
- Whether warehouse (4) and Fiona's house (7) are defeat conditions.
- Whether bandits are a new Renegade kind, and whether the rival guild hires Renegades.
- The Arcane category and where witches and gargoyles first appear (5 or 8).
- What the gift was (proposed: a circlet or crown) and who the guilds' foreign coins and seals belonged to (never settled).
- The mid-boss design: Rhodri's marshal (9), the court champion (8), Rhodri (10).
- The ending cutscene and whether it branches.
- The three baseline home states (1, 2, 3) versus the home state of 9.

## 5. What the engine needs

The game has none of this yet, except where noted:

- **A scenario system:** a list of scenarios, a menu, a scripted baseline per scenario (map type and seed, starting village, units, resources, hero level, unlocks), a way to start one, and objectives with a win and an outro. The tutorial already shows scripted waves, a fixed map and cards (`tutorial-design.md`), which is the closest existing piece.
- **Objectives:** survive N waves, restore ruined towers, find treasures, bury corpses, clear lairs, defeat a boss. Several map onto existing mechanics (waves, ruined towers, treasures, gatherers, lairs).
- **Scripted events:** things that happen at a given wave or moment.
- **Cutscenes:** the format is *open* (`story-design.md` section 8).
- **A per-scenario "hero revives" setting** and a "fail if the hero is downed" check.
- **Pell's market** and **mid-bosses**, both on the README's roadmap.
- **Scenario text:** library lore, journal fragments, log lines.
