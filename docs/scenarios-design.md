# Scenarios design

Status: **planned, nothing of it is built yet.** This page outlines the campaign: ten scenarios that tell the story in `story-design.md` (read
that first; names, places and the cause of the war are explained there). Everything here is a draft. Numbers marked *target* are starting points
to tune, and when built they go into `config.gd` like every other tunable. *Open* means not decided.

## 1. Structure

- The campaign is **ten scenarios played in order**. Each one has its own scripted baseline (map, village, units, resources, hero level, what is
  unlocked). **Nothing carries over** between scenarios, so any scenario can be replayed alone. Only the story carries over.
- Every scenario has an **intro cutscene** (at the start) and an **outro cutscene** (when the objective is fulfilled). Between them the game plays
  as usual, with the story told through the library, treasures, the event log and a few scripted events.
- The hero is **Brenna Hale**. Her being downed is a **defeat** in every scenario except 1 to 3 (home, she revives as in the normal game).
  Scenario 9 is at home but has no revive.
- Scenario 1 has a rule of its own: it is also a **defeat if any villager dies**. No other scenario has it.
- The **tutorial is merged into scenarios 1 to 3**, piece by piece (section 4).
- **Any building can start ruined** in a baseline: huts, walls, gates, wall towers, farms, camps, towers. Repairing a ruin is **cheaper than
  building new**.
- Scenarios 1 to 3 and 9 are at the **home village**, the others are **away**: Pell asks Brenna to come with him, and each away scenario has its
  own place. Home bookends the campaign: she rebuilds it, leaves, and defends it at the end.
- **Pell's market** is present from scenario 2 on. At home it grows (peddler, stall, guild market, see `story-design.md` section 6). Away it is
  his wagon, a smaller stall (in the guild's town of scenario 4 it is the full market).
- **Monsters arrive by category** (`story-design.md` section 5), so the campaign also introduces the library's categories one after another:
  Wilderness (1, 2), with its sea monsters (4), Renegades (3, 4), the Fallen Host (first patrol in 5), Arcane (5, *open*), Undead (6), Evil (8).
The Fallen Host is Rhodri's organised army (`story-design.md` section 5) and leads scenarios 9 and 10. All the others join it there.

## 2. Overview

| # | Name | Where | Map (*target*) | Hero revives | New monsters | New units unlocked | Objective |
|---|---|---|---|---|---|---|---|
| 1 | Homecoming | Home (ruined) | Highlands | Yes | Wilderness, weaker | Archers can be hired, no specialising | Rebuild, grow the economy, survive 5 waves; no villager may die |
| 2 | The Old Friend | Home | Highlands | Yes | none new | Barracks, shield bearer | Survive N waves, trade |
| 3 | The Wardline | Home | Highlands | Yes | Renegades | Specialisations, training grounds | Restore the ruined towers |
| 4 | The Split | The guild's trading town | Coast | No | more Renegades, giant crabs, at most one siren (Arcane) | none | Hold until the convoy leaves |
| 5 | The Betrayal | Brenna's old fort | Highlands | No | Arcane (*open*), a Fallen Host patrol | none | Find the evidence, hold the fort |
| 6 | The Dead | A battlefield village | Desert | No | Undead, the first necromancers | Acolyte (chapel) | Bury the dead |
| 7 | The Exile | Fiona's refuge | Temperate | No | none new | Apprentice (mage's tower), Summoner (stone circle) | Hold the refuge |
| 8 | The Pale Court | The capital's outskirts | Volcanic | No | Evil, Fallen Host camps | none | Clear the crypts |
| 9 | The Last Wardline | Home | Highlands | No | all, led by the Fallen Host | none | Survive the host |
| 10 | The Crown | The capital | Volcanic | No | all, the Fallen Host in force | none | End Rhodri |

Hero level and the units the village starts with are part of each baseline (*target*: the hero from level 1 in scenario 1, rising by about two
levels per scenario to about 16 in the last; units match). Whether a scenario's units are unlocked from the start, or must be found on the map as
in the normal game, is stated per scenario.

## 3. Scenarios

### 1. Homecoming

