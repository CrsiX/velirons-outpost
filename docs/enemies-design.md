# Veliron's Outpost: enemies (design)

Status: **built; describes the current code**. Tested by tests/enemy_bot.gd (thief, gargoyle,
necromancer, vampire, slimes, spiders, the wrathwood, vultures, ghosts, wolves and riders), tests/rat_bot.gd (rats) and tests/sim_bot.gd (waves, raids, corpses).
Scope: every enemy kind, how waves are put together and escalate, difficulty, damage
categories, flyers, corpses and raids. Every number lives in `scripts/core/config.gd`
(`ENEMIES`, `WAVE_MIX`, `RAT_PACKS`, ...). The tables below give the Normal values at wave 1.

## 1. Code

- `scripts/units/enemy.gd` (`Enemy`): walks the road flow field to a gate (near the village it
  breaks in along the siege field, `Siege`, docs/siege-design.md), takes damage
  (applying `resist`), dies, flies, gets slowed or pushed back. It reads every number through
  `stat()` (`Config.enemy_stat`, difficulty-scaled).
- `scripts/units/enemies/`: one behavior per `"behavior"` key (`Enemy.BEHAVIORS`):
  - `melee_behavior.gd`: goblins, skeletons, orks, gargoyles, slimes (and the base of thief and vampire);
  - `witch_behavior.gd` + `spell_bolt.gd`;
  - `rat_behavior.gd`, `thief_behavior.gd`, `necromancer_behavior.gd`, `vampire_behavior.gd`;
  - `spider_mother_behavior.gd` (extends `MeleeBehavior`) and `egg_behavior.gd` (her eggs);
  - `wrathwood_behavior.gd`: the wrathwood (§15c), woken by `scripts/systems/wrathwoods.gd`;
  - `vulture_behavior.gd` + `vulture_pack.gd`: vultures (§15d), sent by `Waves._vulture_packs`;
  - `ghost_behavior.gd`: the ghost (§15f);
  - `mounted_behavior.gd`: a rider while its mount lives (§15e; the base of `captain_behavior.gd` and
    `commander_behavior.gd`), `flee_behavior.gd`: the undead horse;
  - `camp_behavior.gd`: monster-camp and lair guards (set by the camp, not by config).
- `scripts/systems/waves.gd` (`Waves`): countdown, wave make-up, spawning, rat packs, lair
  themes, the co-op extra, raising corpses, slime splits, spider eggs (laying, hatching), kill gold.
- `scripts/systems/corpses.gd` (`Corpses`) + `scripts/units/corpse.gd`: corpses, rotting, clearing.
- `Game.on_enemy_reached_gate`, `Game.thief_steals`, `Game.raid_roll`: what happens once an
  enemy gets in (the hut it reached burns: `Enemy.raid_hut`).
- `scripts/world/warning_lights.gd`: the red warning lights for hidden enemies.

## 2. Wave flow

- **Timing:**
  - Wave 1 starts `FIRST_WAVE_DELAY` (90 s) after the game starts.
  - Every later wave starts `WAVE_BUFFER` (30 s) after the last enemy of the previous one is
    gone (killed, through a gate, vanished). Debug spawns (`spawn_at`) don't count.
  - *Call now:* skips the countdown and pays `EARLY_CALL_GOLD_PER_SECOND` (0.5) gold per second
    left, to every village. Not while a wave runs. In the tutorial the player calls wave 1;
    after that calling is locked (`call_locked`) until *Play on*.
  - Enemies spawn `WAVE_SPAWN_GAP` (1.1 s) apart (divided by the village count in co-op); the
    rats of a pack 0.25 s apart.
- **Size:** `wave_size(n) = 4 + 2n` enemies, plus rat packs on top.
- **Strength:** each enemy's HP is × `WAVE_HP_GROWTH^(n-1)` (1.12 per wave). Only HP grows
  with the waves; damage, speed and loot don't.
- **Spawn points:** up to `wave_spawn_points(n) = min(1 + n/2, 4)` edge spawns (picked at
  random each wave), plus every awake lair of the village's slice. Kinds are shuffled and dealt
  round-robin over them.
- **Make-up** (`Config.wave_composition`):
  - Each kind in `WAVE_MIX` joins from its `from_wave` with `share`, growing by `growth` per
    wave up to `max_share`. Each kind present gets at least 1.
  - If the shares add up to more than `WAVE_MIX_CAP` (85 %), they are scaled down evenly.
    The cap applies to the shares before rounding: each kind's count is rounded (at least 1),
    so the special kinds can end up a little above 85 % (waves 9, 13, 24: 86-88 %).
  - `WAVE_FILLER` (goblin) fills the rest.

| Kind | From wave | Share | Growth / wave | Max share |
|---|---|---|---|---|
| Skeleton | 2 | 12 % | 6 % | 35 % |
| Ork | 3 | 10 % | 3 % | 25 % |
| Big slime | 4 | 6 % | 2 % | 15 % |
| Witch | 5 | 10 % | 2 % | 20 % |
| Wolf | 5 | 6 % | 2 % | 15 % (in packs of 2-3, §15e) |
| Goblin raider | 7 | 5 % | 1.5 % | 12.5 % |
| Thief | 7 | 8 % | 1 % | 15 % |
| Gargoyle | 10 | 6 % | 1 % | 15 % |
| Necromancer | 13 | 4 % | 0.5 % | 8 % |
| Vampire | 13 | 5 % | 1 % | 12 % |
| Spider mother | 9 | 4 % | 0.5 % | 8 % (at most 2, +1 every 5 waves: `max_count`, `max_count_every`) |

- **Rat packs** (`RAT_PACKS`): from wave 3, with chance 60 %, a wave gets 1-2 packs, plus one
  more every 5 waves after wave 3. Each pack has 4-7 rats from one spawn (an edge spawn or a
  lair that sends rats), inserted as a block into the queue (never inside another pack).
- **Lairs** (docs/world-design.md): from wave `LAIR_FROM_WAVE` (10) one lair per village area
  wakes, the next every `LAIR_EVERY` (3) waves. An awake lair is one more spawn point for its
  slice's share (it adds no enemies). It sends only its theme's kinds (`LAIR_THEMES`, those whose
  `from_wave` has come, else goblins): a lair entry of another kind swaps with a fitting edge
  entry, or turns into a fitting kind. Its guards (`guards`) have that wave's HP scale.
  Cleared by the hero, it sleeps `LAIR_QUIET_WAVES` (3) waves.
- **Co-op** (LAN): one wave for the whole game.
  - Every village gets the single-player wave from its own home spawns (its stretch of edge).
  - Plus an extra `round(wave_size × WAVE_EXTRA_PER_PLAYER (0.25) × villages)` enemies, each
    kind drawn at random from the wave's make-up, from random edge spawns (no rat packs among
    them); their target is the standing village nearest to where they spawn.
  - The shares are interleaved, so all villages are attacked at the same time.
  - A fallen village's enemies turn to the nearest standing village (`Enemy.retarget`).
