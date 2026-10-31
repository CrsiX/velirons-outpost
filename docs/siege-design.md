# Veliron's Outpost: building HP and sieges (design)

Status: **built; describes the current code**. Tested by tests/siege_bot.gd.
Scope: why buildings have HP, devastation, repairs, gate and wall levels, and how enemies
break into a village. Every number lives in `scripts/core/config.gd` (`BUILDING_HP`,
`PIECE_PRICES`, `PIECE_LEVELS`, `REPAIR_SHARE`, `REPAIR_TIME_SHARE`, `SIEGE`, each enemy's
`"siege"` and `"entry"`); the mechanics are in `scripts/systems/siege.gd`. The village is in
docs/village-design.md, enemies in docs/enemies-design.md.

## 1. Summary

- **Every building has HP**, huts too (a hut is all-or-nothing: one blow burns it).
- **Damage stays.** Buildings never heal on their own, so a siege has lasting cost: the
  player must spend building material and builder time afterwards. This ties raids to the
  material economy instead of only to huts and lives.
- **At 0 HP a building is devastated:** a ruin that does nothing until repaired.
- **Enemies break in.** Walls and gates hold them back; an intact gate is no longer the end
  of an enemy's road. Once inside, an enemy burns the nearest intact hut, as before.
- **Flyers** ignore walls; rats and thieves slip through a gate after a short hold, so a
  wall is never an answer to them.
- **Gates and walls** upgrade like towers, so the player can decide where the village is
  strong.

## 2. HP

`Config.BUILDING_HP` gives each kind's max HP per level (index = level − 1).

- A finished building starts at full HP; construction sites have none and take no damage.
- **Upgrades** raise the max HP and add the difference to current HP, so a damaged piece
  keeps the HP it was missing: an upgrade is not a free repair. A devastated building, or
  one being repaired, can't be upgraded.
- **Damage:** every category counts the same. Differentiating buildings by category would
  need resistances nobody can see; the title backdrop's buildings take none.

## 2a. Materials of walls, gates and wall towers

Every wall, gate and wall tower is made of one material (`Building.made_of`, from the map's
village layout; `Config.PIECE_MATERIALS`). Materials are mostly about identity: a Highlands
village should look like a Highlands village.

- Stone, sandstone, basalt, limestone, granite and ice are alike in play. Wood is the one with a
  gameplay meaning: an improvised palisade for forward outposts, cheaper and weaker by one
  factor that scales HP, price, upgrade costs and build / repair / upgrade times together
  (`PIECE_MATERIAL_SCALED`, `Config.material_cost`), so it stays internally consistent
  instead of needing its own tables.
- Each material has its own art for every level and its ruin; the name is the stone name
  with a prefix (`Config.piece_art`). Look descriptions live in `tools/gen_art.py`.
- Huts have a material for their look only; the factor never touches them. The generator
  gives a village's huts its material, the editor can paint each. A scenario's special
  homes (`Hut.look`) keep their own art.
- **Where it comes from:** the generator gives a village one material by map type
  (`PIECE_MATERIAL_BY_MAP_TYPE`), never mixed. Ice (no map type of its own yet), wood and mixed
  villages come only from map files (docs/map-editor-design.md §4); older files get their map
  type's material. Watchtowers have none.

## 3. Devastation

At 0 HP the building is **devastated** (`Building.devastated`). It is logged as Important
and a toast says so.

- **What stops** (`Building.working()` is false): stationed or marching units walk back to
  the reserve (as on tear-down), its worker is freed, rats leave a devastated farm, an
  ordered upgrade is cancelled and refunded, and its sight is gone (a devastated gate keeps
  no watch). "Does its job" is always `working()`, never `complete`.
- **Its look:** the piece's ruin art; the ruined watchtower for watchtowers; other kinds are
  drawn darkened with rubble.
- **Walls, wall towers, watchtowers and light stones** stop blocking their tile, so
  villagers (and enemies, §5) can walk through a broken wall.
- **Huts** keep their own ruin: any enemy reaching an intact hut burns it, and whoever lives
  there dies.
- **Tear-down** works on a devastated building too; its refund scales with the HP share, so
  a devastated building gives nothing back. Tearing down a wreck must not be a way to
  launder damage into material.

## 4. Repairs and upgrades

- **Repair** is an order in the building's panel (`repair` command,
  `Construction.order_repair`), not offered under construction, upgrade or tear-down, or at
  full HP.
- **Cost:** building material only, never gold: gold buys the army, material is the village's
  fabric. It is a share (`REPAIR_SHARE`) of the material spent on the building (price plus
  paid upgrades) times the missing HP share, rounded up. Repair is deliberately cheaper than
  rebuilding, but a devastated building still costs real material.
- **Time:** scaled by the missing share (`REPAIR_TIME_SHARE`); a builder walks over as to a
  site. The building gets back the HP paid for. Damage taken during a repair isn't added to
  it: order another afterwards (no moving target).
- **Cancelling** refunds like a site.
- **The village pieces were never bought**, so `PIECE_PRICES` gives them a price (and build
  time) for the repair formula; a restored ruin counts its full list price.
- **Huts** are repaired all or nothing (*Rebuild*, half the price); *Rebuild all huts* queues
  every ruin.
- **The ruined watchtower** (docs/world-objects-design.md §9.5) is claimed by the hero; *Restore*
  turns it into a devastated watchtower of the claimer and orders its repair at once, for
  half a watchtower's price: cheaper than building new, as the reward for claiming it.
- **Gate and wall levels** (`PIECE_LEVELS`): up to level 3 for material and a builder's time,
  like towers. They only add HP and look. Wall towers use `TOWER_LEVELS` and also gain HP.

