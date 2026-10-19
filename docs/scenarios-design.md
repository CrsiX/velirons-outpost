# Scenarios design

Status: **scenarios 1 to 3 and the scenario system are built** (§7 says how, and what was decided for them); scenarios 4 to 11 are planned. This
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
| 9 | The Drowned Abbey | A drowned abbey on a delta shore | Coast | No | leviathan (scripted boss), giant octopus (guard), Dread Legion forces | none | Retrieve the First King's Hand, hold 10 waves |
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

**Objective:** hold the town for 9 waves until the neutral guild's convoy is loaded and leaves. The **warehouse** must survive (defeat if it
falls). The guild master, Wenna, must not die.

**Monsters:** Wilderness and **Renegades** in numbers: thieves, and possibly bandits hired by a rival guild (*open*). The harbour adds the first
**crabs** (Wilderness, aquatic) and, at most, **one siren** (Arcane, used sparingly): they come up the river and the coast. Both are built
(`aquatic-design.md`): the crab is a goblin that swims, the siren a support monster whose song pulls and slows our units and whom melee cannot hit
while she is in the water. The map needs a water body big enough for them (6 deep tiles) and water spawns, made in the map editor.

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

**Starting point:** a ruined fortress with a few survivors (the veteran **Sigmund**, a named warrior as flavour). A small barracks. Shield bearers
and archers
unlocked.
The market is Pell's wagon. Hero level about 7. **No revive.**

**Objective:** find **three pieces of evidence** around the pass (treasures, some guarded by monster camps) *and* hold the fort for 10 waves.

**Monsters:** Wilderness, Renegades and the first **Arcane** (*open*: witches, gargoyles). In the last wave the first **Dread Legion** patrol
arrives: Rhodri's soldiers, sent to finish what the pass began. Brenna knows them: they are her old company, with **Lysa**, her captain, and her
comrade **Torben** among them.

**Problems:** the evidence lies far away, so the hero must leave the fort, with no revive. Monster camps guard the farthest pieces (the hero
attacks one only on the player's order). The fort is hard to expand because of the terrain.

**Events:**
- Sigmund tells the story over the first waves, in pieces.
- The three finds: Rhodri's written order for the garrison, the roll of the fallen (Brenna's company), and a seal that matches a letter from one
  of the neighbouring courts (an object that does not settle whose).
- At the last wave the gargoyles of the fort's old gate come alive, fly out and then attack.

**Story covered:** how Brenna was **betrayed**. Rhodri ordered the pass held with no relief, so that her company could be given to the crown's
ritual. She saw it: Rhodri came to the pass himself, the crown on his head glowing pale, and the ritual did not kill them, it **bound them to
Rhodri**, taking their will (the first trace of what the crown is: `story-design.md` section 4). **Why she was not bound:** she was not in the
fort. Her captain, **Lysa**, uneasy about the order, had sent her down the pass the night before with a plea for relief; Brenna came back without
it and watched from the ridge, too late and alone. Nobody would have believed a deserter against the crown, so she went home and was thought
dead: the roll of the fallen lists the whole company, her too. They are alive, and they are the core of the **Dread Legion**. Lysa saved her and
is bound herself, which is why Brenna wants to free them (scenario 10). This is where Brenna stops being neutral (`story-design.md` section 2).

**Intro cutscene:** Brenna sees the fort again for the first time since she left. The gate, the barracks, the field where the company stood.

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

### 9. The Drowned Abbey

**Where:** a pilgrims' ferry village on a drowned shore, with the church's old abbey half-sunk in the delta beyond it, reached by a causeway.
Map: Coast, a river delta with an island (*target*).

**Starting point:** a small village of ferrymen and the church's last survivors (a few priests who hide out of fear of Rhodri). A short causeway
to the abbey island, water on
several sides. Pell's wagon, and his guild's boats at the quay. Her band of followers from scenario 8, a baseline: archers, shield
bearers, mages, acolytes and summoners, all unlocked. Hero level about 14. **No revive.**