- **Leftover rats:** once only rats are left (and only rats still to come), they get
  `RAT_WAVE_LINGER` (30 s), then they all vanish (`Waves.rats_leave`).
- **Warning lights** (Easy and Normal only): during the first `WARNING_LIGHT_WAVES` (5) waves, a
  soft red light marks where a hidden enemy's road enters watched land. Later, in a wave in
  which a lair woke up, the hidden enemies coming from lairs get one.
- **Scripted waves** (`Waves.scripted`, the tutorial) are used up before the normal rules.

## 3. Difficulty

- `Config.DIFFICULTY_MULTIPLIERS` (per value, else its `"all"`): Easy 0.67, Normal 1.0, Hard 1.5
  but speed 1.2 (speed and HP together decide how long an enemy stays in a tower's range; at 1.5
  both, Hard was far steeper than Easy is gentle).
- It multiplies every value in `DIFFICULTY_SCALED`: `hp`, `speed`, `damage`, `spell_damage`,
  `gold_on_kill`, `gold_on_collect`, `food_on_collect`, `materials_on_collect`.
- Whole-number values (loot) are rounded and never drop below 1, unless they are 0 to begin with
  (`enemy_stat_int`).
- Nothing else is scaled: not cooldowns, ranges and timings (a longer cooldown would make Hard
  easier), nor shares and rates such as `drain`, `gate_eat`, `steal_share`, `bat_speed` or
  `bat_gate_heal`.
- Each enemy also rolls ×0.92-1.08 on its speed.

## 4. Damage categories and resistances

- Every hit has exactly one category (`DAMAGE_CATEGORIES`): `melee`, `projectile`, `magical`,
  `fire`, `holy`, `pure` (a raised enemy's drain; never scaled).
- **Fire** is its own category, not magical: the fire mage's fireball and its splash, and the
  fire elementals' blows. Orbs, frost, warp and the witch's and leviathan's spells stay magical.
  Fire factors: the wrathwood ×2; the water monsters (crab, siren, leviathan, octopus and its
  arms) ×0.5; the vampire ×0.67 (as it took fireballs before fire was split off); others ×1.
- Enemy blows are `melee`, except a kind's `attack_category` (the witch: `magical`).
- `resist` maps a category to a factor on the damage taken (`Enemy.take_damage`); missing = ×1.
- The library's *Damage* tab shows all of this, read from Config (`Library._damage`,
  `Config.DAMAGE_INFO`; docs/tutorial-design.md §4).
- **Holy** (the acolyte line, docs/acolyte-design.md §3): goblin, ork, thief, gargoyle, spider
  mother, spider egg, spiderling ×0.75;
  skeleton ×1.25; necromancer and vampire (bat too) ×1.5; witch, rat, slimes ×1. Anything a
  necromancer raised, and anything undead (`Enemy.undead`: a raised spider mother's eggs and
  spiderlings), takes another ×2 (`raised_holy`).
- **Unholy** (`"unholy": true`): skeleton, necromancer, vampire. Raised and undead enemies count
  as unholy too (`Enemy.is_unholy`). Only the Inquisitor's targeting uses it.
- The vampire takes ×0.67 magical (and fire) damage. The wrathwood takes ×0.5 projectile damage.

## 5. Flyers

- A flyer is a kind with `"flying": true` (the gargoyle) or a vampire in bat form
  (`Enemy.airborne`). `Enemy.flies()` covers both.
- It keeps to the roads, but no ground slows it (swamp, shallow water, fords). Vultures fly
  their own way instead (§15d), and while one has landed to eat (`Enemy.landed`) it is no
  flyer: melee reaches it.
- It's drawn bobbing with beating wings (`unit_<art>_flap`) over a shadow on the ground.
- Only ranged attacks (towers, archers, mages, with their slows and pushes) and fire elementals
  can go for it. The hero, ground soldiers and earth elementals don't target flyers. Barracks
  with only melee units don't turn out for one.
- When a flyer hits a ground melee unit whose blow is ready, that unit strikes back
  (`counter_strike`).

## 6. Corpses

- Killing an enemy pays its `gold_on_kill` at once to the killer's village (else the village it
  attacked), and leaves a corpse unless its kind has `"corpse": false` (rats, slimes, spider eggs, spiderlings). Raised
  enemies (killed or decayed), camp and lair guards leave none.
- A gatherer (or the hero in Gather mode) brings safe corpses home (no living enemy within
  `CORPSE_SAFE_RADIUS`, 6 tiles) for `gold_on_collect` and `food_on_collect`. A thief's corpse
  also holds the gold it stole (`extra_gold`).
- Corpses rot after `CORPSE_LIFETIME` (240 s). All corpses of wave N and older go once wave N+1
  is finished. In the tutorial they don't rot.
- Necromancers can raise corpses (§14), except a necromancer's own (`"revivable": false`).
- Corpses left lying at a wave's start draw vultures (§15d), which eat them.

## 7. At the village (raids)

- Walls, gates and wall towers hold enemies back (docs/siege-design.md §5). Each kind's
  `"entry"` says how it gets in:
  - `"siege"` (the default): near the village it leaves its road and follows the siege field
    to the cheapest way in, hitting the gate, wall or wall tower in its way (`damage` ×
    `siege`; a witch casts at it) until it breaks. Melee foes still come first. Kinds with
    `siege` 0 (necromancer, siren) wait, and slip past after `SIEGE.stuck_slip` (45 s).
  - `"slip"` (rats, thieves): an intact gate holds them `SIEGE.slip_time` (4 s), then they
    get through unharmed.
  - Flyers (gargoyles) fly over walls and gates to the nearest hut.
- Inside, an enemy walks to the nearest intact hut and burns it (huts have 1 HP), on every
  difficulty. Only the villager living there dies.
- A campaign scenario's guild warehouse (scenario 4) is no target for breaking in: only thieves
  go for it (§11; docs/scenarios-design.md §7.7).
