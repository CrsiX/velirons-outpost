# Scenarios design

Status: **the whole campaign (scenarios 1 to 11) and the scenario system are built** (§7 says how, and what was decided for them). This
page outlines the campaign: eleven scenarios that tell the story in `story-design.md` (read that first; names, places and the cause of the war are
explained there). Everything about the scenarios not yet built is a draft. Numbers marked *target* are starting points to tune; a scenario's own
numbers and texts go into its own file (`scripts/scenarios/scenario_<n>.gd`), not into `config.gd`. *Open* means not decided.

## 1. Structure

- The campaign is **eleven scenarios played in order**. Each one has its own scripted baseline (map, village, units, resources, hero level, what is
  unlocked). **Nothing carries over** between scenarios, so any scenario can be replayed alone. Only the story carries over.
- Every scenario has an **intro cutscene** (at the start) and an **outro cutscene** (when the objective is fulfilled). The player can **skip** any
  cutscene. Between them the game plays
  as usual, with the story told through the library, treasures, the event log and a few scripted events.
- The hero is **Brenna Hale**. Her being downed is a **defeat** in every scenario except 1 to 3 (home, she revives as in the normal game).
  Scenario 10 is at home but has no revive.
- Scenario 1 has a rule of its own: it is also a **defeat if any villager dies**. No other scenario has it.
- **Pell must not die** in scenarios 4 to 11: his death fails the scenario. **Fiona's death** is always a defeat too, wherever she appears (7 and
  11), as is Brenna's where she cannot revive.
- The **tutorial is merged into scenarios 1 to 3**, piece by piece (section 4).
- **Any building can start ruined** in a baseline: huts, walls, gates, wall towers, farms, camps, towers. Repairing a ruin is **cheaper than
  building new**.
- Scenarios 1 to 3 and 10 are at the **home village**, the others are **away**: Pell asks Brenna to come with him, and each away scenario has its
  own place. Home bookends the campaign: she rebuilds it, leaves, and defends it at the end.
- **Pell's market** is present from scenario 2 on. At home it grows (peddler, stall, guild market, see `story-design.md` section 6). Away it is
  his wagon, a smaller stall (in the guild's town of scenario 4 it is the full market).
- **Monsters arrive by category** (`story-design.md` section 5), so the campaign also introduces the library's categories one after another:
  Wilderness (1, 2), with its sea monsters (crabs in 4, the octopus and the leviathan in 9), Renegades (3, 4), Arcane (the siren in 4, witches and
gargoyles in 5: *open*), the Dread Legion (first patrol in 5), Undead (6, with the first necromancers, an Evil kind) and Evil (vampires from 8).
The Dread Legion is Rhodri's organised army (`story-design.md` section 5) and leads scenarios 10 and 11. All the others join it there.

## 2. Overview

| # | Name | Where | Map (*target*) | Hero revives | New monsters | New units unlocked | Objective |
|---|---|---|---|---|---|---|---|
| 1 | Homecoming | Home (ruined) | Highlands | Yes | Wilderness, weaker | Archers can be hired, no specialising | Rebuild, grow the economy, survive 5 waves; no villager may die |
| 2 | The Old Friend | Home | Highlands | Yes | none new | Barracks, shield bearer | Survive N waves, trade |
| 3 | The Wardline | Home | Highlands | Yes | Renegades | Specialisations, training grounds | Restore the ruined towers |
| 4 | The Split | The guild's trading town | Coast | No | more Renegades, giant crabs, at most one siren (Arcane) | none | Hold until the convoy leaves |
| 5 | The Betrayal | Brenna's old fort | Highlands | No | Arcane (witches, gargoyles: *open*), a Dread Legion patrol | none | Find the evidence, hold the fort |
| 6 | The Dead | A battlefield village | Desert | No | Undead, the first necromancers (Evil) | Acolyte (chapel) | Bury the dead |
| 7 | The Exile | Fiona's refuge | Temperate | No | none new | Apprentice (mage's tower), Summoner (stone circle) | Hold the refuge |
| 8 | The Pale Court | The capital's outskirts | Volcanic | No | vampires (Evil), Dread Legion camps | none | Clear the crypts |
| 9 | The Drowned Abbey | A drowned abbey on a delta shore | Coast | No | leviathan (scripted boss), giant octopus (guard), Dread Legion forces | none | Retrieve the First King's Hand, slay the leviathan |
| 10 | The Last Wardline | Home | Highlands | No | all, led by the Dread Legion | none | Survive the Legion |
| 11 | The Crown | The capital | Capital city (new, section 6) | No | all, the Dread Legion in force | none | Defeat Rhodri, survive the last wave |

Hero level and the units the village starts with are part of each baseline (*target*: the hero from level 1 in scenario 1, rising by about two
levels per scenario to about 18 in the last; units match). Whether a scenario's units are unlocked from the start, or must be found on the map as
in the normal game, is stated per scenario.

## 3. Scenarios

### 1. Homecoming

**Where:** the home village and its surroundings, a ruined outpost. Brenna starts **outside** it. The map is the old tutorial's fixed Highlands
map (*target*, section 4).

**Starting point:**
- **Brenna** (level 1) wakes in a small tent **outside the village** (provisional: she slept on the way home). Step one is that she goes to the
  village: a short scripted walk after the
  intro cutscene (the player has no command to move her).
