# Veliron's Outpost: advancements (design)

Status: **built** except the three advancements that need the marketplace (Trade charter, and the
trader's pair in tier 2: designed, not built). Tested by tests/advancement_bot.gd. Every number
lives in `scripts/core/config.gd` (`ADVANCEMENTS`, `ADVANCEMENT_TIERS`, `TARGETING_*`), never here.
The research is `Research` (one per village), the effects are read where they apply through
`Village` (`adv_bonus`, `max_piece_level`, `walk_bonus`, `targeting`, `kill_gold`, `crit`,
`recruit_cost`).
Scope: what advancements are, how they are researched and unlocked, exclusive choices, the
targeting advancements, and the list. The town hall (where research happens) is in
docs/village-design.md.

## 1. Why

- **Mid and late game have little new to decide.** Once the walls stand and the army is
  specialised, the game asks the same questions. Advancements give a long-term goal and
  village-wide choices: lasting upgrades, some of them real forks.
- **Within one game only.** Advancements are unlocked during a game and gone when it ends.
  No meta-progression: it would change the balance of every scenario and every bot baseline,
  and a co-op game would mix players with different unlocks. Statistics across games may come
  later, but they never change gameplay.

## 2. Research

- At the **town hall**, one research at a time, paid with **gold plus research time**
  (`Config`, per advancement). A single queue is easy to read. The gold is paid when it starts;
  cancelling gives back what is left of it by the research done, as for a construction site.
- The hall's panel shows the research under way and opens the list (*Research...*): every
  advancement with what it does, its conditions (met or not), its cost and time.
- **Icons:** every advancement has its own (`Config.advancement_icon`, drawn by
  `tools/gen_art.py`, `ADV_ICONS`), shown beside its name in the list, the library and the
  hall's panel (the `{adv:<id>}` text token). One badge for all, its ring telling the tier
  (iron: tier 1, gold: tier 2), so a new advancement needs a sign in `ADV_ICONS`
  (advancement_bot checks every one has its icon).
- **Town hall levels are the tiers:** level 1 has no advancements, level 2 opens tier 1,
  level 3 opens tier 2. Upgrading the hall is the gate to the second half.
- **A devastated town hall pauses research.**
- **Unlock conditions**, any mix of:
  - a wave reached;
  - prerequisites (other advancements): this makes it a tree;
  - the town hall's level;
  - **deeds**: counts from the in-game statistics of *this* game ("X melee kills", "explore
    half the map", "find a volcano"). Deeds never read statistics from earlier games.
  - **gold earned** this game, from any source (the statistics' `earn.gold`).
- **Bonuses add up** with relics and other sources; the same advancement can't be had twice
  (Drill I and Drill II are two advancements).

## 3. Exclusive choices

- The tree is mostly open: everything can eventually be researched; cost, time and
  conditions decide the order.
- A few pairs are **exclusive**: researching one locks the other **for good**. They are rare,
  only where two options contradict each other, and the town hall's panel says clearly before
  research starts that the choice is final (a confirmation naming what it locks).

## 4. Whose advancement

- **Each player has their own.** An advancement helps only the village that researched it,
  unless it says explicitly that it is for all players.
- **Shared vision** is one way: the researcher sees the other players' surveillance; they
  don't see theirs unless they research it too. What it sees there it also knows (it is explored).
  It is offered only with more than one village.

## 5. Targeting: better or manual (exclusive, tier 1)

The default for every unit is "nearest the village centre" (docs/military-design.md): an enemy
that broke in comes before one standing outside a gate. Scenario rules that override targeting
(an octopus arm holding one of ours first) stay above both advancements.

### Better targeting

No control per tower; every tower in the village uses a better rule **chosen by its stationed
unit's kind**:

| Unit | Rule |
|---|---|
| Archer | the default (the baseline) |
| Swiftbowman | weakest first |
| Crossbowman | strongest first |
| Apprentice | weakest first (small hits finish things off) |
| Fire mage | the biggest group, for the most damage on impact |
| Ice mage | fastest first |
| Spatial mage | the enemies its throw-back affects first |
| Acolyte, inquisitor | unholy first, then the default |
| Earth elemental | strongest first (it is the tank) |
| Fire elemental | groups first |
| Thornling | fastest first |
| Healing mage, high priest | no change (they don't target enemies) |

### Manual targeting

Every **tower** (wall towers, watchtowers, the town hall's tower; not barracks sorties) gets a
switch: **nearest the village centre** (the default), **weakest first**, **strongest first**,
**fastest first**, **support first**.

- "Support first" goes for the back line of a wave: enemy kinds with the `support` flag in
  `Config.ENEMIES` (a hand-kept list: witch, necromancer, spider mother, siren, Legion
  banner-bearer, Legion marshal, the Crowned King; docs/enemies-design.md §12), then falls
  back to the default.
- The setting belongs to the **tower**, not the unit: it stays when the unit changes, and for
  some units (a healing mage) it changes nothing. The tower's panel shows it with a button to the
  next rule (command `set_targeting`).
- A summoner's elementals follow their tower's setting (Better targeting: their own kind's rule).
- Barracks sorties keep the default under both.
- **How it is built:** `Targeting` gives the rule (by kind or by the tower's switch) and sort
  keys; `MilitaryBehavior.enemies_near` and the elementals' target choice use them, below the
  scenario overrides and spider eggs last, with nearest-the-centre breaking ties.

## 6. The list

Everything here was agreed in the design session as a starting list; amounts, costs and
conditions are `Config` values (`ADVANCEMENTS`), agreed when built.

### Tier 1 (town hall level 2)

- **Walls, gates, wall towers and watchtowers to level 4** (one advancement for all four
  kinds). New art per material from `tools/gen_art.py`, a real cost: seven materials.
- **Better targeting *or* manual targeting** (§5).
- **Faster attacks** for every unit (a share). "Every unit" is the army, not the hero.
- **Forester, farmer, gatherer and builder walk faster.**
- **Drill I:** a unit's level-up (e.g. level 3 to 4) costs a share less, both the gold and the
  XP needed at the training grounds. Never a specialisation (that is §6 tier 2's own choice).
- *(Designed, not built: needs the marketplace)* **Trade charter:** one more caravan in transit
  at once (docs/market-design.md).
- **Skilled looting:** more gold per kill (what it is: better at taking what the fallen carry);
  only once the village has earned some gold this game.
- **Shared vision** (co-op, one way, §4).
- **Eye for vital points:** melee units, and the hero while she fights with a melee weapon
  (`Hero.has_melee_weapon`), sometimes strike critically; a deed condition: melee kills, the
  hero's included (`kill_by.melee`).

### Tier 2 (town hall level 3)

- **Walls, gates, wall towers and watchtowers to level 5.**
- **More damage** for every unit (a share).
- **Drill II:** as Drill I, adding to it.
- **Master builders** (faster building) ***or*** **cheaper repairs.**
- **Cheaper specialising *or* cheaper base units** (recruiting).
- *(Designed, not built: needs the marketplace)* **Trader: better price at the edge *or* one more
  caravan.**

### Candidates for more exclusive pairs (proposed)

- Fortify (more wall HP) *or* mobilise (a wider barracks activation range). Not built: left
  out until it is agreed.

Wall levels 4 and 5 are never part of an exclusive pair: no repair choice may block them.

Dropped: **shared exploration for all players** (tier 2): shared vision covers it; a pair
"walls level 4/5 *or* cheaper repairs".

## 7. Scope and other modes

- **Campaign:** off unless a scenario switches it on.
- **Save:** researched advancements, the research in progress, exclusive locks, the manual
  targeting setting of every tower and the deed counters need `SaveGame.capture` / restore lines
  and a `SaveGame.FORMAT` bump.
- **Commands:** starting and cancelling research and setting a tower's targeting are
  `Commands`.
- **Library:** a page per tier, built from `Config`.
- **Tests:** a new `advancement_bot` (conditions, exclusive locks, each effect, both targeting
  modes). The balancing bot learns to research later.
