# Scenarios design

Status: **the whole campaign (scenarios 1 to 11) and the scenario system are built** (§7 says how, and what was decided for them). This
page outlines the campaign: eleven scenarios that tell the story in `story-design.md` (read that first; names, places and the cause of the war are
explained there). It holds the intent and the story beats; the numbers (resources, waves, levels, HP, timers) live in each scenario's own file
(`scripts/scenarios/scenario_<n>.gd`, never in `config.gd`) and are not copied here. *Open* means not decided.

## 1. Structure

- The campaign is **eleven scenarios played in order**. Each one has its own scripted baseline (map, village, units, resources, hero level, what is
  unlocked). **Nothing carries over** between scenarios, so any scenario can be replayed alone. Only the story carries over.
- Every scenario has an **intro cutscene** and an **outro cutscene** (when the objective is fulfilled). The player can **skip** any cutscene.
  Between them the game plays as usual, with the story told through the library, treasures, the event log and a few scripted events.
- The hero is **Brenna Hale**. Her being downed is a **defeat** in every scenario except 1 to 3 (home, she revives as in the normal game).
  Scenario 10 is at home but has no revive: she cannot leave her post, which is the point of it.
- Scenario 1 has a rule of its own: it is also a **defeat if any villager dies**. It teaches caring for the villagers; no other scenario has it.
- **Pell must not die** in scenarios 4 to 11: his death fails the scenario. **Fiona's death** is always a defeat too, wherever she appears (7 and
  11), as is Brenna's where she cannot revive.
- The **tutorial is merged into scenarios 1 to 3**, piece by piece (section 4).
- **Any building can start ruined** in a baseline. Repairing a ruin is **cheaper than building new**.
- Scenarios 1 to 3 and 10 are at the **home village**, the others are **away**: Pell asks Brenna to come with him, and each away scenario has its
  own place. Home bookends the campaign: she rebuilds it, leaves, and defends it at the end.
- **Pell's market** is present from scenario 2 on. At home it grows (peddler, stall, guild market, see `story-design.md` section 6). Away it is
  his wagon, a smaller stall (in the guild's town of scenario 4 it is the full market).
- **Monsters arrive by category** (`story-design.md` section 5), so the campaign also introduces the library's categories one after another:
  Wilderness (1, 2), with its sea monsters (crabs in 4, the octopus and the leviathan in 9), Renegades (3, 4), Arcane (the siren in 4, witches and
  gargoyles in 5), the Dread Legion (first patrol in 5), Undead (6, with the first necromancers, an Evil kind) and Evil (vampires from 8).
  The Dread Legion is Rhodri's organised army (`story-design.md` section 5) and leads scenarios 10 and 11. All the others join it there.

## 2. Overview

| # | Name | Where | Map | Hero revives | New monsters | New units unlocked | Objective |
|---|---|---|---|---|---|---|---|
| 1 | Homecoming | Home (ruined) | Temperate | Yes | Wilderness, weaker | Archers, no specialising | Rebuild, grow the economy, survive; no villager may die |
| 2 | The Old Friend | Home | Temperate | Yes | none new | Barracks, shield bearer | Survive, trade |
| 3 | The Wardline | Home | Temperate | Yes | Renegades | Specialisations, training grounds | Restore the ruined towers |
| 4 | The Split | The guild's trading town | Coast | No | more Renegades, crabs, one siren (Arcane) | none | Hold until the convoy leaves |
| 5 | The Betrayal | Brenna's old fort | Highlands | No | Arcane (witches, gargoyles), a Dread Legion patrol | none | Find the evidence, hold the fort |
| 6 | The Dead | A battlefield village | Desert | No | Undead, the first necromancers (Evil) | Acolyte (chapel) | Bury the dead |
| 7 | The Exile | Fiona's refuge | Temperate | No | none new | Apprentice (mage's tower), Summoner (stone circle) | Hold the refuge |
| 8 | The Pale Court | The capital's outskirts | Volcanic | No | vampires (Evil), Dread Legion camps | none | Clear the crypts |
| 9 | The Drowned Abbey | A drowned abbey on a delta shore | Coast | No | leviathan (scripted boss), giant octopus (guard), Dread Legion forces | none | Retrieve the First King's Hand, slay the leviathan |
| 10 | The Last Wardline | Home | Temperate | No | all, led by the Dread Legion | none | Survive the Legion |
| 11 | The Crown | The capital | Capital city (new, section 6) | No | all, the Dread Legion in force | none | Defeat Rhodri, survive the last wave |

Hero level and the units the village starts with are part of each baseline: the hero starts low in scenario 1 and rises steadily to a high
level in the last, and the units match. Whether a scenario's units are unlocked from the start, or must be found on the map as in the normal
game, is stated per scenario.

## 3. Scenarios

### 1. Homecoming

**Where:** the home village and its surroundings, a ruined outpost. Brenna starts **outside** it. The map is a fixed, hand-made Temperate
map ("Brenna's Home", deliberately small; section 4).

**Starting point:**
- **Brenna** wakes in a small tent **outside the village** (she slept on the way home). Step one is that she goes to the village: a short
  scripted walk after the intro cutscene (the player has no command to move her).
