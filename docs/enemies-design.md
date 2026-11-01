# Veliron's Outpost: enemies (design)

Status: **built; describes the current code**. Tested by tests/enemy_bot.gd (thief, gargoyle,
necromancer, vampire, slimes, spiders, the wrathwood, vultures, ghosts, wolves and riders,
poison, the snake), tests/siege_bot.gd (lurking, leaving, the held wall), tests/rat_bot.gd
(rats), tests/library_bot.gd (families) and tests/sim_bot.gd (waves, raids, corpses).
Scope: every enemy kind, how waves are put together and escalate, difficulty, damage
categories, flyers, corpses and raids. **Every number lives in `scripts/core/config.gd`**
(`ENEMIES`, `WAVE_MIX`, `RAT_PACKS`, `WRATHWOOD`, `VULTURES`, `GHOST`, `MOUNTED`, ...); this doc keeps
the reasoning and points at the symbols.

## 2. Wave flow

- **Timing:** a generous delay before wave 1 (`FIRST_WAVE_DELAY`) so the player can set up; later
  waves start a buffer (`WAVE_BUFFER`) after the last enemy of the previous one is gone (killed,
  through a gate, vanished; debug spawns don't count). *Call now* skips the countdown and pays
  gold for the time saved, to every village: the reward for confidence, and never while a wave
  runs. In the tutorial the player calls wave 1; after that calling is locked until *Play on*.
  Enemies spawn a gap apart (shorter in co-op, by the village count), the rats of a pack closer.
- **Size and strength:** `Config.wave_size(n)` grows linearly. Only HP grows with the waves
  (`WAVE_HP_GROWTH`); damage, speed and loot don't, so a late enemy is a tougher target for the
  towers, not a different kind of threat, and the player's economy isn't swamped.
- **Spawn points:** a growing number of edge spawns (picked at random each wave, capped), plus
  every awake lair of the village's slice. Kinds are shuffled and dealt round-robin over them so
  every road gets a mixed group.
- **Make-up** (`Config.wave_composition`): each kind in `WAVE_MIX` joins from its `from_wave`
  with a `share` that grows per wave up to `max_share`; each present kind gets at least 1;
  `max_count` / `max_count_every` cap a kind (`Config.wave_max_count`). The shares are capped
  together (`WAVE_MIX_CAP`) before rounding, so the special kinds can end up a little above the
  cap after rounding; `WAVE_FILLER` (goblin) fills the rest. The table of who joins when is
  `WAVE_MIX`; the order is a teaching curve: skeletons first, then orcs and slimes, then
  witches and wolves, then thieves and raiders, flyers, and the necromancer line.
- **Rat packs** (`RAT_PACKS`): a chance per wave, more packs as waves go on, each from one
  spawn, inserted as a block into the queue (never inside another pack). Not part of `WAVE_MIX`
  because a pack is a different threat (to the food, not the walls).
- **Lairs** (docs/world-design.md): from `LAIR_FROM_WAVE`, one lair per village area wakes, the
  next every `LAIR_EVERY` waves. An awake lair is one more spawn point for its slice's share
  (it adds no enemies, so waking one changes where they come from, not how many). It sends only
  its theme's kinds (`LAIR_THEMES`, those whose `from_wave` has come, else goblins): a lair
  entry of another kind swaps with a fitting edge entry or turns into a fitting kind. Its
  guards have that wave's HP scale. Cleared by the hero, it sleeps `LAIR_QUIET_WAVES`.
- **Co-op** (LAN): one wave for the whole game. Every village gets the single-player wave from
  its own home spawns, plus an extra scaled by `WAVE_EXTRA_PER_PLAYER` and the village count
  (kinds drawn from the wave's make-up, from random edge spawns, no rat packs) whose target is
  the standing village nearest to where they spawn. The shares are interleaved so all villages
  are attacked at once. A fallen village's enemies turn to the nearest standing one
  (`Enemy.retarget`).
- **Leftovers:** once only enemies that can't get in are left (rats, and lurkers that have
  lurked a while, §7a; and only such are still to come), they leave after `LURK.linger`
  (`Waves._check_leftovers`, `leftovers_leave`): otherwise a rat idling on an empty farm or a
  necromancer at a held wall would stall the wave.
- **Warning lights** (Easy and Normal only): in the first `WARNING_LIGHT_WAVES` waves a soft red
  light marks where a hidden enemy's road enters watched land; later, in a wave in which a lair
  woke, the hidden enemies coming from lairs get one. Hard has none: surprise is part of it.
- **Scripted waves** (`Waves.scripted`, the tutorial and scenarios) are used up before the
  normal rules.

## 3. Difficulty

- `Config.DIFFICULTY_MULTIPLIERS` (per value, else its `"all"`). Hard's speed multiplier is
  deliberately milder than its others: speed and HP together decide how long an enemy stays in
  a tower's range, so scaling both fully made Hard far steeper than Easy is gentle.
- It multiplies exactly the values in `DIFFICULTY_SCALED` (strength and loot). Whole-number
  values (loot) are rounded and never drop below 1, unless they are 0 to begin with
  (`enemy_stat_int`).
- Nothing else is scaled: not cooldowns, ranges and timings (a longer cooldown would make Hard
  easier), nor shares and rates such as `drain`, `gate_eat`, `steal_share`, `bat_speed` or
  `bat_gate_heal`.
- Each enemy also rolls a small spread on its speed so a group doesn't march in lockstep.

## 4. Damage categories and resistances

- Every hit has exactly one category (`DAMAGE_CATEGORIES`): `melee`, `projectile`, `magical`,
  `fire`, `holy`, `poison` (§4a), `pure` (a raised enemy's drain; never scaled). Enemy blows
  are `melee` except a kind's `attack_category` (the witch: `magical`); every blow on one of
  ours goes through `Enemy.blow`, which makes a poisoner's blow a dose.
- `resist` maps a category to a factor on the damage taken (`Enemy.damage_factor`); missing is ×1.
  The library's *Damage* tab shows all of it, read from Config (`Library._damage`,
  `Config.DAMAGE_INFO`).
- **Fire** is its own category, not magical, so that fireballs and fire elementals can have
  their own weak and strong targets: the wrathwood (wood) burns, water monsters shrug it off,
  and the vampire keeps the resistance it had when fireballs were still magical.
- **Holy** (docs/acolyte-design.md §3): the undead and the vampire line take more, the
  Horde a little less; anything a necromancer raised, and anything undead (`Enemy.undead`:
  a raised spider mother's eggs and spiderlings), takes another multiplier (`raised_holy`).
- **Unholy** (`"unholy": true`): skeleton, necromancer, vampire, ghost; raised and undead enemies
  count too (`Enemy.is_unholy`). Only the Inquisitor's targeting uses it.
- Other resistances are per-kind data (vampire vs magic, the wrathwood vs projectiles, ...);
  see `ENEMIES.*.resist`. A factor of 0 means immune, and units whose only category it is
  can't target that enemy at all (`MilitaryUnit.can_face`, `Enemy.hurt_by`; the ghost, §15f),
  so towers and barracks don't waste shots or sorties on it.
- Buildings take categories too, by their defence class (docs/siege-design.md §2b).

## 4a. Poison

A category that works as damage over time (`Poison`, a node on the poisoned unit). It is the threat to *people*: it
burns no hut and breaks no wall (docs/siege-design.md §2b), so a poisoner is answered with
soldiers and healing, not with stone.

- **A dose, not a hit.** A poison blow puts a dose on its target. The dose hits at once and then
  again every tick interval, each tick a share smaller than the one before (decay), until a
  tick would fall below the cut-off and the dose ends. The total is a finite sum, so a dose can
  be balanced like a single blow, but its damage is spread out: the fight can be won and the
  target still be lost, which makes a poisoner dangerous after it is dead.
- **Each tick is a poison hit**, so resists apply per tick, a mount takes the ticks while it
  lives, and the hit counts for statistics like any other.
- **Data:** the first tick is the attacker's damage (so difficulty scales it like any blow);
  decay, tick interval and cut-off are `Config.POISON`, which a poisoner's own `"poison"`
  entry overrides, and are never scaled (rates and timings, §3). The spider mother's interval
  is longer than her cooldown, so no tick falls between two bites: a fight with her costs
  what it did before her bite was poison, and the rest lingers after it.
- **No stacking.** A new dose replaces the running one only if it would deal more in total
  than what the running one has left. Otherwise many weak poisoners (and later the snake's
  packs) would kill anything by sheer count.
- **Immune:** a factor of 0 means no dose is put on at all (no bubbles, no ticks;
  `Poison.can_poison`). The undead (skeleton, ghost, vampire, necromancer, and anything raised
  or undead whatever its kind: `raised_poison`) and the Aberrations (slimes, gargoyle) are
  immune: there is no blood to poison. Our units, the hero and villagers take ×1 (they have no
  resist tables).
- A dose ends when its target dies or is downed. Healing doesn't cure it; the ticks go on, also
  on a villager who got home (the poison is already in them).
- **Seen:** green bubbles rise over a poisoned unit or enemy. Co-op clients see them (the
  unit's replicated state); a running dose is saved with the hero, villagers and elementals
  (a soldier's ends when it takes its post again).
- **Who deals it:** the spider mother (§15b) and the snake (§15g).

## 4b. Enemy families

Every enemy kind belongs to one family. A family is a **description only**: it answers "what
may attack me?" for the player ("lots of undead around" → expect skeletons, vampires,
necromancers, ...). It never sets a number: resists stay per kind (§4), so a family can't
become a second source of truth with exceptions for the vampire or the necromancer.

| Family | Kinds |
|---|---|
| The Horde | goblin, orc, goblin raider: thinking monsters, raiders and warbands |
| Beasts | wolf, rat, vulture, spider mother (with eggs and spiderlings), wrathwood, horse, snake |
| Undead | skeleton, ghost, vampire, necromancer |
| Aquatic | crab, leviathan, siren, octopus (with its arms) |
| Humans | thief, witch, the Dread Legion (brainwashed living soldiers, not undead) |
| Aberrations | slimes, gargoyle: unnatural things |

- A raised enemy keeps its kind's family; that it is undead now is shown by its look and by
  the holy and poison rules, not by the family.
- The necromancer is a living sorcerer, but for the player it belongs with what it raises.
- **In code:** one `family` field per `ENEMIES` entry and a table of the families' names and
  "expect..." texts (`ENEMY_FAMILIES`, `ENEMY_FAMILY_ORDER`). Nothing in the simulation reads them; the library groups
  enemies by family and names it on each enemy's page, and a scenario's text may refer to a
  family. A new kind needs a family.

## 5. Flyers

- A flyer is a kind with `"flying": true` (the gargoyle) or a vampire in bat form
  (`Enemy.airborne`); `Enemy.flies()` covers both.
- It keeps to the roads (so the player's defence layout still matters) but no ground slows it.
  Vultures fly their own way (§15d), and one that has landed to eat (`Enemy.landed`) is no
  flyer.
- It is drawn bobbing with beating wings (`unit_<art>_flap`) over a shadow.
- Only ranged attacks (towers, archers, mages, with their slows and pushes) and fire elementals
  can go for it; the hero, ground soldiers and earth elementals can't (the halberdier is the
  melee exception). Barracks with only melee units don't turn out for one. This is the reason
  flyers exist: they force the player to keep ranged units, not just a melee wall.
- When a flyer hits a ground melee unit whose blow is ready, that unit strikes back
  (`counter_strike`), so melee isn't helpless, only unable to hunt.

## 6. Corpses

- Killing an enemy pays `gold_on_kill` at once to the killer's village (else the village it
  attacked), and leaves a corpse unless its kind has `"corpse": false` (rats, slimes, eggs,
  spiderlings). Raised enemies, camp and lair guards leave none.
- A gatherer (or the hero in Gather mode) brings safe corpses home (no living enemy within
  `CORPSE_SAFE_RADIUS`) for `gold_on_collect` and `food_on_collect`: corpses are the second
  income, so enemies are tuned to pay either on kill or as a corpse. A thief's corpse also
  holds the gold it stole (`extra_gold`).
- Corpses rot after `CORPSE_LIFETIME`; all corpses of wave N and older go once wave N+1 is
  finished, so loot not collected is lost. In the tutorial they don't rot.
- Necromancers can raise corpses (§14), except one marked `"revivable": false`.
- Corpses left lying at a wave's start draw vultures (§15d).

## 7. At the village (raids)

- Walls, gates and wall towers hold enemies back (docs/siege-design.md §5). Each kind's
  `"entry"` says how it gets in:
  - `"siege"` (default): near the village it leaves its road and follows the siege field to the
    cheapest way in, hitting the barrier in its way (`damage` × `siege`; a witch casts at it).
    Kinds with `siege` 0 (necromancer, siren, spider mother, snake) can't break anything:
    they lurk until a breach (§7a).
  - `"slip"` (rats, thieves): an intact gate holds them `SIEGE.slip_time`, then they get
    through unharmed: they are sneaks, not breakers.
  - Flyers fly over walls and gates to the nearest hut.
- Inside, an enemy walks to the nearest intact hut and burns it (huts have 1 HP), on every
  difficulty. Only the villager living there dies; empty huts cost no lives.
- A campaign scenario's guild warehouse (scenario 4) is no target for breaking in: only thieves
  go for it (§11).
- Exceptions, each explained under its kind: small slimes roll `raid_chance` and else melt away
  (`"gone"`: the log's word for it; spiderlings never raid, they scuttle off); rats eat food
  (§10); thieves steal gold and run (§11); a vampire bat heals at a gate and turns back (§15);
  wolves maul a villager (§15e).
- Then the defeat check runs: a village falls with no villagers or no intact huts. While an
  enemy is inside a village's walls, villagers walking in there are exposed.
- Enemies are only visible on watched tiles.
- An enemy whose road ends short of the village starts its siege (or lurks) from there
  (`Enemy._start_siege_at_end`). One that can't go on at all leaves instead, logged at
  Important with its reason and the full state at Debug (`Enemy._log_unbroken_entry`): it
  never burns a hut it didn't reach (that was the rule from before walls had HP).

## 7a. A held wall, lurking and leaving

**The rule: a held wall loses no hut to ground enemies.** As long as no wall, gate or wall
tower is broken, no enemy on foot burns a hut. Holding the wall must be a full answer: the
kinds that can't break anything once slipped through intact walls after a wait, so a wall the
player held could still cost a hut and a life.

- **Flyers are the deliberate exception:** the gargoyle flies over and burns a hut; it exists
  so ranged units are needed (§5). A vampire bat still turns back at a gate.
- **What gets in without a breach burns nothing:** rats eat food, thieves steal gold, a ghost
  hunts its villager (§15f). A gate is never open: an intact gate is a barrier like a wall,
  for every enemy (villagers pass through it; enemies don't).
- **Raised enemies:** a necromancer can't raise a corpse inside the walls of a village that
  has no breach (no broken wall, gate or wall tower), since what it raised would be inside
  without having broken in. Outside the walls, or once there is a breach, it raises as before
  (`NecromancerBehavior._raisable`).

**Lurking** (`Enemy.lurker`, `_lurk_tick`; numbers in `Config.LURK`) is a shared state for
every kind on foot that can't break anything (`siege` 0, entry siege): the necromancer, the
siren, the spider mother and the snake. Waiting motionless in
front of a gate is dull and gives the player nothing to answer, so a lurker keeps busy:

- **When:** it is in its village's siege zone and there is no way in for it: the field's
  "open" layer, in which intact barriers block, reaches no tile outside the walls
  (`Siege.open_way`).
- **Moving:** it roams in short stretches outside the walls with short rests, never further
  from the village than the leash beyond the siege zone (`Enemy.in_lurk_range`), so it stays a
  threat to this village and doesn't wander off into the wild.
- **Busy, by kind** (`EnemyBehavior.lurk_goal`: where its roaming goes; none: anywhere):
  - *necromancer:* corpses within the leash, also away from the walls; it walks there, raises,
    and roams on;
  - *spider mother:* her clutches go on (timed and alarmed, §15b), wherever she roams;
  - *snake:* goes for anyone of ours outside and keeps out of reach of manned towers (§15g);
  - *siren:* sings at units in reach of her song, as on her way (docs/aquatic-design.md §6).
- **The village stays its goal:** the moment a breach opens a way in, it stops lurking and goes
  in along the open layer, and raids as its kind does (the snake mauls, the others burn a hut).
- **Leaving:** once a wave's enemies still about are all ones that can't get in (lurkers, and
  rats), and each lurker has lurked at least a minimum time (Config; so one that arrives last
  still has its moment), they turn round: they walk back along their road and vanish at the
  map edge, with no loot and no corpse (`Enemy.give_up`, `leaving`). On the way they can still
  be killed for their kill gold. Logged at Info ("The necromancer gives up and leaves"). The
  wave can then end. Rats leave by the same rule and timer (they vanish, §2).
- They count for the wave while they lurk; the leaving rule bounds how long they hold it up.
- The ghost (§15f) and the vultures (§15d) keep their own rules; they don't lurk.

## 8. Melee kinds: goblin, skeleton, orc

- `MeleeBehavior`: walks the road; when a melee defender (the hero, a soldier outside, an
  elemental) or an exposed villager is within `SUMMON.attack_range`, it stops, lunges and hits
  every `attack_cooldown`, then walks on. Enemies with 0 damage never stop.
- Goblin: the basic attacker and wave filler. Skeleton: goblin stats without the food, so the
  same fight pays differently and is unholy (the first target for holy damage). Orc: slower,
  tougher, hits much harder, pays its worth as food from the corpse rather than gold: it
  rewards gathering.
- A level-1 earth elemental is as strong as a Normal goblin, and as fast, by design: the
  summoner's baseline is "one goblin per elemental" (`SUMMONS.earth`).

## 9. Witch

- No melee. She walks until a target is within `spell_range`, then stands and casts a whirling
  bolt every `spell_cooldown`. The range equals a level-1 watchtower's, so a tower can always
  answer her: she is frail and rich in kill gold, a priority target that must be reachable.
- **Targets:** first whoever last attacked her (a tower, or a melee defender), else the nearest
  manned tower, military unit outside (walking, or out of barracks, even a summoner) or villager
  outside.
- **Effect:** a tower's unit is bewitched for a share of the spell cooldown (`enchant_ratio`):
  no shooting, summoning or healing, a pink glow. Elementals, the hero, units and villagers
  outside take `spell_damage` (magical).
- **Anti-stall:** after `spell_ignore_after` casts at one target she ignores it, until it
  attacks her again (which resets its count). Without this she could hold a wave in front of a
  tower that can't reach her.
- At a camp (no melee damage), a witch guard hits with her `spell_damage`.

## 10. Rat

- Packs (§2) from `RAT_PACKS`, not part of `WAVE_MIX`. Frail, fast, and their HP grows with the
  waves like anything's. They threaten food, not the walls, which asks for a different defence:
  barracks and the hero near the farms.
- `RatBehavior` states: ROAD, TO_FARM, ON_FARM, CHASE.
  - On the road it looks for a working farm (`Farm.working()`) within `farm_search` and goes
    there off the road. On a farm the farm grows nothing and each rat eats stored food.
  - It goes for villagers and units within `bite_range` and bites within reach (very little
    damage).
  - Once the farm is empty and has grown nothing for `give_up_after`, each rat gives it up for
    good by chance and goes on to the next farm or the gate: an empty decoy farm holds them only
    briefly.
  - A rat on a farm that isn't attacked for `vanish_after` vanishes (no corpse, no gold).
- At a gate it burns nothing: it eats a bit of the food (a fixed amount or a share, whichever
  is larger, at most what there is) and is gone.
- Defence: the hero in Defend mode goes for rats on her village's farms when nothing is near a
  gate; barracks go for farms within `BARRACKS_FARM_RANGE_FACTOR` × their range when nothing
  else is in range, staying within `FARM_DEFENSE_LEASH` of the farm.

## 11. Thief

- Fights like a goblin on the way (`ThiefBehavior` extends `MeleeBehavior`), quicker.
- At a gate it burns nothing. It steals a random amount scaled by the wave, but at least a
  share of the gold (`steal_share`), never more than there is (`Game.thief_steals`), then runs
  back along its road. At the map edge it vanishes with the gold (logged). Killed on the way,
  its corpse holds the stolen gold as well: the player can win it back, which makes the chase
  worth it.
- Where its village has a standing guild warehouse (scenario 4) it goes for that instead: along
  its road to where it passes nearest, then across (never through the walls), plunders it
  (`WAREHOUSE.raid_damage`), steals as at a gate and runs back.

## 12. Gargoyle

Grey stone, the first flyer (§5). It fights in melee like the melee kinds (`MeleeBehavior`) but
only ranged attacks and fire elementals can go for it; ground melee units only counter-strike.
Tough and slow, pays food from its corpse.

## 13. Slimes

- Only the big slime is in `WAVE_MIX`. Slain, a slime splits into `split_count` of `split_into`
  (side by side, popping out of it), which walk on along its road, count for the wave and keep
  its HP scale. Each size has twice the HP and damage of the one below (stat ratios in
  `ENEMIES.slime3/2/1`), so killing one big slime is several smaller fights. No corpses, so
  nothing to gather or raise.
- At a gate the big one burns a hut; the smaller ones only with their `raid_chance`, else they
  melt away.
- A spawned slime rolls a pastel colour from `SLIME_COLORS` (sprite `unit_<art>_<colour>`),
  which its halves keep. It squashes and stretches as it moves.
- One library entry ("Slime"); the smaller sizes have `"library": false`.

## 14. Necromancer

- No attack. When a corpse of another kind lies within `raise_range`, and no gatherer or other
  necromancer has it, it stops and channels on it (a green beam) for `cast_time`. The corpse
  rises (`Waves.raise_corpse`) as its old kind with a share of its HP (`raise_hp`), draining to 0
  over `raise_decay` (pure damage), walks to the necromancer's village and counts for the wave.
  The drain keeps raised enemies a short, bounded threat, and makes gathering corpses before
  the necromancer arrives a real defence.
- After a raise it walks on for at least `cast_time` before the next. A corpse gone mid-spell
  ends it.
- While a fighter of any village is near (a melee defender within `raise_range`, or a manned
  tower that has it in range) it doesn't walk on: it stays and waits for its next raise. Units
  that can't hurt it don't count (`MilitaryUnit.fights()`: not a Healing Mage or High Priest),
  or it would wait by them for ever.
- In a High Priest's aura (it or the corpse) the spell takes `necro_slow` times as long: the
  priest slows it, never switches it off.
- A raised enemy killed pays a share of its kind's kill gold (`raise_gold`); one that decayed
  pays nothing; neither leaves a corpse. The first raise per village and game is logged at
  Info, later ones at Debug. Its own corpse yields nothing and can't be raised.
- It takes extra holy damage, and what it raised takes more again (§4).
- At intact walls it lurks (§7a): it roams within the leash and goes for corpses, also away
  from the walls (`lurk_goal`). It can't raise a corpse inside the walls of a village without
  a breach.

## 15. Vampire

- Fights like a goblin (`VampireBehavior` extends `MeleeBehavior`), tougher, resists magic and
  fire: so it is a target for physical and holy damage.
- **Drain:** of the HP it really takes from whatever it hits (villagers, units, the hero,
  summons), it gets `drain` back, never above its max.
- **Bat:** once, the moment its HP would drop below `bat_below` (even to 0: it is never killed
  in one blow), it keeps that share and turns into a bat in a puff of smoke for `bat_time`.
  The bat flies (§5) at `bat_speed` and doesn't bite. A raised vampire turns too, and drain
  down there also triggers it. It exists so the vampire can't be simply burst down by melee.
- A bat that reaches a gate does no harm: it gains `bat_gate_heal` and flies back the way it
  came. Landed, the vampire takes the road to the village again; only on its feet does it break
  in.
- A necromancer can raise it once.

## 15b. Spider mother, spider eggs, spiderlings (Wilderness)

- **Spider mother:** from `WAVE_MIX` (capped per wave and village, one more every few waves:
  `max_count`, `max_count_every`, `Config.wave_max_count`) and out of hollow-tree lairs
  (`LAIR_THEMES.lair_tree`; a lair's entries aren't held to `max_count`). Bigger than an orc,
  otherwise a melee fighter like it (`SpiderMotherBehavior` extends `MeleeBehavior`; breaks
  walls and gates, burns a hut when she gets in), plus her eggs. The point of her: kill her
  early and she leaves little; let her lay and the wave multiplies, so she pressures the
  player to have firepower at the edge of the defended area.
  - *On the way:* once she is within `lay_near` of a manned tower or barracks of any village
    whose units fight (a unit stationed there, a barracks' out on a sortie too; not a Healing
    Mage or High Priest; not training grounds; `SpiderMotherBehavior.post_near`), or when she
    is first alarmed, and from then on every `lay_every`, she lays a clutch (`Waves.lay_eggs`)
    of `clutch` eggs around her without stopping. `lay_near` is a little more than a level 3
    wall tower's range, so she starts laying just before towers can hit her.
  - *Alarmed:* when a fighter of any village is within `alarm_range` (the hero, a soldier or an
    elemental; a manned tower that has her in range; units that can't hurt don't count:
    `EnemyBehavior._fighter_near`, shared with the necromancer) or she is hurt, while fewer
    than `guard_count` of her young are near, she stops, lays a clutch and waits until every
    egg of it has hatched or been smashed. Meanwhile she still fights whoever comes into reach
    (and doesn't hit walls). Then she isn't alarmed again for `alarm_cooldown`.
  - *At most `max_clutches`* per mother, timed and alarmed together. Laid out, she fights on
    like an orc. A raised mother is a new enemy and counts afresh.
  - Killed: gold, and a corpse worth gold and no food. A necromancer can raise her; raised, she
    lays a clutch at once and then every `lay_every`, but her eggs are **undead** (`Enemy.undead`,
    pale like the raised): unholy and extra holy damage, and so are the spiderlings out of them.
    Undead ones don't drain away (only the raised do).
  - *Poison* (§4a): every bite of hers is a dose, with no exceptions. Since poison does
    nothing to buildings, she has `siege` 0: at intact walls she lurks (§7a), laying as she
    roams, and comes in through a breach her spiderlings (or anyone) make. She shelters behind
    her brood. Inside she burns a hut like any enemy (a raid destroys the hut directly; it isn't
    a blow). Spiderlings stay melee.
- **Spider egg** (`spider_egg`, behavior `egg`, `"entry": "none"`): `"fixed_hp"`: always 1 HP,
  never scaled. It never moves and counts for the wave (an egg of a debug mother doesn't). After
  `hatch_time` it hatches (`Waves.hatch`) into `hatch_into` (a spiderling with its mother's HP
  scale, undead from an undead egg); the spiderling is counted before the egg is let go, so the
  wave can't end in between.
  - It wobbles for the last `wobble_time`, faster towards the end, as the warning to the player
    (`EggBehavior.animate`, on every machine).
  - Hatched, it becomes its broken shell (`unit_spider_egg_shell`, `Enemy.hatch_out`): out of
    the `enemies` group (nothing targets or counts it), for `shell_time`, then it fades. Co-op
    clients see the shell (`"sh"` in the enemy state).
  - **Low priority** (`"low_priority"`): towers (`MilitaryBehavior.enemies_near` sorts them
    last), soldiers (the Inquisitor too), elementals and the hero go for eggs only when no other
    enemy is in reach (`Enemy.LOW_PRIORITY_TILES`): a real fight comes first, but a quiet moment
    should be spent smashing eggs.
  - Smashed: no gold, no corpse. Villagers don't flee from eggs (`"scares": false`,
    `Civilian.enemy_nearby`); once they hatch, they flee from the spiderlings.
- **Spiderling** (`melee`): about a rat's strength, quick, fights like a goblin, breaks gates and
  walls and goes round them where that is cheaper (the siege field), but `raid_chance` 0: it
  never burns a hut, it scuttles off once inside. It walks from where it hatched to the nearest
  road and on to its egg's village.
- Library: one entry for the mother (with the eggs) and one for the spiderling; eggs have
  `"library": false`.

## 15c. Wrathwood (Wilderness, very rare)

A tree that wakes up under a forester's axe and goes after him: a rare, memorable event that
punishes clear-cutting rather than a wave kind. It never comes with a wave: it is woken on the
map (`Wrathwoods`, `scripts/systems/wrathwoods.gd`; numbers in `Config.WRATHWOOD`), its fight is
`ENEMIES.wrathwood` and `WrathwoodBehavior`. Slow, very hard-hitting, especially against
buildings; weak to fire, strong against projectiles (a tree), so it asks for fire or melee.

- **Waking up** (`Wrathwoods.on_first_blow`): when a forester starts on a tree nobody has
  chopped yet (one roll per tree), it may wake.
  - Chance: `chance` by tree kind (dead trees and charred stumps never), plus **"the forest
    remembers"**: `remember` for every tree that village's foresters have felled, up to
    `max_chance`.
  - Never before `from_wave`, never while the village already has one, and not for
    `quiet_waves` waves after its last one died (`Wrathwoods.calm_until`).
  - Only where the game allows it (`Wrathwoods.allowed`): never in the tutorial or the title
    backdrop (and not for a co-op client).
  - The tile becomes meadow at once (the sprite goes without falling,
    `World.remove_tree(t, false)`; `tree_woke` for co-op clients) and the wrathwood stands
    there, still looking like its tree, shuddering for `wake_time` (it can be hit meanwhile but
    doesn't move or strike: a warning). Then it bursts out in a shower of leaves (`leaves`
    burst). Logged at Important to its village.
  - It belongs to the forester's village (`target_village`) and counts for no wave
    (`Enemy.wild`: like camp guards, ignored by the wave's count, the rats' and water monsters'
    checks, the warning lights and the timeline's enemy count).
- **Strength:** its HP grows with the waves like a wave's enemies; difficulty scales it.
- **Walking:** its own A* paths (`Pathing.wood_path`) over walkable ground **and forest tiles**
  (not mountains, water, lava or solid buildings). It never takes a road to a gate and never
  breaks into a village (`"entry": "none"`).
- **Regrowth:** near trees it heals a share of its max HP per second; back home (see *Guard*) it
  heals faster for a while: it is strongest in the forest and in its own place.
- **What it does** (`WrathwoodBehavior.State`, saved with it):
  1. *Chase:* the forester who woke it, until he is dead, gone, or safe
     (`Civilian.is_exposed()` false: at home or inside the walls).
  2. *Camp:* then his worker camp, until it is devastated (skipped when gone or devastated).
  3. *Wander:* a while, near where it is.
  4. *Home:* back to its old tile.
  5. *Guard* (territorial, for good): it stays on its tile; anyone of ours within `territory` is
     attacked and chased, but no farther than `leash` from home. So the old tile becomes a
     small no-go area.
  - *Swing-by blows* in every state but Guard: whenever its blow is ready, something within
    `reach` is hit as it passes, without stopping: what it is after first, else one of ours,
    else a building of any village that isn't a hut. It never stops chasing to fight.
  - *Defending itself* (Wander, Home, Guard): whoever hurts it becomes its foe (a unit or the
    hero is chased within the leash; a tower that shoots it is walked to and smashed). The foe
    gone, out of leash, or safe, it goes on with what it was doing.
- **Root grip:** periodically, when someone of ours on the ground is close, it roots everyone
  close (they can't move but can still fight; `Unit.force_move` with no step), so melee in its
  reach is held in place with it.
- **Killed:** gold to the killer's village, and a corpse: a log of living wood
  (`corpse_wrathwood`) worth building material and nothing else, which a necromancer can't raise
  (`"revivable": false`). It belongs to the wave running then (or the last one) and rots like
  any corpse. `Wrathwoods.calm_until` is set.
- **Explorers** avoid it like camp guards (`ExploreJob._camp_danger`, `Enemy.wild`).
- **Debug:** *Spawn enemy...* → wrathwood wakes the explored tree nearest to one of the
  village's foresters (else the nearest to the village), whatever the odds and wave.
- **Saving** (docs/save-design.md): every wrathwood is saved with its state, HP, scale,
  position, home tile, the forester and camp it is after, timers, plus per village the trees
  its foresters felled and `calm_until`.
- Library: one entry.

## 15d. Vultures (Wilderness, animals)

Carrion birds drawn by the dead the last wave left lying. They come for the corpses, not the
village: every corpse they eat is loot the player loses, and they leave when there is nothing
left to eat. This makes uncollected corpses a cost, not just a missed bonus. Numbers:
`Config.VULTURES` and `ENEMIES.vulture`; code: `VultureBehavior` (extends `MeleeBehavior`) and
`VulturePack` (the pack's shared target and mode), `Waves._vulture_packs`. They take extra
damage from projectiles and fire (frail birds).

- **When and how many** (`Waves._vulture_packs`, at a wave's start, after the wave's mix, rat
  packs and lairs: they never take a share of `WAVE_MIX`): from `from_wave` (a scenario may set
  its own, `Scenario.vultures_from_wave`), per village, count the **edible corpses** lying
  nearest it; one pack per `per_corpses`, at most `max_packs`: few corpses, no vultures. Each
  pack has `pack` birds, the wave's HP scale, and counts for the wave.
- **Edible:** any corpse on the map except a vulture's and the wrathwood's log (`never_eats`)
  and one sinking in deep water. The campaign's fallen (scenario 6) are edible: an eaten one is
  lost like one that rose (logged at Important).
- **Target and spawn:** each pack gets one target corpse (different ones while there are enough).
  It comes from the open map edge tile nearest its target from which it can fly there.
- **Flight** (`Pathing.sky_path`): near-straight lines over every tile a ground unit can walk
  plus deep water and forest; never over mountains, lava, buildings or solid map objects. No
  ground slows it. A flyer (§5) in the air.
- **The pack:** every bird flies to the pack's target. When the target is gone (eaten, gathered,
  raised, rotted) the pack picks the edible corpse nearest to it. None left: **search** for
  `search_time`, spreading out; a fresh corpse ends the search. Still none: the pack **leaves**
  by the edge tile nearest by flight, and a bird is gone (`Enemy.vanish`: no corpse, no gold,
  no longer counts for the wave) once out of every village's sight for `hidden_time`, or once
  it has reached the edge. Vultures never have to be killed: a wave never stalls on them. A
  leaving pack doesn't turn back.
- **Eating:** at its corpse a bird **lands** (`Enemy.landed`: a ground target now, melee can hit
  it) and eats for `eat_time`; all of the pack try the same corpse, each on its own timer.
  After a finished meal the corpse goes with `vanish_chance`, else it stays for the next bird.
  Each meal adds `grow` of its starting HP and damage (`Enemy.power`), up to `max_meals`; it is
  drawn a little bigger with each. So a pack left to feast becomes a real fight.
- **Fights only for itself and its corpse:**
  - On its corpse it fights whoever comes within reach, its meal paused meanwhile.
  - Hurt by one of ours out in the field, it flies at that one and fights back until it or the
    foe is down, or the foe is `chase` tiles from the target; then back to the pack.
  - Hurt by what it can't reach (a tower), only that bird **flees**, out of the tower's range
    plus a margin, and back once `flee_time` has passed since its last such hit: a tower alone
    scares them off rather than killing them.
  - It never breaks walls or gates, never goes for a gate, never burns a hut. Villagers run
    from it like from any enemy (gatherers keep off corpses with vultures near:
    `Corpses.is_safe`).
- **Killed:** gold, and a corpse of food and no gold; a necromancer can raise it (the raised bird
  is a pack of its own).
- Co-op: each village's packs come for the corpses nearest it; clients see `landed` and the
  growth (`Enemy.fed`) through the replicator.
- Library: its own entry.

## 15e. Wolves and riders (mounted enemies)

Wolves hunt in packs; goblin raiders ride them. The Dread Legion has cavalry (campaign only),
and its captains and commanders ride into battle too. A mount is a second HP pool: it has to
fall before its rider can be hurt. Numbers: `ENEMIES.wolf`, `goblin_raider`, `legion_cavalry`,
`horse` and `Config.MOUNTED`; code: `Enemy` (`mount`, `mount_hp`, `dismount`, the charge),
`MountedBehavior` (extends `MeleeBehavior`; `CaptainBehavior` and `CommanderBehavior` extend
it) and `FleeBehavior` (the undead horse).

- **The wolf** (a `WAVE_MIX` member like the big slime) is a plain melee animal that comes in
  **packs** (`"pack"`): the wave's wolves are grouped into packs, each from one spawn, spaced
  `pack_gap`; a wave's single wolf gets a second. It breaks gates and walls only weakly. Through
  a gate (`"raid": "maul"`, `Game.on_enemy_reached_gate`) it kills the villager of the hut it got
  to (else of the nearest lived-in intact hut), leaves the hut standing and is gone: a wolf
  threatens people rather than buildings. Raised, it is an **undead wolf**.
- **Mounts** (`Enemy.mount`: the animal's `ENEMIES` kind): a mounted kind has `"mount"`,
  `"mount_hp"` and `"rider"` (what it is on foot); a scenario can put any enemy on a horse (a
  queue entry's `"mount"`, `"mount_hp"`: the captains and commanders). While mounted:
  - every hit lands on the mount (scaled like HP; the animal's `resist`, a commander's
    `guard`); the rider's HP stays whole and a blow that kills the mount never carries over.
    Two HP bars: the mount's (brown) over the rider's.
  - it moves at the mounted speed and hits walls and gates only weakly, and only when it rides
    into one.
  - **Dismount** (`Enemy.dismount`): the mount falls (its kill gold to whoever killed it, a kill
    of the mounted kind, a corpse of the animal, a puff of dust), and a kind with `"rider"` turns
    into that kind in place (new number, HP, speed, behavior and look; it keeps its wave and
    target). A captain or commander just goes on on foot (`on_dismount`). Either way it goes
    back to its road (`Enemy.back_to_road`, unless a retreat, an errand or a siege leads it):
    riding, its path was wherever it rode, and on foot the end of that path would count as
    the end of its road, a way in without breaking in.
- **Riding** (`MountedBehavior`, while mounted):
  - It runs to its village by road but never hits a gate, wall or wall tower: near the walls it
    **circles** the village (`approach`, `ring`). Its ways never cross an intact barrier
    (`MountedBehavior.open_way`). So cavalry is a threat to what is outside the walls, and a
    threat inside only once a wall is down.
  - **Breached:** when the way anyone on foot would break in reaches a hut with no intact
    barrier on it, it **rides in** (`Enemy.ride_in`) and burns a hut. A barrier turning up in
    its way sends it back to circling.
  - It **hunts**: the goblin raider anything of ours within `hunt_radius` that it can reach
    that way (not buildings); Legion riders (`"hunts": "melee"`) only melee fighters. It rides
    at the nearest, fights it, and gives up beyond `chase`.
  - Legion riders **escort** (`"escort"`): while a Legion soldier on foot is about they keep
    within `escort_radius` of the nearest one; with none left they circle like raiders.
  - **Getting off at the gate:** after `circle_time` at the village without a blow it rides to
    the nearest gate and gets off: the mount runs off the map (no corpse, no gold) and the rider
    breaks in on foot. A siege can't be stalled by cavalry that just circles.
  - **Charge:** after riding `charge_distance` without a fight (`Enemy.charge_ready`, dust, a
    lean), its next blow does `charge_x`.
  - **Led by a scenario** (`Enemy.errand`, `MountedBehavior._on_errand`; scenario 9's Lysa at the
    head of her `LegionCompany`): it rides where the errand sends it and fights what comes
    within reach, but never charges (`Enemy._tick_ride`) and hunts, escorts and circles nobody.
    Waiting at its village it rides in through a breach, or after `circle_time` gets off.
- **Against cavalry:** the halberdier does `vs_mounted` to a mount (only to the mount: never to
  the rider on foot), and **breaks a charge** (`"breaks_charge"`): a charge on a halberdier
  gives no bonus, and its blow halts the mount for `halt_time` and spends its charge. This is
  the intended answer to riders.
- **The undead horse** (`horse`, `FleeBehavior`): there is no living horse, only a fallen
  mount's corpse. Raised, it never fights: it bolts to the quietest spot near it and dies of
  the raised drain; it counts for the wave. Villagers don't run from it (`"scares": false`).
- **Goblin raider:** a wolf rider, alone, no cap. **Legion cavalry** only where a scenario sends
  it.
- **Mounted captains and commanders** (docs/scenarios-4-6-design.md, scenarios-7-9-design.md, scenarios-10-11-design.md): Lysa and Torben ride
  (scenarios 5, 9 and 10): they escort their column like cavalry and fall back faster while
  mounted; a captain whose horse falls goes on (and falls back) on foot. Halvard rides
  (scenario 10) and keeps rallying. Rhodri (scenario 11) fights in two phases: mounted, then on
  foot once his horse falls. The mounted art is `unit_<art>_mounted`.
- Co-op: clients see the mount, its HP, the charge and the change of kind through the
  replicator.
- Library: wolf, goblin raider, Legion cavalry and the horse.

## 15f. Ghost (a haunting)

A spirit that comes for one villager, not for the village. It is unseen and untouchable until
something reveals it or it closes in on its victim, so the answer is detection (light stones, a
High Priest) and the right damage (holy, magic, fire), not more arrows. Numbers: `Config.GHOST`
(the haunt) and `ENEMIES.ghost` (the body, a goblin's for now); code: `GhostBehavior` (extends
`EnemyBehavior`), `Pathing.ghost_path`. Art `unit_ghost`.

- **Damage:** melee and projectile do nothing (`resist` 0), so archers, crossbowmen, shield
  bearers and their branches, earth elementals, thornlings and the hero's sword can't target it
  (§4). Fire, magic and pure hurt it; holy most (its holy factor is final: `raised_holy` isn't
  added on top). The Inquisitor's holy melee and a fire elemental's blow count by their category.
- **Faded or solid** (`Enemy.faded` / `set_faded`): faded is the default. Faded it can't be
  targeted or hurt (shots in flight fizzle, splash skips it), can't attack, villagers don't run
  from it (`Enemy.scary()`), no warning light marks it, and it is drawn see-through
  (`faded_alpha`). It turns solid when:
  - **revealed** (`GhostBehavior._revealed`): in a working light stone's light
    (`LIGHTSTONE_SIGHT`) or in any High Priest's aura (`Combat.in_holy_aura`, docs/acolyte-design.md
    §6), any village's; towers and their lanterns reveal nothing. Revealed wins: it is solid
    wherever it is; or
  - **hunting** within its target's reach (melee range plus `solid_margin`). So it can always
    strike, and the player can always answer it there with the right units.
- **Target:** at spawn one living villager of its village at random (not the hero), never told to
  the player, never swapped. It ignores huts, walls, gates and wall towers.
- **Journey** (`Mode`): it follows its road for `road_share` of it (so it comes from the
  expected side), then flies (`ghost_path`: like the vultures' `sky_path`, but through
  buildings) towards where the target is now, re-planning as they move, with now and then a
  detour for flavour. It floats (no ground slows it) but is no flyer (`flies()` false: §5 doesn't
  apply, its damage table decides). It hovers (`"hover"`: bobbing over a shadow, no walking sway).
- **A miner as target:** standing by the mine, it drives him out (`Miner.drive_out`): he flees
  home, unassigned, so the ghost can find him. A mine is no hiding place.
- **Hunt:** within reach it strikes; the villager flees from a solid ghost like from any enemy.
  After `enrage_after` of hunting (road and search) its speed rises by `enrage_speed` for good,
  so a hunt can't stall.
- **Lurking:** when the hunted villager got home while fleeing, that is an escape
  (`GhostBehavior.retreats`); it fades and lurks (`LURK`): strolls a few tiles at a time near its
  target (`lurk_step`, `lurk_leash`) until they come out, then hunts again. After `retreats` escapes
  it gives up, so a ghost can't keep a villager locked in for ever.
- **Target gone** (dead, retired, given up): it fades and roams (`ROAM`) for `roam_time`, then
  vanishes (`Enemy.vanish`: no gold, no corpse). Revealed and hurt meanwhile (or while
  hunting), it hits back at whoever hurt it if it can reach them, never a tower.
- **Breach:** a solid ghost inside the walls counts as a breach (`Siege.breached`: villagers in
  there are exposed); a faded one doesn't. It never damages buildings or burns a hut.
- **Waves:** a late `WAVE_MIX` kind, at most one per village and wave (`max_count`). It counts for
  the wave, which ends only once it is killed or has vanished. Not in the tutorial or the title
  backdrop; scenarios only when their own waves list it.
- **Killed** (only while solid): `gold_on_kill`; no corpse, so nothing for gatherers,
  necromancers or vultures. Counted under "Others" in the statistics.
- Co-op: the replicator sends `faded`; clients draw the opacity. Nothing of it is saved (a wave
  isn't).
- Library: its own entry; the Damage tab shows its immunities from Config.

## 15g. Snake

A Beast (§4b) that threatens the work outside the walls, where the spider mother threatens the
edge of the defences. It joins the waves after the slimes (`WAVE_MIX`).

- **Stats** (`ENEMIES.snake`) about a big slime's (`slime3`): HP, slow speed, and a first
  poison tick about the big slime's blow. Kill gold like the big slime; a corpse worth food (gatherers, necromancers
  and vultures can use it).
- **Only poison** (§4a), with its own decay, tick interval and cut-off, apart from the spider
  mother's, so the two are balanced separately. So `siege` 0: it never hits walls, gates or
  buildings.
- **On its way** it strikes anyone of ours within reach, like a melee kind.
- **At the village it lurks** (§7a): it roams outside the walls, keeps out of reach of manned
  towers (`"lurk_shy"`, `LURK.tower_margin`), and goes for whoever is outside within
  `hunt_radius` (`SnakeBehavior.lurk_goal`): foresters, gatherers, farmers, a sortie, the hero.
  Villagers fear it. Towers can't solve it alone; it asks for soldiers or the hero outside,
  or for keeping the work inside for a while.
- **Only a breach lets it in**, like every lurker: someone else must break a wall or gate.
- **Inside it mauls** like the wolf (`"raid": "maul"`, §15e): it kills one villager in their hut
  and is gone, with no loot and no corpse. It never burns a hut, so it keeps the held-wall rule
  (§7a).
- **Leaving:** like every lurker (§7a).
- **Look:** a natural slither, no walking sway:
  - a coiled base image, head raised: at rest, striking, and in the library;
  - a slither cycle (`"slither"` frames, `unit_snake_slither_<n>`): one tapered body drawn along an S-curve whose wave
    runs back along the body while the head moves almost straight on; each frame shifts the
    curve's phase by a sixth. All frames come from the same parameters in `tools/gen_art.py`,
    so they match exactly;
  - frames advance by the distance moved (one every `slither_step` tiles, `Enemy._slither`),
    not by time, so it never slides on the spot when slowed or rooted and every speed looks
    right; it shows the coiled image when it stops;
  - a corpse image. A raised snake is pale and drained like any raised enemy.
  - Co-op clients pick the frame from its movement themselves; nothing extra is sent.
- Library: its own entry; enemy_bot checks its lurking, that it gets in only through a breach,
  its maul and its poison.

## 16. Monster-camp guards

- Every far treasure (and half of the middle ones) has a camp (`CAMP_CHANCE`,
  docs/world-objects-design.md §9.3) with `CAMP_MONSTERS` by treasure tier: a richer treasure, a harder
  camp.
- They have extra HP (`CAMP_HP_SCALE`), fixed (not wave-scaled), and use `CampBehavior` instead
  of their kind's behavior.
- They never walk a road. They attack any defender or exposed villager near the camp
  (`CAMP_AGGRO`), never follow farther than `CAMP_LEASH`, and walk back when nobody is left.
- Hurt guards don't heal (so wearing a camp down by towers works). Kill gold is paid only when
  the killer belongs to a village; they leave no corpse.
- Towers and barracks fight guards in their range without any order (build next to a camp and it
  fights). Only the hero needs the order (the camp's panel: *Attack with the hero*), so she
  doesn't wander into camps by herself. Guards also fight whoever walks close. Explorers avoid
  them.
- Lair guards (`LAIR_THEMES.guards`) work the same way, with the waking wave's HP scale.
- Wave counts ignore guards (filter `CampBehavior`).

## 16b. Water monsters

The crab, the siren, the leviathan and the gigantic octopus live in water: their habitats,
diving (untargetable while under), melee reach on deep water, sinking corpses, the siren's song
and the octopus's arms, and when they join a village's waves (`WAVE_MIX` `"needs": "water"`,
`"max_count"`, `"chance"`; `Aqua.eligibility`) are all in docs/aquatic-design.md.

## 16c. The Dread Legion (campaign only)

Rhodri's bound soldiers (docs/story-design.md §5): `legion_footman` and `legion_captain`, with
`"campaign": true` (never in `WAVE_MIX`: only where a scenario sends them). A fallen one is
released (`"release"`: no corpse, the colour warms, a pale breath), not killed: they are
victims. The captain (`CaptainBehavior`) is never killed: below `retreat_below` it falls back,
untargetable, off the map the way it came. Named ones (Lysa, Torben) carry a name and art of
their own (`Enemy.set_identity`). Numbers and the rest: docs/scenarios-4-6-design.md.
- The **archer** (`LegionArcherBehavior`) stops to shoot our people out in the open, out-ranged
  by a level 1 watchtower; the **guardsman** takes less from projectiles; the **banner-bearer**
  hastes every Legion soldier near it (`Enemy.haste`); the **court champion** (scenario 8's
  Rurik) cleaves (`EnemyBehavior.cleave`). docs/scenarios-7-9-design.md.
- **Commanders** (`CommanderBehavior`; scenario 10's marshal Halvard, `legion_marshal`, and
  scenario 11's king Rhodri, `legion_king`): bosses whose Legion soldiers near them strike faster
  and take less damage (`command_haste`, `command_guard`; `Enemy.haste`, `Enemy.guard`), and who
  rally soldiers for the wave from an edge spawn while they live (`rally`, `rally_every`). The
  king's blows cleave, and he is `"downed"` at 0 HP: 1 HP left, untargetable, back along his road
  and gone. docs/scenarios-10-11-design.md.
- A camp of Legion soldiers only is a *Legion camp* (its own look). A scenario can set a lair's
  guards, kinds and waking wave and keep it cleared (`Scenario.lairs`).

## 17. Open ideas / not built

- **More invisible enemies:** the ghost (§15f) is the first. A new one should reveal through
  the same rule (`GhostBehavior._revealed`: light stones and `Combat.in_holy_aura`).
- **Flying allied units:** none yet. The vampire's comments note that a bat would be theirs to
  fight.