**Objective:** retrieve **the relic**, the **First King's Hand**, from the abbey's flooded crypt *and* hold the village for 10 waves (*target*).
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
- Whether the warehouse (4) is a defeat condition. Fiona's death always is.
- Whether bandits are a new Renegade kind, and whether the rival guild hires Renegades.
- The Dread Legion: unit kinds and names, how its camps, ranks and banners work (a banner-bearer could buff like the war cry), and its place in the
  mid-boss design (the marshal).
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
  a journal, a letter, a logbook, on parchment over the paused game, `Journal`). Objectives can be `optional` (shown, not needed to win).
- **Not built yet:** saving a scenario (`Game.save_error` refuses it, there is no autosave; the stall and the merchant aren't in saves either),
  upgrading the stall in play, guard mobs, bosses, scripted caravans, choices, the Legion's death effect, anything carried between scenarios (by
  design: nothing carries over).

### 7.2 Cutscenes

- **In the engine, with dialogue** (`Cutscene`, `cutscene.gd`): the game runs on at 1x behind black bars, the HUD hidden and the map's input off;
  the camera moves between spots; people speak in a box at the bottom (portrait, name in their colour, the line typed out); the narrator's lines
  have no portrait and are centred. A tap, click, Space or Enter shows the whole line, then the next; *Skip* (top right) or Esc ends it.
- A scenario writes a cutscene as a list of steps: `say` (speaker id, text), `camera` (a world position, zoom, time), `wait`, `fade` (in / out),
  `title` (a title card), `do` (a scripted action: a cart on the road, dusk), `until` (wait for a condition). The runner has helpers for them:
  `at(tile)`, `actor(art, tile)`, `move_actor`, `road_in`, `dusk`.
- The speakers' portraits are generated art (`portrait_brenna`, `portrait_einar`, `portrait_pell` in `tools/gen_art.py`).
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
  on the tower, a second farm (food), call wave 1, a gatherer, promote the archer, repair a gate or wall tower.
- **Hints** (once each, on the card and in the log): a villager fleeing an enemy, a villager hurt, food falling below 60, enemies inside the walls.
- **Objectives:** survive the 5 waves; every hut rebuilt; every gate and every wall tower whole (walls are not required); more villagers than at
  the start; food not falling. All at once win it.
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
- **Story:** the intro (a title card; a few weeks later; Pell's cart at the north gate; the reunion: she wasn't at the capital, and they leave it at
  that; where can he set up his stall); after wave 1 Pell tells of King Orsin's death and the war of his children, Fiona and Rhodri; after wave 3 a
  stranger from a rival guild walks up the road and asks questions; after wave 5 Pell tells of the guild's split; the outro (dusk at the stall:
  the road to the border town is cut where the Wardline stood; help restore it and the guild can send caravans).
- **Cards:** Pell's stall (placed on a marked spot by the road, or anywhere), trade (buy a lot), Brenna explores (she claims the broken
  watchtower), restore it, her level, barracks with a shield bearer, a tower upgrade.
- **Hints:** Pell fleeing, rats on the farm or the stall, food low. **Objectives:** survive the 7 waves; Pell's stall standing; *optional:* buy
  something from Pell.

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
  watchtower gives up a page of its garrison's journal (four pages; the third says what the light stones between the towers are for), one at a
  time; the restored barracks its logbook: the order to abandon the post, signed in both Fiona's and Rhodri's names, in a careful square hand,
  and Brenna knows it: Lysa's, her old captain's; the outro (the first guild caravan comes down the lit road; word from the border town: the
  guild's store there is under pressure; Brenna leaves home with Pell; from here on nobody can bring her back).
- **Cards:** claim the ruins (Explore), restore a tower, specialise an archer, training grounds with a unit, Train mode (a level from Brenna's XP),
  light the road (a light stone where the road is dark).
- **Hints:** thieves on the road, Pell fleeing. **Objectives:** every ruined watchtower restored and manned (4); the barracks restored and manned;
  the road of the line lit: every road tile from the village out to every ruin site watched by one of the village's buildings (what towers and
  light stones see, not where people walk; `ScenarioRunner.lit`).

