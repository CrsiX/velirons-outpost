# Glossary

Game terms as used in code, docs and tests. One line each, no numbers (the code has them: usually `scripts/core/config.gd`). Longer reasoning is in the doc named at the end of a line.

## Village and economy
- **Outpost / village**: the walled block of huts, walls, gates and wall towers a player runs. `village-design.md`
- **Hut**: houses exactly one villager; intact huts cap the population. A burned hut is a ruin and can be rebuilt.
- **Wall tower / watchtower**: towers hold one military unit. Wall towers are part of the village walls; watchtowers are built outside.
- **Post**: a slot a military unit can be stationed in (tower, training grounds). **Bench**: a barracks' slot. **Reserve**: where bought or withdrawn units wait at home.
- **Sortie**: a barracks' units turning out to fight when enemies come in range.
- **Downed**: at 0 HP a unit or the hero is out until it revives (in the reserve, on its bench, or in the village centre).
- **Devastated**: a building at 0 HP. It does nothing and shows its ruin; repair brings it back. "Does its job" is `working()`. `siege-design.md`
- **Build queue**: how builders (and the hero in Build mode) choose the next job. `village-design.md`
- **Tear down**: a builder dismantles a building outside the walls for a partial refund.
- **Gatherer / forester / farmer / builder / explorer / miner**: civilian roles. **Merchant, guild master, resident**: named campaign villagers who can't be recruited.
- **Caravan**: a cart. In co-op it carries help between villages; in the campaign a scripted guild cart.
- **Starvation / hunger**: villagers die one by one while food is out; military units slow down and take more damage.

## Combat
- **Damage category**: melee, projectile, magical, fire, holy or pure; enemies resist or are weak to categories. `enemies-design.md`
- **Specialisation (branch)**: a base unit turns into a specialised kind from a minimum level and starts again at level 1. `military-design.md`
- **Summon / elemental**: units a summoner creates (earth, fire, thornlings); they crumble with their summoner.
- **Aura**: a High Priest's buff, strongest counts, no stacking. **War cry**: the Warrior's haste shout.
- **Holy / unholy**: the acolyte line's damage; skeletons, necromancers, vampires and anything raised or undead count as unholy. `acolyte-design.md`
- **Raised**: an enemy a necromancer brings back; it drains away and is undead.
- **Siege field**: the cost field enemies near a village follow to its cheapest way in. **Breached**: an enemy is inside. **Slip**: rats and thieves get through gates unharmed after a delay. `siege-design.md`
- **Mount / rider / charge / circling**: mounted enemies' rules (hits land on the mount first; they circle the village instead of breaking barriers until a breach). `enemies-design.md`
- **Dive**: water monsters going under on deep water, untargetable. `aquatic-design.md`
- **Wave**: a batch of enemies; the next one comes a fixed time after the last enemy is gone. **Wild** enemies (camp guards, wrathwood) count for no wave.
- **Wrathwood**: a tree that wakes up when a forester chops it. **Vulture**: carrion birds drawn by corpses left lying. **Fallen**: the campaign's corpses on the battlefield. `enemies-design.md`
- **Ghost**: a spirit hunting one villager, immune to melee and projectiles. **Faded / solid**: unseen and untouchable, or targetable; **revealed**: made solid by a light stone or a High Priest's aura. **Lurk**: waiting faded while its target hides at home. `enemies-design.md`

## World
- **Fog of war**: unexplored (black), explored (darkened), under surveillance (clear). Enemies are only visible when watched.
- **Map object**: treasure, monster camp, unit-unlock site, ruined watchtower, mine, monster lair; hidden until found. `world-objects-design.md`
- **Relic**: a small permanent bonus some treasures hold.
- **Lair**: wakes late and adds a spawn point; the hero can clear it.
- **Spawn / water spawn**: where enemies enter at the map edge or from deep water.
- **Slice**: a co-op village's part of the map. **Ownerless village**: a village on a map file nobody plays; it is ruins.
- **Map type / zone**: Temperate, Highlands, Coast, Desert, Volcanic or Random; zones are meadow, woods, heath, steppe, swamp, ash land, city.
- **Baked map**: a map saved beforehand for the title backdrop.

## Hero
- **Hero modes**: Defend, Build, Explore, Gather, Train, Rest, Support (co-op). **Attack a camp** is an order that overrides the mode. `hero-design.md`
- **Training grounds**: where the hero in Train mode passes her XP to a stationed unit.

## Campaign
- **Scenario**: one campaign level, one file; it has a baseline, waves, cards, objectives, cutscenes. `scenarios-design.md`
- **Card / hint**: the scenario's teaching text top left; a hint may point at something.
- **Journal**: a found page that pauses the game.
- **Prebuilt**: buildings and units a scenario starts with.
- **Brenna**: the hero. **Pell**: the merchant. **Fiona, Lothar, Rhodri, Anselm, Sigmund, Wenna, Lysa, Torben, Halvard, Rurik**: named characters. `story-design.md`
- **Wardline**: the ruined border towers along the north. **Dread Legion**: the campaign's human-led undead army. **Silver Thread Guild**: Pell's neutral merchant guild.
- **Stall, warehouse, graveyard, church, grove**: campaign-only buildings.
- **Trust locks** (scenario 7), **hero lives out** (tent outside the walls), **barred**: scenario rules that limit the player or the hero.

## Tools and tests
- **Bot**: a headless test scene under `tests/`. **Balancing bot**: plays whole games to measure balance. `balance-bot-design.md`
- **Backdrop**: the live game behind the title menu.
- **Library**: in-game reference pages built from `Config`.
- **Tactical map**: the overview map opened with M.
- **Co-op / host / client**: LAN multiplayer; the host simulates, clients send commands. `multiplayer-design.md`
- **Autosave**: written after every wave; saves only happen between waves. `save-design.md`