**Where:** the home village and its surroundings, a ruined outpost. Brenna starts **outside** it. The map is the old tutorial's fixed Highlands
map (*target*, section 4).

**Starting point:**
- **Brenna** (level 1) wakes in a destroyed hut **outside the village**. Step one is that she goes to the village: a short scripted walk after the
  intro cutscene (the player has no command to move her).
- **The village:** its walls, gates and wall towers are almost all destroyed. Only **4 of the 9 huts** stand, the rest are ruins. **One broken
  watchtower** lies outside, somewhere on a road (a ruined watchtower in the game's sense, with a use in scenario 2). Whether the farm and the
  camp start damaged is *open*.
- **Villagers:** one builder, one farmer and one forester. The forester is **Brenna's father, the village's lumberjack** (name *open*). He greets
  her when she reaches the village.
- **Resources:** little food, gold and material (*target*, tune in `config.gd`), enough for a first archer and the first repairs.
- **Units:** the player can hire **archers** from the start. They can be levelled up but **not specialised** yet. No barracks and no training
  grounds. New watchtowers can be built.

**Objective:** *rebuild and survive.* All of these (*targets*):
- survive **5 waves**;
- have the village rebuilt: every hut, gate and wall tower repaired (how much of the walls: *open*);
- bring up the economy: food not falling, more villagers than at the start.

Defeat is the usual (no villagers, or no intact huts) **and also if any villager dies**. That last rule is for this scenario only.

**Rebuilding:** any building can be ruined, so any one may need repairs: huts, walls, gates, wall towers, the farm, the camp, towers. A repair is
**cheaper than building new** (a ruined watchtower already costs half). Building new watchtowers is allowed. The builder works through the repairs
in the order the player chooses.

**Monsters:** Wilderness, kept **weaker on purpose** (an enemy strength setting for this scenario, below Easy: *target*). Wave 1 is goblins,
**rats come from wave 2**, **orks from wave 3**, **slimes in the last wave** (wave 5). The scenario overrides the normal wave mix.

**Problems:**
- One builder, one farmer, one forester: every repair competes with food and gold. Gold comes only from kills and corpses.
- The village is open: enemies walk through the broken walls, and a gate only holds them for a while. The player decides what to repair first and
  where the first tower goes.
- **No villager may die.** An enemy that reaches villagers or burns a hut kills one, so the enemies must be stopped before they get in. Starvation
  kills one every 15 s at 0 food, so the farm comes early. Outside the walls the builder, farmer and forester can be hurt, so the player must
  watch the roads.
- Rats bite villagers at the farm (a little), so the farm needs cover.

**How hard it is:** *easy-ish to play through, harsh if done wrong.* The scenario should teach at once: **care for your villagers, care for the
economy.**
- *Easy side:* weak enemies, wave 1 waits for the player, the first waves are small, and a tower with an archer is enough early. A player who
  builds a tower, an archer and a farm and keeps the villagers home during waves wins without trouble.
- *Harsh side:* a death ends the run. The ways to lose are the lessons: food at 0 starves a villager; a builder or farmer left outside during a
  wave is hurt; an open gate lets rats and goblins reach people; spending all gold on one thing leaves nothing for the next repair.
- *Teaching the lesson:* the first time food is falling, a villager is hurt or someone is outside while enemies are near, a card or log line says
  so ("Your farmer is in danger: villagers flee home when they see an enemy; keep them near"). The existing food-shortage warning is used. A
  defeat is quick to retry, and its screen names the cause ("Pell's farmer starved", "a goblin killed the builder").

**Events:**
- Arrival: Brenna's father greets her (a short scene or scripted event: *open*).
- Wave 1 waits until the player calls it, so a tower and an archer come first (as in the old tutorial). After that waves follow on the normal
  countdown.
- Wave 2: the first rats. Wave 3: the first ork. Wave 5: slimes, a last test.

**Story covered:** who Brenna is (a royal knight who came home to a half-burned village) and her father. The kingdom is in trouble and this
village is remote. The war is a rumour, no more.

**Intro cutscene:** Brenna wakes in small tent outside the village, on the road she came by. She walks out and sees the village in the distance:
broken walls, smoke.

**Outro cutscene:** the last wave dies. A figure with a cart is on the road, lantern lit. Brenna says his name: **Pell**. He replies to greet his
old friend.

### 2. The Old Friend

**Where:** the home village again, now in a scripted state a few weeks later.

**Starting point:** the village repaired (huts, walls, gates, wall towers), a farm, a camp, two towers with archers, **no barracks yet**. The
broken watchtower from scenario 1 still lies outside. Pell arrives with his cart at the start. He will then ask where he can set up a stall,
player needs to put a place. Hero level 2. Specialisations are still locked.

**Objective:** survive *7* waves while keeping Pell's stall running. Pell must not die. *Secondary:* buy something from him (a first use of trade).

**Tutorial pieces:** setting a building (the stall), the hero (exploring, which claims the broken watchtower, and levelling up), the barracks with
a shield bearer, tower upgrades, and trade through Pell.

**Monsters:** Wilderness: goblins, orks, rats, slimes.

**Problems:** food is short (more mouths with Pell's party), so farms matter. Rats go for the farms and the stall's goods. The player learns to
spend gold on material through Pell.

**Events:**
- Pell arrives as a peddler and wants to set up a stall. Completing to build it will start the wave 1 countdown.
- Wave 4's rat pack tests the farm defence.
- A scout from a rival guild turns up asking questions (flavour, foreshadows scenario 4).

**Story covered:** Pell and Brenna are old friends. The world outside: the old king is dead and his two children fought over the crown (Fiona and
Rhodri are named for the first time). The merchant guild split. The border towers stand empty.

**Intro cutscene:** the reunion at the gate. Pell is tired and thinner than she remembers. They do not talk about what happened, only that she was
not at the capital.

**Outro cutscene:** Pell tells Brenna what he needs: the road to the border town is cut where the Wardline's towers used to stand. If she helps
him restore it, his guild can bring caravans.

### 3. The Wardline

**Where:** the home village and the road toward the border, all on one map. same map as scenario 1 and 2, but larger with more details available.

**Starting point:** the village at a stable baseline (all huts, a barracks, several towers, a market stall). No training grounds yet. A few ruined
watchtowers lie along the road. Hero level about 4. **Specialisations are unlocked** (from unit level 3).

**Objective:** claim, restore and station 4 ruined watchtowers and one barracks along the roads. The hero claims them in Explore mode, a builder
restores each for half a watchtower's cost. build light stations to light up all the ways between the restored watch towers. survive the waves
while doing so.

**Tutorial pieces:** specialising a unit (the archer's branches), the training grounds with the hero's Train mode, and the ruined towers themselves.

**Monsters:** Wilderness, and the first **Renegades**: thieves (and a new *bandit* later: *open*).

**Problems:** the towers lie outside the walls, so builders and the hero are exposed. Fog hides the road. Thieves steal the gold the market brings
in. Material is tight because each restoration competes with the village's own upgrades.

**Events:**
- The first Renegades appear on the road in wave 3.
- Each restored tower logs a line and unlocks a journal fragment. It also hints that lightstones are necessary between them.
- The barracks holds the garrison's logbook. Its last entry is an order to abandon the post, signed in both claimants' names. Brenna recognises
  her old captain's handwriting.

**Story covered:** what the Wardline was and why it failed (knights recalled for the war). Where the Renegades come from (deserters of those
garrisons). The first piece of evidence about the wider war.

**Intro cutscene:** Brenna and Pell walk the road and find the first ruined tower. Pell explains the Wardline as the kingdom's border; Brenna
served on it once.

**Outro cutscene:** the road is open, the first guild caravan comes through. Word arrives from the border town: the guild's store there is under
pressure from rival guilds. Brenna leaves home with Pell and the village stays behind. A message states the new rule: from here on, no one can
bring her back.

### 4. The Split

**Where:** a guild trading town on the coast. A walled market town with warehouses and a harbour.

**Starting point:** a village of guild staff (several huts, a guild house, a warehouse), one of which is the guild master (named NPC), living in
the guild house. A small garrison (a few archers and a shield bearer), little gold. The full guild market is here. Brenna arrives with a few
units, level about 5. **No revive.**

**Objective:** hold the town for 9 waves until the neutral guild's convoy is loaded and leaves. The **warehouse** must survive (defeat if it
falls). The guild master must not die. Brenna must not die. Pell must not die.

**Monsters:** Wilderness and **Renegades** in numbers: thieves, and possibly bandits hired by a rival guild (*open*). The harbour adds the first
**crabs** (Wilderness, aquatic) and, at most, **one siren** (Arcane, used sparingly): they come up the river and the coast. They need water
routes, which the game does not have yet (section 6).

**Problems:** two threats. Raids from the wilderness and Renegades on the roads, and a rival guild whose caravans block the south road and whose
hired fighters raid the warehouse. Thieves go for the stock. The town is small and cannot grow far. Brenna is exposed and cannot be revived.

**Events:**
- At wave 4 a rival guild's master offers Brenna gold to leave (flavour). If accepted, instant loss of the scenario.
- At wave 6 a captured Renegade carries coins of a foreign mint.
- The convoy loads in the last waves and the player must hold until it leaves.

**Story covered:** how the guild broke apart (each master picked a heir, or tried to stay out). The first hard evidence that **spies from the
neighbouring countries** funded Rhodri's side: coins and a ledger from three different mints (Karmere, Lyrenne, Aurelith). The story does not say
whose they were.

**Intro cutscene:** the harbour, one half of it closed off by a rival guild's chains. Pell shows Brenna his old guild house.

**Outro cutscene:** the convoy leaves. Pell reads the ledger with Brenna: payments to a quartermaster of Rhodri's army, from three sources.
"Someone bought him." Brenna decides to go to the fort where she served and find out why her company was left behind.

### 5. The Betrayal

**Where:** Brenna's old fort, a hold in a mountain pass on the inner Wardline. Two walls stand and the rest is ruin.

**Starting point:** a ruined fortress with a few survivors (a named veteran warrior as flavour). A small barracks. Shield bearers and archers
unlocked.
The market is Pell's wagon. Hero level about 7. **No revive.**

**Objective:** find **three pieces of evidence** around the pass (treasures, some guarded by monster camps) *and* hold the fort for 10 waves.
Neither Brenna nor Pell may die.

**Monsters:** Wilderness, Renegades and the first **Arcane** (*open*: witches, gargoyles). In the last wave the first **Fallen Host** patrol
arrives: Rhodri's soldiers, sent to finish what the pass began. Brenna knows their armour.

**Problems:** the evidence lies far away, so the hero must leave the fort, with no revive. Monster camps guard the farthest pieces (the hero
attacks one only on the player's order). The fort is hard to expand because of the terrain.

**Events:**
- The veteran tells the story over the first waves, in pieces.
- The three finds: Rhodri's written order for the garrison, the roll of the fallen (Brenna's company), and a seal that matches a letter from one
  of the
  neighbouring courts (an object that does not settle whose).
- At the last wave the gargoyles of the fort's old gate come alive, fly out and then attack.

**Story covered:** how Brenna was **betrayed**. Rhodri ordered the pass held with no relief, so that her company would die there. She saw a ritual
in which the deaths fed something in his keeping, and left to warn someone. She was thought dead. Her comrades were not buried, and the first
trace of what the foreign gift is: it needed deaths.

**Intro cutscene:** Brenna sees the fort again for the first time since she left. The gate, the barracks, the field where the company stood.

**Outro cutscene:** she reads the order aloud: *"Hold until the last. Do not ask for relief."* Pell says nothing. Brenna says the dead of this
pass were never buried, and the next place to go is the field where the armies met.

### 6. The Dead

**Where:** a village on a battlefield, on dry open land where nothing decays quickly. Gravediggers, a priest, and a ruined chapel.

**Starting point:** a small village of survivors (huts, grave diggers who work as gatherers, a priest). The chapel is a **ruined chapel** that
unlocks the **acolyte**. Pell's wagon. Hero level about 9. **No revive.**

**Objective:** **bury N pre-existing corpses** (*target*): gather the fallen before they can be raised. Awakening the chapel is part of it.
The waves continue until enough corpses are buried.

**Monsters:** **Undead** (skeletons), the first **necromancers** (from the middle waves), Wilderness leftovers. Some rare thieves and bandits and
a few witches.

**Problems:** every corpse is a threat because necromancers raise them, so the gatherers must go out into danger. Food is poor on this land. The
acolyte's holy damage is the answer to the Undead, but the player must find and unlock it first.

**Events:**
- At the start the priest asks for help and says the chapel is not dead, only sleeping.
- Wave 3 brings the first necromancer.
- The chapel awakens when the hero visits it, and the acolyte becomes available.

**Story covered:** the war's scale. The unburied dead are why the Undead rise. These were Fiona's soldiers and mages, who fell here, and Rhodri's.
The
church tried to bury them and could not. Why the dead rising is not Rhodri's will alone: he feeds on the war, but everyone's dead rise.

**Intro cutscene:** an open plain of bones under a pale sky. The priest, alone, digging a grave.

**Outro cutscene:** the last grave is filled. The priest tells Brenna that Fiona's court and the church went east, to a valley where the druids
keep their distance from the war. He gives her a token that will get her through.

### 7. The Exile

**Where:** Fiona's refuge, a hidden forest valley with a druids' grove (the stone circle), a mage's tower, and a few houses.

**Starting point:** a small village of refugees, a few court mages and druids, Fiona herself in one house. The **mage's tower** unlocks the
**apprentice**, the **stone circle** the **summoner**. Pell's wagon. Hero level about 11. **No revive.**

**Objective:** earn the trust of Fiona. hold the refuge for 12 waves while the court mages finish a working that hides the valley from the Evil.
If Fiona's house falls, scenario is lost. Pell and Brenna must not die. Fiona must not die. During wave 5, no druids may die.

**Monsters:** Wilderness and Undead drawn by the magic, some Renegades, a few witches.

**Problems:** the refuge is magical, so the monsters keep coming. The druids will defend their grove but will not take part in the succession.
Fiona does not fight. Trust: she has reason to distrust a knight of Rhodri's army. she rejects Brenna and wants her to earn trust first.
The player can not build anything while Fiona rejects Brenna and villagers can not be commanded. Existing buildings can be used, military can
be hired.

**Events:**
- At the start Brenna and Fiona meet, with little warmth. Fiona does not want Brenna in the refuge, thus Brenna starts the scenario
a bit outside in a tent.
- After wave 2 completes, Fiona opens up a little. Villagers can be commanded and recruited. Buildings may be repaired and/or rebuilt
but no new buildings may be constructed.
- At wave 5 the druids' grove is attacked, and the summoner is unlocked. The druids call for help. During this wave, no druid must die.
- After wave 7 completes, Fiona has opened up enough that she permits the player to build new buildings. She will introduce a few more story parts.
- At the end of the waves the working completes.

**Story covered:** Fiona's side. Why the old king waited (the military's distrust of a woman ruling). What the court mages and the church saw:
Rhodri changed after the **envoys came**, but Fiona cannot say from where. Why the druids stayed out. A parallel: two women, both rejected by the
same side.

**Intro cutscene:** Brenna and Pell come out of the trees into the valley. Fiona waits at the gate with two mages.

**Outro cutscene:** Fiona gives Brenna a sealed scroll and asks her to deliver it to the court mages. She explains, only someone of House Aldmoor
can end what Rhodri has become, but she cannot go yet, and they need more allies and more strength. She must keep the mages alive until the Crown
is within reach. Brenna promises to bring her there when the time is right.

### 8. The Pale Court

**Where:** the outskirts of the burned capital, a ruined court district on ash land near a volcano.

**Starting point:** a camp inside a ruined district (a few huts, Pell's wagon behind a wall). The army Brenna has gathered: archers, shield
bearers, mages, acolytes, summoners (all unlocked by now, a baseline). Hero level about 13. **No revive.**

**Objective:** clear **the three crypt lairs** under the court. The hero does this on the player's order, while the camp holds.

**Monsters:** **Evil**: vampires and necromancers. Undead. Gargoyles (the palace's stone guardians). Witches. The **Fallen Host** holds the
court's gates in camps of soldiers, captains and banner-bearers (*open*).

**Problems:** the lairs wake one by one (the game's existing lair rule), so the pressure rises. Vampires heal from the hits they land. Flyers need
ranged units. The hero cannot be downed, so each crypt is a real risk.

**Events:**
- Courtiers of the Pale Court greet Brenna by name.
- Rhodri speaks through a herald: an offer to come back.
- At the last lair the court's champion appears (the first hint of the 25-wave mid-boss idea in the README roadmap).

**Story covered:** what Rhodri has become and what surrounds him: the courtiers who stayed are now the Evil, drawn by the death. The **crown**:
the gift that corrupted him was given as a circlet or crown (*open*, proposed). The corruption is gradual and he is still partly himself.

**Intro cutscene:** the capital by night, the palace dark against a red sky. A vampire courtier bows to Brenna.

**Outro cutscene:** the throne hall's gate stands open. Rhodri's host marches out of the city, not toward the palace, but toward Brenna's home. He
knows where she came from.

### 9. The Last Wardline

**Where:** the home village, at its strongest. The same map as scenarios 1 to 3.

**Starting point:** a scripted baseline of a fully built village: all huts, a barracks at level 3, many towers including the restored Wardline
towers, a good economy, high-level units, Pell's guild market with caravans bringing help. Hero level about 16. **No revive.**

**Objective:** survive *N* waves (*target* 15), ending with a **mid-boss wave** (Rhodri's marshal).

**Monsters:** everything: Wilderness, Renegades, Undead, Evil, Arcane, flyers, rats on the farms, thieves. The core of the host is the **Fallen
Host**: Rhodri's soldiers, in ranks, with captains and banner-bearers, marching in on the home village by every road.

**Problems:** enemies arrive from every road at once, the economy is stretched, and the hero is the only one who cannot be revived. Brenna cannot
leave her post.

**Events:**
- At fixed waves guild caravans arrive with gold and material (because she restored the road).
- Fiona's mages send word: they are coming.
- The mid-boss wave: Rhodri's marshal leads the host.

**Story covered:** what the outpost means. The villagers' loyalty. The first time the kingdom's last line holds against its fallen. Brenna's
choice to stay and defend rather than chase Rhodri.

**Intro cutscene:** Brenna and Pell on the home wall at dusk, the horizon full of torches.

**Outro cutscene:** the host breaks. The marshal, dying, hands Brenna a sealed letter from Rhodri: *"You were the only one who said no."* Fiona's
message: she and the mages ride for the capital.

### 10. The Crown

**Where:** the capital's throne hall district, a ruined palace city on ash land.

**Starting point:** Brenna's and Fiona's forces together in a final camp. Fiona is present but not under the player's control. Everything
unlocked. Hero level about 18. **No revive.**

**Objective:** hold the camp for *N* waves (*target* 12) while Fiona and the mages work to break the crown's hold, then **defeat Rhodri**, the
final boss.

**Monsters:** everything, with Rhodri's court at its strongest and the **Fallen Host** at full strength, the army of the final struggle.

**Problems:** the last waves are the hardest, the hero cannot be revived, and Rhodri attacks in phases (*open*, with the mid-boss design).

**Events:**
- Fiona's working advances with each wave.
- Rhodri speaks to Brenna during the fight and shows what is left of him.
- At the end Rhodri, freed from the crown, can speak a last time.

**Story covered:** the end of the war and the cost of it. What becomes of the crown, of Fiona, of Rhodri and of the Wardline. The spies' origin
stays unsolved (a last clue is burned or lost).

**Intro cutscene:** the throne hall, Rhodri on a throne with the crown, and a pale court around him. He smiles at Brenna.

**Outro cutscene:** the ending (*open*): the choice of the crown (crown Fiona, destroy the crown, or leave it), what happens to the Wardline, a
last scene between Brenna and Pell. May branch by the choice.

## 4. The tutorial inside scenarios 1 to 3

The 13 steps of the current tutorial (`tutorial-design.md` section 3.3) are spread over the first three scenarios. The cards and highlights are
reused; a step ends when the player has done the thing. The *Let's go* button and the card's end step are replaced by the scenario's cutscenes.

| Scenario | Tutorial steps | New lessons that scenario adds |
|---|---|---|
| 1 | 1 welcome, 2 watchtower, 3 builders, 4 archer on a tower, 5 farm and food, 6 call the first wave, 7 gatherer, 11 unit levels (archers) | Walking to the village, repairing ruins (huts first, then gates and wall towers), the food rate and starvation, why no villager may die |
| 2 | 8 hero explores (claims the broken watchtower), 9 hero levels, 10 barracks and shield bearer, 12 tower upgrades | Trade through Pell |
| 3 | none from the old list | Specialising a unit, training grounds and the hero's Train mode, claiming ruined towers (the objective) |

Waves wait for the player while a step needs it, as in the tutorial (the first wave of scenario 1 starts when called, and corpses don't rot until
the gatherer step is done). When the scenario's steps are over the normal countdown runs.

## 5. Open questions

- Whether the tutorial cards can be switched off for replays (proposed: yes) and what the title screen's *Tutorial* button does (proposed: it
  starts scenario 1).
- Scenario 1's numbers: starting resources, enemy strength, repair cost share, economy goal, how much wall must be repaired, whether the farm and
  camp start damaged.
- Brenna's father's name, and whether he returns later (scenario 9, for example).
- Each other scenario's exact *N* and *target* numbers.
- Hero level and the units per baseline.
- Whether the warehouse (4) and Fiona's house (7) are defeat conditions.
- Whether bandits are a new Renegade kind, and whether the rival guild hires Renegades.
- The Fallen Host: unit kinds and names, how its camps, ranks and banners work (a banner-bearer could buff like the war cry), and its place in the
  mid-boss design (the marshal).
- Which other sea monsters exist (siren, giant octopus, leviathan) and where else than the Coast they appear. Scenario 4 has only giant crabs and
  one siren at most.
- The Arcane category and where witches, gargoyles and the siren first appear (5 or 8; the siren is rare and shows up once at most in 4).
- What the gift was (proposed: a circlet or crown) and who the guilds' foreign coins and seals belonged to (never settled).
- The mid-boss design: Rhodri's marshal (9), the court champion (8), Rhodri (10).
- The ending cutscene and whether it branches.
- The home state of scenario 9 versus 1 to 3.

## 6. What the engine needs

The game has none of this yet, except where noted:

- **A scenario system:** a list of scenarios, a menu, a scripted baseline per scenario (map type and seed, starting village, units, resources,
  hero level, unlocks), a way to start one, and objectives with a win and an outro. The tutorial already shows scripted waves, a fixed map and
  cards (`tutorial-design.md`), which is the closest existing piece. That doc, which says "no cutscenes", has to be updated when the tutorial is
  merged.
- **Destroyable and rebuildable buildings:** today only huts (rebuilding) and watchtowers (restoring a found ruin) can be ruined. The intent is
  that **every building can be destroyed and rebuilt**, with a cheaper repair than a new building. Walls, gates, wall towers, farms and camps need
  a ruined state.
- **Breaches (a separate design task):** enemies **walk around broken walls straight into the village**, but are **held at a gate for a while**
  until the gate breaks. So walls and gates are real defences, not decoration. This replaces the rule that enemies never get in and the inside is
  always safe. How it works (pathing, how long a gate holds, who attacks what, what it means for villagers inside, the normal game) is its own
  design, to be written as a doc of its own before it is built. This outline only assumes that buildings can be broken and circumvented.
- **Water routes for sea monsters (later):** enemies only walk the roads today. Sea monsters need to travel rivers, lakes and coasts, attack from
  the water and perhaps be limited to the shore. This is later engine work and no scenario before 4 needs it.
- **Per-scenario rules:** enemy strength, a custom wave mix (which kinds from which wave), locked specialisation, "hero revives" and "fail if the
  hero is downed", and "fail if a villager dies".
- **Objectives:** survive N waves, rebuild the village, restore ruined towers, find treasures, bury corpses, clear lairs, defeat a boss. Several
  map onto existing mechanics (waves, ruined towers, treasures, gatherers, lairs).
- **Scripted events:** a scripted walk for the hero, things that happen at a given wave or moment.
- **Cutscenes:** the format is *open* (`story-design.md` section 8).
- **Pell's market** and **mid-bosses**, both on the README's roadmap.
- **Scenario text:** library lore, journal fragments, log lines.