- Exceptions:
  - kinds with `raid_chance` roll for it (small slimes); failed, they melt away (`"gone"`: the
    log's words for it); spiderlings have 0: they never burn a hut, they scuttle off;
  - rats eat food instead (§10);
  - thieves steal gold and run back (§11);
  - a vampire bat heals at a gate and turns back (§15); a vampire that turns into a bat
    while breaking in goes back to its road.
- Then the defeat check runs: a village falls with no villagers or no intact huts.
- While an enemy is inside a village's walls, villagers walking in there are exposed.
- Enemies are only visible on watched tiles.

## 8. Melee kinds: goblin, skeleton, ork

- `MeleeBehavior`: walks the road; when a melee defender (the hero, a soldier outside, an
  elemental) or an exposed villager is within `SUMMON.attack_range` (0.8 tiles), it stops, lunges and hits
  every `attack_cooldown`, then walks on. Enemies with 0 damage never stop.

| Kind | HP | Speed | Damage / cooldown | Kill gold | Corpse gold / food | Holy |
|---|---|---|---|---|---|---|
| Goblin | 20 | 1.1 | 4 / 1.0 s | 3 | 3 / 2 | ×0.75 |
| Skeleton | 20 | 1.1 | 4 / 1.0 s | 3 | 3 / 0 | ×1.25, unholy |
| Ork | 55 | 0.8 | 11 / 1.2 s | 6 | 0 / 6 | ×0.75 |

- A level-1 earth elemental is as strong as a Normal goblin, and as fast (`SUMMONS.earth.speed`,
  1.1 tiles/s).

## 9. Witch

| HP | Speed | Kill gold | Corpse gold / food | Spell range | Spell cooldown | Spell damage |
|---|---|---|---|---|---|---|
| 12 | 1.0 | 12 | 0 / 1 | 3.6 | 2.0 s | 5 |

- No melee. She walks until a target is within `spell_range` (3.6 tiles, a level-1 watchtower's
  range, so a tower can always answer), then stands and casts a whirling pink bolt
  (`spell_speed` 5 tiles/s) every `spell_cooldown`.
- **Targets:** first whoever last attacked her (a tower, or a melee defender), else the nearest
  manned tower, military unit outside (walking, or out of barracks, even a summoner) or villager
  outside.
- **Effect:**
  - a tower's unit is bewitched for `spell_cooldown × enchant_ratio` (0.45, so 0.9 s): no
    shooting, no summoning, a pink glow;
  - elementals, the hero, units and villagers outside take `spell_damage` (magical).
- **Anti-stall:** after `spell_ignore_after` (20) casts at one target she ignores it, until it
  attacks her again (which resets its count).
- At a camp (no melee damage), a witch guard hits with her `spell_damage` (difficulty-scaled).

## 10. Rat

| HP | Speed | Bite / cooldown | Kill gold | Corpse |
|---|---|---|---|---|
| 7 | 2.4 | 0.6 / 0.8 s | 1 | none |

- Comes in packs (§2), from wave 3; not part of `WAVE_MIX`. Like all enemies, its HP grows
  with the waves.
- `RatBehavior` states: ROAD, TO_FARM, ON_FARM, CHASE.
  - On the road it looks for a working farm (finished, not being torn down: `Farm.working()`)
    within `farm_search` (6 tiles) and goes there off the road.
  - On a farm it wanders the field: the farm grows nothing, and each rat eats `farm_eat`
    (0.2) stored food per second.
  - It goes for villagers and units within `bite_range` (2.5 tiles) and bites once within
    `SUMMON.attack_range` (0.8).
  - Once the farm is empty and grew nothing for `give_up_after` (15 s), each rat on it gives it up
    for good (`give_up_chance` 50 % every `give_up_check` 1 s) and goes on to the next farm or
    the gate.
  - A rat on a farm that isn't attacked for `vanish_after` (30 s) vanishes (no corpse, no gold).
- At a gate it burns nothing: it eats max(`gate_eat` 5, `gate_eat_share` 5 % of the food), at
  most what there is, and is gone.
- Defence: the hero in Defend mode goes for rats on her village's farms when nothing is near a
  gate. Barracks go for farms within `BARRACKS_FARM_RANGE_FACTOR` (2) × their range when nothing
  else is in range; their units stay within `FARM_DEFENSE_LEASH` (4) of the farm.

## 11. Thief

| HP | Speed | Damage / cooldown | Kill gold | Corpse gold / food | Holy |
|---|---|---|---|---|---|
| 20 | 1.5 | 4 / 1.0 s | 2 | 3 + stolen / 0 | ×0.75 |

- From wave 7. Fights like a goblin on the way (`ThiefBehavior` extends `MeleeBehavior`).
- At a gate it burns nothing. It steals max(random whole number from wave to 2 × wave,
  `steal_share` 4 % of the gold), never more than there is (`Game.thief_steals`). Then it
  runs back along its road with a coin sack.
- Back at the map edge it vanishes with the gold (logged). Killed on the way, its corpse holds
  the stolen gold as well.
- Where its village has a standing guild warehouse (scenario 4) it goes for that instead: along
  its road to where it passes nearest, then across (never through the walls), plunders it
  (`WAREHOUSE.raid_damage` HP), steals as at a gate and runs back the way it came.

## 12. Gargoyle

| HP | Speed | Damage / cooldown | Kill gold | Corpse gold / food | Holy |
|---|---|---|---|---|---|
| 40 | 0.8 | 7 / 1.2 s | 8 | 0 / 4 | ×0.75 |

- From wave 10, grey stone, the first flyer (§5). It fights in melee like the melee kinds
  (`MeleeBehavior`), but only ranged attacks and fire elementals can go for it. Ground melee
  units only counter-strike.

## 13. Slimes

| Kind | HP | Speed | Damage / cooldown | Kill gold | Splits into | Raid chance |
|---|---|---|---|---|---|---|
| Big slime (`slime3`) | 40 | 0.8 | 11 / 1.2 s | 3 | 2 × slime2 | 100 % |
| Slime (`slime2`) | 20 | 1.1 | 5.5 / 1.2 s | 2 | 2 × slime1 | 25 % |
| Small slime (`slime1`) | 10 | 1.4 | 2.75 / 1.2 s | 1 | none | 10 % |

- From wave 4 (only big slimes are in `WAVE_MIX`). No corpses, so nothing to gather or raise.
- Slain, a slime splits into `split_count` of `split_into` side by side, popping out of it.
  They walk on along its road, count for the wave, and keep its HP scale.
- A spawned slime rolls a pastel colour from `SLIME_COLORS` (red, blue, yellow, green, pink;
  sprite `unit_<art>_<colour>`), which its halves keep. It squashes and stretches as it moves.
- One library entry ("Slime"); the smaller sizes have `"library": false`.

## 14. Necromancer

| HP | Speed | Kill gold | Corpse | Holy |
|---|---|---|---|---|
| 20 | 0.95 | 25 | yields nothing, can't be raised | ×1.5, unholy |

- From wave 13. No attack.
- When a corpse of another kind lies within `raise_range` (3 tiles), and no gatherer or other
  necromancer has it, it stops and channels on it (a green beam) for `cast_time` (5 s).
- Then the corpse rises (`Waves.raise_corpse`) as its old kind with `raise_hp` (half) of its
  max HP, draining to 0 over `raise_decay` (20 s, pure damage). It walks to the necromancer's
  village and counts for the wave.
- After a raise it walks on for at least `cast_time` before the next. A corpse gone
  mid-spell ends it.
- While a fighter of any village is near (a melee defender within `raise_range`, or a manned
  tower that has it in range) it doesn't walk on: it stays and waits for its next raise.
  Units that can't hurt it don't count (`MilitaryUnit.fights()`: not a Healing Mage or a
  High Priest, on a tower or out of barracks), or it would wait by them for ever.
- In a High Priest's aura (it or the corpse) the spell takes `necro_slow` (×2) as long.
- A raised enemy killed pays `raise_gold` (half) of its kind's kill gold, rounded down; one
  that decayed pays nothing. Neither leaves a corpse. Raised enemies take ×2 holy damage.
- The first raise per village and game is logged at Info, later ones at Debug.

## 15. Vampire

| HP | Speed | Damage / cooldown | Kill gold | Corpse gold / food | Resist |
|---|---|---|---|---|---|
| 40 | 0.9 | 4 / 1.0 s | 6 | 8 / 0 | magical ×0.67, holy ×1.5, unholy |

- From wave 13. Fights like a goblin (`VampireBehavior` extends `MeleeBehavior`).
- **Drain:** of the HP it really takes from whatever it hits (villagers, units, the hero,
  summons), it gets `drain` (67 %) back, never above its max.
- **Bat:** once, the moment its HP would drop below `bat_below` (a third), even to 0, it keeps a
  third and turns into a bat in a puff of smoke for `bat_time` (10 s). The bat flies (§5) at
  `bat_speed` (1.8) and doesn't bite. A raised vampire turns too, and drain down there also
  triggers it.
- A bat that reaches a gate does no harm: it gains `bat_gate_heal` (a third of its max HP) and
  flies back the way it came. Landed, the vampire takes the road to the village again; only on
  its feet does it break in.
- A necromancer can raise it once.

## 15b. Spider mother, spider eggs, spiderlings (Wilderness)

| Kind | HP | Speed | Damage / cooldown | Kill gold | Corpse gold / food | Holy |
|---|---|---|---|---|---|---|
| Spider mother | 90 | 0.6 | 9 / 1.3 s | 10 | 8 / 0 | ×0.75 |
| Spider egg | 1 (always) | 0 | none | 0 | no corpse | ×0.75 |
| Spiderling | 8 | 1.8 | 1.5 / 1.0 s | 1 | no corpse | ×0.75 |

- **Spider mother:** from wave 9 (`WAVE_MIX`; at most 2 per wave and village, one more every 5
  waves after wave 9: 3 from wave 14, 4 from 19; `Config.wave_max_count`), and out of
  hollow-tree lairs (`LAIR_THEMES.lair_tree`; a lair's entries aren't held to `max_count`).
  Bigger than an ork. Otherwise a melee fighter like the ork (`SpiderMotherBehavior` extends
  `MeleeBehavior`; breaks walls and gates, burns a hut when she gets in), plus her eggs:
  - *On the way:* once she is within `lay_near` (7 tiles, a little more than a level 3 wall
    tower's 6.4) of a manned tower or barracks of any village whose units fight (a unit
    stationed there, a barracks' out on a sortie too; not a Healing Mage or High Priest; not
    training grounds; `SpiderMotherBehavior.post_near`), or when she is first alarmed (below),
    and from then on every `lay_every` (15 s), she lays a clutch (`Waves.lay_eggs`) of
    `clutch` (4-6, at random) eggs around her (within `lay_spread`, 0.6 tiles; on ground one
    can walk), without stopping.
  - *Alarmed:* when a fighter of any village is within `alarm_range` (4 tiles: the hero, a
    soldier or an elemental; or a manned tower that has her in range; units that can't hurt,
    such as a Healing Mage, don't count: `EnemyBehavior._fighter_near`, shared with the
    necromancer) or she is hurt, while fewer than `guard_count` (3) of her young (spiderlings
    and unhatched eggs, any mother's) are within `guard_radius` (2.5), she stops, lays a clutch
    and waits until every egg of it has hatched or been smashed. Meanwhile she still fights
    whoever comes into reach (and doesn't hit walls). Then she isn't alarmed again for
    `alarm_cooldown` (12 s, counted from the laying); the next clutch on the way comes
    `lay_every` after it.
  - *At most `max_clutches` (5)* clutches per mother, timed and alarmed together
    (`SpiderMotherBehavior.clutches`). Laid out, she fights on like an ork: she no longer
    stops to guard. A raised mother is a new enemy and counts afresh.
  - Killed: 10 gold, a corpse worth 8 gold and no food. A necromancer can raise her; raised,
    she lays a clutch at once and then every `lay_every` (15 s; she drains away in 20 s),
    otherwise as before (same clutch, same hatch time, laying takes no time), but her eggs are **undead**
    (`Enemy.undead`, pale like the raised): unholy and ×2 holy damage, and so are the
    spiderlings out of them. Undead ones don't drain away (only the raised do).
- **Spider egg** (`spider_egg`, behavior `egg`, `"entry": "none"`): `"fixed_hp"`: always 1 HP,
  never scaled by difficulty or wave. It never moves and counts for the wave (an egg of a
  debug mother doesn't). After `hatch_time` (6 s) it hatches (`Waves.hatch`) into
  `hatch_into` (a spiderling with its mother's HP scale, undead from an undead egg); the
  spiderling is counted before the egg is let go, so the wave can't end in between.
  - It wobbles for the last `wobble_time` (2.5 s), faster and harder towards the end
    (`EggBehavior.animate`, on every machine).
  - Hatched, it becomes its broken shell (`unit_spider_egg_shell`, `Enemy.hatch_out`): out of
    the `enemies` group (nothing targets or counts it), for `shell_time` (4 s), then it fades.
    It shows on watched tiles like any enemy.
    Co-op clients see the shell (`"sh"` in the enemy state).
  - **Low priority** (`"low_priority"`): towers (`MilitaryBehavior.enemies_near` sorts them
    last), soldiers (the Inquisitor too), elementals and the hero go for eggs only when no
    other enemy is in reach (`Enemy.LOW_PRIORITY_TILES` on their distance).
  - Smashed: no gold, no corpse. Villagers don't flee from eggs (`"scares": false`,
    `Civilian.enemy_nearby`); once they hatch, they flee from the spiderlings.
- **Spiderling** (`melee`): about a rat's strength, quick (1.8), fights like a goblin, breaks
  gates and walls (`siege` 1) and goes round them where that is cheaper (the siege field),
  but `raid_chance` 0: it never burns a hut, it scuttles off once inside. 1 gold, no corpse.
  It walks from where it hatched to the nearest road and on to its egg's village.
- Library: one entry for the mother (with the eggs) and one for the spiderling; eggs have
  `"library": false`.

## 15c. Wrathwood (Wilderness, very rare)

A tree that wakes up under a forester's axe and goes after him. It never comes with a wave:
it is woken on the map (`Wrathwoods`, `scripts/systems/wrathwoods.gd`; numbers in
`Config.WRATHWOOD`), its fight is `ENEMIES.wrathwood` and `WrathwoodBehavior`.

| Kind | HP | Speed | Damage / cooldown | Kill gold | Corpse | Resist |
|---|---|---|---|---|---|---|
| Wrathwood | 220 | 0.45 | 22 / 2.5 s (×3 against buildings) | 35 | 40 building material, no gold or food | projectile ×0.5, fire ×2, holy ×0.75 |

- **Waking up** (`Wrathwoods.on_first_blow`): when a forester starts on a tree that nobody has
  chopped yet (its first blow; one roll per tree), it may wake.
  - Chance: `chance` by tree kind (oak 1.5 %, pines 0.3 %; dead trees and charred stumps never),
    plus **"the forest remembers"**: `remember` (0.05 %) for every tree that village's foresters
    have felled so far, together at most `max_chance` (3 %). Kinds with no base chance stay at 0.
  - Never before wave `from_wave` (8) has begun, never while the village already has one, and
    not for `quiet_waves` (3) waves after its last one died (`Wrathwoods.calm_until`).
  - Only where the game allows it (`Wrathwoods.allowed`): never in the tutorial or the title
    backdrop. Scenarios (not built yet) will have it off unless they turn it on.
  - The tile becomes meadow at once (the tree's sprite goes without falling,
    `World.remove_tree(t, false)`; `tree_woke` for co-op clients) and the wrathwood stands
    there, still looking like its tree (the tree's own art), shuddering for `wake_time` (3 s).
    It can be hit meanwhile, but doesn't move or strike. Then it bursts out in a shower of
    leaves (`leaves` burst) and shows its own art. Logged at Important to its village:
    "Tree 482 woke up as a wrathwood! It is after forester 2."
  - It belongs to the forester's village (`target_village`) and counts for no wave
    (`Enemy.wild`: like camp guards, it is ignored by the wave's count, the rats' and water
    monsters' checks, the warning lights and the timeline's enemy count).
- **Strength:** its HP grows with the waves like a wave's enemies (×`WAVE_HP_GROWTH`^(n−1), n the
  wave running or the last one); difficulty scales it like any enemy.
- **Walking:** it walks its own A* paths (`Pathing.wood_path`) over walkable ground **and forest
  tiles** (not mountains, water, lava or solid buildings). It never takes a road to a gate and
  never breaks into a village (`"entry": "none"`).
- **Regrowth:** within `regrow_radius` (2.5 tiles) of a tree it heals `regrow` (4 %) of its max
  HP per second. Back home (see *Guard*) it heals ×`home_boost` (2) that for `home_boost_time`
  (10 s), trees around or not.
- **What it does** (`WrathwoodBehavior.State`, saved with it):
  1. *Chase:* it goes for the forester who woke it, re-planning every 0.5 s. It ends when the
     forester is dead, gone, or safe (`Civilian.is_exposed()` false: at home or inside the walls).
  2. *Camp:* then it walks to that forester's worker camp and hits it until it is devastated
     (skipped when the camp is gone or already devastated).
  3. *Wander:* `wander_time` (20 s) of strolling within `wander_radius` (3) tiles of where it
     is.
  4. *Home:* it walks back to its old tile.
  5. *Guard* (territorial, for good): it stays on its tile. Anyone of ours within `territory`
     (4 tiles) of it (an exposed villager, the hero, a soldier, an elemental) is attacked and
     chased, but no farther than `leash` (6 tiles) from home; then it walks back.
  - *Swing-by blows* in every state but Guard: whenever its blow is ready, something within
    `reach` (1 tile) is hit as it passes, without stopping: what it is after first (the
    forester, the camp), else one of ours (an exposed villager, the hero, a soldier, an
    elemental; flyers only when they hit it), else a building of any village that isn't a hut
    (`damage` × `siege`, 3). It never stops chasing to fight.
  - *Defending itself* (Wander, Home, Guard): whoever hurts it becomes its foe. A unit or the hero
    is chased and hit (staying within `leash` of where it started defending, or of home when
    guarding); a tower that shoots it is walked to and smashed when it is within that leash.
    The foe gone, out of reach of the leash, or safe, it goes on with what it was doing (the
    wander time keeps running).
- **Root grip:** every `grip_every` (8 s; the first `grip_every` s after waking), when at least
  one of ours on the ground (an exposed villager, the hero, a soldier, an earth elemental;
  never flyers or units on posts) is within `grip_radius` (1.6 tiles), it stops for
  `grip_cast` (0.6 s, arms down into the ground) and roots grow up around every one of them:
  they can't move for `grip_time` (2 s; `Unit.force_move` with no step each frame), but can
  still fight. Roots coil up round each held one (`fx["grip"]`, drawn on every machine).
- **Killed:** 35 gold to the killer's village, and a corpse: a log of living wood
  (`corpse_wrathwood`) worth `materials_on_collect` (40) building material and nothing else,
  which a necromancer can't raise (`"revivable": false`). It belongs to the wave running then
  (or the last one) and rots like any corpse. `Wrathwoods.calm_until` is set.
- **Explorers** avoid it like camp guards (`ExploreJob._camp_danger`, `Enemy.wild`).
- **Debug:** *Spawn enemy...* → wrathwood wakes the explored tree nearest to one of the
  village's foresters (else the nearest to the village), whatever the odds and wave.
- **Saving** (docs/save-design.md): every wrathwood is saved with its state, HP, HP scale,
  position, home tile, the forester and camp it is after (nids), wander time and home boost
  left, plus per village the trees its foresters felled and `calm_until`.
- Library: one entry ("Wakes when a forester starts on a tree, from wave 8, rarely").

## 15d. Vultures (Wilderness, animals)

Carrion birds drawn by the dead the last wave left lying. They come for the corpses, not the
village: every corpse they eat is loot the player loses, and they leave when there is nothing
left to eat. Numbers: `Config.VULTURES` (the packs) and `ENEMIES.vulture` (the bird); code:
`scripts/units/enemies/vulture_behavior.gd` (`VultureBehavior`, extends `MeleeBehavior`) and
`vulture_pack.gd` (`VulturePack`: the pack's shared target and mode), `Waves._vulture_packs`.

| Kind | HP | Speed | Damage / cooldown | Kill gold | Corpse | Resist |
|---|---|---|---|---|---|---|
| Vulture | 18 | 1.6 | 3 / 1.0 s | 2 | 3 food, no gold | projectile ×1.25, fire ×1.25, holy ×0.75 |

- **When and how many** (`Waves._vulture_packs`, at the start of a wave, after the wave's mix,
  rat packs and lairs: they never take a share of `WAVE_MIX`): from wave `from_wave` (6; a
  scenario may set its own, `Scenario.vultures_from_wave`: scenario 6 from wave 4), per village,
  count the **edible corpses** lying nearest that village (§ below). Packs = min(`max_packs`
  (3), corpses / `per_corpses` (5), rounded down): fewer corpses, fewer vultures (0-4 corpses:
  none). Each pack has `pack` (2-4) vultures, the wave's HP scale, and counts for the wave.
- **Edible:** any corpse on the map except a vulture's (`never_eats`: vultures, the wrathwood's
  log) and one sinking in deep water. The campaign's fallen (scenario 6) are edible: an eaten one
  is lost like one that rose (logged at Important, "A vulture has eaten one of the fallen").
- **Target and spawn:** each pack gets one target corpse (different ones while there are enough,
  at random among its village's). It comes from the map's edge: the open edge tile nearest its
  target from which it can fly there; its birds spawn there `gap` (0.4) s apart.
- **Flight** (`Pathing.sky_path`): near-straight lines (A*, no road), over every tile a ground
  unit can walk on plus deep water and forest; never over mountains (volcanoes), lava, buildings
  or solid map objects (lairs, camps). No ground slows it. A flyer (§5) while in the air: only
  ranged attacks, fire elementals and halberdiers reach it.
- **The pack:** every bird flies to the pack's target. When the target is gone (eaten, gathered,
  raised, rotted), the pack picks the edible corpse nearest to it (its birds' middle) and they
  all fly there. None left: **search** for `search_time` (10) s, the birds spreading out within
  `search_spread` (3) tiles; a corpse turning up meanwhile (a fresh kill) ends the search. Still
  none: the pack **leaves**: it picks the edge tile nearest by flight (a flood fill over the
  sky grid) and flies there; a bird is gone (`Enemy.vanish`: no corpse, no gold, it no longer
  counts for the wave) once it has been out of every village's sight for `hidden_time` (3) s,
  or once it has reached that edge tile and waited `hidden_time` there. Vultures never have to
  be killed. A leaving pack doesn't turn back.
- **Eating:** at its corpse a bird **lands** (`Enemy.landed`: a ground target now, melee can hit
  it) and eats for `eat_time` (4) s; all of the pack try to eat the same corpse, each on its own
  timer. When a bird's meal is done and the corpse is still there, it gets its share and then
  the corpse goes with `vanish_chance` (50 %); otherwise it stays for the next. A bird whose
  corpse went before its meal was done gets nothing and takes off with its pack. Each share
  adds `grow` (25 %) of its starting max HP (and as much HP) and damage (`Enemy.power`), at most
  `max_meals` (4) shares: twice as strong; it is drawn a little bigger with each.
- **Fights only for itself and its corpse:**
  - On its corpse it fights whoever comes within reach (`MeleeBehavior`: our fighters, a
    villager outside), its meal paused meanwhile.
  - Hurt by one of ours out in the field (the hero, a soldier on a sortie or walking, an
    elemental: `melee_defenders`), it flies at that one and fights back until it or the foe
    is down, or the foe is `chase` (6) tiles from the pack's target; then back to the pack.
  - Hurt by what it can't reach (a tower: a `Building`), only that bird **flees**: out of the
    tower's range plus `flee_margin` (1) tiles, and back to its pack once `flee_time` (8) s have
    passed since its last such hit.
  - It never breaks walls or gates, never goes for a gate, never burns a hut. Villagers run from
    it like from any enemy (gatherers keep off corpses with vultures near: `Corpses.is_safe`).
- **Killed:** `gold_on_kill` 2; its corpse brings 3 food and no gold. A necromancer can raise a
  vulture's corpse: the raised bird is a pack of its own and does what vultures do. Vultures
  never eat a vulture's corpse.
- Co-op: each village's packs come for the corpses nearest it; clients see `landed` and the
  growth (`Enemy.fed`) through the replicator.
- Library: its own entry (from wave 6, the pack rule, eating and growth, leaving).

## 15e. Wolves and riders (mounted enemies)

Wolves hunt in packs; goblin raiders ride them. The Dread Legion has cavalry (campaign only), and
its captains and commanders ride into battle too. A mount is a second HP pool: it has to fall
before its rider can be hurt. Numbers: `ENEMIES.wolf`, `goblin_raider`, `legion_cavalry`, `horse`
and `Config.MOUNTED`; code: `Enemy` (the mount: `mount`, `mount_hp`, `dismount`, the charge),
`scripts/units/enemies/mounted_behavior.gd` (`MountedBehavior`, extends `MeleeBehavior`: how a
rider moves and picks its fights; `CaptainBehavior` and `CommanderBehavior` extend it) and
`flee_behavior.gd` (`FleeBehavior`: the undead horse).

| Kind | HP | Speed | Damage / cooldown | Kill gold | Corpse | Holy |
|---|---|---|---|---|---|---|
| Wolf | 13 | 1.4 | 4 / 0.8 s | 2 | 3 food, no gold | ×1 (animal) |
| Goblin raider | mount 18, then a goblin (20) | 1.6 mounted | 5 / 1.0 s | mount 2, then a goblin's | the wolf's, then a goblin's | mount ×1, then ×0.75 |
| Legion cavalry | mount 45, then a footman (38) | 1.5 mounted | 8 / 1.1 s | mount 2, then a footman's | the horse's (8 food, no gold); the footman is released | mount ×1 |
| Horse (only raised) | 45 (raised: half) | 1.5 | none | 2 (raised: 1) | 8 food, no gold | ×1, raised ×2 |

- **The wolf** (from wave 5, `WAVE_MIX` like the big slime: 6 %, +2 %/wave, at most 15 %) is a
  plain melee enemy (`MeleeBehavior`) that comes in **packs** of 2-3 (`"pack"`): the wave's
  wolves are grouped into packs, each from one spawn, the wolves `pack_gap` (0.3 s) apart; a
  wave's single wolf gets a second. It breaks gates and walls weakly (`siege` 0.5). Through
  (`"raid": "maul"`, `Game.on_enemy_reached_gate`), it kills the villager of the hut it got to
  (else of the intact, lived-in hut nearest it), leaves the hut standing, and is gone. Raised by
  a necromancer it is an **undead wolf** (raised: unholy, ×2 holy, drains away in 20 s).
- **Mounts** (`Enemy.mount`: `"wolf"` or `"horse"`, the animal's `ENEMIES` kind): a mounted kind
  has `"mount"`, `"mount_hp"` and `"rider"` (what it is on foot); a scenario can put any enemy on
  a horse (a queue entry's `"mount"`, `"mount_hp"`: the captains and commanders). While mounted:
  - every hit lands on the mount (`mount_hp`, scaled like HP: wave and difficulty; the
    animal's `resist`, a commander's `guard`); the rider's HP stays whole. A blow that kills the
    mount never carries over. Two HP bars: the mount's (brown) over the rider's.
  - it moves at the mounted speed (its kind's `speed`; a given horse: `MOUNTED.mounts.horse`),
    and hits walls and gates with its kind's low `siege` (0.3) only when it rides into one.
  - **Dismount** (`Enemy.dismount`): the mount falls (its kill gold, `gold_on_kill` of the
    mounted kind, to whoever killed it; it counts as a kill of the mounted kind; a corpse of the
    animal where it fell; a puff of dust), and a kind with `"rider"` turns into that kind in
    place (a new number for the log, its own HP, speed, behavior and look; it keeps its wave and
    its target). A captain or commander just goes on on foot (`on_dismount`).
- **Riding** (`MountedBehavior`, while mounted):
  - It runs to its village by road, but never hits a gate, wall or wall tower: within `approach`
    (5) tiles of the walls it **circles** the village, about `ring` (3) tiles outside the walls,
    round and round. Its ways (to a target, to its soldiers) never cross an intact barrier
    (`MountedBehavior.open_way`); one it can't reach that way it leaves be for 5 s.
  - **Breached:** when the way anyone on foot would break in (the siege field, from the edge of
    its zone nearest the rider) reaches a hut with no intact barrier on it (a broken gate or
    wall), it **rides in** like the others (`Enemy.ride_in`: the siege field, mounted) and burns
    a hut. A barrier turning up in its way sends it back to circling for 5 s.
  - It **hunts**: the goblin raider anything of ours within `hunt_radius` (5) tiles it can reach
    that way (villagers out of shelter, the hero, soldiers walking or on a sortie, ranged ones
    too, summons; not buildings); Legion riders (`"hunts": "melee"`) only melee fighters (the hero, melee
    soldiers, summons). It rides at the nearest, fights it, and gives up beyond `chase` (8) tiles.
  - Legion riders **escort** (`"escort"`): while a Legion soldier on foot is about, they keep
    within `escort_radius` (2.5) tiles of the nearest one, hunting only from there; with none
    left they circle like raiders.
  - **Getting off at the gate:** after `circle_time` (40) s at the village without a blow, it
    rides to the gate nearest it and gets off there: the mount runs off the map (no corpse, no
    gold, a look only) and the rider breaks in on foot.
  - **Charge:** after riding `charge_distance` (3) tiles without a fight (`Enemy.charge_ready`,
    dust under its hooves, leaning forward), its next blow does `charge_x` (×2).
  - **Led by a scenario** (`Enemy.errand`, `MountedBehavior._on_errand`; scenario 9's Lysa at
    the head of her `LegionCompany`): it rides where the errand sends it and fights what comes
    within reach, but never charges (`Enemy._tick_ride`) and hunts, escorts and circles nobody. Waiting at its village
    it rides in through a breach, or after `circle_time` gets off and breaks in on foot.
- **Against cavalry:** the halberdier's blows do `vs_mounted` (×2.5) to a mount (only to the mount:
  never to the rider on foot), and it **breaks a charge** (`"breaks_charge"`): a charge on a
  halberdier gives no bonus, and its blow on a mounted enemy halts the mount for `halt_time`
  (0.5) s and spends its charge.
- **The undead horse** (`horse`, `FleeBehavior`): there is no living horse, only a fallen
  mount's corpse. Raised, it never fights: it bolts to the spot within `flee_search` (8) tiles
  with the fewest of our people and towers around, again every 3 s, and dies of the raised drain
  (20 s); unraised (a debug one) it vanishes after `flee_time` (20) s. It counts for the wave.
  Villagers don't run from it (`"scares": false`).
- **Goblin raider** (from wave 7, alone, 5 %, +1.5 %/wave, at most 12.5 %, no cap); **Legion
  cavalry** only where a scenario sends it (scenario 8 from wave 6, scenarios 10 and 11).
- **Mounted captains and commanders** (docs/scenarios-design.md §7): Lysa and Torben ride
  (scenarios 5, 9 and 10): they escort their column like cavalry and fall back faster while
  mounted; a captain whose horse falls goes on (and falls back) on foot. Halvard rides
  (scenario 10) and keeps rallying. Rhodri (scenario 11) fights in two phases: mounted, then on
  foot once his horse falls ("Rhodri's horse falls! Rhodri fights on foot"). The mounted
  art is `unit_<art>_mounted`.
- Co-op: clients see the mount, its HP, the charge and the change of kind through the replicator.
- Library: wolf, goblin raider, Legion cavalry (with the mount's HP and the charge) and the horse.

## 15f. Ghost (a haunting)

A spirit that comes for one villager, not for the village. It is unseen and untouchable until
something reveals it or it closes in on its victim; the answer is detection (light stones, a High
Priest) and the right damage (holy, magic, fire), not more arrows. Numbers: `Config.GHOST` (the
haunt) and `ENEMIES.ghost` (the body); code: `GhostBehavior` (extends `EnemyBehavior`).

| Kind | HP | Speed | Damage / cooldown | Kill gold | Corpse | Resist |
|---|---|---|---|---|---|---|
| Ghost | goblin's (placeholder) | goblin's | goblin's (placeholder) | placeholder | none | melee ×0, projectile ×0, fire ×0.75, magical ×1, pure ×1, holy ×2 |

- **Damage:** melee and projectile do nothing (×0). Holy ×2 is the final factor (`raised_holy` is
  not added on top), and it is `"unholy": true`. A fire elemental's blow is fire, the Inquisitor's
  holy melee is holy: both hurt it. Nothing that deals only melee or projectile damage (archers,
  crossbowmen, shield bearers and their branches, the hero's sword, earth elementals, thornlings)
  can target it at all, revealed or not, so towers and barracks never waste shots or turn out for
  it (`Combat` targeting asks whether a damage category hurts it).
- **Phases:** *faded* (the default) or *solid*. Faded: it can't be targeted or hit (shots in
  flight fizzle, splash skips it), it can't attack, villagers don't see it (no flee), and it is
  drawn at 20 % opacity on watched land (`GHOST.faded_alpha`). Solid: drawn fully, targetable by
  what can hurt it, and it can attack. It turns solid when:
  - it is **revealed**: within a working light stone's light radius (the stone's own sight radius,
    `LIGHTSTONE_SIGHT`; a site or a devastated one doesn't count), or in a High Priest's aura
    (`Combat.in_holy_aura`). Any village's stone or priest counts. Towers, their lanterns and
    their levels reveal nothing; or
  - it is **hunting** and within the target's reach: melee range + 1 tile (`GHOST.solid_margin`).
  Beyond that it fades again. Revealed wins over the hunt's rule: a revealed ghost is solid
  wherever it is. The change is a short fade (`phase_time`, art only; the rule applies at once).
- **Target:** at spawn it picks one living villager of its village at random (the hero is not a
  villager). It never takes another. Any villager may be picked, a miner too. The hut isn't its aim: it ignores huts altogether. The player isn't told who is hunted.
- **Journey** (`GhostBehavior`): from its edge spawn it follows the **road** to its village until
  it has covered `road_share` (90 %) of the road distance to the walls. Then it **searches**: it
  flies (`Pathing.ghost_path`: like the vultures' `sky_path`, over land, forest and deep water,
  never over mountains, lava or solid map objects, but it also passes every building) towards
  where the target is now, re-planning as the target moves. It ignores walls, gates, wall towers
  and huts. Now and then the straight-ish route takes a detour for flavour
  (`detour_chance`, `detour_length`). Still a ground unit for everything else: no swamp or ford
  effects (it floats), not a flyer (§5: it isn't reached by ranged only, its damage table decides).
- **A miner as target:** the ghost goes to the miner's mine. Once it is adjacent to the mine (it
  doesn't go in) the miner leaves it, so the ghost sees them, turns solid and hunts. The miner
  flees to the village, never back into the mine. That is the whole mechanic.
- **Hunt:** within reach it attacks the target (goblin-like blows); the villager flees as from any
  enemy (`FleeBehavior`-independent: the normal villager flee, triggered by a solid ghost in
  sight). Speed is a goblin's. After `enrage_after` (60) s of hunting in all (faded or solid, the
  journey counts) its speed **doubles** for good, so a hunt can't stall.
- **Breaching:** while a ghost is inside its village's walls **and solid**, the village counts as
  breached (`Siege.breached`: villagers in there are exposed, at home too). Inside and faded it
  does not. It never damages buildings and never burns a hut.
- **Lurking:** when its target runs home and is hidden in the village, the ghost loses them: it
  counts an **escape** (`GhostBehavior.retreats`, per ghost: it has one target; an escape is a
  target that was fleeing (`evading`) and got home), fades and **lurks** (`Mode.LURK`): faded
  (unless lit), it strolls without a goal: it picks a random place `lurk_step` (3 to 6) tiles
  from where it floats, no farther than `lurk_leash` (12) from its target, drifts there and
  picks again. It doesn't fight there (only back at what hurt it, when lit). When the target
  comes out again (no longer home) it goes after them (`SEARCH`). A target already at home when
  it arrives is lurked at, without counting. After `retreats` (3) escapes it gives up: the
  target counts as gone (next point), so a ghost can't block the village for ever. The 60 s
  enrage counts only the road and the search, not the lurking.
- **Hovering:** it never walks: no walking sway, it bobs up and down (`Enemy.hovers()`,
  `"hover": true`, `_hover`) over a shadow of its own (the same `_shadow` a flyer has), moving
  or standing. It is no flyer (`flies()` stays false: the damage table decides who reaches it).
- **Target gone:** when the target is dead or retired (any cause: the ghost, rats, starvation, the
  villager list's *Retire*) the ghost fades, stops hunting and **roams** for `roam_time` (20) s:
  it wanders the map (`sky_path` to random explored places), faded, never picking a new target.
  Revealed and hurt meanwhile, it **counterattacks** whoever hurt it if it can reach them
  (acolytes, fire elementals, summons and units in reach) and ignores what it can't reach (an
  archer on a tower); the roam is its main part. The 20 s are the ghost's maximum lifetime after its target is gone. After them it **vanishes** (`Enemy.vanish`:
  no corpse, no gold, no longer counts for the wave). A revealed ghost that takes damage while hunting
  also fights back like that, and otherwise goes on hunting.
- **Waves:** from wave 12 (`WAVE_MIX`), a small share, at most one per village per wave
  (`max_count`, `Config.wave_max_count`); it counts for the wave, and the wave is over only once
  every ghost has been killed **or has vanished** (so a wave with a ghost lasts at least until its
  target is gone plus 20 s, or until it is killed). No warning light marks its road. It comes
  from the village's edge spawns like the others; not in the tutorial or, for now, the title backdrop (it may come later), and
  scenarios take it only when their own waves list it.
- **Loot:** killed (only while solid, so only by what hurts it): `gold_on_kill`. A ghost that
  vanishes pays nothing. No corpse: nothing to gather, nothing for a necromancer or a vulture.
- **Co-op and saves:** the replicator sends the phase (`Enemy.faded`; a client draws the opacity).
  Nothing of a ghost is saved: a wave isn't (docs/save-design.md).
- **Library:** its own entry (from wave 12, the damage table, how it is revealed, what it hunts);
  the Damage tab shows melee/projectile ×0 and the rest from Config. A ghost kill counts under
  "Others" in the statistics (it is not in `STATS.kill_kinds`).
- **Code:** `Enemy.faded` / `set_faded` / `scary()` / `hurt_by(category)`, `targetable()` is false
  while faded and `take_damage` ignores everything; the villagers' flee checks and the build queue's
  danger test use `scary()`; `Siege` skips faded enemies; `MilitaryUnit.can_face(e)` (its
  `damage_category()`) filters the targets of towers (`MilitaryBehavior.enemies_near(post, r, unit)`),
  barracks (`enemy_near`), sortie soldiers, elementals and the hero. A miner is driven out by
  `Miner.drive_out`. Art `unit_ghost` (`gen_art.py`).
- **Tested** in `tests/enemy_bot.gd` (`_test_ghosts`): the table, the wave rule, faded damage, who
  can target it, light stones, the grudge, the hunt, the breach flag, the enrage, retire and death
  ending the hunt with the 20 s vanish, the miner.

## 16. Monster-camp guards

- Every far treasure (and half of the middle ones) has a camp (`CAMP_CHANCE`, docs/world-design.md
  §9.3) with `CAMP_MONSTERS`:
  - tier 2: goblin, goblin, ork;
  - tier 3: goblin, ork, ork, witch.
- They have `CAMP_HP_SCALE` (×1.5) HP, fixed (not wave-scaled), and use `CampBehavior` instead of
  their kind's behavior.
- They never walk a road. They attack any defender or exposed villager within `CAMP_AGGRO` (3.5
  tiles) of the camp, never follow farther than `CAMP_LEASH` (5), and walk back to their spot
  when nobody is left.
- Hurt guards don't heal. Kill gold is paid only when the killer belongs to a village; they
  leave no corpse.
- Towers and barracks fight guards in their range without any order (build next to a camp and
  it fights). Only the hero needs the order (the camp's panel: *Attack with the hero*). Guards
  also fight whoever walks close. Explorers avoid them.
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
released (`"release"`: no corpse, the colour warms, a pale breath). The captain
(`CaptainBehavior`) is never killed: below `retreat_below` (30 %) it falls back, untargetable, off
the map the way it came. Named ones (Lysa, Torben) carry a name and art of their own
(`Enemy.set_identity`). Numbers and the rest: docs/scenarios-design.md §7.7.
- The **archer** (`LegionArcherBehavior`) stops to shoot our people out in the open within `shoot_range`
  (3.2, below a level 1 watchtower), arrows as projectiles; the **guardsman** takes half from projectiles;
  the **banner-bearer** hastes every Legion soldier within `banner_radius` (`Enemy.haste`: ×1.25); the
  **court champion** (scenario 8's Rurik) cleaves (`EnemyBehavior.cleave`). docs/scenarios-design.md §7.13.
- **Commanders** (`CommanderBehavior`; scenario 10's marshal Halvard, `legion_marshal`, and scenario 11's
  king Rhodri, `legion_king`): bosses whose Legion soldiers within `command_radius` strike faster
  (`command_haste`) and take less damage (`command_guard`; `Enemy.haste`, `Enemy.guard`), and who send
  `rally` soldiers for the wave from an edge spawn every `rally_every` seconds while they live. The king's
  blows cleave, and he is `"downed"` at 0 HP: 1 HP left, untargetable, back along his road and gone.
  docs/scenarios-design.md §7.16.
- A camp of Legion soldiers only is a *Legion camp* (its own look). A scenario can set a lair's guards,
  kinds and waking wave and keep it cleared (`Scenario.lairs`).

## 17. Open ideas / not built

- **Invisible enemies:** the ghost (§15f) is the first. `Combat.in_holy_aura(game, grid_pos)` is the hook: a
  High Priest's aura is meant to reveal them (docs/acolyte-design.md §6).
- **Flying allied units:** none yet. The vampire's comments note that a bat would be theirs to
  fight.
