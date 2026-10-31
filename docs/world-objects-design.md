# World design: special objects
Part of the world design; index in world-design.md. Numbers live in `config.gd`, behaviour in `scripts/world/objects/` and `scripts/world/gen/`.

## 9. Special objects

Neutral things on the map, **hidden in the fog** until explored. Finding one is logged at Info level and says who can use it (the hero claims, loots, unlocks; everyone for a mine). There are no hover hints or markers: the log is the only guide, so the player has to explore.

**Placement** is per slice (world-design.md §3), but not every kind has to appear in every slice: mines need mountains, lairs and ruins are spread over the map, unlock-site copies are fewer than slices. Every object stands on open land (not on a road, in a village, on the map edge or right next to a village centre), keeps its distance from other objects, and is reachable on foot from its slice's village. What is kept fair is the **treasures** (same count and tiers at the same distances from each village). Objects stand on open land, apart from each other, and are reachable on foot from their slice's village (so nothing is unreachable by design).

### 9.1 The hero in Explore mode

She takes the nearest target of the highest priority her village has found and she can walk to: first **claims** (awakened unlock sites, ruined watchtowers), then **looting** (unguarded treasures, dropped loot), then **exploring** unknown land.

- No range limit, in any slice: simplest rule, and slices are only about fairness of generation.
- She never loots a guarded treasure before its camp is cleared and never attacks a camp on her own: a camp is a real fight, so it is the player's call (§9.3).
- The explorer villager only reveals. Claiming, unlocking and looting are the hero's job, which keeps her Explore mode worth having. Gatherers pick up dropped loot, nothing more.

### 9.2 Treasures

Kinds differ by terrain, so they differ from slice to slice, but count and tiers are the same. Tiers are by distance from the village: far is worth more and more dangerous.

- **Relics** (small permanent bonuses) replace gold only sometimes, only on higher tiers and at most a few per map, so they stay special. Cleared lairs can drop one too (§9.6).
- **Looting** is automatic in Explore mode; there is no "Send hero" button: fewer choices. The reward is paid when the looter gets home, like corpses. A hero downed on the way (or switched to another mode) drops it as a sack that the hero or a gatherer can pick up. Only a first loot earns XP, so dropping and re-taking can't be farmed.
- **First come, first served**, in anyone's slice; the log tells everyone. This is deliberate co-op tension at low cost.

### 9.3 Guarded treasures: monster camps

Every far treasure, some middle ones and no near ones are guarded by a camp: neutral monsters by tier, tougher than normal, who stay by their camp and don't walk the roads. They are enemies like any other (in the `enemies` group, so towers and units fight them), pay their kill gold like wave enemies and leave no corpse. Every slice has at least one far camp (its far treasure is placed where a camp fits, closer if need be), so the fight is always on offer.