- **The village:** its walls, gates and wall towers are almost all destroyed. Only **4 of the 9 huts** stand, the rest are ruins. **One broken
  watchtower** lies outside, somewhere on a road (a ruined watchtower in the game's sense, with a use in scenario 2). Whether the farm and the
  camp start damaged is *open*.
- **Villagers:** one builder, one farmer and one forester. The forester is **Brenna's father, the village's lumberjack**, **Einar**. He greets
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
broken watchtower from scenario 1 still lies outside. Pell (he came at the end of scenario 1) has helped rebuild, and now asks for a place for
his wares: the player places his stall. Hero level 2. Specialisations are still locked.

**Objective:** survive *7* waves while keeping Pell's stall running: once it has stood, losing it (devastated, or torn down) loses the scenario.
Pell must not die. *Secondary:* buy something from him (a first use of trade); the walls hold (every gate, wall and wall tower standing at the
end, as at the start).

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
restores each for half a watchtower's cost. build light stones to light up all the ways between the restored watch towers. survive the waves
while doing so.

**Tutorial pieces:** specialising a unit (the archer's branches), the training grounds with the hero's Train mode, and the ruined towers themselves.

**Monsters:** Wilderness, and the first **Renegades**: thieves (and a new *bandit* later: *open*).

**Problems:** the towers lie outside the walls, so builders and the hero are exposed. Fog hides the road. Thieves steal the gold the market brings
in. Material is tight because each restoration competes with the village's own upgrades.

**Events:**
- The first Renegades appear on the road in wave 3.
- Each restored tower logs a line and unlocks a journal fragment. It also hints that light stones are necessary between them.
- The barracks holds the garrison's logbook. Its last entry is an order to abandon the post, signed in both claimants' names. Brenna recognises
  her old captain's handwriting: **Lysa**'s.

**Story covered:** what the Wardline was and why it failed (knights recalled for the war). Where the Renegades come from (deserters of those
garrisons). The first piece of evidence about the wider war.

**Intro cutscene:** Brenna and Pell walk the road and find the first ruined tower. Pell explains the Wardline as the kingdom's border; Brenna
served on it once.

**Outro cutscene:** the road is open, the first guild caravan comes through. Word arrives from the border town: the guild's store there is under
pressure from rival guilds. Brenna leaves home with Pell and the village stays behind. A message states the new rule: from here on, no one can
bring her back.

### 4. The Split

**Where:** a guild trading town on the coast. A walled market town with warehouses and a harbour.

**Starting point:** a village of guild staff (several huts, a guild house, a warehouse), one of which is the guild master **Wenna** (named NPC),
living in
the guild house. A small garrison (a few archers and a shield bearer), little gold. The full guild market is here. Brenna arrives with a few
units, level about 5. **No revive.**

**Objective:** hold the town for 9 waves until the Silver Thread Guild's convoy is loaded and leaves. The **warehouse** must survive (defeat if it
falls). The guild master, Wenna, must not die.

**Monsters:** Wilderness and **Renegades** in numbers: thieves (bandits: decided against for now, thieves only). The harbour adds the first
**crabs** (Wilderness, aquatic) and, at most, **one siren** (Arcane, used sparingly): they come up the river and the coast. Both are built
(`aquatic-design.md`): the crab is a goblin that swims, the siren a support monster whose song pulls and slows our units and whom melee cannot hit
while she is in the water. The map needs a water body big enough for them (6 deep tiles) and water spawns, made in the map editor.

**Problems:** two threats. Raids from the wilderness and Renegades on the roads, and a rival guild whose caravans block the south road and whose
hired fighters raid the warehouse. Thieves go for the stock (only they: the monsters go for the huts), more of them once the coins are found;
crabs and the siren come out of the sea only. The town is small and cannot grow far. Brenna is exposed and cannot be revived.

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

**Where:** Brenna's old fort, a citadel in the only pass through a mountain range that runs across the land from west to east and splits it
in two. Whoever holds the fort holds the way between the halves.

**Starting point:** the fort stands whole and empty: nobody is there when Brenna and Pell arrive. Two walls close the pass, one to the north and
one to the south, each from mountain to mountain with a gate in the middle and a wall tower at each end; the mountains are the fort's sides.
Inside, a road runs from gate to gate, with 4 huts, two barracks and training grounds beside it (all empty). Pell lives in one hut, the other
three are free: the fort holds very few people. Pell sets up his wagon (a peddler's stall) outside the south gate. No farm, no other villager.
Shield bearers and archers unlocked. Hero level about 7. **No revive.**

**The land:** north of the range lies forest, the wilderness: every monster camp is there. South of it lies meadow and steppe, the safer side
(the kingdom's). Roads come down to the pass from the north edge and from the west and east edges on both sides, so enemies come from both
halves. **Sigmund**, the old veteran, camps in a tent on the south side: the fort's people scattered after that night and he would not sleep
inside its walls. Found (his tent uncovered), he joins as a builder and moves into the fort, and the waves begin.

**Objective:** find **three pieces of evidence** on both sides of the range (treasures; the two in the north guarded by monster camps) *and* hold
the fort for 10 waves. Sigmund is not a piece of evidence.

**Monsters:** Wilderness, Renegades and the first **Arcane** (*open*: witches, gargoyles). In the last wave the first **Dread Legion** patrol
arrives: Rhodri's soldiers, sent to finish what the pass began. Brenna knows them: they are her old company, with **Lysa**, her captain, and her
comrade **Torben** among them.

**Problems:** the evidence lies far away, so the hero must leave the fort, with no revive. Monster camps guard the farthest pieces (the hero
attacks one only on the player's order). The fort is hard to expand because of the terrain, and its 4 huts limit the village to Pell and three
more: when Sigmund comes, one of them may have to make room for him.

**Events:**
- Sigmund is found on the south side and joins (see below); he tells the story over the first waves, in pieces.
- The three finds: Rhodri's written order for the garrison, the roll of the fallen (Brenna's company), and a seal that matches a letter from one
  of the neighbouring courts (an object that does not settle whose).
- At the last wave the gargoyles on the rocks above the pass come alive, fly out and then attack.

**Story covered:** how Brenna was **betrayed**. Rhodri ordered the pass held with no relief, so that her company could be given to the crown's
ritual. She saw it: Rhodri came to the pass himself, the crown on his head glowing pale, and the ritual did not kill them, it **bound them to
Rhodri**, taking their will (the first trace of what the crown is: `story-design.md` section 4). **Why she was not bound:** she was not in the
fort. Her captain, **Lysa**, uneasy about the order, had sent her down the pass the night before with a plea for relief; Brenna came back without
it and watched from the ridge, too late and alone. Nobody would have believed a deserter against the crown, so she went home and was thought
dead: the roll of the fallen lists the whole company, her too. They are alive, and they are the core of the **Dread Legion**. Lysa saved her and
is bound herself, which is why Brenna wants to free them (scenario 10). This is where Brenna stops being neutral (`story-design.md` section 2).

**Intro cutscene:** Brenna sees the fort again for the first time since she left: the walls, the barracks, the field where the company stood.
It is empty: no guard on the walls, nobody in the huts. Pell finds it eerie; Brenna wonders where everyone went.

**Outro cutscene:** she reads the order aloud: *"Hold until the last. Do not ask for relief."* Pell says nothing. Brenna: Rhodri gave her company
to his crown, and the only one left who can stand against him is his sister. She will find Fiona. Pell knows Fiona's court fled east; the way
there crosses the field where the armies met, and Brenna says the dead of this pass were never buried either.

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
- At the start the priest, **Anselm**, asks for help and says the chapel is not dead, only sleeping.
- Wave 3 brings the first necromancer.
- The chapel awakens when the hero visits it, and the acolyte becomes available.

**Story covered:** the war's scale. The unburied dead are why the Undead rise. These were Fiona's soldiers and mages, who fell here, and Rhodri's soldiers.
The church tried to bury them and could not. Why the dead rising is not Rhodri's will alone: he feeds on the war, but everyone's dead rise.

**Intro cutscene:** an open plain of bones under a pale sky. The priest, alone, digging a grave.

**Outro cutscene:** the last grave is filled. The priest tells Brenna that Fiona's court and the church went east, to a valley where the druids
keep their distance from the war. He gives her a token that will get her through: a priest's word for a knight of Rhodri's army, which will get
her in, but not trusted.

**Decided:** the fallen are their own corpses on the field (soldiers in Fiona's blue and Rhodri's crimson) that never rot; a necromancer raises
one as a skeleton. The gravediggers are gatherers: they carry the fallen to a **graveyard** (a new campaign building by the chapel), where each one
is buried for good; enemy corpses still go home for gold. Anselm is a villager who stays in his house (like Wenna). Built as §7.11.

### 7. The Exile

**Where:** Fiona's refuge, a hidden forest valley with a druids' grove (the stone circle), a mage's tower, and a few houses.

**Starting point:** a small village of refugees, a few court mages and druids, Fiona herself in one house. The **mage's tower** unlocks the
**apprentice**, the **stone circle** the **summoner**. Pell's wagon. Hero level about 11. **No revive.**

**Objective:** earn the trust of Fiona. hold the refuge for 12 waves while the court mages finish a working that hides the valley from the Evil.
Fiona must not die. (If her house falls, she dies by the usual rule that the villager in a lost house dies, so it is the same.) During wave 5, no
druids may die.

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
- At wave 5 the druids' grove is attacked, and the summoner is unlocked. The druids' elder calls for help, and says why the druids stayed
  out of the war (`story-design.md` section 4, the unlock sites): their pact with the first king (the druids keep the land, the crown keeps the
  border, neither meddles in the other's affairs; who wears the crown is the crown's affair), and the church on Fiona's side once drove them from
  the towns, so they owe her side nothing. They fight for their grove, not for her. During this wave, no druid must die.
- After wave 7 completes, Fiona has opened up enough that she permits the player to build new buildings. She tells Brenna, in a scene, why
  their father never named her (`story-design.md` section 4, *Why Orsin named no heir*): the law and his wish were hers, but the army would not
  follow a queen, and crowning her against it would have left her a crown and a rebellion; naming Rhodri would have broken the law, set the
  church and the mages against the crown, and put power in the hands of a son he knew was greedy for it. So he waited to win the officers over,
  told no one, and died first. Her line to end it: "He was waiting for your side to change its mind. I was his answer, and he never gave it."
- At the end of the waves the working completes.

**Story covered:** Fiona's side. Why the old king named no heir, told by Fiona after wave 7 (above): neither Fiona (the army would not follow
her) nor Rhodri (against the law, the church and the mages, and greedy) without a war, so he waited and died first. What the court mages and the church saw: Rhodri changed after the **envoys came**, but Fiona cannot
say from where. Why the druids stayed out: their elder tells it at wave 5, the druids' old pact with the first king (they keep the land, the
crown keeps the border, neither meddles in the other's affairs), and the church on Fiona's side once drove them from the towns. A parallel: two
women, both rejected by the same side, and Fiona now rejects Brenna for having served it. Brenna came because of what was done to her company:
Fiona learns that her brother's crown binds people, and that Brenna has nowhere else to go.

**Intro cutscene:** Brenna and Pell come out of the trees into the valley. Fiona waits at the gate with two mages.

**Outro cutscene:** Fiona gives Brenna a sealed scroll and asks her to deliver it to the court mages. She explains, only someone of House Aldmoor
can end what Rhodri has become, but she cannot go yet, and they need more allies and more strength. She must keep the mages alive until the Crown
is within reach. Brenna promises to bring her there when the time is right.

**Decided:** the druids are three named **druid summoners** on the benches of their **grove** (a campaign barracks by the stone circle). They
fight for it as barracks units do, but take no orders (they can't be moved, upgraded or withdrawn). During wave 5 a druid downed is a defeat; at
other times they revive as usual. The trust phases: until wave 2 is over Brenna lives at her tent outside the walls (she rests and defends from
there), and nothing can be built, repaired or rebuilt, no villager recruited, retired or assigned; units can be hired and stationed on the
existing posts. After wave 2 she may move in, and villagers, repairs and rebuilding open; after wave 7 new buildings. Built as §7.12.

### 8. The Pale Court

**Where:** the outskirts of the burned capital, a ruined court district on ash land near a volcano.

**Starting point:** a camp inside a ruined district (a few huts, Pell's wagon behind a wall). Brenna has **no army**, only a band of followers:
court mages and acolytes who came with her from Fiona's refuge, and a few archers and other volunteers (the units unlocked by now, a baseline:
archers, shield bearers, mages, acolytes, summoners). Hero level about 13. **No revive.**

**Objective:** clear **the three crypt lairs** under the court. The hero does this on the player's order, while the camp holds.

**Monsters:** **Evil**: vampires and necromancers. Undead. Gargoyles (the palace's stone guardians). Witches. The **Dread Legion** holds the
court's gates in camps of soldiers, captains and banner-bearers (*open*). Only the herald speaks.

**Problems:** the lairs wake one by one (the game's existing lair rule), so the pressure rises. Vampires heal from the hits they land. Flyers need
ranged units. The hero cannot be downed, so each crypt is a real risk.

**Events:**
- **Lothar**, a herald of the Pale Court (a human envoy, under a white flag), meets Brenna and greets her by name. He carries Rhodri's words, and
  no monster speaks. Lothar is the court's one recurring herald and **survives** until the story needs him last (scenarios 10 and 11).
- Lothar delivers Rhodri's offer: come back to his side. If Brenna accepts the offer, the scenario is lost.
- At the last lair the court's champion, **Rurik**, appears (the first hint of the 25-wave mid-boss idea in the README roadmap).

**Story covered:** what Rhodri has become and what surrounds him: **the Pale Court** (`story-design.md` section 4), his herald Lothar, marshal and
champion, the Legion at its gates, and the Evil that gathered in the crypts, drawn by the death. The **crown** (`story-design.md` section 4): the
old king's own crown, reworked by a foreign "goldsmith" and now glowing with malice. The corruption is gradual and he is still partly himself.

**Intro cutscene:** the capital by night, the palace dark against a red sky. A herald in pale colours waits on the road under a white flag and
bows to Brenna.

**Outro cutscene:** the throne hall's gate stands open. Brenna sees the crown on Rhodri's head from the doorway and understands that it is not a
gift but something that feeds on him. A church survivor says some of the church's priests hid something that may break such a thing: the **First
King's Hand**, a
relic sword, in the abbey that sank in the delta. Nobody knows whether it will. Fiona's messenger confirms it. Rhodri hears that Brenna refused
the offer to join his side and starts laughing devilish.

**Decided:** "no army" means **no recruiting**: Brenna's band (archers, shield bearers, apprentices, acolytes, a summoner) waits in the reserve
at the start (`Scenario.reserve`), and gold only levels and specialises it (`Scenario.recruiting` false). The three crypts are **monster lairs**
(crypt art) that the scenario wakes one by one (`Scenario.lairs`: the nearest at wave 1, the next at wave 4, the farthest at wave 7), with their
own guards and kinds; awake, each is one more spawn point of the scripted waves (`"lairs": true`), and a cleared one stays cleared. The hero
clears one as a camp (*Attack with the hero*). **Rurik**, the court champion, is a guard of the third crypt and a boss that can be killed (a
new Legion kind, `legion_champion`: heavy blows that cleave). The Legion gets three more kinds, all campaign-only: the **archer** (shoots our
people outside from a little less than a watchtower's range), the **guardsman** (a tower shield: half damage from arrows and bolts) and the
**banner-bearer** (Legion soldiers near its banner strike faster). Two **Legion camps** hold the court's gates (camps of Legion soldiers, each
guarding a treasure: optional). Lothar's offer is a choice after wave 3. Built as §7.14.

### 9. The Drowned Abbey

**Where:** a pilgrims' ferry village on a drowned shore, with the church's old abbey half-sunk in the delta beyond it, reached by a causeway.
Map: Coast, a river delta with an island (*target*).

**Starting point:** a small village of ferrymen and the church's last survivors (a few priests who hide out of fear of Rhodri). A short causeway
to the abbey island, water on
several sides. Pell's wagon, and his guild's boats at the quay. Her band of followers from scenario 8, a baseline: archers, shield
bearers, mages, acolytes and summoners, all unlocked. Hero level about 14. **No revive.**

**Objective:** retrieve **the relic**, the **First King's Hand**, from the abbey's flooded crypt (no number of waves to hold).
The hero goes to the abbey
on the player's order, as with a monster camp, fights what guards it (the **giant octopus**, a guard mob: see Monsters), takes the relic and
carries it home. If she is downed, it is lost
(a defeat anyway).

**Monsters:**
- **Wilderness, aquatic:** **giant crabs** from the shore, and in the last wave the
  **leviathan**, a boss-like mob that rises when the relic leaves the abbey. The leviathan is built (`aquatic-design.md`: a water-bound serpent
that blasts from the water and always comes up), but only as an ordinary wave member. Here it is a **scripted spawn**: stronger (scripted HP and
damage), spawned when the relic leaves the abbey, and the wave ends only when it is dead.
- **Evil and Undead:** necromancers raise the abbey's drowned dead (skeletons, and the drowned soldiers of an old battle) and vampires hold the
  crypt.
- **The Dread Legion:** from the middle waves a force arrives by the causeway. It has learned where the relic lies. Captains and banner-bearers,
  with no marshal yet (he leads in scenario 10).
- Wilderness leftovers (goblins, rats).
- **Guard (not a wave monster):** a **giant octopus** guards the abbey. It does not count for the waves and need not be defeated, but killing it
  first makes retrieving the sword much easier. In the parallel monster design it is **insanely strong, the strongest mob in the game** (this can
  change). It never leaves its deep water beside the abbey, and its eight arms grab whoever comes within reach and can drown them. It can drown
the hero (downed: a defeat here), so killing it first from towers by the water, or keeping out of its reach, matters. The built octopus is a wave
member from wave 20 (`aquatic-design.md`): here the scenario places it as a guard instead.

**Problems:** three fronts at once: the water, the causeway and the abbey. The hero has to leave the village with no revive, while a Legion
force is on the causeway, so the player must decide **when** to send her. Towers cover the water less well than the road. The octopus guarding the
abbey holds and kills whoever goes near, so the hero's trip is the real risk. Flyers (vampire bats, gargoyles) need ranged units. Taking the relic
wakes the leviathan, so the
last wave is the hardest.

**Events:**
- Waves 1 to 3: crabs, to teach the water side (the octopus is not part of the waves). Pell's guild boats ferry in a few supplies at fixed waves.
- At the start the priests do not trust Brenna: she is military, a knight of the army that serves Rhodri, and Fiona's word (from scenario 7)
  does not change what she wore. They hide and say nothing.
- At wave 4 the priests tell, afraid, what the abbey hides: the relic and how to reach the crypt, but not that they will give it up. They support
  Fiona but hid the sword, because they feared Rhodri could rise over her.
- At wave 6 the first Legion force arrives on the causeway. Its captain, **Lysa**, Brenna's old captain, demands the relic. Brenna recognises her
  and refuses her own old company. The priests see it.
- The hero's trip is on the player's order. The relic can be taken from wave 7 on: the priests unseal the crypt then, because the Legion at the
  causeway is the worse risk, but they still do not give the sword to Brenna.
- When the leviathan is slain, the priests agree that the sword goes to Fiona, and the scenario ends: Brenna has risked her life for their
  village, and they see the goodwill in her.
- When the relic is taken, the leviathan rises. The last wave is its attack, with the Legion's rest on the causeway at the same time.

**Story covered:** the **First King's Hand**: a ceremonial sword of the first king, who founded the Wardline, obviously a relic and not a weapon
for battle. It can "cleanse the blood" and "rule with righteousness", so the church believes it helps against Rhodri, but **nobody knows whether
it does**. Some priests hid it and sank the abbey to keep it from Rhodri. Only someone of House Aldmoor can wield it (Fiona's line from scenario
7). The Legion's
captain hunts the sword while the main force marches home. This is not the church's stance (the church supports Fiona) but that of the priests of
this place: they support Fiona, but feared Rhodri could rise over her. They distrust Brenna because she is military, from the side that serves
Rhodri, and they give up the sword only once the leviathan is slain: not because of the kill, but because they have seen her defend their
village and refuse her own company for it. Earning their trust is the scenario's thread, as Fiona's was in 7.

**Intro cutscene:** Brenna and Pell arrive by ferry in mist. The abbey's spires stand out of the water, and a bell rings under it.

**Outro cutscene:** the leviathan sinks. The priests come out of hiding; the eldest says they took her for one of Rhodri's, and were wrong. They
agree that the sword goes to Fiona. The relic glows in Brenna's hands.
**Lysa**, the Legion's captain, dying, says the force at the abbey was
only
meant to hold her here: the main force of the Legion, led by the marshal Halvard, is already marching on her **home village**. She turns to Pell:
they must go back.

**Decided:** Lysa does not die: beaten on the causeway (a captain, she falls back), she is herself for a moment in the outro and warns Brenna,
then the binding pulls her away (scenario 10 stays as planned). The abbey is a treasure on its island (`abbey`, campaign-only), held by a
camp of vampires; the priests keep it **sealed** until wave 6 is over (`Treasure.sealed`); then the hero clears the camp on the player's order
and loots the relic in Explore mode, and carries it home. The **octopus** is a guard (`Enemy.post`: it keeps to the deep water near its post
and doesn't count for the waves), stronger than a wave one. Taking the relic raises the **leviathan** at once (a boss: several times the HP,
harder blasts, counted for the wave; between waves the next wave starts with it), and the Legion's rest comes by the causeway with it. The
objectives: bring the relic home, slay the leviathan (no number of waves to hold: the waves go on until both are done). Built as §7.15.

#### 9a. The rework (built: §7.15)

Replaces the story, the map and most rules above; built as §7.15. Numbers marked *(tune)* are first guesses.

**Why the rework:** in the built version Brenna fights the leviathan after she already has the relic, with no reason in the story; the
priests' trust comes only from holding the walls; the Legion marches on the village although it wants the relic. Now every fight is about
the relic, the trust is won or lost in one rescue, and the leviathan stands between Brenna and the sword.

**The map (new, replaces `drowned_abbey.json`):** a shore village by the sea, shaped differently from the standard 5x5 block, with a small
**harbour** (piers, boats, nets, crates, a ferry bell), a broad sandy shore with a few sandbanks off it, reached through shallow water. Inside the walls stands a **new church**, bigger and newer than the drowned abbey (a
campaign building with its own art; the priests' house of worship, and where the relic is kept once it is home). The abbey's island lies in
the middle of a **broad river** (3 to 5 tiles of water, meandering a little) that runs from the north edge down to the sea beside the
harbour, so the octopus and the leviathan can move between them. The island can be reached **only from the village's side**, over one
**straight** bridge (no bends on bridges or fords). The far bank is joined to the rest by one road with a bridge north of the island,
winding round the mountains in the far north-east from the map edge there; enemies may come that way too. The Legion comes down a road from the north edge
on the village's side, so towers by the village can fight it on its way to the island. Made with the map tool first, then edited by hand in
the editor (from then on only targeted edits to the file).

**The people:** Pell (must not die), the eldest priest (unnamed) and the other priests. The priests are no longer hidden: they walk their
rounds outside, between their homes, the new church and the harbour (`Resident.rounds`, as scenario 6's priest).

**Pell's boats:** the guild's supply boats become real: after waves 2, 5 and 8 a boat sails into the harbour and ties up at the pier. Its goods
are unloaded into a **caravan** (a cart, as `ScenarioCaravan`) that walks over land from the pier to Pell's stall, drops the goods there and is
gone. The goods go to the village's stores; the floating "+gold +food +material" shows at the stall. (Today only the numbers appear.)

**The seal and the relic:** the abbey's crypt is **sealed** at the start. The seal has HP (a bar, like the warehouse's in scenario 4). The relic
can be in four places: in the crypt, carried (by Brenna or by Lysa), lying on the ground, or **home** (in the new church, inside the walls).

**The octopus rescue (after wave 4):** between waves 4 and 5 a priest (not the eldest) walks down to the harbour. The guard octopus leaves the
abbey and grabs him. He has far more HP than a villager and is **held in shallow water for about 20 s** *(tune)* before he is pulled into deep
water and drowns. A countdown shows over him and on the card. Cutting the arm (towers, ranged units, Brenna) frees him; in this scenario
towers and units go for an arm holding one of ours before anything else, the octopus itself included. Freed, he runs back to the
church; only there is he rescued. Caught again on the way, he is dragged into the shallows again with a new 20 s. Afterwards the octopus
goes back to guard the abbey (and is in Brenna's way when she crosses). This decides the branch:

- **Rescued:** the eldest comes to the gate and tells what the abbey hides (the Hand; why they hid it; vampires in the crypt; something bigger
  in the deep).
- **Drowned:** the priests shut Brenna out. She can't enter the village at all, not even a gate (up to the gate is as far as she goes,
  to hand the relic in): a tent goes up outside the walls, as in scenario 1, and it is her home (`Scenario.hero_lives_out` / `Hero.home_override`, as in scenario 7: she heals and rests there). Only Brenna is shut out: the village
  works normally and the player gives every order as before. The priests say nothing.

**The Legion goes for the relic, not for the huts.** A Legion column with Lysa at its head goes wherever the relic is: to the abbey's seal while
it is sealed in the crypt, to the relic on the ground, or into the village to the new church once it is home (breaking in like any enemy:
`Siege`). Its soldiers go on fighting what is in their way. The rest of a wave (monsters) goes for the huts as usual. The column **marches as a
company**: its soldiers keep together in a loose formation round Lysa (ranks a little apart, keeping pace with one another), not strung out
one by one along the road as monsters are; it should look like an army on the march.

- **Rescued branch:** only **wave 6** brings a Legion column. Lysa demands the relic; Brenna refuses her own captain. If the column is beaten,
  the priests unseal the crypt. Waves 7 and 8 have no Legion.
- **Drowned branch:** **waves 6, 7 and 8** each bring a Legion column, stronger each time *(tune)*. If the relic is home by then, holding the
  village against them is the point (the church is inside the walls). After wave 8 the priests give in: they have seen her hold off her own
  company three times. In this order: first they **let her back in** (a talk: they trust her again, a little; the tent is gone, the village
  is her home again); then, **if the crypt is still sealed**, they unseal it; **or, if they hold the relic** (handed in at the gate), they give
  it to her. (The last two exclude each other: a relic they hold has left the crypt.)

**Lysa and the relic:**
- When the **seal breaks**, the leviathan wakes (see below) and Lysa **searches the crypt** for the relic: **8 s** (as long as Brenna's
  looting). She ignores the leviathan. Then she walks back to the map edge with her soldiers around her.
- Lysa takes the relic from anywhere. In the crypt and in the church she has to search for it (**8 s** each); lying on the ground she **picks
  it up at once**. While she lives and is still fighting (not falling back), a relic lying on the ground draws her.
- **If Lysa reaches the map edge with the relic, the scenario is lost.**
- Beaten (a captain: below 30 % HP), she **drops the relic where she stands** and falls back without it; while falling back she picks
  nothing up. Her soldiers stay around the relic and fight on, so taking it back is hard: towers and barracks within reach of the island pay off.
- **Brenna** picks up a relic on the ground in Explore mode (like dropped loot) and carries it home. She drops it wherever she is when she is
  switched out of Explore mode (as any loot today). Downed while carrying it: lost anyway (no revive here).
- **Drowned branch:** Brenna is shut out, so she brings a relic to the **gate** and it is handed in there; then she goes back to her tent. The
  priests hold it in the church, but it is not hers: she must still earn their trust (the three Legion waves) before they give it to her.

**The leviathan:** it sleeps until the crypt is **first used**: Brenna entering the opened crypt, or the Legion breaking the seal.
- Woken by **Brenna** (rescued branch, or the drowned branch after wave 8): it rises as she reaches the crypt and drives her off the island; it
  coils round the island and blocks the crypt's door, so **the relic can't be taken while it lives**. No Legion comes with it (in the rescued
  branch the Legion is done after wave 6); only the normal waves go on. Once it is slain, Brenna goes back, takes the relic (8 s) and carries
  it home.
- Woken by **the Legion breaking the seal**: Lysa takes the relic anyway and flees; the leviathan is awake but need not be slain to get the
  relic home.
- While it lives it has **several goals** and moves between them through the deep water that joins the lake to the sea (the boats are at
  the harbour, far from the crypt):
  - **guard the crypt** while the relic is still in it: it keeps near the island, and Brenna can't get in;
  - **sink Pell's boats**: when a boat comes in it goes for it, and the boat and its goods are lost, so no supplies come while it lives;
  - **attack whatever is near the water**: it surfaces along the shore and blasts towers, units and people in its reach, as a wave
    leviathan does.
  So it can't be ignored for long.

**Winning:** the relic home (and, in the drowned branch, given to Brenna) **and** the leviathan slain. The waves keep coming until then (the
last listed wave repeats, bigger each time); there is no wave count to hold.
- Relic home, leviathan already dead: won.
- Relic home, leviathan alive: the priests ask Brenna to kill it, to make their home safe. **A choice:**
  - **Yes:** the objective *Slay the leviathan* appears; slaying it wins.
  - **No:** a cutscene: a priest sends out a messenger. Hold one more wave; then a cutscene: the messenger comes back with a decree signed by
    Fiona, urgently asking Brenna to slay the leviathan. The objective appears; slaying it wins.
  The choice is flavour: both ways end the same.

**Defeats:** Pell dies; Brenna is downed (no revive); Lysa reaches the map edge with the relic. The priest drowning is no defeat: it is the
drowned branch.

**Objectives (shown as they come):** rescue the priest (with its countdown); defend the abbey from the Legion; get the relic back from Lysa (while
she has it); slay the leviathan (when it blocks the crypt, or after the priests' request or Fiona's decree); bring the relic home. Hints and
cards say at every turn what changed.

**How it plays, in order:**
1. Waves 1 to 4: crabs, goblins, the drowned dead; the watchtower by the shore starts wave 1's countdown (as built). The priests walk their
   rounds.
2. After wave 4: the octopus grabs a priest at the harbour; about 20 s to cut him free.
3. **Rescued:** the priests tell. Wave 6: the Legion goes for the seal; Lysa demands the relic. Beaten: the crypt is unsealed; waves 7 and 8
   bring no Legion. **Drowned:** Brenna lives in her tent, the priests say nothing; waves 6, 7 and 8 bring the Legion for the relic, wherever
   it is; after wave 8 the priests give in and let her back in.
4. If the seal breaks at any point: the leviathan wakes, Lysa takes the relic and flees; beat her before she reaches the edge, then take the
   relic back from among her soldiers.
5. If Brenna opens the crypt: the leviathan wakes and drives her off; slay it, then take the relic.
6. With the relic home: won if the leviathan is dead; otherwise the priests' request (yes, or no and Fiona's decree), then slay it.

**Outro:** as today in spirit: the priests come out of the new church; the eldest says they were wrong about her; the Hand goes to Fiona; on
the causeway Lysa is herself for a moment and warns Brenna that Halvard marches on her home; Brenna and Pell go back. The lines depend on the
branch (the rescue, or the tent and the three waves).

### 10. The Last Wardline

**Where:** the home village, at its strongest. The same map as scenarios 1 to 3.

**Starting point:** a scripted baseline of a fully built village: all huts, a barracks at level 3, many towers including the restored Wardline
towers, a good economy, high-level units, Pell's guild market with caravans bringing help. Hero level about 16. **No revive.**

**Objective:** survive 16 waves, ending with a **mid-boss wave** (Rhodri's marshal, **Halvard**).

**Monsters:** everything: Wilderness, Renegades, Undead, Evil, Arcane, flyers, rats on the farms, thieves. The core of the attack is the **Dread
Legion**: Rhodri's soldiers, in ranks, with captains and banner-bearers, marching in on the home village by every road.

**Problems:** enemies arrive from every road at once, the economy is stretched, and the hero is the only one who cannot be revived. Brenna cannot
leave her post.

**Events:**
- At fixed waves guild caravans arrive with gold and material (because she restored the road), but only while there are no monsters on that road.
- Brenna's father **Einar** is at the home village, as a villager. In passing he greets her cheerfully, as if nothing were wrong ("Ah, my girl,
  how goes it?"), and she answers that an attack is coming: "Father, the Legion is coming. Get everyone inside!" He is only a small, warm beat
before the fight, a gimmick: whether he survives does not matter and is not tracked.
- Fiona's mages send word: they are coming. Fiona is not present at the home village (on her way to the capital, or preparing something: not said).
- Before the Legion's first wave Lothar rides up under a white flag and demands her surrender once more. One wave later, they arrive and three mages
  get added to the military stock of the player.
- The mid-boss wave at the end: Rhodri's marshal, Halvard, leads the legion.

**Story covered:** the villagers' loyalty: the village sided with no one in scenario 1; now it stands with **Fiona**, as Brenna does, and the
Legion comes because of it. The restored Wardline, built to keep the wilderness out, now has to hold against the kingdom's own bound soldiers.
Brenna's choice to stay and defend rather than chase Rhodri.

**Intro cutscene:** Brenna and Pell on the home wall at dusk, the horizon full of torches. Brenna tells Pell who is out there: **Lysa**, her
captain, and **Torben**, a comrade of her company. "I will free them."

**Outro cutscene:** the legion stopped, only corpses remained. The marshal, dying, holds Brenna's hand: "Thank you." A messenger from Fiona
arrives: she, the priests and the mages ride for the capital.


**Decided:** the home map grown for scenario 3 (`wardline.json`), with every Wardline ruin standing restored and manned at the start (a
prebuilt post can be a restored ruin: `"ruin"`). Sixteen waves; the Legion comes from wave 4 on, by every road. Lothar's demand after wave 3 is a
choice again (surrendering loses). Fiona's word comes after wave 2, and Idris brings her three mages after wave 4 (a fire, an ice and a healing
mage, into the reserve: `ScenarioRunner.give_units`). Torben leads wave 8 and Lysa wave 12 (captains: they fall back); wave 16 is Halvard's,
with both of them. **Halvard** is a **commander** (a new Legion kind, `legion_marshal`, `CommanderBehavior`): Legion soldiers near him strike
faster and take less damage (his command aura), and every so often he **rallies** fresh footmen down the roads while he lives; he can be killed.
**Guild caravans** (`ScenarioRunner.caravan`: a cart along a road, which halts while an enemy is near it and pays its cargo at the gate) set out
down the Wardline road at waves 3, 6, 9, 12 and 15. Einar is the named forester; whether he lives is not tracked. Built as §7.17.
### 11. The Crown

**Where:** the capital's throne hall district: a **city**, with cobblestone streets and ruined and standing buildings, next to the throne hall.
The vegetation is basically gone: no grass (replaced by ashen land), only a few steppe spots where trees grow and can be cut down. So **no
farms**. The scenery is drastically different from the existing map types (section 6).

**Starting point:** Brenna's and Fiona's forces together in a final camp. Fiona is present but not under the player's control (her death is a
defeat). Pell has his stall in the camp, and caravans bring food now and then. Everything unlocked. Hero level about 18. **No revive.**

**Objective:** hold the camp for *N* waves (*target* 12). In the **last wave Rhodri comes out** and the player **defeats** him: his HP stops at 0
as a *down*, he is not killed, and he flees into the throne hall. When the wave ends, the **victory sound** plays and the campaign is complete,
then the ending cutscene runs.

**Monsters:** everything, with Rhodri's court at its strongest and the **Dread Legion** at full strength, the army of the final struggle. In the
last wave **Rhodri** comes out as a **captain-like melee unit with commanding abilities** (the captain's exact behaviour is not defined yet; his
HP, damage and so on are scripted for this scenario).

**Problems:** the last waves are the hardest, the hero cannot be revived, and there are no farms, so food comes only from the caravans and Pell's
stall.

**Events:**
- Fiona and her mages hold the camp's ward while the waves come, with the First King's Hand.
- Rhodri speaks to Brenna during the fight and shows what is left of him.
- Every now and then a caravan arrives with food.
- Lothar comes out with Rhodri in the last wave and is the last of the court to fall (his last need in the story). Afterwards nobody is left in
  the throne hall.
- Rhodri is downed and flees into the throne hall, where he is alone.

**Story covered:** the end of the war and the cost of it. The crown breaks, but the curse does not die with it. The spies' origin stays unsolved
(the "goldsmith" is never found). What comes after is left **open**.

**Intro cutscene:** the final camp, where Brenna gives Fiona the First King's Hand. Cut to the throne hall: Rhodri on a throne with the crown, and
a pale court around him. He smiles.

**Outro cutscene:** Rhodri has fled into the throne hall, where nobody is left: he is alone. Fiona confronts him. After a short conversation, in
which Rhodri is himself for a moment, she takes the First King's Hand and beheads him. The crown falls to the floor and breaks into many
pieces, and a visible curse spreads through the throne hall, finds Fiona and goes through her whole body. She lets go of the sword and her eyes
turn black. Cut: end of the campaign. What happens next is **open**. There is no branching.


**Decided:** a hand-made map (`capital.json`, from Volcanic by the tool) with a new zone, the **city** (`Config.ZONES.city`: cobblestone
ground; its blocked tiles are **houses**, standing and ruined, instead of peaks: mountain terrain with a house prop, `"peaks"`), ash land
around it and a few steppe spots with trees. The **throne hall** is a landmark at the north road's end (a campaign treasure that can never be
looted, `throne_hall`). The final camp: the village's walls half broken, Fiona at home in her house (a resident; her death is a defeat),
Pell's stall, towers manned by Fiona's mages (bound: they take no orders). No farms (none can be built); a food caravan comes after every wave.
Twelve waves, all categories, the Legion at full strength. **Rhodri** (`legion_king`) is a commander like Halvard, with a cleave like Rurik's;
at 0 HP he is **downed**, not killed (`"downed"`): he keeps 1 HP, nothing can target him, and he falls back along his road into the throne hall
and is gone. He comes out in wave 12 with **Lothar** (a named court champion with the herald's look), who can be killed. Won when wave 12 is
over with Rhodri downed (the game's win sound). The outro's curse is an effect in the throne hall (`curse`) and Fiona's portrait with black eyes
(`portrait_fiona_cursed`). Built as §7.18.
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
- ~~Scenario 1's numbers~~: decided and built (§7.3).

- Each other scenario's exact *N* and *target* numbers.
- Hero level and the units per baseline.
- ~~Whether the warehouse (4) is a defeat condition~~: it is (§7.7). Fiona's death always is.
- Whether bandits are a new Renegade kind (not for now: thieves only), and whether the rival guild hires Renegades.
- The Dread Legion: the footman and the captain are built (§7.7); the other kinds and names, how its camps, ranks and banners work (a
  banner-bearer could buff like the war cry), a captain's commanding abilities, and its place in the mid-boss design (the marshal).
- The druids (7): whether they come back later (scenario 10 or 11), and whether a grove can be found in a normal game.
- Where else than the Coast the water monsters appear. Scenario 4 has only crabs and one siren at most. The stats of the scripted leviathan and
  the guard octopus are *open*.
- The Arcane category and where witches, gargoyles and the siren first appear (5 or 8; the siren is rare and shows up once at most in 4).
- Who the guilds' foreign coins and seals belonged to, and who the "goldsmith" was (never settled).
- The mid-boss design: Rhodri's marshal (10), the court champion (8), the leviathan (9), Rhodri (11).
- What happens after the open ending (the curse on Fiona, the Legion, the kingdom).
- The home state of scenario 10 versus 1 to 3.

## 6. What the engine needs

The game has none of this yet, except where noted:

- **A scenario system** (built, §7): a list of scenarios, a menu, a scripted baseline per scenario (map type and seed, starting village, units, resources,
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
- **Water monsters are built** (`aquatic-design.md`: crab, siren, leviathan, octopus). The scenarios need only: maps with a water body big enough
  and water spawns (the map editor), the leviathan as a scripted, stronger spawn, and the octopus as a non-wave guard (below).
- **A capital-city map (scenario 11):** cobblestone and buildings in place of the generated wilderness, a few steppe spots with trees, no meadow.
  A new map type or a hand-made map, with its own art.
- **Choices:** a decision the player makes in a dialog (scenarios 4 and 8: accept an offer and lose the scenario). The existing confirmation
  dialogs are the closest piece.
- **Guard mobs:** a strong monster that guards a place and does not count for the waves (scenario 9's octopus). The monster camps' guards are the
  closest piece. The built octopus is a normal wave member, but its arm entity is already an enemy that is not counted for the wave.
- **A boss that is downed and flees:** scripted HP and damage, a down at 0 HP instead of a death, then a flee (Rhodri in scenario 11).
- **Scripted caravans:** food arrives at fixed moments where there are no farms (scenario 11).
- **A death effect for the Legion:** when a Legion unit dies, the pale colour fades, a human face shows for a moment and a breath goes out
  (scenarios 5, 8, 9, 10 and 11), so each kill reads as a release.
- **Per-scenario rules:** enemy strength, a custom wave mix (which kinds from which wave), locked specialisation, "hero revives" and "fail if the
  hero is downed", "fail if Pell dies" (scenarios 4 to 11) and "fail if a villager dies".
- **Objectives:** survive N waves, rebuild the village, restore ruined towers, find treasures, bury corpses, clear lairs, defeat a boss. Several
  map onto existing mechanics (waves, ruined towers, treasures, gatherers, lairs).
- **Scripted events:** a scripted walk for the hero, things that happen at a given wave or moment.
- **Cutscenes:** skippable by the player. Built: in the engine, with dialogue boxes (§7.2).
- **Pell's market** and **mid-bosses**, both on the README's roadmap.
- **Scenario text:** library lore, journal fragments, log lines.

## 7. As built

### 7.1 The scenario system

- **One file per scenario:** `scripts/scenarios/scenario_<n>.gd` extends `Scenario` (`scenario.gd`) and holds everything that scenario is: in
  `_init` its data (title, the map file, difficulty and enemy strength, resources, villagers and their names, how much of the village stands, the
  hero's name, level and start, what may be built and recruited, specialising, revive and death rules, the exact waves, the speakers), and in
  overridden functions its content (the intro, the arrival and the outro cutscenes, the teaching cards, the one-time hints, the objectives, events
  per wave). `Campaign.SCENARIOS` (`campaign.gd`) lists them in order. A scenario's numbers live in its file, not in `config.gd`.
- **The runner** (`ScenarioRunner`, a child of `Game` while a scenario runs; `Game.scenario`) plays it: before the world is made it loads the map
  file (`MapData.for_game`), sets the difficulty and the enemy scale (`Settings.enemy_scale`, values that replace the difficulty's multiplier,
  below Easy if need be) and the starting village; once the world stands it ruins the huts and pieces (`apply_baseline`: huts nearest the centre
  stand, of each piece kind the first ones in row order stand, at `pieces_hp`, the rest are devastated); then the intro, the hero's walk, the
  arrival, the cards, the hints and the objectives (polled every 0.25 s), and the outro once every objective holds at once and no wave runs.
  The villagers wait at home until the intro is over (`ScenarioRunner._hold_villagers`); then they go to work. A hint with `"point"` and
  `"until"` stays on the card and points like a card (the card's own pointer waits) until `"until"` holds.
- **Rules** it enforces: `Commands.submit` asks `ScenarioRunner.command_error` (buildings, unit kinds, specialising, no hero orders or wave calls
  during the story parts); the HUD hides what isn't allowed (`Game.available`, `Game.allows_building`; `MilitaryUnit.upgrade_options` leaves out
  the branches when `Game.allows_branches` is false). A villager's death (`Population.civilian_died`) or the hero being downed (`Hero.downed`) end
  the scenario when its rules say so (`fail_on_villager_death`, `must_live` names, `hero_revives`); the usual defeat does too. The defeat screen names the cause and offers *Try again* (the scenario starts
  over) and *Main menu*; the win screen *Main menu* and *Play again* (`Game.end_game`, `Hud.show_game_over(..., won)`).
- **Waves:** a scenario's waves are `Waves.scripted` entries without a fixed `spawn`: `kinds`, spread over `spawns` edge spawns, plus `rat_packs`
  (each pack from one spawn). `Waves.last_wave` stops the waves after the last one (the top bar says "All N waves survived"); `Waves.buffer` is
  the gap between waves; wave 1 can wait to be called (`first_wave_waits`), or wait until the scenario lets it come (`first_wave_call` false,
  `ScenarioRunner.release_waves`); with `repeat_last` the last listed wave comes again and again, `more_each_wave` bigger each time, until the
  objectives are met (`Waves.last_wave` 0).
- **More of the baseline:** `prebuilt` posts and buildings, finished and manned, placed by a road (`road`: 0 the one nearest the village by road;
  `at`: road tiles before its gate; `RoadSpots`) or on a fixed `tile`, at a `level`, with their `units`; `wall_tower` mans the corner tower by that
  road. Named villagers (`names`, by role; `Civilian.given_name`).
- **During play:** `play_scene` (a short scene between waves: a talk, a visitor; one after the other; cutscenes hold the wave countdown),
  `on_poll` (a scenario's own events every 0.25 s), `on_wave_started` / `on_wave_finished`, `on_card_done`, and `show_journal` (a page found:
  a journal, a letter, a logbook, on parchment over the paused game, `Journal`). Objectives can be `optional` (shown, not needed to win). A
  card can wait (`ready`), showing `wait_text` meanwhile under its own `wait_title` (else the last card's title stays).
- **Progress:** a won scenario is remembered as completed (`Campaign.complete`, by its title, `user://campaign.json`); the campaign page marks
  the completed ones, highlights the next and, in release builds, shows only the unlocked ones (docs/ui-design.md, the campaign page).
- **Not built yet:** saving a scenario (`Game.save_error` refuses it, there is no autosave; the stall, the merchant, the guild master, the graveyard, the fallen, the grove, the druids and the
  warehouse aren't in saves either), upgrading the stall in play, guard mobs, bosses, scripted caravans, the Legion's other kinds (archers,
  banner-bearers, the marshal) and a captain's commanding abilities, anything carried between scenarios (by design: nothing carries over).

### 7.2 Cutscenes

- **In the engine, with dialogue** (`Cutscene`, `cutscene.gd`): the game runs on at 1x behind black bars, the HUD hidden and the map's input off;
  the camera moves between spots; people speak in a box at the bottom (portrait, name in their colour, the line typed out); the narrator's lines
  have no portrait and are centred. A tap, click, Space or Enter shows the whole line, then the next; *Skip* (top right) or Esc ends it.
- A scenario writes a cutscene as a list of steps: `say` (speaker id, text), `camera` (a world position, or a Callable giving it when the step plays; zoom, time), `follow` (a Callable giving a node:
  the camera glides to it and stays on it while it moves, until the next camera step or the end), `wait`, `fade` (in / out),
  `title` (a title card), `do` (a scripted action: a cart on the road, dusk), `until` (wait for a condition), and a **choice**: a `say` step with
  `choices` (`[{"text", "do"}]`) shows a button per choice instead of waiting for a tap; the picked one's `do` runs (scenario 4's offer: taking
  the gold calls `ScenarioRunner.lose`), then the cutscene goes on. Skip before a choice still to come jumps to it (only the `do` steps on the way
  run), so the player always makes it; at the choice Skip and Esc do nothing; after it Skip ends the cutscene. The runner has helpers for them:
  `at(tile)`, `actor(art, tile)`, `move_actor`, `road_in`, `dusk`.
- The speakers' portraits are generated art (`portrait_brenna`, `portrait_einar`, `portrait_pell`, `portrait_wenna`, `portrait_sigmund`,
  `portrait_lysa`, `portrait_rival` in `tools/gen_art.py`).
- Whether they can be watched again (title screen, library) is still *open*.

### 7.3 Scenario 1 as built (`scenario_1.gd`)

- **Map:** `data/maps/homecoming.json`, made by `tools/make_scenario_map.gd` from the generator's Highlands seed 1337 (the old tutorial's map)
  without unlock sites and lairs, with one ruined watchtower (the one nearest the village, by the west road). It is a normal map file: open it in
  the map editor (it is listed with the built-in maps), change it, and Export it over the same file. The tool never overwrites it without `--force`.
  The hero's start (41, 19) and her tent (42, 18) by the north road are set in `scenario_1.gd`; move them there if the map changes.
- **Baseline:** Easy, with enemy HP, damage and spell damage at 0.5 (speed and loot as on Easy); 150 gold, 120 food, 180 material; a builder, a
  farmer and Einar the forester; the farm and the camp stand (not damaged); 4 of 9 huts stand; 1 gate, 3 walls and 1 wall tower stand at 60 % HP,
  the rest are devastated; smoke rises over some ruined huts until they are rebuilt. Brenna is level 1.
- **Rules:** archers only, no specialising; watchtowers, farms, camps and light stones (no barracks, no training grounds); she revives as usual;
  any villager's death is a defeat ("Einar, Brenna's father, died from the attack of goblin 4. No villager may die in this scenario.").
- **Waves:** 1: 3 goblins, called by the player, down the cards' road; 2: 4 goblins and a pack of 4 rats; 3: 4 goblins, an ork and 4 rats; 4: 6
  goblins, an ork and 5 rats; 5: 5 goblins, 2 orks, 2 big slimes and 5 rats. 40 s between waves. Corpses don't rot until the gatherers' card is done.
- **Story:** the intro (a title card; the narrator: the old king is dead, they say, a rumour out here; Brenna wakes by her tent, the camera pans to
  the ruined village and its smoke); the walk home (no orders for her meanwhile; the camera follows her); the arrival (Einar greets her and
  tells what happened; the rule that nobody may die); the outro (dusk, a cart with a lantern on the north road: Pell).
- **Cards** (the tutorial's steps 1-7 and 11, and the rebuilding): rebuild a hut, a watchtower on the marked spot, the builder at work, an archer
  on the tower, a second farm (food), call wave 1, a gatherer, upgrade the archer, mend the walls (repair a gate, wall or wall tower).
- **Hints** (once each, on the card and in the log): a villager fleeing an enemy, a villager hurt, food falling below 60, enemies inside the walls.
- **Objectives:** survive the 5 waves; every hut rebuilt; every gate, wall and wall tower whole; more villagers than at the start; food not
  falling. All at once win it.
- **The old tutorial stays** as it is for now (title screen *Tutorial*); scenarios 1 to 3 now cover all of its steps, so it can be retired when
  you decide.

### 7.4 Pell, the stall and trade

- **The trade stall** (`stall`, `Stall`, 2x2, 30 material, 12 s; `Config.BUILDINGS` with `"campaign": true`: only in a scenario that lists it in
  `build`, never in a normal game). Its level is its stage (`Config.STALL_LEVELS`): *Peddler's Stall* (30 goods, +6 a minute, lots of 10 material
  for 15 gold or 10 food for 12), *Trade Stall* (60, +12, 15 for 20 / 15 for 15), *Guild Market* (120, +24, 25 for 30 / 25 for 22). There is no
  upgrade in play yet: a scenario sets the level (`prebuilt`).
- **The merchant** (`merchant`, `Merchant`; can't be recruited; Pell) lives in a hut and works the stall (`works_at`): he walks there and stays by
  it, tending it. Only while he is there is it open: its goods refill, and its panel buys lots (the `trade` command, `Stall.buy`; it says why not:
  closed, sold out, not enough gold). Like any villager outside he runs home from enemies and comes back once rested.
- **Rats** treat the stall as a farm (`Stall` extends `Farm`; its `stored` is its goods, its `rate` 0): they go for it and eat the goods, and it
  refills nothing meanwhile; barracks and the hero go after rats there as on a farm. (Rats bite people first: with Pell at the stall they go for
  him, and he flees.) Farm-only rules (the food warning's tips, the scenarios' `farms()`) look at `kind == "farm"`.
- Art: `stall` (a booth with a striped awning and Pell's cart), `stall_3` (the guild market), `unit_merchant` (Pell).

### 7.5 Scenario 2 as built (`scenario_2.gd`)

- **Map:** the home map (`homecoming.json`), as in scenario 1.
- **Baseline:** Easy, enemies at 0.6 HP and damage; 120 gold, 60 food, 110 material (food is short); a builder, a farmer, Einar, a gatherer and
  Pell; all huts and the walls whole; the farm and the camp; two watchtowers by the two nearest roads, with an archer each (level 2 and 1). Brenna
  is level 2.
- **Rules:** archers and shield bearers, no specialising; watchtowers, farms, camps, light stones, barracks and the stall; Pell must not die
  (`must_live`; "Pell died ... Pell must not die.").
- **Waves:** seven, Wilderness only: 1: 4 goblins; 2: 5 goblins, 4 rats; 3: 5 goblins, an ork; 4: 4 goblins, an ork and two rat packs (6, 5: the
  farm test); 5: 6 goblins, 2 orks, a big slime; 6: 7 goblins, 2 orks, 5 rats; 7: 8 goblins, 3 orks, 2 big slimes, 5 rats. Wave 1 can't be called:
  its 45 s countdown starts once the stall stands. 40 s between waves.
- **Story:** the intro (a title card; a few weeks later; Pell's cart by the north gate, where it has stood since he came; he has carried the
  last stone of the wall, and asks for a place for his wares; she wasn't at the capital, and they leave it at that); after wave 1 Pell tells of
  King Orsin's death and the war of his children, Fiona and Rhodri; after wave 3 a stranger from a rival guild walks up the road, asks questions
  (Pell flies the Silver Thread's colours; the stranger calls them the Leftovers) and walks off down the road again; after wave 5 Pell tells
  of the guild's split (the pieces made alliances with Fiona's court, Rhodri's army and each other; the few who stayed neutral, with no
  alliances, are the Silver Thread Merchant Guild, called the Leftovers by the others); the outro (dusk at the stall: the road to the border town is cut where the Wardline stood; help restore it and the
  guild can send caravans).
- **Cards:** Pell's stall (placed on a marked spot by the road, or anywhere), Brenna explores (she claims the broken watchtower), restore it,
  trade (it waits, titled *Pell's goods*, until wave 2 is over and the open stall has goods for a lot, or something was bought already; the stall
  is marked only while a lot can be bought), her level, barracks with a shield bearer, a tower upgrade.
- **Hints:** Pell fleeing, rats on the farm or the stall, food low. **Objectives:** survive the 7 waves; build Pell's stall and don't lose it
  (once it has stood, devastated or torn down is a defeat: "Pell's stall was torn down / destroyed ..."; nothing in its waves attacks
  buildings, rats only eat its goods, so in practice only a tear-down loses it); *optional:* buy something from Pell; the walls hold (no gate,
  wall or wall tower devastated).

### 7.6 Scenario 3 as built (`scenario_3.gd`)

- **Map:** `data/maps/wardline.json`, 100x100: `tools/make_scenario_map.gd` (`-- 3`) grows the home map: it sits in the middle, a generated
  Highlands map (seed 4711) fills the ring around it (its roads, villages and objects left out), and the home roads run on straight to the new
  edges (bridges and fords where they cross water). The seams between the two show; smoothing them is for the map editor. Placed along the north
  road (the road to the border), 13, 25 and 37 road tiles from the gate: three ruined watchtowers, and at 46 a ruined **barracks** (2x2); with the
  one by the west road from the home map, four towers and the barracks. The two monster camps by the north road (from the home map) are in the
  way: the builders flee from them, so the hero (or towers) must clear them.
- **Ruined barracks:** a ruin object can have been a watchtower or barracks (`"building"` in the map file, format version 3;
  `RuinedTower.building()`): claimed and restored the same way (half its price: 10 material and 15 gold), it becomes devastated barracks.
- **Baseline:** Easy, enemies at 0.75; 260 gold, 160 food, 220 material; two builders, two farmers, Einar, a gatherer, Pell; Pell's Trade Stall
  (level 2), a second farm, barracks with a level 3 shield bearer, three watchtowers with archers (level 3, 3 and 2). Brenna is level 4.
- **Rules:** archers and shield bearers, specialising open (from level 3); training grounds allowed; Pell must not die.
- **Waves:** Wilderness, and from wave 3 thieves (the first Renegades); six listed (5 goblins and 4 rats up to 8 goblins, 3 orks, 3 thieves, 2
  big slimes and 6 rats), then the last again with 2 goblins, an ork and a thief more each time, until the objectives are met. The first wave comes
  after the usual 90 s; 45 s between waves.
- **Story:** the intro (Brenna and Pell walk the north road to the first ruin; Pell explains the Wardline, Brenna served on it); each restored
  watchtower gives up a page of its garrison's journal (four pages; the third says what the light stones are for: rune stones the last garrison set along the road between the towers, whose glow shows the stretch no tower sees; the fourth that they have gone dark), one at a
  time; the restored barracks its logbook: the order to abandon the post, signed in both Fiona's and Rhodri's names, in a careful square hand,
  and Brenna knows it: Lysa's, her old captain's; the outro (the first guild caravan comes down the lit road; word from the border town: the
  guild's store there is under pressure; Brenna leaves home with Pell; from here on nobody can bring her back).
- **Cards:** claim the ruins (Explore), restore a tower, specialise an archer, training grounds with a unit, Train mode (a level from Brenna's XP),
  light the road (a light stone where the road is dark; no spot is marked, only the Build tab's entry: the dark road shows where). The light card
  waits (titled *Explore the line*) until a stretch of the line's road between the village and a restored tower is explored and still dark
  (`_known_dark_road`), or a light stone was placed already.
- **Hints:** thieves on the road, Pell fleeing, a monster camp found (its guards keep explorers and Brenna away; Brenna attacks it on order,
  towers and barracks in range fight its guards by themselves), no explorer once wave 3 is over (recruit one). **Objectives:** every ruined watchtower restored and manned (4); the barracks restored and manned;
  the road of the line lit: every road tile from the village out to every ruin site watched by one of the village's buildings (what towers and
  light stones see, not where people walk; `ScenarioRunner.lit`).

### 7.7 What scenarios 4 and 5 added to the engine

- **The guild warehouse** (`warehouse`, `Warehouse`, 2x2, 500 HP: ten plunders; `"campaign": true`, never placed by the player: a scenario prebuilds it). It
  is the **thieves' target**, and only theirs (the siege field leads the rest to the huts): a thief (`ThiefBehavior`) whose village has a
  standing warehouse follows its road to where it passes nearest the warehouse, then goes across to it (`Pathing.find_path`; never a way through
  the walls: then the gate as usual), plunders it (`Warehouse.plunder`: it loses `Config.WAREHOUSE.raid_damage` (50) HP; no hut burns), steals
  gold as at a gate (`Game.thief_steals`) and runs back the way it came with the sack. At 0 HP it is devastated. It can't be repaired (`Warehouse.can_repair` false: what is plundered is gone; the `repair` command refuses it) or torn down.
  Art: `warehouse` (timber and stone, a slate roof, a loading door with a hoist, the guild's sign: gold scales on blue).
- **`must_stand`** (Scenario): building kinds that must not fall; once every one of a kind is devastated the scenario is lost
  (`Scenario.fallen_text`).
- **`near_water`** prebuilt placement: the free spot within the siege band by the walls nearest the water (the warehouse by the harbour).
- **The guild master** (`guildmaster`, `GuildMaster`; can't be recruited): a villager who stays in her hut (she never goes out, so she is safe
  while it stands, and dies with it). A named villager's hut can have its own look and name (`Scenario.homes`, `Hut.look` / `look_name`: Wenna's
  *Guild House*, art `guild_house`). Art `unit_guildmaster`.
- **The Dread Legion** (`story-design.md` §5; `Config.ENEMIES`, `"campaign": true`: never in the normal waves, only where a scenario sends
  them). A fallen Legion soldier is **released** (`"release": true`, `Enemy._release`): the pale colour warms, a pale breath rises (burst
  `release`), and it sinks away; no corpse.
  - *Legion Footman* (`legion_footman`): 38 HP, speed 0.95, 7 damage every 1.1 s, breaks gates and walls; 5 gold. A pale soldier in a grey
    helm and a faded tabard, spear and round shield.
  - *Legion Captain* (`legion_captain`, behaviour `captain`, `CaptainBehavior`): 140 HP, 12 damage every 1.2 s, no gold. **Never killed:** the
    moment its HP would drop below `retreat_below` (30 %) it keeps that much and **falls back** (`Enemy.retreating`): nothing targets it any
    more (`Enemy.targetable`), it leaves any siege, and walks back the way it came at `retreat_speed` (×1.4) and off the map (the wave ends
    then). The story needs Lysa and Torben later (scenarios 9 and 10). Commanding abilities: *open*.
  - **Named enemies:** a queue entry's `name` and `art` give an enemy a name and a look of its own (`Enemy.set_identity`): the name shows over
    its head and is its label in the log; Lysa's captain has a crimson plume and a dark-red braid (`unit_legion_captain_lysa`), Torben's the
    generic pale plume (`unit_legion_captain`).
- **Adding to a running wave:** `ScenarioRunner.add_enemies(kind, tile, count, extra, front)` (`Waves.add_to_wave`): more enemies for the wave
  under way, from a road tile, counted for it (scenario 5's Legion down the pass, its captains, the old gate's gargoyles); at the end of its
  queue, or with `front` next to come. `spawn_near(tile)`: the edge spawn whose road comes in nearest a tile. `keep_in_sight(who, radius)`:
  an observer that follows an enemy or a cutscene figure and keeps the land round it watched for the player while it is on the map
  (`ScenarioRunner.Sight`; scenario 9's Lysa).
- **Water monsters in scripted waves** come from the village's water spawns as in the normal waves (`Waves._water_spawns`: water-bound always,
  amphibians half the time).
- **Helpers:** `treasures()` (the map's treasures, farthest first), `named_enemy(name)`.
- **Maps:** `tools/make_scenario_map.gd` `-- 4` (Coast, seed 42: the village on a sea inlet, three roads, two water spawns) and `-- 5`
  (Highlands, seed 11: mountains round the fort, the road down from the north, five treasures, two of them guarded by camps); both without
  unlock sites, lairs and ruins. `data/maps/guildtown.json`, `data/maps/old_fort.json`; edit them by hand in the map editor.

### 7.8 Scenario 4 as built (`scenario_4.gd`)

- **Map:** `guildtown.json` (*The Guild Town*).
- **Baseline:** Easy, enemies at 0.9; 200 gold, 170 food, 200 material; two builders, two farmers, a forester, a gatherer, Pell and **Wenna**
  (the guild master, in the Guild House); the farm and the camp; the **warehouse** by the harbour (`near_water`), Pell's **Guild Market**
  (stall level 3), barracks with a level 3 shield bearer, two watchtowers with archers (level 3 and 2). Brenna is level 5.
- **Rules:** archers and shield bearers, specialising, training grounds; Brenna **can't be revived** (downed is a defeat); Pell and Wenna must
  not die; the warehouse must not fall (`must_stand`).
- **Waves:** nine, about 2.5 times a home wave (17 enemies in wave 1, 64 and three rat packs in wave 9). Goblins and orks, which go for the
  huts; **thieves** in every wave, which go for the warehouse (4 to 8 in waves 1-6; once the foreign coins are found after wave 6 the
  paymasters send about twice as many: 16, 18, 22; bandits are not built: thieves are the Renegades, as decided); **crabs** from wave 2 and
  **one siren** in wave 7, out of the sea only (`amphibians_from_water`: never from the map edge); rat packs and big slimes now and then.
  Wave 1 waits to be called; 40 s between waves.
- **Story:** the intro (the harbour half closed by a rival guild's chains; Pell's old guild house; Wenna: the convoy is loading in the warehouse,
  nine days; the rules); after wave 1 Wenna tells how the guild broke apart (every master had to choose an heir; the Silver Thread Guild is the ones who
  wouldn't); after wave 3 a **rival guild's master** comes up the road and offers Brenna gold to leave: a **choice** (*Take the gold and leave*
  loses the scenario: "Brenna took the rival guild's gold and rode away..."; *Refuse* goes on); wave 7 starts the convoy's loading; after wave 6 a
  captured thief's **coins of three mints** (Karmere, Lyrenne, Aurelith; a journal page; Wenna expects twice the thieves now); the outro (the convoy rolls out; that night Pell reads
  the Renegades' ledger: payments to a quartermaster of Rhodri's army from three sources, "someone bought him"; Brenna will go back to her fort).
- **Cards:** the warehouse (tap it), guard the harbour (a manned watchtower within 5 tiles of the warehouse), call the first wave.
- **Hints:** crabs, the siren, the warehouse plundered (it can't be repaired), Brenna badly hurt (no revive: send her to rest), thieves (after the warehouse). **Objectives:** hold until
  the convoy leaves (9 waves); keep the warehouse standing (its HP share shown).

### 7.9 Scenario 5 as built (`scenario_5.gd`)

- **Map:** `old_fort.json` (*The Old Fort*, 75x75), made by `tools/make_scenario_map.gd` (`"citadel"`), not generated: a mountain range across
  the middle from west to east (about 13 tiles deep, ragged), the pass straight through it north to south (7 tiles wide at the fort, wider
  towards both ends). The fort fills the pass: two walls of 7 tiles across it, 8 tiles apart (`T W G W W W T` north, `T W W G W W T` south),
  the mountains on both sides; the road bends a little from the north gate through the fort's middle (the village centre lies on it) to the
  south gate. Inside: 4 huts in two rows of two east of the road (a tile apart, a tile clear of the mountains), two barracks and training
  grounds (prebuilt, `Scenario.build_inside`), a dried-up well (decor, `well_dry`: no use) and one dead tree. Where two roads run side by side,
  the doubled tiles are taken out, and so are stubs, a road tile sticking out with one road neighbour (`_prune`). The map is the
  tool's start; the user has edited it by hand in the map editor since, so it is never made again with the tool (`--force` would
  undo those edits). What the code ties to it: `SIGMUND_TENT`, the prebuilt posts' offsets from the village centre, the evidence (by
  treasure tier: two tier 3 in the north, one tier 2 in the south; tier 1 small chests). The user's edit added a **hollow-tree lair** in
  the northern forest (its road to the network) and reshaped forest and mountains.
- **The lair:** asleep until wave 6 (`LAIR_WAVE`, `Scenario.lairs`), or until the village finds it (an explorer or Brenna uncovers it:
  `on_poll` wakes it at once). Awake, it sends its theme (goblins, rats, spider mothers) with every wave (every wave has `"lairs": true`);
  Brenna can clear it, and cleared it stays cleared. North: oak woods with pine patches and clearings (the wilderness: both camps). South:
  meadow with steppe spots, a few trees. Roads: one from the north edge and one from the south edge to their gates, and one from the west and
  one from the east edge on each side, joining them before the pass: six edge spawns, three a side. Objects: in the north, two treasures
  guarded by camps (the far evidence) and a small chest; in the south, one treasure (evidence) and a small chest. Sigmund's tent: a fixed tile in
  the south, off the west road (`SIGMUND_TENT`).
- **Baseline:** Easy, enemies at 0.95; 220 gold, 150 food, 220 material; only Pell (in a hut; his stall a Peddler's Stall outside the south
  gate). Every hut, wall, gate and wall tower stands whole, the gates at level 2 (`Scenario.piece_levels`); the barracks and training grounds stand empty. No farm. Brenna is level 7.
- **Rules:** archers and shield bearers, specialising, training grounds; no revive; Pell must not die and can't retire (no merchant or
  resident can). Buildings may be placed inside the fort's walls on free tiles off the road (`build_inside`), so what is torn down there makes
  room.
- **Sigmund:** his tent (and him beside it) stand on `SIGMUND_TENT`. Once its tile is explored he is found: wave 1 is on its way (10 s,
  `FIRST_WAVE_AFTER`; it can't be called before) and he joins as a builder named Sigmund (`ScenarioRunner.join_villager`: spawned at the tent,
  he walks to his hut) once his scene is over (he stands by his tent while he talks). If no hut is free, a builder leaves (retired, logged) and Sigmund takes his hut; if there is no builder either, the
  objective **"Give Sigmund a roof over his head"** appears (`"shown"`) and he waits by his tent until a hut is free (the player retires
  someone in the villager list), then moves in at once. The objective shows once he is found and is ticked as soon as he lives in the fort.
- **Waves:** ten, from both halves (six spawns). Goblins, orks, rats, thieves; **witches** from wave 3 and **gargoyles** from wave 6 (the first
  Arcane). Wave 10: 6 goblins and 2 orks, and when it starts (`on_wave_started`) the **Dread Legion** comes down from the north edge (8 footmen,
  and the captains **Lysa** and **Torben**), while 3 **gargoyles** wake on the rocks above the pass (a road tile 14 tiles up the north road).
  45 s between waves.
- **Evidence:** three treasures: the two guarded ones in the north and the one in the south (the guarded treasures farthest north, the
  treasure farthest south); hidden in the fog, no card marks them. The hero loots them as any treasure (guarded ones once their camp is
  cleared). Each found piece shows its page (the game grey behind it), in the order found: **Rhodri's order** ("Hold until the last. Do not ask
  for relief. Relief will not come. The crown will come to you itself..."), **the roll of the fallen** (forty-one names in one ink on one day,
  Brenna's among them, no grave marked), **a foreign seal** (a tower over three waves; whose, nobody can say).
- **Story:** the intro (the fort whole and empty, nobody on the walls; Pell finds it eerie; the field where the company stood; the evidence is
  in the hills, on both sides; Pell sets up outside the south gate); Sigmund found (he camps outside, he couldn't sleep in there; "you look well
  for a dead woman"); Sigmund tells it after waves 1, 2, 3 and 5 (Lysa sent Brenna down the pass with a plea for relief; Rhodri came the next
  evening with the crown; the company knelt on the field and stood up bound; no body on the field), Pell after wave 7; wave 10's scene (the
  column down the pass, Lysa and Torben; "Hold until the last."; the gargoyles above the pass); when a captain falls back, Brenna: they are
  alive, and she will free them; the outro (as before).
- **Cards:** the evidence (Explore; nothing marked; the waves come once Sigmund is found), guarded (attack a camp). **Hints:** a witch, a
  gargoyle, the Legion (released when it falls), Brenna badly hurt. **Objectives:** find the three pieces of evidence; Sigmund's roof (once he
  is found); hold the fort for 10 waves.

### 7.10 What scenarios 6 and 7 added to the engine

- **The fallen** (`Corpse.fallen`, `Corpse.make_fallen`, `Corpses.spawn_fallen` / `fallen()`): a battlefield's dead, placed by a scenario.
  They are corpses of kind `skeleton` (raised, one comes up as a skeleton) with their own look (`corpse_fallen`: Fiona's blue,
  `corpse_fallen_2`: Rhodri's crimson, by chance), never rot and are never cleared after a wave. A necromancer raises them like any corpse.
- **The graveyard** (`graveyard`, `Graveyard`, 3x3, 150 HP; `"campaign": true`, prebuilt by a scenario, can't be torn down). While the village
  has a standing one, gatherers (and the hero gathering) fetch the fallen too, `Config.FALLEN.carry` (1) at a time, carry them there instead of
  home (`GatherJob` states `TO_GRAVE`, `BURYING`), and lay each in its grave in `bury_time` (4 s): `Graveyard.buried` grows, a mound with a cross
  appears for each (`grave_mound`, up to 30), and they pay nothing. Without a graveyard nobody fetches the fallen. Art: `graveyard` (flat, on the
  decal layer: a low stone wall, a lychgate, old crosses, a fresh grave with a spade).
- **Residents** (`Resident`, `"stays_home"` in `Config.CIVILIANS`: what they do at home): campaign villagers who never leave their hut and die
  with it; `GuildMaster` is one now. A scenario may give one **rounds** (`Resident.rounds`: stops out in the field, `"tile"`, `"to"`,
  `"doing"`; `Resident.stay` seconds at each and at home): they walk them one after the other, home between rounds, and run home from enemies
  like anyone outside (Anselm: the chapel, the graveyard). New roles: `priest` (Anselm) and `princess` (Fiona); neither can be recruited. Art `unit_priest`,
  `unit_princess`; their houses `priest_house` (a bell-cote with a cross) and `fiona_house` (grey stone, her blue banner) via `Scenario.homes`.
- **The druids** are the summoner's plant branch (`druid`, docs/military-design.md §3b: thornlings whose blows root); the grove's
  take no orders (`MilitaryUnit.bound`, from a prebuilt unit's `"fixed": true`; `MilitaryUnit.fixed()`: `Commands` refuses moving, withdrawing,
  swapping, upgrading and sending one; no upgrade options, no *Withdraw* in the panel). Their **grove** (`grove`, `Grove`, a `Barracks` with `post_kind` "grove", 400 HP, prebuilt at level 3 with its
  benches; no upgrades, no tear-down): they turn out for enemies near it, fight, are downed and come back to their benches like barracks units.
  Only druids serve in a grove. Art: `grove` (moss inside a ring of small stones, an old oak with mistletoe, log seats, a green fire).
- **Unlock sites in a scenario:** `Scenario.sites` (site kind -> the wave it awakens: 0 at the start, -1 only when the scenario calls
  `ScenarioRunner.awaken_site`), honoured by `World`; `Scenario.unlocked` (units unlocked from the start); `ScenarioRunner.site(kind)`.
  `tools/make_scenario_map.gd` places sites by a road (`"add_sites"`, like `"add_ruins"`).
- **Prebuilt by a site:** a prebuilt entry's `"near_site"` puts it on the free spot nearest the map's site of that kind (the graveyard by the
  chapel, the grove by the stone circle).
- **The hero living out** (`Scenario.hero_lives_out`): she starts at `hero_start` by her tent and doesn't walk in; that is her post
  (`Hero.home_override`, `Hero.home()`: where she stands guard, rests, heals and revives) until `ScenarioRunner.hero_moves_in` (the tent is packed
  up, she walks in).
- **A scenario's own command rules:** `Scenario.command_error(r, type, args)`, asked after the runner's own (scenario 7's trust).
- Portraits: `portrait_anselm`, `portrait_fiona`, `portrait_elder` (Elder Oren), `portrait_mage` (Idris, a court mage).

### 7.11 Scenario 6 as built (`scenario_6.gd`)

- **Map:** `data/maps/battlefield.json` (*The Field of Bones*; `make_scenario_map.gd -- 6`: Desert, seed 606, the ruined chapel by the east road
  9 tiles from the gate).
- **Baseline:** Easy, enemies at 1.0; 240 gold, 90 food (short: dry land), 200 material; two builders, a farmer, a forester, Pell and
  **Anselm** (a priest, in *Anselm's House*); no gatherers (the player recruits the gravediggers: three huts are free); the farm and the camp;
  three gates and three wall towers stand at 80 %; the **graveyard** by the chapel, Pell's wagon (a peddler's stall), barracks with a level 1
  shield bearer, a wall tower with a level 1 archer; nothing in the reserve. Brenna is level 9.
- **The field:** 36 of the fallen in four clusters on open land 8 to 17 tiles from the village and at most 2 tiles from a road (`ROAD_NEAR`:
  a necromancer passing by can raise them), as far apart as the land allows (a cluster short of room: the rest by the cluster nearest); their
  places are uncovered at the start.
- **Anselm** walks his rounds once the intro is over (`ANSELM_STAY` 10 s each): prays beside the chapel, prays at the graveyard, home.
- **Rules:** archers, shield bearers and acolytes; specialising, training grounds; no revive; Pell and Anselm must not die; the chapel is
  awake from the start (`sites`): Brenna wakes it by going there (Explore), and acolytes can be recruited. **Lost** once fewer of the fallen are
  left (on the field and carried) than still have to be buried ("Too many of the fallen have risen").
- **Waves:** Undead with Wilderness leftovers: skeletons and goblins, orks from wave 4, the first **necromancer** in wave 3 (two from wave 6),
  a few thieves and witches, rats, a big slime. Eight listed, then the last again with 2 skeletons and an ork more each time
  (`repeat_last`) until enough are buried. The first comes by itself after the usual 90 s; 45 s between waves.
- **Story:** the intro (the plain of the dead, Anselm alone digging a grave by the chapel; he will tell where the court went if they help; the
  chapel is only sleeping); after wave 1 who the dead were (Fiona's soldiers and mages, Rhodri's soldiers; the church couldn't bury them); wave
  3, the first necromancer; the chapel woken (light through the broken roof; Anselm will make acolytes); after wave 5 why the dead rise (not
  Rhodri's will alone: everyone's dead rise); the outro (dusk; Anselm, Brenna and Pell walk from the village to the graveyard, actors at
  `OUTRO_PACE` tiles a second, the real three hidden, talking on the way: the court went east to the druids' valley; there Anselm plants a
  cross over the last grave, `grave_cross`, and prays; a priest's sealed word that gets a knight of Rhodri's army in, but not trusted).
- **Cards:** the sleeping chapel (Explore), the fallen (whoever is brought to the graveyard is buried; no word of recruiting; done at 3
  buried). **Hints:** the gravediggers (once wave 2 is over, if no gatherer was ever recruited and a hut is free: gatherers carry the fallen,
  pointing at recruiting one until one is recruited or no hut is free), a necromancer, one of the fallen risen (how many are left), Brenna
  badly hurt, food short. **Objectives:** bury 24 of the
  fallen; wake the chapel.

### 7.12 Scenario 7 as built (`scenario_7.gd`)

- **Map:** `data/maps/refuge.json` (*The Refuge*; `make_scenario_map.gd -- 7`: Temperate, seed 707, a forest valley; the stone circle by the
  north road 11 tiles from the gate, the mage's tower by the west road).
- **Baseline:** Easy, enemies at 1.05; 260 gold, 160 food, 240 material; two builders, a farmer, a forester, a gatherer, Pell and **Fiona**
  (a princess, in *Fiona's House*); the camp, and the farm by the south road (the forest leaves no room by the walls; food about even); 8 of 9 huts stand, 6 walls, 3 gates and 3 wall towers at 70 %, the rest devastated;
  the **druids' grove** by the stone circle with three level 4 **druids**, Pell's wagon, two watchtowers with the court mages (apprentices,
  level 4 and 3), barracks with a level 4 shield bearer, a wall tower with a level 4 archer. Brenna is level 11, at her tent by the east road
  (`hero_lives_out`). Acolytes are unlocked (`unlocked`).
- **Rules:** archers, shield bearers, acolytes, apprentices and summoners (the last two once found); specialising, training grounds; no revive;
  Pell and Fiona must not die. **Fiona's trust** (`command_error`): until wave 2 is over her people take no orders (no building, repairs, hut
  rebuilds, upgrades, tear-down, recruiting, retiring or assigning villagers, restoring ruins); units can be hired and stationed. After wave 2
  (trust 1) Brenna moves in, everything but new buildings opens, and the court mages open their tower (the apprentice, by visiting it). After
  wave 7 (trust 2) new buildings too. **Wave 5** comes for the grove: a second band (4 goblins, 4 skeletons, 2 orks, a witch) down the north
  road past it, and a druid downed in that wave loses the scenario (one still down from before counts once it stood again). After it the stone
  circle answers (the summoner, by visiting it).
- **Waves:** twelve. Goblins and skeletons, orks from wave 3, witches, thieves, necromancers from wave 6, rats and big slimes now and then.
  Wave 1 waits to be called; 45 s between waves.
- **Story:** the intro (out of the trees; Fiona at the gate with two mages: Anselm vouches for Brenna, but she wears Rhodri's colours; she may
  camp outside, her people take no orders; Pell's wagon may come in); after wave 2 Fiona lets her in, counting her people, not trusting her, and
  Idris opens the tower; wave 5 the elder calls for help; after it the elder tells why the druids stayed out (the pact with the first king; the
  church drove them from the towns) and that the circle will answer; after wave 7 Fiona allows building and tells why Orsin named no heir;
  after wave 9 Brenna tells what happened to her company (the crown binds people), and Idris that Rhodri changed after the envoys came, from
  nobody knows where; the outro (the working hides the valley; a sealed scroll for the court mages in the capital; only House Aldmoor can end
  what Rhodri has become; Brenna will bring her there when the time is right).
- **Cards:** outside the walls (hire a soldier and station it), the court mages' tower (waits for trust 1), mend the refuge (rebuild the
  ruined hut), the stone circle (waits for wave 5). **Hints:** the druids turning out, the grove's wave, a witch, a necromancer, Brenna badly
  hurt. **Objectives:** hold the refuge for 12 waves; earn Fiona's trust (outside, let in, trusted).

### 7.13 What scenarios 8 and 9 added to the engine

- **More of the Dread Legion** (`Config.ENEMIES`, all `"campaign": true`, `"release": true`, no corpse):
  - *Legion Archer* (`legion_archer`, `LegionArcherBehavior`): 26 HP, speed 0.95, 5 projectile damage every 1.6 s. It stops on its road
    to shoot the nearest of our people out in the open (`AquaBehavior.people`: the hero outside the walls, soldiers out, summons, villagers
    outside; never a tower's unit) within `shoot_range` 3.2, below a level 1 watchtower's 3.6. Its arrows are `EnemyArrow`s. Breaking in,
    it shoots the barrier in its way (`siege` 0.6). 6 gold.
  - *Legion Guardsman* (`legion_guard`): 70 HP, speed 0.75, 6 damage every 1.3 s, a tower shield: projectile damage ×0.5; `siege` 1.5. 7 gold.
  - *Legion Banner-bearer* (`legion_banner`): 45 HP, 3 damage every 1.2 s. Every Legion soldier (a `legion_` kind) within its
    `banner_radius` 2.5 strikes and shoots 1 + `banner_haste` (1.25) times as fast (`Enemy.haste`, checked every 0.5 s; the strongest
    banner counts; melee, camp guards, archers, siege blows). A faint pale ring on the ground shows how far its banner reaches. 8 gold.
  - *Court Champion* (`legion_champion`; scenario 8's Rurik): 520 HP, speed 0.8, 15 damage every 1.5 s, projectile ×0.75; every blow also
    hits everyone else of ours within `cleave_radius` 1.3 of its target for `cleave` 0.6 of it (`EnemyBehavior.cleave`, in `MeleeBehavior`
    and `CampBehavior`). 60 gold. It can be killed.
  - Art: `unit_legion_archer`, `unit_legion_guard`, `unit_legion_banner`, `unit_legion_champion`; Lothar's `unit_herald` (a pale tabard, a
    white flag).
- **Legion camps:** a monster camp whose monsters are all Legion kinds is a *Legion camp* (`MonsterCamp.display_name`, art `legion_camp`:
  an army's pale tent, a spear rack, the pale banner, a cold fire). `MonsterCamp.add_guard(kind, hp_scale)` adds a guard (Rurik).
- **A scenario's lairs** (`Scenario.lairs`, applied by `ScenarioRunner._set_lairs`; `ScenarioRunner.lairs()`: the map's lairs, nearest
  first): per lair the wave it wakes at, its guards and their HP scale (`MonsterLair.guard_kinds`, `guard_hp`), and the kinds it sends
  whatever the wave (`kinds_any`); cleared, a scenario's lair stays cleared (`stays_cleared`). Lairs past the list never wake. A scripted
  wave with `"lairs": true` has the awake lairs as spawn points too, each sending its kinds (`Waves._theme_lairs`).
- **The band:** `Scenario.reserve` (units in the reserve at the start) and `Scenario.recruiting` (false: nobody can be recruited; the Army
  tab shows no recruit entries).
- **Treasures:** `Treasure.sealed` (can't be looted until the scenario opens it). A reward's `"item"` is a campaign item: it is paid as
  `Village.items` (the relic sword). The `abbey` treasure (`Config.TREASURES`, `"campaign": true`: never generated, not in the library; art
  `abbey` / `abbey_looted`, 2x2: a church half under water, a broken spire, a gold light from the crypt until it is looted).
- **Guards and bosses:** `Enemy.post` / `post_leash`: a water monster keeps to the deep tiles within the leash of its post
  (`AquaBehavior._cache`; scenario 9's octopus, spawned with `Waves.spawn_at`, outside the waves). A queue entry's `"hp_x"` multiplies an
  enemy's HP and `"power"` its damage and spell damage (`Enemy.power`; the leviathan).
- **The outro waits** for a scene that is playing to end first.
- **Maps:** `tools/make_scenario_map.gd` places lairs (`"add_lairs"`, their doors on the road), treasures with a camp beside them
  (`"add_camps"`) and an island (`"island"`: a road's stretch in a lake, bridges over it, a treasure and its camp on the island, a water
  spawn on the lake).
- Portraits: `portrait_lothar`, `portrait_rurik`, `portrait_rhodri`, `portrait_church_priest` (an unnamed priest, scenario 8), `portrait_eldest_priest` (the drowned shore's eldest priest, unnamed).

- **Scenario 9's rework added** (§7.15): the **church** (`Church`, campaign-only; `"inside"` in `Config.BUILDINGS`: a prebuilt one may
  stand inside the walls); **LegionCompany** (a captain and her soldiers after a relic: a column on her trail, the seal, searching,
  carrying, dropping, escaping); `Enemy.errand` (a scenario's object asked first when an enemy's walk ends, so the end of a path it was given
  isn't a gate; while its `holds(enemy)` is true the siege leaves the enemy alone: Lysa inside the walls going to the church); `Waves` queue entries' `"on_spawn"` (a Callable(Enemy) once it is on the map) and `"gap"`; `AquaBehavior.set_post` (a water
  monster's post moved: the octopus to the harbour, the leviathan between the crypt and the boats); `OctopusBehavior.grab` and `hold_left`
  (a scripted grab whose arm holds its catch in the shallows for a while); `Treasure.seal_hp` / `seal_max` (a seal enemies break, with a
  bar) and `blocked` (why an open treasure can't be looted now); a dropped relic ("sack" with an `"item"`) drawn as `relic_sword`;
  `Resident.start_rounds` (new rounds at once); `ScenarioRunner.hero_moves_out` (a tent as her home) and `keep_in_sight` (an observer
  following a story figure); `ScenarioRunner.keep_free` (a tile nothing may be built on: scenery); `Scenario.rotate_kinds` / `rotate_count` (repeated
  waves grow by kinds in turn); `Enemy.spared` (nothing targets or hurts it while a scene of the story plays); an objective's `"failed"` (it can't be met any more: a red cross and red text on the card, logged
  once; the scenario goes on; scenario 9's rescue once the priest drowned); `Scenario.can_win` (more than the shown objectives); an objective's `"gone"` (once it holds, the objective
  is hidden for good and no longer counted: a goal only for the start); a cutscene `"camera"` step may be a Callable.

### 7.14 Scenario 8 as built (`scenario_8.gd`)

- **Map:** `data/maps/pale_court.json` (*The Pale Court*; `make_scenario_map.gd -- 8`: Volcanic, seed 808, its camps and lairs taken out;
  three crypts by the north, south and west roads, 11, 17 and 24 road tiles from the gate; two Legion camps by the west and south roads).
- **Baseline:** Easy, enemies at 1.1; 320 gold, 160 food, 260 material; two builders, a farmer, a forester, a gatherer, Pell; the farm and
  the camp; 5 of 9 huts stand, 4 walls, 2 gates and 2 wall towers at 60 %; Pell's wagon (a peddler's stall), empty barracks (level 2) and an
  empty watchtower. **The band** in the reserve: archers (6, 5), shield bearers (6, 5), apprentices (6, 5), an acolyte (6), a summoner (5).
  Brenna is level 13.
- **Rules:** **no recruiting** (`recruiting` false); the band's kinds can specialise; training grounds; no revive; Pell must not die.
- **The crypts** (`lairs`): the nearest wakes at wave 1 (3 skeletons and a vampire, HP ×1.5; it sends skeletons and vampires), the next at
  wave 4 (2 skeletons, 2 vampires, a gargoyle, ×1.7; skeletons, vampires, necromancers), the farthest at wave 7 (2 vampires, a gargoyle,
  ×1.9; vampires, necromancers, gargoyles) with **Rurik** (a court champion, HP ×1.2) at its door. The hero clears them as camps.
- **Waves:** nine listed, all from the awake crypts too: skeletons and a few goblins, vampires from wave 2, necromancers and witches from 3,
  gargoyles and Legion footmen from 4, archers from 5, banner-bearers from 6, guardsmen from 7; then the last again with a skeleton and a
  footman more each time (`repeat_last`) until the crypts are cleared. Wave 1 waits to be called; 45 s between waves.
- **Story:** the intro (the capital by night; Lothar under a white flag greets Brenna and will come again; Idris: the Evil gathers in the
  crypts under the court); after wave 1 Idris on the Pale Court; after wave 3 Lothar's **offer** (a choice: *Go back to Rhodri's side* loses:
  "Brenna went back to Rhodri's side..."; *Refuse* goes on); after wave 5 the crown and the foreign goldsmith; wave 7 Rurik at the third
  crypt ("I don't remember you."); his fall (released); the outro (the throne hall's gate; the crown feeds on Rhodri; a priest of the church tells of
  the First King's Hand in the sunken abbey; a rider from Fiona confirms it; Lothar reports the refusal and Rhodri laughs).
- **Cards:** your band (station four), better, not more (upgrade a unit), the first crypt (waits for wave 1). **Hints:** vampire,
  necromancer, gargoyle, Legion archer, banner-bearer, guardsman, a Legion camp found, Rurik, Brenna badly hurt. **Objectives:** clear the
  three crypts; break the Legion's camps (optional).

### 7.15 Scenario 9 as built (`scenario_9.gd`)

Built after the rework of §9a.

- **Map:** `data/maps/drowned_abbey.json` (*The Drowned Abbey*; `make_scenario_map.gd -- 9`, laid out by `tools/abbey_map.gd`): a
  generated temperate map (seed 937167274) for the land, its roads, village and objects taken out, and laid over it: the sea along the south
  edge (its shore wandering, straight in front of the harbour); the village at (32, 46), a walled 9x7 block (four gates, 9 huts, the
  church's 3x3 in its north-east corner, centre (34, 45)); a road from the south gate down to the quay at the water; a broad river
  (`river_x`, `river_half`: its middle swinging 3.5 tiles round column 47, a deep middle of 1 to 3 tiles and a shallow tile each side, 3 to 5
  tiles of water) from the north edge into the sea east of the harbour, parting round the abbey's island at (47, 37) (an oval, land 4.2 x 6.5
  tiles, its shore wobbling; the arms round it 3 x 4 tiles, at least a tile of deep water everywhere); the only way onto the island a road
  from the east gate up the bank (column 38) and over one straight stone bridge from bank to bank (a ford running on from a bridge becomes
  part of it). The far bank is reached only by the east road: from the east edge in the north-east corner, winding round the mountains
  there (`EAST_ROAD`), over the river on a straight bridge on row 20 (north of the island) and on to the north road; enemies come
  that way too (its edge spawn). On the island the abbey (2x2), a camp of 2 vampires and a skeleton beside it (the scenario makes the first vampire
  the **Fallen Abbot**: named, x7 HP and x6 damage, `ABBOT_HP` / `ABBOT_POWER`; the other vampire and the skeleton
  x4 HP, `CAMP_GUARD_HP`, damage as ever), two ruined
  watchtowers either side of the bridge's end and a ruined barracks, abandoned (`ISLAND_RUINS`: the hero claims them, builders restore them,
  so the abbey can be held even without towers by the river; a hint says so once the rescue is over). Roads from the north edge (the
  Legion's: it comes down the village's bank, past the village's towers, and turns off across the open bank to the bridge) and the west edge;
  water spawns in the sea (two) and up the river. Roads only turn on land: a water tile where one turns becomes land, so every bridge and
  ford runs straight. The shore is a broad beach: a beach by the water and sand behind it (steppe ground) up to 2 to 4 tiles in
  (`BEACH_DEPTH`, its trees felled), and three sandbanks off it (`SANDBANKS`), each in a rim of shallow water with a shallow ford to
  the beach. The beacon's spot (the scenario's `BEACON_OFFSET` from the quay) has its trees felled and a footpath to the nearest road.
  The generated treasures, camps and mines that still fit (16 tiles from the village, away from the river and the island) stay, each
  with a footpath to the nearest road it can get to.
- **Baseline:** Easy, enemies at 1.15; 300 gold, 170 food, 260 material; two builders, a farmer, a forester, a gatherer, Pell and two
  priests (residents, named "Eldest priest" and "Priest" in the log and the villager list, not numbered: the
  eldest, who looks as in her portrait (`unit_eldest_priest`: a dark-blue veil and habit, a white wimple, a gold cross), and the younger
  one, whom the octopus catches; they live in the church, going in and out of its door,
  `Resident.home_tile`, and walk their rounds: the eldest to the east gate, the younger to the quay);
  the farm and the camp; the **church** (`church`, `Church`, 3x3, campaign-only, `"inside"`: prebuilt inside the walls; it keeps the relic
  once it is home, a glow shows it); Pell's stall by the quay; barracks (level 2) with a shield bearer (7) and an archer (6), two watchtowers
  (an archer 7 by the north road, an apprentice 6 by the bank road), a summoner and an acolyte (6) in the reserve. The harbour (scenery, `_build_harbour`; nothing can be
  built where a piece of it stands on land, `ScenarioRunner.keep_free`: "The ferry bell stands here"): two piers (the quay's, where the
  guild's boats tie up, and a second one about 7 tiles west, `SECOND_PIER`, with its own crates, mooring posts, net rack, fish rack, an
  upturned boat and three boats on the water), two moored boats at the first, the ferry bell at the quay, crates, a net rack, mooring
  posts, upturned boats, fish racks and driftwood along the beach; on the river's bank near the sea a beacon with gulls circling it (the shipwreck beside it is the map's own, a treasure to loot;
  scenery never stands on a map object). Brenna is level 14. No revive; Pell and the eldest priest must not die (`must_live`).
- **Wave 1** waits (it can be called) until the player has built a watchtower of theirs within 3 tiles of deep water (finished; nobody
  needs to be on it; not a prebuilt one): then its 60 s countdown starts. An objective says so ("Build a watchtower by the shore",
  "then wave 1 comes"); ticked (or once wave 1 is called early), it stays 4 s (`WATCH_GOAL_STAYS`) and is then gone for good (an objective's `"gone"`: only for the start). Ten listed waves, then the last again, bigger, until it is won (no number of waves to hold); 45 s between waves. Each repeat adds
  2 crabs, 2 skeletons and an ork more than the one before (`more_each_wave`), and 2 more in turn from goblin, ork, big slime, crab,
  spider mother, thief, vampire, necromancer (`rotate_kinds`, `rotate_count`: round robin, on from where the last repeat stopped).
  Besides crabs, the drowned dead and the Evil, the Wilderness all along: goblins, orks from wave 2 (1 to 3), big slimes (waves 3,
  5, 8, 10), a spider mother in waves 7, 9 and 10, rat packs (6; 7 and 5 in wave 8).
- **The rescue** (after wave 4): a scene (the priest walks down to ring the ferry bell); the younger priest walks to the quay
  (`Resident.start_rounds`). Only when he gets there does the guard octopus come: moved to the deep water by the harbour, at
  least 2 tiles off the quay and both piers (`OCTOPUS_OFF_PIER`; `AquaBehavior.set_post`), it surfaces and grabs him (`OctopusBehavior.grab`), drags him off the quay into the shallows and holds him
  there, unharmed, while a second scene plays (the alarm). Its other arms keep still meanwhile (its `focus`: no towers smashed, nobody
  else grabbed), and nobody can fight the octopus or its arms while the scene plays (`Enemy.spared`: the game runs on under a
  cutscene, and towers would cut him free before the player could act). Towers and units go for an arm holding one of ours first (`Scenario.arms_first`: `Enemy.holding`, set by the octopus;
  `MilitaryBehavior.enemies_near` puts those first), never the octopus while he is held. Once that scene is over his `RESCUE_HOLD` 20 s run: the arm hurts him (he has 8x a villager's HP) and then pulls him
  under. A countdown floats over him and stands in the objective. Cut free he runs for the church (`Civilian.run_home`; the objective
  says "running for the church"); any arm that catches him again (on the way, or the moment he is freed) holds him in the shallows with a
  new `RESCUE_HOLD` from the moment it takes hold, never drags him straight under (`OctopusBehavior.catch_hold`: only for whom a
  scenario names, here only him during the rescue). Drowned, the objective is crossed out in red. Rescued once he is home in the church: the priests tell (the Hand, why they hid it, vampires,
  something in the deep, others know). Drowned: they shut Brenna out (`ScenarioRunner.hero_moves_out`: a tent near the west gate is her
  home; `Hero.barred`: she never sets foot in the village, a gate included, until they trust her: her ways go round it,
  `Pathing.find_path_outside`, and she leaves enemies inside alone) and say nothing. Either way the octopus goes back to the abbey.
- **The Legion** (`LegionCompany`): a column with Lysa at its head, always down the north road (its edge spawn on the north edge,
  `_legion_spawn`; front of the wave's queue, 0.45 s apart) in wave 6 (rescued) or waves 6,
  7 and 8 (drowned; columns growing). It goes for the relic: the abbey's **seal** (600 HP, a bar; every soldier near the abbey strikes it),
  the relic on the ground (Lysa picks it up at once), the church (they break in as ever; Lysa searches it 8 s). Seal broken: the leviathan
  wakes and Lysa searches the crypt (8 s). With the relic she walks back to the edge she came from: there the scenario is lost. Beaten she
  drops it (a dropped "sack" with the relic, drawn as the sword); her soldiers stand round it until it's taken, then go for the village.
  Lysa is always seen (`keep_in_sight`); the wave's scene follows her with the camera while she walks (`"follow"`). Rescued branch: the column beaten with the relic still in the crypt, the priests unseal it.
  Drowned branch: after wave 8 the priests let Brenna in (a talk), then unseal the crypt, or give her the relic if they hold it.
- **The relic** (`mark["relic"]`: "crypt", "lysa", "ground", "hero", "home"): Brenna loots it in Explore mode and carries it home (never a
  gatherer: dropped loot holding an `"item"` is the hero's to carry; the
  church keeps it); shut out, she takes it to the east gate and the priests take it in (it is theirs until they trust her).
- **The leviathan** (outside the waves; HP x5, its blast as ever: 34.5 HP/s while it lasts with the scenario's enemy scale, 30 on Normal elsewhere) wakes when the crypt is first used: Brenna going in (it blocks the crypt,
  `Treasure.blocked`, until it is slain; she is driven off) or the seal broken. While it lives it keeps to the crypt while the relic is in it,
  goes for a boat coming in (and sinks it, goods lost), else blasts the shore near the village.
- **Pell's boats** after waves 2, 5 and 8 sail in to the pier; a cart (`ScenarioCaravan`) takes their goods from the quay to his stall
  (60 food, 80 material, 40 gold).
- **Winning** (`Scenario.can_win`): the relic home and Brenna's, and the leviathan slain. Relic home with the leviathan alive: the priests
  ask her to slay it (a choice): yes, the objective; no, a messenger goes to Fiona, and a wave later her decree brings the objective.
- **Cards:** a watch on the water; the First King's Hand (waits for the crypt to open). **Hints:** crab, the rescue, the Legion, Lysa with
  the relic, the relic on the ground, necromancer, vampire, siren, the leviathan, Brenna badly hurt. **Objectives** (shown as they come):
  save the priest (optional, its countdown); keep the relic from the Legion (optional, the seal's state); bring the Hand home; slay the
  leviathan.
- **Defeats:** Pell dies; Brenna is downed; Lysa gets away with the relic.

### 7.16 What scenarios 10 and 11 added to the engine

- **Commanders** (`Config.ENEMIES`, `CommanderBehavior`, campaign-only):
  - *Legion Marshal* (`legion_marshal`; scenario 10's Halvard): 760 HP, speed 0.8, 16 damage every 1.4 s, projectile ×0.75, `siege` 2.
    Every Legion soldier within `command_radius` 3 (himself too) strikes and shoots 1.3× as fast (`command_haste`) and takes ×0.75 damage
    (`command_guard`, not on pure damage): `Enemy.haste` / `Enemy.guard` (`Enemy._lead`, every 0.5 s; the strongest banner or commander
    counts). A double gold ring on the ground shows how far. Every 30 s (`rally_every`, the first after 20 s) while he lives and a wave
    runs, he sends 2 footmen (`rally`) for the wave from a random edge spawn, logged. He can be killed (released). 80 gold.
  - *The Crowned King* (`legion_king`; scenario 11's Rhodri): 1000 HP, speed 0.85, 18 damage every 1.4 s, cleave 0.6 within 1.3, command
    radius 3.5 (×1.35 haste, ×0.7 damage), a rally of 2 footmen and a guardsman every 25 s (first after 15 s). `"downed"`: at 0 HP he keeps
    1 HP, falls back (`Enemy.retreating`: untargetable) along his road ×1.4 as fast and vanishes at its end (no release).
  - Art: `unit_legion_marshal` (dark plate, a pale mantle, a baton), `unit_legion_king` (the cold crown, a royal coat, a long sword).
- **A restored ruin as a prebuilt post** (`Scenario.prebuilt`'s `"ruin": i`: the map's i-th ruin of that kind, nearest the village first,
  in the map's order; `ScenarioRunner._restore_ruin`).
- **Reinforcements:** `ScenarioRunner.give_units(list)` puts units into the reserve (and returns them).
- **Scripted caravans** (`ScenarioRunner.caravan(near, cargo)`, `ScenarioCaravan`): a cart along the road from the edge spawn nearest
  `near` to the gate, 1.2 tiles/s in game time; it halts while a wave's enemy is within 3.5 tiles of it (on again once none is within
  4.5; greyed, logged at most every 20 s) and at the gate
  pays its cargo (`delivered`). Enemies don't attack it.
- **The city zone** (`Config.ZONES.city`, map format version 4, zone code `c`; never generated): cobblestone ground (`tile_cobble_0..2`),
  rubble as decor (`city_rubble`), no farms; a zone's `"peaks"` stand on its mountain tiles instead of peaks (standing and ruined houses,
  `house_0..2`, `house_ruin_0..1`), drawn on its own ground (`GroundLayer`), kept by the tidy-up (`MapTidy.peaks`) and offered by the
  editor. Its roads never look like passes.
- **Landmarks:** a campaign treasure with `"landmark"` (its panel line) can never be looted (`Treasure.landmark`): the `throne_hall` (3x3,
  art `throne_hall`: a pale stone hall, a slate gable, cold-lit lancet windows, a tower with the crown's banner).
- The burst `curse` (black-violet tendrils creeping out and a shadow rising, 2.4 s). Portraits: `portrait_halvard`,
  `portrait_fiona_cursed`. The campaign page shows no "still to come" line once every planned scenario is built.
- **Maps:** `tools/make_scenario_map.gd` makes a city (`"city"`: zones by distance, natural mountains in it levelled, houses in 3x3 blocks
  between lanes every fourth row and column, off the roads and 4 tiles clear of the walls, steppe spots with trees, the throne hall by a
  road near the edge).

### 7.17 Scenario 10 as built (`scenario_10.gd`)

- **Map:** `data/maps/wardline.json` (scenario 3's).
- **Baseline:** Easy, enemies at 1.15; 450 gold, 260 food, 360 material; two builders, two farmers, Einar the forester, two gatherers,
  Pell; every hut and piece standing; Pell's guild market (level 3), a second farm, barracks (level 3: a warrior 6, a halberdier 5, a
  berserker 5), training grounds; the four Wardline towers restored and manned (a crossbowman 6, a swiftbowman 6, an archer 8, a swiftbowman
  5; the first two at level 2) and the Wardline barracks (level 2: a shield bearer 7, an inquisitor 4); a watchtower on each road (a High
  Priest 4, a crossbowman 5, a fire summoner 5); two wall towers (an archer 7, an acolyte 6); an archer and a shield bearer (5) in the
  reserve. Brenna is level 16.
- **Rules:** everything unlocked, recruiting open; specialising, training grounds; **no revive**; Pell must not die.
- **Waves:** sixteen, from 3-4 roads: Wilderness first (goblins, orks, rats, thieves), witches, gargoyles and a slime in 3; the Legion
  from wave 4 (footmen, archers, banner-bearers, guardsmen) with Undead and Evil (vampires, necromancers, spider mothers) growing to wave
  16. **Torben** (a captain) leads wave 8, **Lysa** wave 12; wave 16 brings **Halvard** down the Wardline road with 2 guardsmen and a
  banner-bearer, Torben and Lysa with him. Wave 1 waits to be called; 40 s between waves.
- **Caravans:** a guild caravan (80 gold, 60 food, 100 material) sets out down the Wardline road when waves 3, 6, 9, 12 and 15 start.
- **Story:** the intro (dusk on the wall, torches on every road; Lysa and Torben: "I will free them"; Einar: "Ah, my girl! How goes it?" /
  "Father, the Legion is coming. Get everyone inside!"); after wave 1 Pell; after wave 2 Fiona's rider (her mages are coming); after wave 3
  Lothar's **demand** (a choice: *Open the gates* loses); wave 4 the Legion's drums; after wave 4 Idris brings **Fiona's three mages** (a
  fire, an ice and a healing mage, level 5, into the reserve); waves 8 and 12 Torben and Lysa; after wave 8 Brenna on Torben; wave 16
  Halvard ("Then hold it."); his fall; the outro (Halvard, dying, holds Brenna's hand: "Thank you."; Fiona rides for the capital with the
  priests, the mages and the Hand).
- **Cards:** the line is manned (upgrade a unit), the guild's caravans (waits for the first; done when one is in), Fiona's mages (station
  two), the marshal (bring him down). **Hints:** Legion archer, banner-bearer, captain, a caravan halted, the marshal's rally, spider
  mother, Brenna badly hurt. **Objectives:** hold the village through 16 waves; bring down Halvard; bring in the guild's caravans
  (optional).

### 7.18 Scenario 11 as built (`scenario_11.gd`)

- **Map:** `data/maps/capital.json` (*The Capital*; `make_scenario_map.gd -- 11`: Temperate, seed 1111, its unlock sites, lairs, camps
  and mines taken out; a city 24 tiles round the village and 9 round the throne hall, ash land beyond, four steppe spots with oaks and
  pines; the throne hall by the north road 3 road tiles from the edge).
- **Baseline:** Easy, enemies at HP 1.25, damage 1.2; 520 gold, 240 food, 380 material; two builders, two foresters, two gatherers, Pell,
  **Fiona** (a resident in her house); every hut; 5 walls, 3 gates, 2 wall towers at 70 %; Pell's stall (level 2), barracks (level 3: a
  warrior 7, a halberdier 6, an inquisitor 6), a watchtower on each road manned by **Fiona's mages** (fire 7, ice 7, healing 6; bound:
  no orders), a crossbowman 7 and an archer 8 on the wall towers; an archer, a shield bearer, an acolyte, a summoner and an apprentice (6)
  in the reserve. Brenna is level 18.
- **Rules:** **no farms** (none can be built, the city and ash land grow nothing); no worker camp at the start (no trees by the walls: the
  player builds one by a grove); everything unlocked; no revive; Pell and Fiona must not die.
- **Waves:** twelve, every category with the Legion at full strength. **Wave 12:** **Rhodri** (the king) comes out of the throne hall's
  road with **Lothar** (a court champion with the herald's look, HP ×0.8), 3 guardsmen and a banner-bearer. Wave 1 waits to be called; 45
  s between waves. After every wave but the last a **food cart** (70 food, 30 material) comes down the road farthest from the throne hall.
- **Story:** the intro (Brenna gives Fiona the First King's Hand; the mages hold the ward, Pell the food; Rhodri on his throne smiles);
  after wave 1 Pell on the carts; after wave 4 Rhodri's voice over the city ("I followed a man. Not a crown."); after wave 8 Fiona on her
  brother; wave 12 Rhodri and Lothar come out ("Enough. I'll do it myself."); Rhodri at half HP ("Why does it hurt?"); Rhodri beaten,
  fleeing into the throne hall; Lothar, the last of the court, falling; the outro (the empty throne hall; Rhodri, himself for a moment,
  asks Fiona to do it; she beheads him with the Hand; the crown breaks, the curse spreads and goes into her; her eyes turn black; the end
  of the campaign). Won with the game's win sound when wave 12 is over and Rhodri beaten.
- **Cards:** the last camp (station the army: ten on posts), timber (a worker camp by a grove), no fields here (done with the first cart),
  the king (beat him). **Hints:**
  food short, banner-bearer, guardsman, spider mother, material short (the steppe trees), Brenna badly hurt. **Objectives:** hold the camp
  for 12 waves; beat Rhodri.
