class_name Relics
## Relics (docs/items-design.md §7): special finds whose static effect works
## just by a village having one, never worn. Village-wide relics
## (Config.RELICS "reach" "village") work for the village that has them
## (Village.relics, duplicates kept, room in the armoury), map-wide ones
## ("map") for everyone while any standing village has one. A duplicate
## counts once. Every relic source (generated treasures, lairs, the market's
## relic offer) picks through `pool`; whatever brings one home goes through
## `bring_home`.


static func is_relic(id: String) -> bool:
	return Config.RELICS.has(id)


static func spec(id: String) -> Dictionary:
	return Config.RELICS.get(id, {})


static func name_of(id: String) -> String:
	return str(spec(id).get("name", id))


static func desc_of(id: String) -> String:
	return str(spec(id).get("desc", ""))


## "village" or "map".
static func reach(id: String) -> String:
	return str(spec(id).get("reach", "village"))


## Its icon's text token (Hud.icon_bbcode).
static func token(id: String) -> String:
	return "{relic:%s}" % id


## The relics a source may give in a game of `players` villages (a "coop" one
## only with two villages or more).
static func pool_for(players: int) -> Array[String]:
	var out: Array[String] = []
	for k: String in Config.RELICS:
		if not Config.RELICS[k].get("coop", false) or players > 1:
			out.append(k)
	return out


static func pool(game: Game) -> Array[String]:
	return pool_for(game.villages.size())


## A random relic from the pool, preferring one `v` doesn't have yet (v null:
## any). "" if the pool is empty.
static func random(game: Game, rng: RandomNumberGenerator, v: Village = null) -> String:
	var p := pool(game)
	if v != null:
		var fresh: Array[String] = []
		fresh.assign(p.filter(func(k: String) -> bool: return not has_relic(v, k)))
		if not fresh.is_empty():
			p = fresh
	return p[rng.randi() % p.size()] if not p.is_empty() else ""


## A relic this game can't use (a co-op one alone) turns into one it can,
## picked by `n` (so every machine agrees).
static func usable(game: Game, id: String, n: int) -> String:
	var p := pool(game)
	if p.has(id) or p.is_empty():
		return id
	var local := p.filter(func(k: String) -> bool: return reach(k) == "village")
	return str(local[absi(n) % local.size()]) if not local.is_empty() else str(p[absi(n) % p.size()])


## Does `v` have relic `id`?
static func has_relic(v: Village, id: String) -> bool:
	return v.relics.has(id)


## The sum of effect `key` over `v`'s village-wide relics, each kind once.
static func bonus(v: Village, key: String) -> float:
	var sum := 0.0
	var seen := {}
	for r in v.relics:
		if seen.has(r) or not Config.RELICS.has(r) or str(Config.RELICS[r]["reach"]) != "village":
			continue
		seen[r] = true
		sum += float(Config.RELICS[r].get(key, 0.0))
	return sum


## The sum of map-wide effect `key` over the map-wide relics any standing
## village has, each kind once however many have it.
static func map_bonus(game: Game, key: String) -> float:
	if game == null:
		return 0.0
	var sum := 0.0
	var seen := {}
	for v: Village in game.villages:
		if v.fallen:
			continue
		for r in v.relics:
			if seen.has(r) or not Config.RELICS.has(r) or str(Config.RELICS[r]["reach"]) != "map":
				continue
			seen[r] = true
			sum += float(Config.RELICS[r].get(key, 0.0))
	return sum


## The tax on help sent between villages (Config.help_tax, the Peace ribbon applied).
static func help_tax(game: Game) -> float:
	return Config.help_tax(game.villages.size()) * maxf(0.0, 1.0 - map_bonus(game, "help_tax"))


## A siren's or an octopus's dive when hurt, in seconds (the Stormglass applied).
static func dive_time(game: Game, base: float) -> float:
	return base * maxf(0.0, 1.0 - map_bonus(game, "dive"))


## Relic `id` brought home (Treasure.pay): among the village's relics; a full
## armoury leaves it in a sack by the town hall. Returns the floating text's
## part ("" if it waits).
static func bring_home(v: Village, id: String) -> String:
	if not v.armoury.full():
		var dup := v.relics.has(id)
		v.relics.append(id)
		v.armoury.changed.emit()
		if dup:
			v.events.important("Found another %s: a second one does nothing more." % name_of(id))
		else:
			v.events.important("Found the %s: %s!" % [name_of(id), desc_of(id)])
		return "%s %s" % [token(id), name_of(id)]
	var hall := v.town_hall()
	var sack: Treasure = null
	var t := ItemDrops.free_tile(v.game, hall.tile if hall != null else v.center)
	if t.x >= 0:
		sack = v.game.world.add_dropped_loot(t, {"relic": id})
	if sack != null:
		v.events.info("The armoury is full: the %s waits by the town hall." % name_of(id))
	else:
		v.events.info("The armoury is full: the %s is lost." % name_of(id))
	return ""