- **Sending the hero is an explicit order** ("Attack with the hero" in the camp's panel), because it is a real fight. A mode button cancels it; one she can't reach she gives up (docs/hero-design.md §4.5). Towers and barracks fight guards in range without an order.
- **A failed attack isn't wasted:** guards don't heal and the dead stay dead, so the next attempt finishes the job. Cleared camps stay empty, which gives the hero something to do between waves.
- **Explorers keep away from guards** (and awake lairs' guards); they would only flee home again and again, so fog by a camp waits until it is cleared.
- **Fleeing uncovers the camp:** whoever flees from guards (any villager, the hero in a worker mode) finds the camp for their village. Otherwise a camp hidden in the fog could never be ordered against.

### 9.4 Unit-unlock sites

Summoner, apprentice and acolyte are found on the map instead of being in the Army tab from the start; later units are further out and awaken later. Archers, shield bearers and barracks are there from the start.

- **Global unlocks:** one find unlocks the kind for every player, so a co-op team shares the benefit (and nobody is locked out by a bad slice). Copies are fewer than slices and sit in different slices.
- **Dormant scenery first:** the sites exist from the start and can be found, but nothing happens there before their wave. At the wave every copy awakens; each player is told by whether *their own village* already found a copy (another player's find doesn't count): a rumour if not (no marker, the site still has to be explored), "has awakened" if so.
- The hero unlocks it by visiting (Explore mode goes for it first, §9.1). Other copies stay as scenery.
- **When new units are added later: ask how each one is unlocked** before building it.

### 9.5 Ruined watchtowers

Old towers out in the land, always near a road (more road nearby, likelier the spot), so they can be reached and defended.

- Anyone can reveal one; only the hero **claims** it, before exploring new land.
- **Restoring is a separate, explicit order** with a cost: claiming alone only reserves it. The ruin becomes a devastated watchtower repaired by a builder like any repair (docs/siege-design.md §4), at a reduced price.
- A map file can also hold a **ruined barracks** (`"building": "barracks"`; the Wardline, docs/scenarios-1-3-design.md), restored the same way. The generator only makes tower ruins.
- First come, first served, in any slice: a village may own a tower in another player's land. Restoring is the owner's call.

### 9.6 Monster lairs and mines

**Lairs** look different by terrain (cave by a mountain, hollow tree in pine forest, sunken ruin in swamp, pit in ash land, crypt on steppe; none in meadow, oak woods or heath), lie far out and block walking.

Each lair has its **own road** to the network, deliberately winding (bent waypoints, noisy routing cost), so its monsters take a long, visible way in and the player can build for it. A lair that can't get a road is placed elsewhere.

**Waking** is staggered: per slice the first lair wakes late, so the early game stays simple, and each further one every few waves, in an order fixed by the seed. The slice's village gets a loud notice and the warning lights mark the new road (also after the usual early waves); a village that hasn't found it gets only a rough direction.

- An awake lair is **one more spawn point** for its slice's share: the wave keeps its size and mix, and the lair's entries swap kinds with edge entries so it sends only its **theme's** kinds (a crypt the undead, a hollow tree goblins and rats), limited to kinds whose wave has come. No extra enemies, so lairs change where, not how hard. In co-op a lair's enemies go for its own slice's village.
- Awake lairs have guards, as strong as that wave's enemies.
- **Clearing** is an order, like a camp. A cleared lair leaves a loot sack (growing with waves, sometimes a relic the village lacks) and sleeps a few waves, then wakes again with new guards: clearing is a reward and a respite, not a permanent fix.

**Mines** sit on the outer edge of a mountain range, far from villages and objects, each with a road spur to the nearest road. A map with mountains has at least one (one more is tried anywhere if none was placed); a slice without mountains gets none.

- **The miner** is unlocked for every player once anyone first walks up to a mine, a discovery reward like the unit sites. He lives in a hut (dies with it) but works at the mine, safe inside, producing gold passively.
- **One miner per mine**, first to arrive; a second is told it's taken and walks home unassigned. A mine can't be claimed, only worked. Unassigned or dead, the mine is free again.

### 9.7 Later (not in this scope)

Oases (farms in the desert) and a travelling merchant. (The merchant exists now only as the campaign's Pell, docs/scenarios-design.md; the generated game has none.)

### 9.8 Water monsters: what the generator provides

docs/aquatic-design.md needs deep water near villages, which the older maps didn't have (rivers one deep tile wide, lakes kept away from villages, villages kept away from the sea). The generator now provides it (`GenWater.near_villages`, `landings`, `water_spawns`):

- **Water bodies** are labelled once (`Pathing.label_water`; a bridge over deep water joins both sides) with size and width, which the checks, the editor and the game all use to decide what fits.
- **Coast maps:** every village whose sea isn't close gets an **inlet**, a winding channel from the sea with a deep core and a shallow rim, reaching close enough to the walls for water monsters to matter. It joins the sea, so roads route around it and beaches line it, and it gives up with a soft warning when no reasonable channel exists. Inlets are made right after the villages and before the roads (stage 6b, world-design.md §3.2), which is why the road network treats them as sea and never crosses their deep water. An inlet keeps away from other villages, mountains, lava, craters and the map's outer ring. The sea keeps its distance from villages everywhere else.
  **Known rough:** the inlet generator's result looks ugly; it works but is due a rework.
- **Other map types:** with the type's `"lagoon"` chance a village gets a round lake on its most open side, deep enough for a leviathan (an octopus only when big). Lagoons and inlets roll their own random numbers, so a map that gets neither is unchanged (old seeds keep their maps).
- **Landings** (after the roads): a short road from the shore near each inlet's or lagoon's tip to the network, so crabs and sirens can climb out.
- **`water_spawns`** (last): a few per body that fits a water monster and reaches a village, at the map edge if the body reaches it, else in deep open water away from villages and each other. Stored in `MapData` and the JSON format.
- **Checks:** the editor refuses a water spawn off deep water or in a body no water monster fits; a Coast village without an inlet is only a warning.
- Changes like these alter the generated maps, so the title backdrop's baked maps must be rebaked (rebake-title-maps skill); title_bot fails while they are stale.
