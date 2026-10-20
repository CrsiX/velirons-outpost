# Story design

Status: **scenarios 1 to 9 are built** (Brenna, Einar, Pell, Wenna, Sigmund, Lysa and Torben, Anselm, Fiona, Elder Oren and Idris, Lothar,
Rurik, Rhodri, the portraits, the cutscene format, the Legion's footman, captain, archer, guardsman,
banner-bearer and champion: `scenarios-design.md` §7); the rest is planned. This page holds the story the game's scenarios, library texts and event log will draw on. It changes no rule or number. `scenarios-design.md` is the detailed campaign outline and **takes precedence** where the two differ. Anything marked
*open* is not decided.

## 1. Premise

The kingdom of Veliron fell in a civil war. The old king died without a clear heir and two claimants fought for the crown. Each pulled the knights
off the **Wardline** to fight the other, and the border was left empty. The wilderness that had always lived beyond the borders walked in, and the
war brought worse things after it.

The elder claimant, a **woman** (*heir 1*, **Fiona**), is alive and now in **exile**. The younger, a **man** (*heir 2*, **Rhodri**), was gradually
corrupted and is now **evil** (section 4).

The player **starts neutral**. The outpost is a remote village that sided with neither claimant. It is the hero's home town, which is why it is remote
and why it still stands. Neutral lasts until Brenna learns what Rhodri did to her company (scenario 5): from then on she, and with her the
village, stand with Fiona (section 2).

**Why "the outpost".** The village was founded as the Wardline's outpost on the north road: the walled supply post where the knights of the
border towers around it were fed, housed and relieved (that is why a village this small has walls, gates and wall towers). The towers emptied in
the war, the knights went, and the village kept the name. It is the last post of the line still held, Veliron's outpost.

## 2. The characters