- **The village:** its walls, gates and wall towers are almost all destroyed and fewer than half the huts stand. **One broken watchtower** lies
  outside, on a road (a ruined watchtower in the game's sense, with a use in scenario 2).
- **Villagers:** one builder, one farmer and one forester. The forester is **Brenna's father, the village's lumberjack**, **Einar**.
- **Resources:** little, but enough for a first archer and the first repairs.
- **Units:** the player can hire **archers** from the start. They can be levelled up but **not specialised** yet. No barracks and no training
  grounds. New watchtowers can be built.

**Objective:** *rebuild and survive.* Survive a short run of waves; have every hut, gate and wall tower repaired (how much of the walls: the
scenario decides); bring up the economy (food not falling, more villagers than at the start).

Defeat is the usual **and also if any villager dies**.

**Rebuilding:** any building can be ruined, so any one may need repairs. A repair is **cheaper than building new** (a ruined watchtower already
costs half). The builder works through the repairs in the order the player chooses.

**Monsters:** Wilderness, kept **weaker on purpose** (an enemy strength setting below Easy). Wave 1 is goblins, **rats come from wave 2**,
**orcs from wave 3**, **slimes in the last wave**. The scenario overrides the normal wave mix.

**Problems:**
- One builder, one farmer, one forester: every repair competes with food and gold. Gold comes only from kills and corpses.
- The village is open: enemies walk through the broken walls, and a gate only holds them for a while. The player decides what to repair first and
  where the first tower goes.
- **No villager may die.** An enemy that reaches villagers or burns a hut kills one, so the enemies must be stopped before they get in. Starvation
  kills a villager when food stays at 0, so the farm comes early. Outside the walls the builder, farmer and forester can be hurt, so the player
  must watch the roads.
- Rats bite villagers at the farm (a little), so the farm needs cover.

**How hard it is:** *easy-ish to play through, harsh if done wrong.* The scenario should teach at once: **care for your villagers, care for the
economy.**
- *Easy side:* weak enemies, wave 1 waits for the player, the first waves are small, and a tower with an archer is enough early.
- *Harsh side:* a death ends the run. The ways to lose are the lessons: food at 0 starves a villager; a builder or farmer left outside during a
  wave is hurt; an open gate lets rats and goblins reach people; spending all gold on one thing leaves nothing for the next repair.
- *Teaching the lesson:* the first time food is falling, a villager is hurt or someone is outside while enemies are near, a card or log line says
  so. A defeat is quick to retry, and its screen names the cause ("a goblin killed the builder").

**Events:**
- Arrival: Brenna's father greets her.
- Wave 1 waits until the player calls it, so a tower and an archer come first (as in the old tutorial). After that waves follow on the normal
  countdown.
- Wave 2: the first rats. Wave 3: the first orc. The last wave: slimes, a last test.

**Story covered:** who Brenna is (a royal knight who came home to a half-burned village) and her father. The kingdom is in trouble and this
village is remote. The war is a rumour, no more.

**Intro cutscene:** Brenna wakes in a small tent outside the village, on the road she came by. She walks out and sees the village in the distance:
broken walls, smoke.

**Outro cutscene:** the last wave dies. A figure with a cart is on the road, lantern lit. Brenna says his name: **Pell**. He replies to greet his
old friend.

### 2. The Old Friend

**Where:** the home village again, a few weeks later.

**Starting point:** the village repaired, a farm, a camp, two towers with archers, **no barracks yet**. The broken watchtower from scenario 1
still lies outside. Pell (he came at the end of scenario 1) has helped rebuild, and now asks for a place for his wares: the player places his
stall. Specialisations are still locked.

**Objective:** survive the waves while keeping Pell's stall running: once it has stood, losing it (devastated, or torn down) loses the scenario.
Pell must not die. *Secondary:* buy something from him (a first use of trade); the walls hold.

**Tutorial pieces:** setting a building (the stall), the hero (exploring, which claims the broken watchtower, and levelling up), the barracks with
a shield bearer, tower upgrades, and trade through Pell.

**Monsters:** Wilderness: goblins, orcs, rats, slimes.

**Problems:** food is short (more mouths with Pell's party), so farms matter. Rats go for the farms and the stall's goods. The player learns to
spend gold on material through Pell.

**Events:**
- Pell arrives as a peddler and wants to set up a stall. Building it starts the wave 1 countdown.
- A mid-scenario rat pack tests the farm defence.
- A scout from a rival guild turns up asking questions (flavour, foreshadows scenario 4).

**Story covered:** Pell and Brenna are old friends. The world outside: the old king is dead and his two children fought over the crown (Fiona and
Rhodri are named for the first time). The merchant guild split. The border towers stand empty.

**Intro cutscene:** the reunion at the gate. Pell is tired and thinner than she remembers. They do not talk about what happened, only that she was
not at the capital.

**Outro cutscene:** Pell tells Brenna what he needs: the road to the border town is cut where the Wardline's towers used to stand. If she helps
him restore it, his guild can bring caravans.

### 3. The Wardline

**Where:** the home village and the road toward the border, all on one map: the map of scenarios 1 and 2, grown larger with more detail.

**Starting point:** the village at a stable baseline (all huts, a barracks, several towers, a market stall). Ruined watchtowers lie along the
road. **Specialisations are unlocked** (from unit level 3).

**Objective:** claim, restore and station the ruined watchtowers and the one ruined barracks along the border road. The hero claims them in
Explore mode, a builder restores each for half its price. Build light stones to light up all the ways between the restored towers. Survive the
waves while doing so.

**Tutorial pieces:** specialising a unit (the archer's branches), the training grounds with the hero's Train mode, and the ruined towers themselves.

**Monsters:** Wilderness, and the first **Renegades**: thieves (a *bandit* kind was considered and decided against for now).

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

**Starting point:** a village of guild staff (huts, a guild house, a warehouse), one of whom is the guild master **Wenna** (named NPC), living in
the guild house. A small garrison, little gold. The full guild market is here. Brenna arrives with a few units. **No revive.**

**Objective:** hold the town until the Silver Thread Guild's convoy is loaded and leaves. The **warehouse** must survive (defeat if it falls). The
guild master, Wenna, must not die.

**Monsters:** Wilderness and **Renegades** in numbers: thieves. The harbour adds the first **crabs** (Wilderness, aquatic) and, at most, **one
siren** (Arcane, used sparingly): they come up the river and the coast. Both are built (`aquatic-design.md`): the crab is a goblin that swims, the
siren a support monster whose song pulls and slows our units and whom melee cannot hit while she is in the water. The map needs a water body big
enough for them and water spawns, made in the map editor.

**Problems:** two threats. Raids from the wilderness and Renegades on the roads, and a rival guild whose caravans block the south road and whose
hired fighters raid the warehouse. Thieves go for the stock (only they: the monsters go for the huts), more of them once the coins are found;
crabs and the siren come out of the sea only. The town is small and cannot grow far. Brenna is exposed and cannot be revived.

**Events:**
- A rival guild's master offers Brenna gold to leave (a choice). If accepted, instant loss of the scenario.
- Late in the scenario a captured Renegade carries coins of a foreign mint.
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

**Starting point:** the fort stands whole and empty: nobody is there when Brenna and Pell arrive. Two walls close the pass, each from mountain to
mountain with a gate in the middle and a wall tower at each end; the mountains are the fort's sides. Inside, a road runs from gate to gate, with
a few huts, two barracks and training grounds beside it (all empty). Pell lives in one hut, the others are free: the fort holds very few people.
Pell sets up his wagon (a peddler's stall) outside the south gate. No farm, no other villager. **No revive.**

**The land:** north of the range lies forest, the wilderness: every monster camp is there. South of it lies meadow and steppe, the safer side
(the kingdom's). Roads come down to the pass from both halves, so enemies come from both sides. **Sigmund**, the old veteran, camps in a tent on
the south side: the fort's people scattered after that night and he would not sleep inside its walls. Found (his tent uncovered), he joins as a
builder and moves into the fort, and the waves begin.

**Objective:** find **three pieces of evidence** on both sides of the range (treasures; the two in the north guarded by monster camps) *and* hold
the fort for the waves. Sigmund is not a piece of evidence.

**Monsters:** Wilderness, Renegades and the first **Arcane** (witches, gargoyles). In the last wave the first **Dread Legion** patrol arrives:
Rhodri's soldiers, sent to finish what the pass began. Brenna knows them: they are her old company, with **Lysa**, her captain, and her comrade
**Torben** among them.

**Problems:** the evidence lies far away, so the hero must leave the fort, with no revive. Monster camps guard the farthest pieces (the hero
attacks one only on the player's order). The fort is hard to expand because of the terrain, and its few huts limit the village: when Sigmund
comes, someone may have to make room for him.

**Events:**
- Sigmund is found on the south side and joins; he tells the story over the first waves, in pieces.
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

**Starting point:** a small village of survivors (huts, a priest, no gatherers yet: the player recruits the gravediggers). The chapel is a
**ruined chapel** that unlocks the **acolyte**. Pell's wagon. **No revive.**

**Objective:** **bury enough of the fallen** before they can be raised. Awakening the chapel is part of it. The waves continue until enough are
buried.

**Monsters:** **Undead** (skeletons), the first **necromancers** (from the middle waves), Wilderness leftovers, a few thieves and witches.

**Problems:** every corpse is a threat because necromancers raise them, so the gatherers must go out into danger. Food is poor on this land. The
acolyte's holy damage is the answer to the Undead, but the player must find and unlock it first.

**Events:**
- At the start the priest, **Anselm**, asks for help and says the chapel is not dead, only sleeping.
- Wave 3 brings the first necromancer.
- The chapel awakens when the hero visits it, and the acolyte becomes available.

**Story covered:** the war's scale. The unburied dead are why the Undead rise. These were Fiona's soldiers and mages, who fell here, and Rhodri's
soldiers. The church tried to bury them and could not. Why the dead rising is not Rhodri's will alone: he feeds on the war, but everyone's dead
rise.

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
**apprentice**, the **stone circle** the **summoner**. Pell's wagon. **No revive.**

**Objective:** earn the trust of Fiona. Hold the refuge while the court mages finish a working that hides the valley from the Evil. Fiona must
not die (if her house falls, she dies by the usual rule that the villager in a lost house dies, so it is the same). During the druids' wave, no
druid may die.

**Monsters:** Wilderness and Undead drawn by the magic, some Renegades, a few witches.

**Problems:** the refuge is magical, so the monsters keep coming. The druids will defend their grove but will not take part in the succession.
Fiona does not fight. Trust: she has reason to distrust a knight of Rhodri's army, so she rejects Brenna and wants her to earn trust first.
While Fiona rejects Brenna the player can build nothing and villagers cannot be commanded; existing buildings can be used and military hired.

**Events:**
- At the start Brenna and Fiona meet, with little warmth. Fiona does not want Brenna in the refuge, so Brenna starts a bit outside in a tent.
- After wave 2 Fiona opens up a little. Villagers can be commanded and recruited; buildings may be repaired or rebuilt but not newly built.
- At wave 5 the druids' grove is attacked, and the summoner is unlocked. The druids' elder calls for help, and says why the druids stayed
  out of the war (`story-design.md` section 4, the unlock sites): their pact with the first king (the druids keep the land, the crown keeps the
  border, neither meddles in the other's affairs; who wears the crown is the crown's affair), and the church on Fiona's side once drove them from
  the towns, so they owe her side nothing. They fight for their grove, not for her.
- After wave 7 Fiona permits new buildings. She tells Brenna, in a scene, why their father never named her (`story-design.md` section 4, *Why
  Orsin named no heir*): the law and his wish were hers, but the army would not follow a queen, and crowning her against it would have left her
  a crown and a rebellion; naming Rhodri would have broken the law, set the church and the mages against the crown, and put power in the hands
  of a son he knew was greedy for it. So he waited to win the officers over, told no one, and died first. Her line to end it: "He was waiting
  for your side to change its mind. I was his answer, and he never gave it."
- At the end of the waves the working completes.

**Story covered:** Fiona's side (above). What the court mages and the church saw: Rhodri changed after the **envoys came**, but Fiona cannot
say from where. A parallel: two women, both rejected by the same side, and Fiona now rejects Brenna for having served it. Brenna came because of
what was done to her company: Fiona learns that her brother's crown binds people, and that Brenna has nowhere else to go.

**Intro cutscene:** Brenna and Pell come out of the trees into the valley. Fiona waits at the gate with two mages.

**Outro cutscene:** Fiona gives Brenna a sealed scroll and asks her to deliver it to the court mages. She explains, only someone of House Aldmoor
can end what Rhodri has become, but she cannot go yet, and they need more allies and more strength. She must keep the mages alive until the Crown
is within reach. Brenna promises to bring her there when the time is right.

**Decided:** the druids are three named **druid summoners** on the benches of their **grove** (a campaign barracks by the stone circle). They
fight for it as barracks units do, but take no orders. A druid downed during the grove's wave is a defeat; at other times they revive as usual.
The trust phases: Brenna lives at her tent outside the walls and the villagers take no orders until wave 2 is over; then she may move in and
villagers, repairs and rebuilding open; after wave 7 new buildings. Built as §7.12.

### 8. The Pale Court

**Where:** the outskirts of the burned capital, a ruined court district on ash land near a volcano.

**Starting point:** a camp inside a ruined district (a few huts, Pell's wagon behind a wall). Brenna has **no army**, only a band of followers:
court mages and acolytes who came with her from Fiona's refuge, and a few archers and other volunteers (the units unlocked by now). **No revive.**

**Objective:** clear **the three crypt lairs** under the court. The hero does this on the player's order, while the camp holds.

**Monsters:** **Evil**: vampires and necromancers. Undead. Gargoyles (the palace's stone guardians). Witches. The **Dread Legion** holds the
court's gates in camps of soldiers, captains and banner-bearers. Only the herald speaks.

**Problems:** the lairs wake one by one (the game's existing lair rule), so the pressure rises. Vampires heal from the hits they land. Flyers need
ranged units. The hero cannot be downed, so each crypt is a real risk.

**Events:**
- **Lothar**, a herald of the Pale Court (a human envoy, under a white flag), meets Brenna and greets her by name. He carries Rhodri's words, and
  no monster speaks. Lothar is the court's one recurring herald and **survives** until the story needs him last (scenarios 10 and 11).
- Lothar delivers Rhodri's offer: come back to his side. If Brenna accepts the offer, the scenario is lost.
- At the last lair the court's champion, **Rurik**, appears (the first hint of the mid-boss idea in the README roadmap).

**Story covered:** what Rhodri has become and what surrounds him: **the Pale Court** (`story-design.md` section 4), his herald Lothar, marshal and
champion, the Legion at its gates, and the Evil that gathered in the crypts, drawn by the death. The **crown** (`story-design.md` section 4): the
old king's own crown, reworked by a foreign "goldsmith" and now glowing with malice. The corruption is gradual and he is still partly himself.

**Intro cutscene:** the capital by night, the palace dark against a red sky. A herald in pale colours waits on the road under a white flag and
bows to Brenna.

**Outro cutscene:** the throne hall's gate stands open. Brenna sees the crown on Rhodri's head from the doorway and understands that it is not a
gift but something that feeds on him. A church survivor says some of the church's priests hid something that may break such a thing: the **First
King's Hand**, a relic sword, in the abbey that sank in the delta. Nobody knows whether it will. Fiona's messenger confirms it. Rhodri hears that
Brenna refused the offer to join his side and starts laughing devilish.

**Decided:** "no army" means **no recruiting**: Brenna's band waits in the reserve at the start, and gold only levels and specialises it. The
three crypts are **monster lairs** that the scenario wakes one by one; awake, each is one more spawn point of the scripted waves, and a cleared
one stays cleared. The hero clears one as a camp (*Attack with the hero*). **Rurik** is a guard of the third crypt and a boss that can be killed.
The Legion gets three more kinds, all campaign-only, each teaching something: the **archer** (shoots our people outside), the **guardsman** (a
tower shield, so arrows are weak against it) and the **banner-bearer** (Legion soldiers near its banner strike faster). Two optional **Legion
camps** hold the court's gates. Lothar's offer is a choice after wave 3. Built as §7.14.

### 9. The Drowned Abbey

**Where:** a pilgrims' harbour village on a drowned shore, with the church's old abbey on an island in a river delta beyond it. Map: Coast, with
a river and an island (the map and the story were reworked once: 9a says why; §7.15 says how it was built).

**Starting point:** a small village of ferrymen and the church's last survivors (two priests, the eldest and a younger one, who keep their distance out of fear of Rhodri), Pell's wagon,
and his guild's boats at the quay. Brenna has her band from scenario 8, all unlocked. **No revive.**

**Objective:** retrieve **the relic**, the **First King's Hand**, from the abbey's sealed crypt and bring it home, and slay the leviathan that
stands in the way. There is no number of waves to hold: the waves go on until both are done. The hero goes to the abbey on the player's order, as
with a monster camp, fights what guards it, takes the relic and carries it home. If she is downed, it is lost (a defeat anyway).

**Monsters:**
- **Wilderness, aquatic:** **giant crabs** from the shore, and the **leviathan**, a boss that stands between Brenna and the sword. The built
  leviathan (`aquatic-design.md`) is a water-bound serpent that blasts from the water; here it is a **scripted spawn**, much stronger, that
  wakes when the crypt is first used and is outside the waves.
- **Evil and Undead:** necromancers raise the abbey's drowned dead and vampires hold the crypt.
- **The Dread Legion:** a column comes for the relic. It has learned where it lies. Captains and soldiers, no marshal yet (he leads in
  scenario 10).
- Wilderness leftovers (goblins, rats, a spider mother).
- **Guard (not a wave monster):** a **giant octopus** guards the abbey. It does not count for the waves. It never leaves its deep water, and its
  eight arms grab whoever comes within reach and can drown them, the hero included (downed: a defeat here), so killing it from towers by the
  water, or keeping out of its reach, matters. The built octopus is a wave member late in a normal game (`aquatic-design.md`): here the
  scenario places it as a guard and uses it for the rescue.

**Problems:** three fronts at once: the water, the road down the village's bank, and the abbey. The hero has to leave the village with no revive,
so the player must decide **when** to send her. Towers cover the water less well than the road. Flyers (vampire bats, gargoyles) need ranged
units. The leviathan blocks the crypt, sinks Pell's boats and blasts the shore, so it cannot be ignored.

**Events (in order):**
- The first waves teach the water side (crabs); Pell's guild boats ferry in supplies after fixed waves.
- At the start the priests do not trust Brenna: she is military, a knight of the army that serves Rhodri, and Fiona's word (from scenario 7)
  does not change what she wore. They walk their rounds but keep away from her and say nothing about the abbey.
- A priest is caught by the octopus at the harbour. Whether he is **rescued or drowned** decides the branch (9a).
- The Legion's captain **Lysa**, Brenna's old captain, demands the relic. Brenna refuses her own old company. The priests see it.
- When the leviathan is slain and the relic is home, the priests agree that the sword goes to Fiona, and the scenario ends: Brenna has risked her
  life for their village, and they see the goodwill in her.

**Story covered:** the **First King's Hand**: a ceremonial sword of the first king, who founded the Wardline, obviously a relic and not a weapon
for battle. It can "cleanse the blood" and "rule with righteousness", so the church believes it helps against Rhodri, but **nobody knows whether
it does**. Some priests hid it and sank the abbey to keep it from Rhodri. Only someone of House Aldmoor can wield it (Fiona's line from scenario
7). The Legion's captain hunts the sword while the main force marches home. This is not the church's stance (the church supports Fiona) but that
of the priests of this place: they support Fiona, but feared Rhodri could rise over her. They distrust Brenna because she is military, from the
side that serves Rhodri, and they give up the sword only after they have seen her defend their village and refuse her own company for it.
Earning their trust is the scenario's thread, as Fiona's was in 7.

**Intro cutscene:** Brenna and Pell arrive by ferry in mist. The abbey's spires stand out of the water, and a bell rings under it.

**Outro cutscene:** the priests come out of hiding; the eldest says they took her for one of Rhodri's, and were wrong. They agree that the sword
goes to Fiona. The relic glows in Brenna's hands. **Lysa**, the Legion's captain, herself for a moment, says the force at the abbey was only meant
to hold her here: the main force of the Legion, led by the marshal Halvard, is already marching on her **home village**. Brenna turns to Pell: they
must go back. (Lysa does not die: beaten, a captain falls back, and then the binding pulls her away, so scenario 10 stays as planned.)

#### 9a. The rework (built: §7.15)

Replaces the story, the map and most rules of the first version of scenario 9; built as §7.15. Tunable numbers (hold times, wave counts, HP) are
in `scenario_9.gd`.

**Why the rework:** in the first version Brenna fought the leviathan after she already had the relic, with no reason in the story; the
priests' trust came only from holding the walls; the Legion marched on the village although it wanted the relic. Now every fight is about
the relic, the trust is won or lost in one rescue, and the leviathan stands between Brenna and the sword.

**The map:** a shore village by the sea, shaped differently from the standard block, with a small **harbour** (piers, boats, nets, crates, a ferry
bell) and a broad sandy shore with sandbanks, reached through shallow water. Inside the walls stands a **new church**, bigger and newer than the
drowned abbey (a campaign building; the priests' house of worship, and where the relic is kept once it is home). The abbey's island lies in a
**broad river** that runs from the north edge down to the sea beside the harbour, so the octopus and the leviathan can move between them. The island
can be reached **only from the village's side**, over one **straight** bridge (no bends on bridges or fords, so water monsters can pass under
them predictably). The far bank is joined to the rest by one road and a bridge north of the island; enemies may come that way too. The Legion
comes down a road from the north edge on the village's side, so towers by the village can fight it on its way to the island. Made with the map
tool first, then edited by hand in the editor (from then on only targeted edits to the file).

**The people:** Pell and the eldest priest (named, with her own look) must not die; the other priest, the younger one, is the one the octopus
catches, and his death is no defeat. There are only these two: the rescue needs one to lose and one who stays to speak for the church either
way. They live in the new church and are no longer hidden: they walk their rounds outside, in and out of its door (the eldest looks out over
the river from the gate towards the island, the younger blesses the boats at the harbour; as scenario 6's priest).

**Pell's boats:** the guild's supply boats become real: a boat sails into the harbour and ties up at the pier, and its goods are unloaded into a
**caravan** that walks over land to Pell's stall and drops them there, so the goods are seen to arrive (before, only the numbers appeared).

**The seal and the relic:** the abbey's crypt is **sealed** at the start; the seal has HP, like the warehouse's in scenario 4, so the Legion can
break it. The relic can be in four places: in the crypt, carried (by Brenna or by Lysa), lying on the ground, or **home** (in the new church).

**The octopus rescue:** between two waves a priest (not the eldest) walks down to the harbour. Only when he reaches the quay does the guard octopus leave the abbey, come up by the harbour and grab him. It drags him into the shallows and
holds him **unharmed while the alarm scene plays**: the game runs on under a cutscene, and towers would otherwise cut him free before the
player could act. Then he is **held in shallow water** for a while before he is pulled into deep water and drowns; a countdown shows over him
and on the card. He is far tougher than a villager, so the arm's own damage doesn't kill him before the countdown does. Cutting the arm
(towers, ranged units, Brenna) frees him; in this scenario towers and units go for an arm holding one of ours before anything else, the octopus
itself included. Freed, he runs back to the church; only there is he rescued. Caught again on the way, he is held again with a new countdown.
Afterwards the octopus goes back to guard the abbey (and is in Brenna's way when she crosses). (If the octopus is already dead when the
rescue is due, nothing can grab him and it counts as rescued.) This decides the branch:

- **Rescued:** the eldest comes to the gate and tells what the abbey hides (the Hand; why they hid it; vampires in the crypt; something bigger
  in the deep). The saved priest stays in the church a good while before his rounds again.
- **Drowned:** the priests shut Brenna out. She can't enter the village at all, not even a gate (up to the gate is as far as she goes, to hand the
  relic in): a tent goes up outside the walls, as in scenario 1, and it is her home (as in scenario 7: she heals and rests there). Only Brenna is shut
  out: the village works normally and the player gives every order as before. After the one scene of the shutting-out the priests say nothing.
  The drowned priest is gone for good, and his objective is crossed out in red (failed, but the scenario goes on).

**The Legion goes for the relic, not for the huts.** A Legion column with Lysa at its head goes wherever the relic is: to the abbey's seal while
it is sealed in the crypt, to the relic on the ground, or into the village to the new church once it is home (breaking in like any enemy). Its
soldiers go on fighting what is in their way. The rest of a wave (monsters) goes for the huts as usual. The column **marches as a company**: its
soldiers keep together in a loose formation round Lysa, not strung out one by one along the road as monsters are; it should look like an army on
the march.

- **Rescued branch:** only **one** wave brings a Legion column (the Legion is done after it). Lysa demands the relic; Brenna refuses her own
  captain. When that wave is over (a wave only ends once its Legion column is beaten, so the unsealing needs no separate "beaten" condition) and the relic is still sealed in the crypt, the priests unseal it (if the Legion broke the seal itself there
  is nothing left to unseal).
- **Drowned branch:** **three** waves bring a Legion column, stronger each time. If the relic is home by then, holding the village against them is
  the point (the church is inside the walls). After the third the priests give in: they have seen her hold off her own company three times. In this
  order: first they **let her back in** (a talk: they trust her again, a little; the tent is gone); then, **if the crypt is still sealed**, they
  unseal it; **or, if they hold the relic** (handed in at the gate), they give it to her. (The last two exclude each other: a relic they hold has left the
  crypt. If the relic is elsewhere (Brenna carries it, it lies on the ground, Lysa has it), they only let her in.)

**Lysa and the relic:**
- When the **seal breaks**, the leviathan wakes (see below) and Lysa **searches the crypt** for the relic, for a fixed time (the same as Brenna's
  looting takes). She ignores the leviathan. Then she walks back to the map edge with her soldiers around her.
- Lysa takes the relic from anywhere. In the crypt and in the church she has to search for it (the same time each); lying on the ground she **picks it up at once**.
  While she lives and is still fighting (not falling back), a relic lying on the ground draws her.
- **If Lysa reaches the map edge with the relic, the scenario is lost.**
- Beaten (a captain falls back), she **drops the relic where she stands** and falls back without it; while falling back she picks nothing up. Her
  soldiers stay around the relic and fight on, so taking it back is hard: towers and barracks within reach of the island pay off.
- **Brenna** picks up a relic on the ground in Explore mode (like dropped loot) and carries it home. She drops it wherever she is when she is
  switched out of Explore mode (as any loot). Downed while carrying it: lost anyway (no revive here).
- **Drowned branch:** Brenna is shut out, so she brings a relic to the **gate** and it is handed in there; then she goes back to her tent. The
  priests hold it in the church, but it is not hers: she must still earn their trust (the three Legion waves) before they give it to her.

**The leviathan:** it sleeps until the crypt is **first used**: Brenna entering the opened crypt, or the Legion breaking the seal.
- Woken by **Brenna** (rescued branch, or the drowned branch once the priests have given in): it rises as she reaches the crypt and drives her off the island; it coils round
  the island and blocks the crypt's door, so **the relic can't be taken while it lives**. No Legion comes with it; only the normal waves go on. This is intended design, and nothing in the code enforces it because it cannot happen: the crypt only opens after the Legion's waves are over, so Brenna can't wake the leviathan while a column is still coming. Once
  it is slain, Brenna goes back, takes the relic and carries it home.
- Woken by **the Legion breaking the seal**: Lysa takes the relic anyway and flees; the leviathan is awake but need not be slain to get the relic
  home.
- While it lives it has **several goals** and moves between them through the deep water that joins the river to the sea (the boats are at the
  harbour, far from the crypt): **guard the crypt** while the relic is still in it; **sink Pell's boats** (the goods are lost, so no supplies come
  while it lives); **attack whatever is near the water**, surfacing along the shore and blasting towers, units and people in reach, as a wave
  leviathan does. So it can't be ignored for long. The script moves its post between these goals (a boat coming in beats the crypt, the crypt beats
  the shore); a boat that arrives while it lives is lost whether or not it reached the pier.

**Winning:** the relic home (and, in the drowned branch, given to Brenna) **and** the leviathan slain. The waves keep coming until then (the last
listed wave repeats, bigger each time).
- Relic home, leviathan already dead: won.
- Relic home, leviathan alive: the priests ask Brenna to kill it, to make their home safe. **A choice:** *Yes*: the objective *Slay the
  leviathan* appears; slaying it wins. *No*: a priest sends out a messenger; one wave later the messenger comes back with a decree signed by
  Fiona, urgently asking the same; the objective appears. The choice is flavour: both ways end the same.

**Defeats:** Pell or the eldest priest dies; Brenna is downed (no revive); Lysa reaches the map edge with the relic. The priest drowning is no defeat: it is the
drowned branch.

**Objectives (shown as they come):** build a watchtower by the shore (only for the start, then gone); rescue the priest (optional, with its
countdown); keep the relic from the Legion (optional; its detail shows the seal's state and "Lysa has it!"); bring the relic home (its detail says
where it is, also while Lysa has it); slay the leviathan (shown once it blocks the crypt, or after the priests' request or Fiona's decree). Hints and cards say at every turn what changed.

**How it plays, in order:**
1. The early waves: crabs, goblins, the drowned dead; the watchtower by the shore starts wave 1's countdown. The priests walk their rounds.
2. After the fourth wave: the octopus grabs a priest at the harbour; a short time to cut him free.
3. **Rescued:** the priests tell. One Legion wave goes for the seal; Lysa demands the relic. Beaten: the crypt is unsealed. **Drowned:** Brenna
   lives in her tent, the priests say nothing; three Legion waves go for the relic, wherever it is; then the priests give in and let her back in.
4. If the seal breaks at any point: the leviathan wakes, Lysa takes the relic and flees; beat her before she reaches the edge, then take the relic
   back from among her soldiers.
5. If Brenna opens the crypt: the leviathan wakes and drives her off; slay it, then take the relic.
6. With the relic home: won if the leviathan is dead; otherwise the priests' request (yes, or no and Fiona's decree), then slay it.

**Outro:** the lines depend on the branch (the rescue, or the tent and the three waves).

### 10. The Last Wardline

**Where:** the home village, at its strongest. The same map as scenario 3.

**Starting point:** a scripted baseline of a fully built village: every ruin restored, a strong barracks, many towers including the restored
Wardline towers, a good economy, high-level units, Pell's guild market with caravans bringing help. **No revive**, even at home.

**Objective:** survive the waves, ending with a **mid-boss wave** (Rhodri's marshal, **Halvard**).

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
- Before the Legion's first wave Lothar rides up under a white flag and demands her surrender once more (a choice: opening the gates loses). One
  wave later, Fiona's mages arrive and are added to the military stock of the player.
- Captains Torben and Lysa lead later waves (they fall back when beaten). The mid-boss wave at the end: Rhodri's marshal, Halvard, leads the
  legion with both of them.

**Story covered:** the villagers' loyalty: the village sided with no one in scenario 1; now it stands with **Fiona**, as Brenna does, and the
Legion comes because of it. The restored Wardline, built to keep the wilderness out, now has to hold against the kingdom's own bound soldiers.
Brenna's choice to stay and defend rather than chase Rhodri.

**Intro cutscene:** Brenna and Pell on the home wall at dusk, the horizon full of torches. Brenna tells Pell who is out there: **Lysa**, her
captain, and **Torben**, a comrade of her company. "I will free them."

**Outro cutscene:** the legion stopped, only corpses remained. The marshal, dying, holds Brenna's hand: "Thank you." A messenger from Fiona
arrives: she, the priests and the mages ride for the capital.

**Decided:** the home map grown for scenario 3, with every Wardline ruin standing restored and manned at the start. **Halvard** is a **commander**
(a new Legion kind): Legion soldiers near him strike faster and take less damage, and every so often he **rallies** fresh footmen down the roads
while he lives, so killing him early matters; he can be killed. **Guild caravans** are scripted carts that halt while an enemy is near and pay
their cargo at the gate. Built as §7.17.

### 11. The Crown

**Where:** the capital's throne hall district: a **city**, with cobblestone streets and ruined and standing buildings, next to the throne hall.
The vegetation is basically gone: no grass (replaced by ashen land), only a few steppe spots where trees grow and can be cut down. So **no
farms**. The scenery is drastically different from the existing map types (section 6).

**Starting point:** Brenna's and Fiona's forces together in a final camp. Fiona is present but not under the player's control (her death is a
defeat). Pell has his stall in the camp, and caravans bring food now and then. Everything unlocked. **No revive.**

**Objective:** hold the camp for the waves. In the **last wave Rhodri comes out** and the player **defeats** him: his HP stops at 0 as a *down*, he
is not killed, and he flees into the throne hall. When the wave ends, the **victory sound** plays and the campaign is complete, then the ending
cutscene runs.

**Monsters:** everything, with Rhodri's court at its strongest and the **Dread Legion** at full strength, the army of the final struggle. In the
last wave **Rhodri** comes out as a commander with a cleave (a boss with scripted strength); with him **Lothar**.

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

**Decided:** a hand-made map with a new zone, the **city** (its blocked tiles are **houses**, standing and ruined, instead of peaks), ash land
around it and a few steppe spots with trees. The **throne hall** is a landmark at the north road's end (a campaign treasure that can never be
looted). The final camp: the village's walls half broken, Fiona at home in her house, Pell's stall, towers manned by Fiona's mages (bound: they
take no orders). No farms; a food caravan comes after every wave. **Rhodri** is a commander like Halvard, with a cleave like Rurik's; at 0 HP he
is **downed**, not killed: nothing can target him, and he falls back along his road into the throne hall and is gone. He comes out in the last
wave with **Lothar**, who can be killed. Built as §7.18.

## 4. The tutorial inside scenarios 1 to 3

The steps of the standalone tutorial (`tutorial-design.md`) are spread over the first three scenarios. The cards and highlights are reused; a step
ends when the player has done the thing. The *Let's go* button and the card's end step are replaced by the scenario's cutscenes.

| Scenario | Tutorial steps | New lessons that scenario adds |
|---|---|---|
| 1 | welcome, watchtower, builders, archer on a tower, farm and food, call the first wave, gatherer, unit levels (archers) | Walking to the village, repairing ruins (huts first, then gates and wall towers), the food rate and starvation, why no villager may die |
| 2 | hero explores (claims the broken watchtower), hero levels, barracks and shield bearer, tower upgrades | Trade through Pell |
| 3 | none from the old list | Specialising a unit, training grounds and the hero's Train mode, claiming ruined towers (the objective) |

Waves wait for the player while a step needs it, as in the tutorial (the first wave of scenario 1 starts when called, and corpses don't rot until
the gatherer step is done). When the scenario's steps are over the normal countdown runs. The standalone tutorial stays for now; the scenarios
cover all of its steps, so it can be retired when the user decides.

## 5. Open questions

- Whether the tutorial cards can be switched off for replays (proposed: yes) and what the title screen's *Tutorial* button does (proposed: it
  starts scenario 1).
- Whether the cutscenes can be watched again (title screen, library).
- Whether bandits are a new Renegade kind (not for now: thieves only), and whether the rival guild hires Renegades.
- The Dread Legion: how its camps, ranks and banners fit the rest of the monster design, and a captain's commanding abilities.
- The druids (7): whether they come back later, and whether a grove can be found in a normal game.
- Where else than the Coast the water monsters appear.
- Who the guilds' foreign coins and seals belonged to, and who the "goldsmith" was (never settled, by design).
- What happens after the open ending (the curse on Fiona, the Legion, the kingdom).

## 6. What the engine needed

The outline above assumed these pieces; all are built (§7). The reasons are kept because they explain the shape of the scenario system:

- **A scenario system:** a list of scenarios, a scripted baseline per scenario, a way to start one, objectives with a win and an outro. The
  tutorial (`tutorial-design.md`) was the closest existing piece.
- **Destroyable and rebuildable buildings:** the intent is that **every building can be destroyed and rebuilt**, with a cheaper repair than a new
  building (`siege-design.md`).
- **Breaches:** enemies **walk around broken walls straight into the village**, but are **held at a gate for a while** until the gate breaks, so
  walls and gates are real defences, not decoration. This replaced the rule that enemies never get in and the inside is always safe.
- **Water monsters** (`aquatic-design.md`). The scenarios needed only maps with a water body big enough and water spawns (the map editor), the
  leviathan as a scripted, stronger spawn, and the octopus as a non-wave guard.
- **A capital-city map (scenario 11):** cobblestone and buildings in place of the generated wilderness, with its own art: a new zone, not a new
  map type, so it stays out of the generator.
- **Choices:** a decision the player makes in a dialog (accept an offer and lose the scenario).
- **Guard mobs** that do not count for the waves, **a boss that is downed and flees**, **scripted caravans** where there are no farms.
- **A death effect for the Legion:** when a Legion unit dies, the pale colour fades, a human face shows for a moment and a breath goes out, so
  each kill reads as a release (they are alive, bound: Brenna wants to free them).
- **Per-scenario rules:** enemy strength, a custom wave mix, locked specialisation, "hero revives" and "fail if the hero is downed", "fail if
  Pell dies", "fail if a villager dies".
- **Objectives, scripted events, skippable cutscenes, scenario text** (library lore, journal fragments, log lines).

## 7. As built

The scenario files hold the numbers (baselines, resources, waves, levels, texts, tile coordinates); the sections below say what each scenario
added to the engine and why.

### 7.1 The scenario system

- **One file per scenario:** `scripts/scenarios/scenario_<n>.gd` extends `Scenario` (`scenario.gd`) and holds everything that scenario is: in
  `_init` its data, and in overridden functions its content (the intro, arrival and outro cutscenes, teaching cards, one-time hints, objectives,
  events per wave). `Campaign.SCENARIOS` lists them in order. Keeping a scenario's numbers in its own file, not in `config.gd`, keeps the
  config about the normal game.
- **The runner** (`ScenarioRunner`, a child of `Game` while a scenario runs) plays it: before the world is made it loads the map file, sets the
  difficulty and the enemy scale (`Settings.enemy_scale`: values that replace the difficulty's multiplier, so a scenario can be weaker than Easy)
  and the starting village; once the world stands it ruins the huts and pieces (`apply_baseline`), then plays the intro, the hero's walk, the
  arrival, the cards, hints and objectives, and the outro once every objective holds at once and no wave runs. The villagers wait at home until
  the intro is over (`_hold_villagers`) so the cutscene is not played over a village at work.
- **Rules:** `Commands.submit` asks `ScenarioRunner.command_error`, so every rule is enforced at the one place all orders pass (and a co-op-style
  client could not bypass it); the HUD hides what isn't allowed (`Game.available`, `Game.allows_building`, `Game.allows_branches`). A villager's
  death or the hero being downed end the scenario when its rules say so (`fail_on_villager_death`, `must_live` names, `hero_revives`); the usual
  defeat does too. The defeat screen names the cause; the win screen leads on to the next scenario (completed or not) or, after the last, to the
  campaign map (`Game.play_next_scenario`, `Settings.campaign_next`).
- **Waves:** a scenario's waves are `Waves.scripted` entries. `Waves.last_wave` stops the waves after the last one; wave 1 can wait to be called
  (`first_wave_waits`) or until the scenario lets it come (`first_wave_call`, `release_waves`); with `repeat_last` the last wave comes again,
  growing (`more_each_wave`, `rotate_kinds`), until the objectives are met. That is how a scenario can say "until done" instead of "N waves".
- **Baseline:** `prebuilt` posts and buildings, finished and manned, placed by a road (`RoadSpots`, so the spot is meaningful to the player), on
  a fixed tile, or near a map object (`near_site`, `near_water`); named villagers (`Civilian.given_name`).
- **During play:** `play_scene` (a short scene between waves, one after the other; cutscenes hold the wave countdown), `on_poll`,
  `on_wave_started` / `on_wave_finished`, `on_card_done`, and `show_journal` (a found page on parchment over the paused game). Objectives can
  be `optional`. A card can wait (`ready`, `wait_text`) so a lesson only shows once the player can act on it.
- **Progress:** a won scenario is remembered as completed (`Campaign.complete`); release builds show only the unlocked ones (`ui-design.md`,
  the campaign page).
- **Not built:** saving a scenario (`Game.save_error` refuses it, and its campaign-only buildings and people aren't in saves), upgrading the
  stall in play, anything carried between scenarios (by design: nothing carries over).

### 7.2 Cutscenes

- **In the engine, with dialogue** (`Cutscene`): the game runs on behind black bars with the HUD hidden and the map's input off; the camera
  moves between spots; people speak in a box with a portrait; the narrator's lines have no portrait (the mission narrator, in italics, says
  what to do, not the story). A tap shows the whole line, then the next; *Skip* or Esc ends it.
- A scenario writes a cutscene as a list of steps (`say`, `camera`, `follow`, `wait`, `fade`, `title`, `do`, `until`, and **choices**; the step
  kinds are in `cutscene.gd`). A **choice** is a `say` step with buttons; Skip before a choice still to come jumps to it (only the `do` steps on
  the way run), so the player always makes it, and at the choice Skip and Esc do nothing. A figure made with `actor` goes when the cutscene ends,
  played or skipped, because a skip never runs the steps after it, so a scene can't rely on its last `do` to clear up; one the scenario keeps on
  purpose is made with `keep`.
- Portraits are generated art (`tools/gen_art.py`).

### 7.3 Scenario 1 as built (`scenario_1.gd`)

- **Map:** `data/maps/homecoming.json`, made by hand in the map editor (never regenerated). The code ties to it: Brenna's start and tent, the
  south road's end (Brenna's road home and Pell's), the lake road's end (scenario 2's stranger), and one ruined watchtower for scenario 2. If the
  map changes, move those in `scenario_1.gd`.
- **Baseline:** weaker than Easy, a farm and camp standing, fewer than half the huts, a few pieces at part HP and the rest devastated; smoke
  rises over ruined huts until rebuilt so the player sees what is left to do.
- **Story and cards:** the intro, the walk home (no orders for her meanwhile), Einar's arrival scene and the rule that nobody may die, the outro
  with Pell's cart. The cards are the tutorial's steps plus the rebuilding; the hints (a villager fleeing, hurt, food falling, enemies inside
  the walls) each fire once, in the moment the lesson applies.
- **The old tutorial stays** as it is for now (title screen *Tutorial*).

### 7.4 Pell, the stall and trade

- **The trade stall** (`stall`, `Stall`; `"campaign": true` in `Config.BUILDINGS`: only in a scenario that lists it in `build`, never in a
  normal game). Its level is its stage (`Config.STALL_LEVELS`: peddler, stall, guild market: goods, refill rate and lot sizes grow). There is no
  upgrade in play: a scenario sets the level (`prebuilt`).
- **The merchant** (`Merchant`; can't be recruited; Pell) lives in a hut and works the stall: only while he tends it is it open and do its goods
  refill. Like any villager outside he runs home from enemies and comes back once rested.
- **Rats** treat the stall as a farm (`Stall` extends `Farm`; its stored food is its goods): they eat the goods, and barracks and the hero go after
  rats there as on a farm. Farm-only rules (the food warning's tips, the scenarios' `farms()`) look at `kind == "farm"` so the stall doesn't
  count as food production.

### 7.5 Scenario 2 as built (`scenario_2.gd`)

- **Map:** the home map, as in scenario 1.
- **Rules:** Pell must not die; once the stall has stood, losing it is a defeat. Nothing in its waves attacks buildings and rats only eat its
  goods, so in practice only a tear-down loses it.
- **Wave 1** can't be called: its countdown starts once the stall stands, which makes placing the stall the first thing the player does.
- **Story:** between waves Pell tells of King Orsin's death and the war, a stranger from a rival guild asks questions (Pell flies the Silver
  Thread's colours; the stranger calls them the Leftovers), and Pell tells of the guild's split (the pieces allied with Fiona's court, Rhodri's
  army and each other; the few who stayed neutral are the Silver Thread Merchant Guild).
- **Cards:** the trade card waits until wave 2 is over and the open stall has goods for a lot (or something was bought already), and the stall is
  marked only while a lot can be bought, so the player is never pointed at a closed shop.

### 7.6 Scenario 3 as built (`scenario_3.gd`)

- **Map:** `data/maps/wardline.json`, grown from the home map by `tools/make_scenario_map.gd -- 3` and then **edited by hand** (never regenerate
  it). The inner part is the home map tile for tile (an offset from the full map; an edit to one needs the same edit in the other), the **border
  road** runs across the whole north with the Wardline's ruined towers and, at its east end, the ruined barracks. The home map's ruin stands
  restored at the start (scenario 2 restored it) and counts as the nearest prebuilt ruin. The code ties to the ruins' count and place (journal
  pages, talks, the checks in `scenario_bot`).
- **Ruined barracks:** a ruin object can have been a watchtower or a barracks (`"building"` in the map file, format version 3;
  `RuinedTower.building()`): claimed and restored the same way, for half its price, it becomes a devastated barracks. Ruins can thus be barracks
  without a new object kind.
- **Rules:** specialising open, training grounds allowed; Pell must not die. Waves repeat (`repeat_last`) until the objectives are met, because
  restoring a far line takes as long as the player takes.
- **Story:** each restored watchtower gives up a page of its garrison's journal (six pages, one per tower, in the order restored): the line
  falling quiet, the captain counting heads and writing down every name (Lysa, unnamed until the logbook), what the **light stones** are for
  (rune stones the last garrison set along the road, whose glow shows the stretch no tower sees), and that they have gone dark. After pages 2 and
  4 Brenna and Pell talk; the restored barracks gives its logbook: the order to abandon the post, signed in both claimants' names, in Lysa's hand.
- **Objective design:** the road of the line must be **lit**: every road tile from the village to every ruin watched by one of the village's
  buildings (what towers and light stones see, not where people walk: `ScenarioRunner.lit`). The light card waits until a stretch is explored
  and still dark, so that the dark road itself shows the player where a stone goes (no spot is marked).
- **Hints:** thieves, a monster camp found (its guards keep explorers and Brenna away; towers and barracks in range fight them by themselves),
  no explorer once wave 3 is over.

### 7.7 What scenarios 4 and 5 added to the engine

- **The guild warehouse** (`Warehouse`, `"campaign": true`, prebuilt by the scenario): the **thieves' target**, and only theirs (the siege field
  leads the rest to the huts): a thief whose village has a standing warehouse follows its road to where it passes nearest the warehouse, then
  goes across to it, plunders it and runs back the way it came with the sack. Plundered goods are gone, so it **can't be repaired** (the
  `repair` command refuses it) or torn down. The values are in `Config.WAREHOUSE`.
- **`must_stand`** (Scenario): building kinds that must not fall; once every one of a kind is devastated the scenario is lost.
- **The guild master** (`GuildMaster`; can't be recruited): a villager who stays in her hut (she never goes out, so she is safe while it stands,
  and dies with it). A named villager's hut can have its own look and name (`Scenario.homes`, `Hut.look`).
- **The Dread Legion** (`story-design.md` §5; `Config.ENEMIES`, `"campaign": true`: never in the normal waves, only where a scenario sends
  them). A fallen Legion soldier is **released** (`"release": true`): the pale colour warms, a pale breath rises and it sinks away, with no corpse,
  so each kill reads as a release.
  - *Legion Footman* (`legion_footman`): the line soldier; breaks gates and walls.
  - *Legion Captain* (`legion_captain`, `CaptainBehavior`): **never killed**: below a share of its HP it keeps that much and **falls back**
    (`Enemy.retreating`): nothing targets it any more, it leaves any siege, and walks back the way it came and off the map. The story needs Lysa
    and Torben later (scenarios 9 and 10).
  - **Named enemies:** a queue entry's `name` and `art` give an enemy a name and a look of its own (`Enemy.set_identity`).
- **Adding to a running wave:** `ScenarioRunner.add_enemies` (`Waves.add_to_wave`): more enemies for the wave under way, counted for it
  (scenario 5's Legion down the pass, its captains, the gargoyles). `spawn_near(tile)`, `keep_in_sight(who, radius)` (an observer that keeps the
  land round an enemy or cutscene figure watched while it is on the map: scenario 9's Lysa).
- **Water monsters in scripted waves** come from the village's water spawns as in normal waves; `amphibians_from_water` keeps scenario 4's
  crabs and siren to the sea.
- **Maps:** `tools/make_scenario_map.gd -- 4` and `-- 5` make the start of `guildtown.json` and `old_fort.json`; edit them by hand in the map editor.

### 7.8 Scenario 4 as built (`scenario_4.gd`)

- **Map:** `guildtown.json`, a Coast map with the village on a sea inlet.
- **Waves:** large (a multiple of a home wave). Goblins and orcs go for the huts; **thieves** in every wave go for the warehouse, and once the
  foreign coins are found the paymasters send about twice as many (the player's reward for the clue is a harder fight, as the story says);
  **crabs** and **one siren** out of the sea only.
- **Story:** after wave 1 Wenna tells how the guild broke apart; the rival guild's master's **offer** is a **choice** (taking the gold loses);
  the captured thief's **coins of three mints** (Karmere, Lyrenne, Aurelith) as a journal page; the outro (the Renegades' ledger).
- **Cards and hints:** the warehouse (tap it), guard the harbour (a manned tower near the warehouse); the warehouse plundered (it can't be
  repaired), Brenna badly hurt (no revive: send her to rest).

### 7.9 Scenario 5 as built (`scenario_5.gd`)

- **Map:** `old_fort.json`, laid out by `tools/citadel_map.gd`, not generated: a mountain range across the middle with one pass, the fort filling
  it (two walls across the pass from mountain to mountain, the road bending through both gates; inside a few huts, two barracks and training
  grounds, empty, a dried-up well and a dead tree: decor with no use). The map is the tool's start; the user has edited it by hand since, so it
  is never made again with the tool (`--force` would undo those edits). What the code ties to it: `SIGMUND_TENT`, the prebuilt offsets from the
  village centre, the evidence picked by treasure tier (the far ones in the north guarded, one in the south), and the user's **hollow-tree lair**
  in the northern forest.
- **Rules:** gates start at a higher level than walls (`Scenario.piece_levels`) so the fort reads as a real citadel; no merchant or resident can
  retire (Pell must stay); buildings may go inside the fort's walls on free tiles (`build_inside`), so what is torn down there makes room.
- **The lair:** asleep until a late wave or until the village finds it (an explorer or Brenna uncovers it), so exploring the north is never
  punished before the player has seen it. Awake, it sends its theme with every wave; Brenna can clear it.
- **Sigmund:** found once his tent's tile is explored; wave 1 then comes shortly (it can't be called before). He joins as a builder
  (`ScenarioRunner.join_villager`). If no hut is free, a builder leaves (retired, logged) and Sigmund takes his hut; with no builder either, the
  objective **"Give Sigmund a roof over his head"** appears until the player retires someone, so the fort's few huts become a decision, not a
  dead end.
- **Evidence:** three treasures hidden in the fog, no card marks them; each found piece shows its page (the game grey behind it): **Rhodri's order**
  ("Hold until the last. Do not ask for relief. ..."), **the roll of the fallen** (one ink, one day, Brenna's name among them, no grave marked), **a
  foreign seal** (whose, nobody can say).
- **Waves:** from both halves; **witches** and **gargoyles** are the first Arcane. In the last wave the Legion comes down the pass (captains Lysa
  and Torben) while gargoyles wake on the rocks above it.
- **Story:** Sigmund tells it over several waves (Lysa sent Brenna down the pass with a plea for relief; Rhodri came the next evening with the
  crown; the company knelt on the field and stood up bound; no body on the field); when a captain falls back, Brenna says they are alive and she
  will free them.

### 7.10 What scenarios 6 and 7 added to the engine

- **The fallen** (`Corpse.fallen`, `Corpses.spawn_fallen`): a battlefield's dead, placed by a scenario. They are corpses of kind `skeleton` (raised,
  one comes up as a skeleton) with their own look (Fiona's blue, Rhodri's crimson), never rot and are never cleared after a wave, so the
  necromancers' threat is a standing one, not a timer.
- **The graveyard** (`Graveyard`, campaign-only, prebuilt, can't be torn down): while the village has a standing one, gatherers (and the hero
  gathering) fetch the fallen too, carry them there instead of home and bury them (`GatherJob` states `TO_GRAVE`, `BURYING`), for no pay. Without
  a graveyard nobody fetches the fallen. Values: `Config.FALLEN`.
- **Residents** (`Resident`, `"stays_home"` in `Config.CIVILIANS`): campaign villagers who never leave their hut and die with it (`GuildMaster`
  is one). A scenario may give one **rounds** (`Resident.rounds`: stops out in the field): they walk them one after the other, home between,
  and run home from enemies like anyone outside. Roles `priest` and `princess`; neither can be recruited.
- **The druids** are the summoner's plant branch (`docs/military-design.md` §3b); the grove's take no orders (`MilitaryUnit.bound`, from a
  prebuilt unit's `"fixed": true`; `Commands` refuses moving, withdrawing, swapping, upgrading and sending one), because they serve their grove,
  not the player. Their **grove** (`Grove`, a `Barracks` with `post_kind` "grove", prebuilt, no upgrades or tear-down): they turn out for enemies
  near it, fight, are downed and come back to their benches like barracks units. Only druids serve in a grove.
- **Unlock sites in a scenario:** `Scenario.sites` (site kind to the wave it awakens: at the start, or only when the scenario calls
  `ScenarioRunner.awaken_site`), `Scenario.unlocked` (units unlocked from the start). `"near_site"` puts a prebuilt building next to the map's
  site of that kind (the graveyard by the chapel, the grove by the stone circle).
- **The hero living out** (`Scenario.hero_lives_out`): she starts by her tent and doesn't walk in; that tent is her post (`Hero.home_override`)
  until `ScenarioRunner.hero_moves_in`.
- **A scenario's own command rules:** `Scenario.command_error`, asked after the runner's own (scenario 7's trust).

### 7.11 Scenario 6 as built (`scenario_6.gd`)

- **Map:** `battlefield.json` (Desert; the ruined chapel by the east road, a little way from the gate).
- **The field:** the fallen lie in a few clusters on open land, within a short reach of a road (so a passing necromancer can raise them), spread
  as far apart as the land allows, their places uncovered at the start so the player sees the task.
- **Rules:** food is short (dry land). The scenario is **lost** once fewer of the fallen are left (on the field and carried) than still have to
  be buried, so "too many have risen" has a clear moment instead of a slow grind. Brenna wakes the chapel by going there (Explore).
- **Waves:** Undead with Wilderness leftovers, necromancers from the third wave; the last repeats until enough are buried.
- **Anselm** walks his rounds once the intro is over (chapel, graveyard, home).
- **Story:** who the dead were; the first necromancer; the chapel woken; why the dead rise; the outro has Anselm, Brenna and Pell walk from the
  village to the graveyard as actors (the real three hidden, talking on the way), and Anselm plants a cross over the last grave (`grave_cross`).
- **Hints:** if no gatherer was ever recruited after wave 2 and a hut is free, a hint points at recruiting one (the player is not told to
  recruit until the need is real).

### 7.12 Scenario 7 as built (`scenario_7.gd`)

- **Map:** `refuge.json` (Temperate, a forest valley; the stone circle by the north road, the mage's tower by the west road). The farm sits by
  the south road because the forest leaves no room by the walls.
- **Fiona's trust** (`command_error`): until wave 2 is over her people take no orders (no building, repairs, hut rebuilds, upgrades, tear-down,
  recruiting, retiring or assigning villagers, restoring ruins); units can be hired and stationed. After wave 2 Brenna moves in, everything but
  new buildings opens, and the court mages open their tower (the apprentice). After wave 7 new buildings too. The locks are the trust story made
  playable: the player feels being a guest.
- **The grove's wave:** a band comes down the north road past the grove; a druid downed in that wave loses the scenario (one still down from
  before counts once it stood again). After it the stone circle answers (the summoner).
- **Story:** Fiona at the gate with two mages (Anselm vouches for Brenna, but she wears Rhodri's colours); the elder tells why the druids stayed
  out; Fiona tells why Orsin named no heir; Brenna tells what happened to her company and Idris that Rhodri changed after the envoys came; the
  outro (the working hides the valley, the sealed scroll).
- **Cards:** the court mages' tower waits for trust 1, the stone circle for the grove's wave.

### 7.13 What scenarios 8 and 9 added to the engine

- **More of the Dread Legion** (`Config.ENEMIES`, all `"campaign": true`, `"release": true`, no corpse), each a lesson in a different counter:
  - *Legion Archer* (`LegionArcherBehavior`): stops on its road to shoot our people in the open (never a tower's unit), from a range just below a
    level 1 watchtower's, so towers can answer; breaking in, it shoots the barrier in its way.
  - *Legion Guardsman* (`legion_guard`): a tower shield, so arrows and bolts weigh half; slow and sturdy.
  - *Legion Banner-bearer* (`legion_banner`): every Legion soldier near its banner strikes and shoots faster (`Enemy.haste`; the strongest banner
    counts; a faint ring on the ground shows how far), the enemy-side parallel of the warrior's war cry.
  - *Court Champion* (`legion_champion`; Rurik): heavy blows that cleave everyone of ours beside its target; a boss that can be killed.
- **Legion camps:** a monster camp whose monsters are all Legion kinds is a *Legion camp*. `MonsterCamp.add_guard(kind, hp_scale)` adds a guard
  (Rurik).
- **A scenario's lairs** (`Scenario.lairs`, `ScenarioRunner._set_lairs`): per lair the wave it wakes at, its guards and HP scale, and the kinds it
  sends; cleared, a scenario's lair stays cleared. Lairs past the list never wake. A scripted wave with `"lairs": true` has the awake lairs as
  spawn points too.
- **The band:** `Scenario.reserve` (units in the reserve at the start) and `Scenario.recruiting` (false: the Army tab shows no recruit entries).
- **Treasures:** `Treasure.sealed` (can't be looted until the scenario opens it). A reward's `"item"` is a campaign item, paid as `Village.items`
  (the relic sword). The `abbey` treasure (`"campaign": true`: never generated, not in the library).
- **Guards and bosses:** `Enemy.post` / `post_leash` (a water monster keeps to the deep tiles near its post; scenario 9's octopus, spawned with
  `Waves.spawn_at`, outside the waves). A queue entry's `"hp_x"` multiplies an enemy's HP and `"power"` its damage (the leviathan).
- **The outro waits** for a scene that is playing to end first.
- **Maps:** `tools/make_scenario_map.gd` places lairs, treasures with a camp beside them and an island (a road's stretch in a lake, bridges over it,
  a treasure and its camp on the island, a water spawn on the lake).
- **Scenario 9's rework added** (§7.15): the **church** (`Church`, campaign-only; `"inside"` in `Config.BUILDINGS`: a prebuilt one may stand inside
  the walls); **LegionCompany** (a captain and her soldiers after a relic); `Enemy.errand` (a scenario's object asked first when an enemy's walk
  ends, so the end of a path it was given isn't a gate; while its `holds(enemy)` is true the siege leaves the enemy alone); queue entries'
  `"on_spawn"` and `"gap"`; `AquaBehavior.set_post`; `OctopusBehavior.grab` and `hold_left` (a scripted grab whose arm holds its catch in the
  shallows for a while); `Treasure.seal_hp` (a seal enemies break, with a bar) and `blocked`; a dropped relic drawn as `relic_sword`;
  `Resident.start_rounds`; `ScenarioRunner.hero_moves_out` and `keep_in_sight`; `keep_free` (a tile nothing may be built on: scenery);
  `Scenario.rotate_kinds` / `rotate_count` (repeated waves grow by kinds in turn); `Enemy.spared` (nothing targets or hurts it while a scene of
  the story plays); an objective's `"failed"` (a red cross; the scenario goes on) and `"gone"` (hidden for good once met: a goal only for the
  start); `Scenario.can_win` (more than the shown objectives); a cutscene `"camera"` step may be a Callable.

### 7.14 Scenario 8 as built (`scenario_8.gd`)

- **Map:** `pale_court.json` (Volcanic; three crypts by the north, south and west roads at growing distances from the gate, two Legion camps by
  the west and south roads).
- **Rules:** **no recruiting**; the band's kinds can specialise; no revive; Pell must not die.
- **The crypts:** each is weaker than the next (guards' HP grows); the farthest has **Rurik** at its door. The hero clears them as camps.
- **Waves:** every wave also comes out of the awake crypts. New Legion kinds are introduced one at a time over the waves (archers, banner-bearers,
  guardsmen), each with a hint, then the last wave repeats until the crypts are cleared.
- **Story:** Lothar greets Brenna; Lothar's **offer** is a **choice** (going back to Rhodri's side loses); the crown and the foreign goldsmith;
  Rurik ("I don't remember you."); the outro (the throne hall's gate, the First King's Hand, Lothar reports the refusal and Rhodri laughs).
- **Cards:** your band (station it), better, not more (upgrade a unit; no recruiting), the first crypt (waits for it to wake).

### 7.15 Scenario 9 as built (`scenario_9.gd`)

Built after the rework of §9a; the numbers (HP, hold times, wave contents, boat cargo) are in `scenario_9.gd`.

- **Map:** `drowned_abbey.json`, laid out by `tools/abbey_map.gd` over a generated temperate map (its roads, village and objects taken out): the sea
  along the south, the walled harbour village with its church, a quay (two piers, a ferry bell, boats, a beacon on the river's bank: scenery, kept
  free of buildings by `keep_free`; the shipwreck by the beacon is a treasure of the map's), a broad river parting round the abbey's island, one
  straight bridge from the village's bank (the only way onto the island), an east road crossing the river north of the island, and on the island
  the abbey with its vampire camp and the ruins the hero can restore. Roads only turn on land (a water tile where one turns becomes land), so every
  bridge and ford runs straight. The shore is a broad beach with three sandbanks reached through shallow water. The generated treasures, camps and
  mines that still fit stay, each with a footpath to a road. What the code ties to it: the church tile, the quay, `SECOND_PIER`,
  `BEACON_OFFSET`, the island's ruins, the Legion's spawn on the north edge.
- **The camp's leader** is the **Fallen Abbot** (a named vampire with much more HP and damage than the other guards, which also have more HP than
  usual), so the abbey's camp has a face.
- **The people:** two priests (residents named "Eldest priest" and "Priest", not numbered; the eldest has her own art) living in the church by its door
  (`Resident.home_tile`); the church keeps the relic once it is home, and shows it. The harbour is scenery (`_build_harbour`: two piers, boats, the ferry
  bell, props, a beacon with gulls), built once at the start. The abbey is held by the vampires' camp; eight of the drowned dead lie on the island for
  necromancers to raise.
- **Wave 1** waits until the player has built a watchtower of theirs by the shore (finished; not a prebuilt one), which teaches the water side
  before the waves start; an objective says so and is then gone for good (`"gone"`).
- **The rescue:** the younger priest walks to the quay; only when he gets there does the guard octopus come (moved to the deep water by the
  harbour, off the piers). It grabs him and holds him unharmed while the alarm scene plays; its other arms keep still (`focus`) and nobody can fight
  the octopus or its arms meanwhile (`Enemy.spared`), because the game runs on under a cutscene and towers would cut him free before the player
  could act. Then the countdown runs; towers and units go for a holding arm first (`Scenario.arms_first`, `Enemy.holding`), never the octopus
  while he is held. Cut free he runs for the church; an arm that catches him again holds him in the shallows with a new countdown
  (`OctopusBehavior.catch_hold`: only for whom a scenario names). Rescued once he is home in the church; drowned, the objective is crossed out in
  red and Brenna is shut out (`hero_moves_out`, `Hero.barred`: her ways go round the village, `Pathing.find_path_outside`, and she leaves enemies
  inside alone).
- **The Legion** (`LegionCompany`): Lysa on her horse leads a column down the north road in one wave (rescued) or three (drowned), going for the
  relic wherever it is. Beaten she drops it (a dropped "sack" with the relic); her soldiers stand round it until it's taken. Lysa is always seen
  (`keep_in_sight`); the wave's scene follows her with the camera. Her company leads her (`Enemy.errand`): see §7.19.
- **The relic** (`mark["relic"]`: "crypt", "lysa", "ground", "hero", "home"): only Brenna carries it (dropped loot holding an `"item"` is the hero's
  to carry, never a gatherer's); shut out, she takes it to the east gate and the priests take it in.
- **The leviathan** (outside the waves, much stronger) wakes when the crypt is first used (Brenna going in: it blocks the crypt,
  `Treasure.blocked`, until slain; or the seal broken). While it lives it keeps to the crypt while the relic is in it, goes for a boat coming in,
  else blasts the shore near the village.
- **Pell's boats** sail in to the pier; a cart (`ScenarioCaravan`) takes their goods to his stall.
- **Between waves:** Pell's boats after fixed waves; the rescue after wave 4; with the priests rescued the crypt is unsealed after the Legion's wave if the
  relic is still in it; drowned, the priests give in after the last Legion wave (let her in, then unseal or hand her the relic they hold); a messenger's
  decree comes the wave after the priests' request.
- **Cards and hints:** a card for the watchtower, then one for the crypt that waits while it is sealed; hints for crabs, the rescue, the island's ruins
  (restore them to hold the abbey), the Legion, Lysa with the relic, the relic on the ground, necromancer, vampire, siren, leviathan, a badly hurt Brenna.
- **Winning** (`Scenario.can_win`): the relic home and Brenna's, and the leviathan slain; with it alive, the priests ask (a choice, see 9a).
- **Defeats:** Pell or the eldest priest dies; Brenna is downed; Lysa gets away with the relic.

### 7.16 What scenarios 10 and 11 added to the engine

- **Commanders** (`Config.ENEMIES`, `CommanderBehavior`, campaign-only):
  - *Legion Marshal* (`legion_marshal`; Halvard): every Legion soldier near him (himself too) strikes and shoots faster and takes less damage
    (`Enemy.haste` / `Enemy.guard`; the strongest banner or commander counts; a double gold ring shows how far), and while he lives and a wave
    runs he **rallies** more footmen from a random edge spawn, logged. He can be killed (released).
  - *The Crowned King* (`legion_king`; Rhodri): a commander with a cleave. `"downed"`: at 0 HP he keeps 1 HP, falls back (untargetable) along his
    road faster and vanishes at its end (no release).
- **A restored ruin as a prebuilt post** (`Scenario.prebuilt`'s `"ruin": i`: the map's i-th ruin of that kind, nearest the village first;
  `ScenarioRunner._restore_ruin`).
- **Reinforcements:** `ScenarioRunner.give_units(list)` puts units into the reserve.
- **Scripted caravans** (`ScenarioRunner.caravan`, `ScenarioCaravan`): a cart along a road to the gate that halts while a wave's enemy is near (and
  goes on once none is, with hysteresis so it doesn't stutter) and at the gate pays its cargo. Enemies don't attack it, because the point is the
  player defending the road, not losing the cart to bad luck.
- **The city zone** (`Config.ZONES.city`, map format version 4; never generated): cobblestone ground, no farms; a zone's `"peaks"` stand on its
  mountain tiles instead of peaks (standing and ruined houses), drawn on its own ground, kept by the tidy-up and offered by the editor.
- **Landmarks:** a campaign treasure with `"landmark"` can never be looted (`Treasure.landmark`): the `throne_hall`.
- The burst `curse`, `portrait_halvard`, `portrait_fiona_cursed`.
- **Maps:** `tools/make_scenario_map.gd` makes a city (zones by distance, natural mountains levelled, houses in blocks between lanes, off the
  roads and clear of the walls, steppe spots with trees, the throne hall by a road near the edge).

### 7.17 Scenario 10 as built (`scenario_10.gd`)

- **Map:** `data/maps/wardline.json` (scenario 3's).
- **Baseline:** every ruined tower restored and manned, nearest the village first (the units are a mix of branches so the player sees what the
  tech tree gives late); Fiona's mages come later as reinforcements.
- **Rules:** everything unlocked, recruiting open; **no revive**; Pell must not die.
- **Waves:** from several roads; Wilderness first, then the Legion from the fourth wave with Undead and Evil growing to the last. **Torben** leads
  one wave, **Lysa** a later one, and the last brings **Halvard** with both.
- **Caravans** set out down the Wardline road at fixed waves, because she restored it.
- **Story:** the intro; Pell; Fiona's rider; Lothar's **demand** (a choice); the Legion's drums; Idris brings **Fiona's three mages**; Torben and
  Lysa; Halvard ("Then hold it."); the outro.
- **Cards:** the line is manned (upgrade a unit), the guild's caravans, Fiona's mages (station two), the marshal (bring him down).

### 7.18 Scenario 11 as built (`scenario_11.gd`)

- **Map:** `capital.json`, made by `make_scenario_map.gd -- 11`: a city round the village and the throne hall, ash land beyond, a few steppe spots
  with trees.
- **Rules:** **no farms** (none can be built); no worker camp at the start (no trees by the walls: the player builds one by a grove); everything
  unlocked; no revive; Pell and Fiona must not die. Fiona's mages are bound: no orders.
- **Waves:** every category with the Legion at full strength. In the last wave **Rhodri** comes out of the throne hall's road with **Lothar** and
  an escort. After every wave but the last a **food cart** comes down the road farthest from the throne hall, away from the fight.
- **Story:** Rhodri's voice over the city ("I followed a man. Not a crown."); Fiona on her brother; "Enough. I'll do it myself."; Rhodri at half
  HP ("Why does it hurt?"); Rhodri beaten, fleeing into the throne hall; Lothar, the last of the court, falling; the outro (the empty throne hall;
  Rhodri, himself for a moment, asks Fiona to do it; she beheads him with the Hand; the crown breaks, the curse goes into her; the end of the
  campaign). Won with the game's win sound when the last wave is over and Rhodri beaten.
- **Cards:** the last camp (station the army), timber (a worker camp by a grove), no fields here (done with the first cart), the king.

### 7.19 Riders in the campaign (docs/enemies-design.md §15e)

- **Legion cavalry** (`legion_cavalry`: a footman on a pale horse, `MountedBehavior`; unhorsed, a footman) rides in the waves from one wave after
  the Legion archer first comes (scenarios 8, 10 and 11). A hint in each tells what it does and that halberdiers are the answer.
- **Mounted captains and commanders** (a queue entry's `"mount": "horse"`, `"mount_hp"`; art `unit_<art>_mounted`): Lysa and Torben ride in
  scenario 5, Lysa in scenario 9, Torben, Lysa and Halvard in scenario 10, Rhodri in scenario 11 (the horses' HP are constants in the scenario
  files). They ride with their soldiers (escort) and hunt our melee fighters; when the horse falls they go on on foot, and Rhodri's fight has its
  two phases. A captain beaten while mounted falls back on its horse, faster. Rurik stays on foot. In scenario 9 Lysa's company leads her
  (`Enemy.errand`, `MountedBehavior._on_errand`): she rides where it sends her at her soldiers' pace, fights what comes within reach but never
  charges, and hunts, escorts and circles nobody; waiting at the village she rides in through a breach, or after `circle_time` gets off and
  breaks in on foot; beaten, she falls back at her horse's own speed.