## 5. Enemies at the village

### 5.1 How an enemy gets in

Each enemy kind has an `"entry"`:

- **`"siege"`** (default for anything walking): it breaks in (§5.2).
- **`"slip"`** (rats and thieves): stays on its road to the gate; an intact gate holds it
  briefly (`SIEGE.slip_time`), then it passes unharmed and does what it always did at a
  gate. The hold keeps a gate meaningful without making small raiders chew through walls
  (which would also make thieves and rats an HP sponge instead of a nuisance). A devastated
  gate doesn't hold it.
- **Flyers** (`"flying"`) keep to the roads until close, then fly over to the nearest hut.
  A vampire bat still turns back at a gate (docs/enemies-design.md).
- **Water-bound monsters** never come ashore and don't break in.

### 5.2 The siege field

`Siege` (one per village, rebuilt on demand) is a 4-connected Dijkstra field over the village
and a band (`SIEGE.approach`) round its pieces, towards its intact huts. The guild warehouse
is never a target (only thieves go for it, docs/scenarios-4-6-design.md).

- **Costs:** open ground is cheap; a ruined hut, devastated piece or open gate counts as
  ground; an intact gate, wall or wall tower costs a detour proportional to its HP
  (`SIEGE.hp_per_step`); what an enemy can't walk on is out.
- **Why a cost field instead of "attack the gate":** enemies should take the cheapest way in
  *as the player built it*. A level 1 gate is weaker than the walls beside it, so it draws
  them; upgrading it sends them to a wall instead, if the detour is shorter than the HP
  difference; a devastated wall pulls them round an intact gate. A damaged piece gets cheaper
  as it loses HP, so they keep at the weakest. Upgrades and repairs therefore shape where
  the fight happens.
- Movement is 4-connected on purpose: a devastated corner tower leads nowhere while both
  its walls stand, because the hut beside it is only diagonal.
- **Flyers** use the same field with every tile as ground.
- **Rebuilding:** marked stale whenever anything it depends on changes, rebuilt when next
  needed, rate-limited (`SIEGE.rebuild_interval`) except at once after a devastation or
  repair, so the player sees the effect of a fix immediately.

### 5.3 An enemy breaking in

- **Leaving the road:** an enemy follows its road until it is within `SIEGE.approach` of the
  village's pieces on a tile the field reaches, then is *sieging* (`Enemy.sieging`) and
  follows the field.
- **At a barrier** it stops and attacks it (`Enemy.breach`):
  - **Fighting comes first.** Its behaviour still picks melee foes first; a barrier is the
    least important target. Shot at by a tower, a goblin keeps hitting the gate; walked up to
    by a shield bearer, it turns and fights. Defenders in front of a wall are thus worth
    something.
  - **Blows:** `damage` × the kind's `siege` factor; a witch casts at it instead, when
    nothing better is in range.
  - **Changing its mind:** it rescans periodically but leaves its barrier only for a way
    clearly cheaper (`SIEGE.switch_margin`), so it doesn't run back and forth.
- **Enemies that can't hurt a barrier** (`siege` 0: necromancer, siren) wait in front of it
  and slip past after `SIEGE.stuck_slip`, so a wave can't stall at a gate nobody guards.
- **Inside:** it walks to the nearest intact hut, burns it and is gone (small slimes roll
  their `raid_chance` first).
- **While any enemy is inside** (`Siege.breached(village)`), villagers walking in there are
  exposed; at home they stay safe. A breach is therefore a real escalation, not just a
  cosmetic one. A faded ghost inside doesn't count, a solid one does
  (docs/enemies-design.md §15f): what can't be seen can't be run from.
- **Remaining distance** (`Enemy.remaining()`, what archers use to find the enemy closest to
  the gate): for a sieging enemy, whole tiles to the village's walls.
- **Spatial magic** throws a sieging enemy back up the field, away from the huts.
- **Co-op:** each village has its own field; an enemy whose village falls turns to another
  and leaves its siege.

### 5.4 Who attacks barriers

Per kind, `"entry"` and `"siege"` in `Config.ENEMIES` decide: walking melee kinds break in;
the witch casts at barriers; necromancer and siren wait, then slip; gargoyles fly over;
rats and thieves slip; leviathan and octopus stay in the water. Raised enemies keep their
kind's values.

### 5.5 Other buildings

Farms, camps, light stones, barracks, training grounds and watchtowers can be devastated the
same way, but no enemy goes for them yet (thieves and the guild warehouse aside), except the
octopus: an arm with nobody in reach smashes a building within reach. This is the hook for
scenario tactics later.

## 6. The hero

In Defend mode she watches the whole wall ring, not just the gates, so a breach anywhere
draws her. Enemies inside the walls come first, then the nearest, then the strongest. In
Build mode she repairs like a builder.

## 7. UI

- A damaged building shows a thin HP bar (colour by share); a full or devastated one none.
- Every panel has an HP line; damaged buildings offer *Repair (+cost)* and, while repairing,
  progress and *Cancel repair*; a devastated building's title says so. Gates and walls have
  panels with level, HP, upgrade and repair.
- Log: devastation Important; repairs and level-ups Info; repair orders Debug. The first
  blow at a village piece per wave toasts a warning, so the player looks up.
- The library lists HP per level, gates and walls get their own entries; statistics count
  buildings devastated, repairs done and HP damage taken (repair material under Economy,
  purpose "repairs").

## 8. Saving and co-op

- **Saving:** a save holds each building's HP, `devastated`, level and repair state
  (see `SaveGame.capture`).
- **Co-op:** clients get HP, devastation and repair progress in the building snapshots.