**Named characters.** Everyone named has a role in a scenario. Everyone else (villagers, units, traders, the court's nobles) is unnamed, and
nothing in the story depends on them.

| Name | Who | Where |
|---|---|---|
| **Brenna Hale** | The hero, a woman, one of the royal knights | Every scenario |
| **Pell Dunmore** | The merchant, an old friend of Brenna's | From scenario 2 on |
| **Einar** | Brenna's father, the village's lumberjack | Scenario 1; a short cameo in 10 |
| **Sigmund** | The veteran at Brenna's old fort | Scenario 5 |
| **Wenna** | The Silver Thread Guild's master | Scenario 4 |
| **Anselm** | The priest of the battlefield village | Scenario 6 |
| **Fiona Aldmoor** | Heir 1, in exile | Scenarios 7 and 11 |
| **Elder Oren** | The druids' elder at the refuge's grove | Scenario 7 |
| **Idris** | A court mage at Fiona's refuge, who goes with Brenna | Scenarios 7 and 8 |
| **Rhodri Aldmoor** | Heir 2, corrupted | Scenarios 8 to 11 |
| **Orsin Aldmoor**, **Aislyn Aldmoor** | The old king and queen (the queen died giving birth to Rhodri) | Told, not seen |
| **Lothar** | The Pale Court's herald; not killed until he is last needed | Scenarios 8, 10, 11 |
| **Halvard** | Rhodri's marshal, commands the Dread Legion | Scenarios 9 (named), 10 |
| **Rurik** | The court champion; killed at the third crypt (released) | Scenario 8 |
| **Lysa** | Brenna's old captain, now the Legion's captain; beaten in 9 she falls back and is herself for a moment | Scenarios 5, 9, 10 |
| **Torben** | A comrade of Brenna's company, now in the Legion | Scenarios 5, 10 |

The royal family is **House Aldmoor**. Text always refers to a person by first name. Last names show only in places like cutscene title cards, the
library and journals. A new named character is added only if a scenario needs one.

**The hero** (**Brenna**) is a **woman**. One of the royal knights. She was in the military, so she served heir 2, who later became **evil**. She
was **betrayed by that side**: Rhodri had the pass held with no relief so that her company could be given to the crown's ritual and bound to him
(scenario 5, section 4). She escaped it only because she was not there: her captain, **Lysa**, uneasy about the order, sent her down the pass by
night with a plea for relief. Brenna came back the next evening without it and saw the ritual from the ridge, too late and alone. She could tell
no one who would believe a deserter against the crown, the roll of the fallen lists her with the whole company, and she went back to her home
town, the outpost. The game's hero (see `hero-design.md`) is this character. Her
mode-based behaviour stays as it is; the story gives it a face. (The game's texts, its code comments and `hero-design.md` call the hero "she".)

The military's distrust of heir 1 was about a woman **ruling and commanding the realm**, not about women serving in the ranks. The hero is a
knight who earned her place, which makes her an exception worth a line of story: she served the side whose officers would not have accepted a
woman as their queen. The betrayal explains why she stays away from court, and the last scenarios carry a personal stake for her.

**Why she helps Fiona.** Once she knows what was done to her company (scenario 5), staying neutral is no longer possible for her: Rhodri gave her
comrades to his crown, and the only other claimant is his sister. Fiona is the obvious counter-choice, not a cause Brenna believed in before.
Fiona and her side first reject her because she is from the military, the side that refused Fiona. Earning their trust is part of scenarios 7
(Fiona) and 9 (the priests of the abbey).

**The merchant** (**Pell**) is a man. An old friend of the hero. When everything went wrong, he came back to the remote village, and that is why
the outpost has a trader. He arrives at the end of scenario 1, belongs to the **Silver Thread Guild** (section 6), and is with her from then on.

## 3. The Wardline

The kingdom's border defence: a chain of watchtowers manned by knights, paid for by the crown, so the wilderness never reached the farms. It is
manpower and stone, not magic.

| Game element | Story meaning |
|---|---|
| Ruined watchtowers (claimed by the hero, restored by a builder) | Broken links of the Wardline. Restoring one rebuilds it. |
| Watchtowers, wall towers | Links that still stand or are rebuilt. |
| Light stones | Stay *light stones*: a building that helps the player, with no story role. |
| Walls and gates | The last intact stretch of the line. In scenario 1 they are broken, and a breach lets enemies in (`scenarios-design.md` section 6). |
| Roads | The old King's Roads. Enemies walk them because they are the way in. |

## 4. How the kingdom fell

**The claimants**

- **The old king** is **Orsin**. His queen, **Aislyn**, died giving birth to heir 2. Both heirs are their children.
- **Heir 1** (**Fiona**, woman, the elder): supported by the **court mages and the church**. By the old law the elder inherits, and Orsin meant
  the crown for her. He never confirmed her (why: below).
- **Heir 2** (**Rhodri**, man, the younger): supported by the **military**. He was not the rightful heir, but wanted the power. His greed is the
  root of his fall.

**Why Orsin named no heir.** He had two choices and saw that each one would start the war he feared:
- **Naming Fiona** was the law and his wish. But the military, the realm's whole armed force, would not serve a woman ruling and commanding the
  realm. Crowned against them, she would have had an army that might not obey her, or that turned to her brother. Orsin did not want to leave
  her a crown and a rebellion.
- **Naming Rhodri** would have pleased the army. But he was the younger, so it broke the law of succession, and the church and the court mages,
  who uphold that law, would have stood against the crown. And Orsin knew his son: Rhodri was already greedy for power, and Orsin did not trust
  him with it.
- **So he waited.** He meant to win the officers over to Fiona slowly, through the years he expected to have left, and to name her once the army
  would follow. He kept it to himself, so as not to force either side's hand. He died first, suddenly, with nothing written down, and each side
  read his silence as it liked. The war began over what he had not said.

**The sequence**

1. The king dies without having confirmed an heir. The military backs heir 2, the court mages and the church back heir 1. The two sides are not
   aligned, and the war begins.
2. **Spies from the neighbouring countries** (below) offer heir 2 help, and that help slowly corrupts him. One of them, posing as a
   **goldsmith**, is a very powerful mage: he works on the old king's crown for Rhodri (see the crown, below). The crown's enchantment is the
   help. The story makes clear that the
   spies were the reason. It stays **unclear whom they belonged to**.
3. Both sides pull knights off the Wardline and the towers empty.
4. The wilderness walks in: goblins and orks first.
5. Renegades (deserters, unpaid soldiers, ruined merchants) prey on the roads.
6. Heir 2's corruption grows. To keep winning he gives his own towns and soldiers to the crown's ritual, and that becomes part of the corruption.
   The hero is betrayed in this step (scenario 5). The soldiers given to it are not killed but **bound to Rhodri**: the ritual takes their free
   will, a will-bending like brainwashing, and they become the **Dread Legion**, his army. What it takes from them feeds the crown, and the crown
   feeds on its wearer in turn.
7. The war's unburied dead rise. The evil is drawn by a kingdom full of death and gathers around heir 2. He does not create it: monsters still
   have no single source.
8. Heir 1 flees into exile, with what is left of the court mages and the church. The capital burns, but the palace stands: Rhodri holds court in
   it (the Pale Court, below).

**The Pale Court**

The royal court was the whole government of Veliron: nobles, officers, mages and clergy. The succession **split** it. Fiona took the court mages
and the church into exile. Rhodri kept the military and the nobles who sided with him. The capital burned in the war (step 8), but the palace
stood, and Rhodri holds court in its ruins. This is the **Pale Court**: his inner circle and seat of power, formed *after* the old king's death
and the split, and it is on **Rhodri's side**. It is "pale" because the corruption drains colour from those near it and from its bearer.
- **The human members.** Only they speak. The **herald**, **Lothar**, carries Rhodri's words and offers to Brenna and to the player (scenario 8).
  He returns in later scenarios and is not killed until he is last needed. The **marshal**, **Halvard**, commands the Legion. The **court
  champion**, **Rurik**, is his strongest sworn fighter. A few loyal **nobles** are unnamed: they are only a look in the court's crowd and in its
  enemy units, each with their own clothes and design.
- **The Dread Legion:** the soldiers, in camps at the gates (see section 5).
- **The Evil** (vampires, necromancers): **not** former courtiers. They gathered in the crypts because of the death and the corruption, and Rhodri
  tolerates them as his court. They are monsters and never speak.
- **Its function:** the seat of the corruption and the voice of his offers. It shows the player what Rhodri has become before the final fight.

**The crown and the First King's Hand**
- **The crown** is the old king's own, a typical crown. Rhodri had a foreign "goldsmith" (really one of the spies, a very powerful mage) work on
  it, and it now glows and sends out malice. It is clearly an artifact. The goldsmith laid an enchantment on it: the **ritual** that binds
  whoever is given to it to the crown's wearer, taking their will. It is part of the crown now, not a gift beside it, and every binding makes
  Rhodri stronger and paler: the ritual and his corruption are one thing. Why the goldsmith made it, and for whom, stays unclear: he cursed it.
  The ritual needs the crown near: Rhodri came to the pass himself (scenario 5).
- **The First King's Hand** is a sword, a relic of the first king, who founded the Wardline. It is ornate and clearly a relic, not a weapon for
  battle. It is said to "cleanse the blood" and to "rule with righteousness", so the story assumes it helps against Rhodri. **Nobody actually
  knows if it does.** Some priests hid it and sank their abbey to keep it from Rhodri, because they feared he could rise over Fiona (scenario 9:
  not the church's stance, which supports Fiona). In the end it is used to behead Rhodri (scenario 11).

**The unlock sites**
- The **mage's tower** (apprentice) and the **ruined chapel** (acolyte) belong to heir 1's supporters, the court mages and the church. Unlocking a
  unit means finding what is left of them (the chapel in scenario 6, the tower in Fiona's refuge in scenario 7).
- The **stone circle** (summoner) belongs to **druids**. They stayed out of the question of the succession and kept their distance from the whole
  conflict. They are not part of heir 1's alliance (scenario 7). Why: their pact with the first king, as old as the Wardline, says the druids keep
  the land and the crown keeps the border, and neither meddles in the other's affairs. A quarrel over who wears the crown is the crown's affair.
  The church that backs Fiona also once drove the druids out of the towns, so they owe her side nothing. They defend their own grove, and they
  let the refuge stand beside it.

**The neighbouring countries**

Veliron is a kingdom. Around it lie three rivals, each a different form of state:

| Country | Form of state | Names |
|---|---|---|
| A | A kingdom | Kingdom of Karmere |
| B | A republic | Republic of Lyrenne |
| C | A theocracy | The Holy Dominion of Aurelith |

Any of them, or several, could have sent the spies. The story never settles it. It may point at one in one scenario and at another in the next.

## 4a. The map of Veliron

Where things lie (the campaign map on the title screen, `ui-design.md`; `Campaign.PLACES`):

- **Borders:** the ocean to the west; the **wilderness** to the north, beyond the **Wardline**, the chain of towers along the whole northern
  border; the **Kingdom of Karmere** to the north-east, the **Republic of Lyrenne** along the middle and the south-east, the **Holy Dominion
  of Aurelith** across the south. Veliron shares land borders with all three.
- **The outpost** (scenarios 1, 2, 3 and 10): on the north road just below the Wardline, the middle of the north. The Wardline's ruins run
  north from it to the border.
- **The guild town** (4): the Silver Thread's harbour on the west coast.
- **The old fort** (5): in the pass through the north-eastern mountains, on the inner Wardline, near Karmere.
- **The battlefield** (6): the plain in the middle of the kingdom, where the armies met; the way east crosses it.
- **Fiona's refuge** (7): in the eastern forest, near the border with Lyrenne.
- **The capital and the Pale Court** (8, 11): in the heart of the kingdom, south of the middle.
- **The drowned abbey** (9): on an island in the great lake in the south, near the Dominion's border.

The places leave room between them for more later. Brenna's road: the outpost, the guild town, the old fort, the battlefield, the refuge,
the court, the abbey, home again, the capital.

## 5. Monster categories

There is **no single source** of monsters. Categories exist because each arrived for its own reason, and the library can group by them. The
**monster** categories (Wilderness, Undead, Evil, Arcane) are not people who were changed. **Renegades** and the **Dread Legion** are people, and
the library marks them as such.

| Category | Members now | Planned or open | Why they came |
|---|---|---|---|
| **Wilderness** | goblin, ork, rat, slime | spider mother with her eggs and spiderlings (built: `enemies-design.md` §15b); **sea monsters**: giant crab (4), giant octopus and leviathan (9), which swim rivers, lakes and the sea (built: `aquatic-design.md`) | Always lived around the kingdom. The Wardline held them back. |
| **Renegades** (*Abtrünnige*) | thief | bandit, deserter, assassin | **Fully human**, ordinary criminals who saw the chance when the order collapsed: bad people, but not evil. |
| **Undead** | skeleton | ghost, wraith, zombie | The war's dead, unburied. |
| **Evil** | vampire, necromancer | demon | Intelligent and malicious, drawn by the death. |
| **Dread Legion** | footman, captain, archer, guardsman, banner-bearer, the court champion (campaign only: `scenarios-design.md` §7.7, §7.13) | the marshal (a mid-boss) | Rhodri's own army: human soldiers under the corruption's influence, like brainwashing. See below. |
| **Arcane** (*open*) | witch, gargoyle | siren, wisp, golem | Magic-made or magic-using. Goes with neither Wilderness nor Evil. |

Library and log text should use the category name ("a Renegade", "the Undead"), not a person's backstory.

**Sea monsters** are not a category of their own: they are the aquatic part of the Wilderness, as old as the sea. They follow rivers, lakes and
the sea (built, see `aquatic-design.md`).
- The **giant crab** is the basic shore attacker (tough, slow, hard-shelled). Scenario 4 uses only crabs, and one siren at most.
- The **siren** is **Arcane**, not Wilderness (its song is magic), and used sparingly: an amphibian support monster whose song pulls our units
  towards her and slows them, and whom melee cannot hit while she is in the water (an animal here, not a person).
- The **giant octopus** grabs with eight arms and can drown whoever it holds. It is a **guard** of the abbey in scenario 9 and does not come in
  waves. In the parallel monster design
  it is the strongest mob in the game (this can change).
- The **leviathan** is a water-bound serpent that blasts from the water. It is a scripted boss in scenario 9.

**The Dread Legion** is Rhodri's **organised battle force**, and it is made of **people**: the soldiers of the military that backed him, ranked
and led. They are not monsters, not Evil and not dead. The corruption that he fed with their lives (section 4, step 6) bends their will, like
**brainwashing**: they follow orders without question, say little and look empty-eyed, but they are still human and still have a name and a past.
They look like soldiers in different poses and with different skills, paler than human, and behave a bit robotically, like soldiers following
orders.
- Its core is **Brenna's own old company**, whom the ritual at the pass bound (scenario 5). Two of them are named: its captain **Lysa** and her
  comrade **Torben**.
- When a Legion soldier falls, the game shows a release: the pale colour fades, a human face shows for a moment and a breath goes out (built:
  the colour warms, a pale breath rises).
- Its named captains, **Lysa** and **Torben**, are never killed before the story is done with them: beaten, they fall back (scenario 5).
- It is the army of the final struggle, and it is what marches on the home village (scenarios 5, 8, 9, 10 and 11).
- The difference from the Renegades: they chose to be criminals, the Legion never chose.
- In the last wave of scenario 11 Rhodri himself fights as a captain-like melee boss with commanding abilities.

## 6. Trade: the merchant guilds

A market that trades with the outside (planned) is how the story shows that the world beyond Veliron still exists.

- **The guild split.** The merchant guild tried to stay neutral in the war, but it was hit hard and broke apart. It split into several guilds that
  are now somewhat hostile to each other. The pieces that picked a side made alliances (with Fiona's court, with Rhodri's army, with each other). Only a smaller version of
  the original stayed neutral, with no alliances: the **Silver Thread Merchant Guild** (short: the Silver Thread Guild; "the one thread
  that still runs through the whole kingdom"). The guilds that chose call it the **Leftovers**. The outpost and its merchant
  belong to it.
- **Why they deal with the outpost:** its walls make it the only safe stop on its stretch of road, it sits near the old kingdom's ruins where
  relics and salvage are worth coin, and the merchant is the hero's friend.
- **Enemies on the road:** Renegades raid caravans and steal gold on the same roads. The rival guilds are a second threat (whether they hire
  Renegades is *open*).
- **Mechanics it could reuse:** the existing "buy material with gold" button is the first trade. The co-op caravan (a horse-drawn cart) can be the
  traders' arrival.
- **Growth** (at home; away it is Pell's wagon, and the guild town of scenario 4 has the full market):

| Stage | What it is | Story reason |
|---|---|---|
| Peddler | A few goods in small amounts. | The merchant arrives alone, the first outsider in months (scenario 2). |
| Stall | More goods. | The merchant comes back. |
| Silver Thread market | Full trade, caravans. | The roads are safe enough (scenarios 3 and 4). |

## 7. Scenarios: a campaign

The scenarios form one **campaign** of eleven: each builds on the last, and playing all of them tells the whole story. Each has its own settings
(map, difficulty, size of the village) and explains why the monsters roam. The map generator is not part of the story. The hero and the merchant
return in every scenario from 2 on.

The detailed outline of every scenario (place, starting point, objective, problems, events, story, cutscenes) is in `scenarios-design.md`, which
takes precedence. The table below is a short summary:

| # | Name | Place | Story | New monsters |
|---|---|---|---|---|
| 1 | Homecoming | Home (ruined) | Brenna wakes in a tent on the road home, rebuilds the village with her father Einar. The war is a rumour. Pell arrives. | Wilderness, weaker |
| 2 | The Old Friend | Home | Pell's reunion, news of the world and the guild split. | none new |
| 3 | The Wardline | Home | Restore the broken watchtowers. The first evidence of the wider war. | Renegades |
| 4 | The Split | The guild's coastal town | The rival guilds. The first hard evidence of the foreign spies. | more Renegades, giant crabs, at most one siren (Arcane) |
| 5 | The Betrayal | Brenna's old fort | How her company was betrayed and bound. The first Legion patrol. | Arcane (witches, gargoyles), Dread Legion patrol |
| 6 | The Dead | A battlefield village | The war's scale. Bury the dead before they are raised. | Undead, the first necromancers (Evil) |
| 7 | The Exile | Fiona's refuge | Fiona's side, and earning her trust. | none new |
| 8 | The Pale Court | The capital's outskirts | Rhodri's court, his offer, the crown. | Vampires (Evil), Dread Legion camps |
| 9 | The Drowned Abbey | A drowned abbey on a delta shore | The First King's Hand. The Legion hunts it too. | Leviathan, giant octopus (a guard) |
| 10 | The Last Wardline | Home | The Legion attacks the home village. The mid-boss Halvard. | All, led by the Dread Legion |
| 11 | The Crown | The capital | The final fight. Fiona beheads Rhodri, the crown breaks and the curse passes to her. An open end. | All, the Dread Legion in force |

**Nothing carries over between scenarios** (no units, relics, hero levels or market stage). Every scenario starts from its own scripted baseline,
so any one of them can be replayed on its own. The story carries over, not the game state.

**Deaths.** In scenarios 1 to 3, at the home village, Brenna revives as in the normal game (her people bring her back). In **all other scenarios
her being downed is a defeat**, and the player can try again. This includes scenario 10, although it is at home: there is no one left to bring her
back. Pell's death fails every scenario from 4 on, and Fiona's death is always a defeat. Scenario 1 also fails if any villager dies. These are
per-scenario settings (in each scenario's own file, `scripts/scenarios/scenario_<n>.gd`), and a message on entering the first away scenario should say so.

Each scenario opens and closes with a cutscene (section 8). The outro plays when the scenario's **objective** is fulfilled. The objectives are in
`scenarios-design.md`. The tutorial is merged into scenarios 1 to 3 (see `scenarios-design.md` section 4).

## 8. Where the story shows

The story is told mainly through **two cutscenes per scenario**, one at the beginning and one at the end. The player can **skip** any cutscene.
The rest of the telling is in places the game already has.

- **Intro cutscene (every scenario):** plays at the start and introduces the part of the story the scenario covers. The one for scenario 1 has
  Brenna wake in a tent on the road home and see the ruined village in the distance.
- **Outro cutscene (every scenario):** plays when the scenario's objective is fulfilled and gives further information that closes the scenario and
  leads to the next. The campaign's last one is the story's ending, an open end (scenario 11).
- **Skipping and format:** cutscenes may be skipped by the player. They play in the game's engine: the map behind, the camera moving, people
  speaking in dialogue boxes with their portraits (`scenarios-design.md` §7.2). Whether they can be watched again from the title screen or the
  library is *open*.
- **Title screen:** a one-line intro (draft below).
- **Library:** category groupings on the Enemies tab (the Renegades and the Dread Legion marked as people), a short lore line per entry, lore on
  the Places tab for unlock sites and ruined towers.
- **Treasures and relics:** journal fragments and evidence from the war (scenario 5's three finds, the logbook in scenario 3), and the First
  King's Hand as the one named relic (scenario 9).
- **Event log:** a line when a Wardline tower is restored, the first time a category appears, the merchant's arrival.
- **Tutorial:** merged into scenarios 1 to 3.

Draft intro:

> *Veliron fell in a winter of civil war. The towers stand empty and the roads lead only to your gates. One outpost kept its post. Nine huts, four
  towers, and a steward who sided with no one. Hold the line.*

## 9. Open questions

The story is otherwise settled. What remains (the other open questions are in `scenarios-design.md` section 5):

- Whether the rival guilds hire Renegades.
- Whether witch, gargoyle and siren form an Arcane category.
- Whether the Dread Legion can be freed, for example when the crown breaks (the ending is open).
- Whether cutscenes can be watched again (their format is decided: in the engine, with dialogue).
