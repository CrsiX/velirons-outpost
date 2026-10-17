extends Node
## Two-process LAN co-op test (milestone 5 of docs/multiplayer-design.md).
## Start the host and a client, both headless, on the same machine:
##   godot --headless --path . res://tests/net_bot.tscn -- --role=host
##   godot --headless --path . res://tests/net_bot.tscn -- --role=client
## (tests/run_net_test.sh does both.) Each side prints its checks; exit code 0
## when all pass. The client finds the host by LAN discovery (loopback), joins
## the lobby, gets ready; the host starts; then both check the replicated game.
## With `--custom` the host picks a map file instead (three villages; the
## client gets village 3, village 2 stands empty: docs/map-editor-design.md §8).
## With `--resume` the host resumes a saved co-op game of two villages
## (docs/save-design.md §6): exactly two players, who swap villages; each
## plays its village under their own name in the saved colour.

const HOST_NAME := "Hostwatch"
const CLIENT_NAME := "Clientvale"
const TIMEOUT := 60.0
## The lobby's map settings for this test (a coast map with a camp, a ruin, treasures).
const MAP_TYPE := "coast"
const MAP_SEED := 4240

var role := ""
var custom := false
var resume := false
const SAVE_DIR := "user://net_bot_saves"
var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
		if a == "--custom":
			custom = true
		if a == "--resume":
			resume = true
	# Survive the switch into the level: another node becomes the "current scene".
	var stand_in := Node.new()
	stand_in.name = "StandIn"
	get_tree().root.add_child.call_deferred(stand_in)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = stand_in
	if role == "host" and resume:
		await _host_resume()
	elif role == "client" and resume:
		await _client_resume()
	elif role == "host" and custom:
		await _host_custom()
	elif role == "host":
		await _host()
	elif role == "client" and custom:
		await _client_custom()
	elif role == "client":
		await _client()
	else:
		print("usage: -- --role=host | --role=client")
	_finish()


func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if cond else "  FAIL ") + "[%s] %s" % [role, msg])
	if not cond:
		failures.append(msg)


func wait_until(cond: Callable, timeout: float = TIMEOUT) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > timeout * 1000.0:
			return false
	return true


func seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _finish() -> void:
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - [%s] %s" % [role, f])
	Net.leave()
	get_tree().quit(1 if failures.size() > 0 else 0)


func _client_id() -> int:
	for id in Net.players:
		if id != 1:
			return id
	return -1


# --- host ---------------------------------------------------------------------------------

func _host() -> void:
	check(Net.host(HOST_NAME, 0) == "" and Net.is_host(), "hosting a lobby")
	check(Net.join_decision(Net.PROTOCOL + 1, "Other") != "" and Net.join_decision(Net.PROTOCOL, HOST_NAME) != "", "the host turns away another version and a taken name")
	var joined := await wait_until(func() -> bool: return _client_id() > 0)
	check(joined, "a client joins the lobby")
	if not joined:
		return
	var cid := _client_id()
	check(Net.players[cid]["name"] == CLIENT_NAME and int(Net.players[cid]["color"]) != 0, "it has its name, and another colour than the host's")
	Net.set_map(MAP_TYPE, MAP_SEED)
	var ready := await wait_until(func() -> bool: return Net.players.has(cid) and Net.players[cid]["ready"])
	check(ready and Net.can_start(), "it gets ready: the host can start")
	check(Net.start_game(), "the host starts the game")
	check(Net.join_decision(Net.PROTOCOL, "Latecomer") == "The game has already started", "no late joining once started")
	var loaded := await wait_until(func() -> bool: return Net.game != null and Net.players[cid]["loaded"])
	check(loaded, "the client loaded the level")
	if not loaded:
		return
	var game := Net.game
	var v0 := game.villages[0]
	var v1 := game.villages[1]
	check(game.villages.size() == 2 and v0.village_name == HOST_NAME and v1.village_name == CLIENT_NAME and not game.is_client, "two villages, named after the players")
	# (a tile 3 beyond the client's walls, on the far side from the host's village)
	var dir := Vector2(v1.center - v0.center).normalized()
	var behind := v1.center
	while Rect2i(v1.rect).has_point(behind) and game.map.in_bounds(behind):
		behind = v1.center + Vector2i((dir * (Vector2(behind - v1.center).length() + 1.0)).round())
	behind = v1.center + Vector2i((dir * (Vector2(behind - v1.center).length() + 3.0)).round())
	check(game.fog.is_explored_by(0, v1.center) and not game.fog.is_explored_by(0, behind) and game.fog.is_explored_by(1, behind), "each village has its own fog (the other's walls are known, nothing around them) [%s %s %s, behind %s, centers %s %s]" % [game.fog.is_explored_by(0, v1.center), game.fog.is_explored_by(0, behind), game.fog.is_explored_by(1, behind), behind, v0.center, v1.center])
	var their_start := v1.buildings().filter(func(b: Building) -> bool: return not Rect2i(v1.rect).has_point(b.tile) and not (b is StaticPiece))
	check(not their_start.is_empty() and their_start.all(func(b: Building) -> bool: return not game.fog.is_explored_by(0, b.tile)), "the client's starting farm and camp aren't in our fog (%d buildings)" % their_start.size())
	# The world (docs/world-design.md): the lobby's map, objects, unlocks.
	check(game.map.map_type == MAP_TYPE and game.map.seed_value == MAP_SEED and not game.world.map_objects.is_empty(), "the lobby's map type and seed are used (%s, %d, %d objects)" % [game.map.map_type, game.map.seed_value, game.world.map_objects.size()])
	var camp: MonsterCamp = null
	var ruin: RuinedTower = null
	var loot: Treasure = null
	for o in game.world.map_objects:
		if o is MonsterCamp and camp == null:
			camp = o
		elif o is RuinedTower and ruin == null:
			ruin = o
		elif o is Treasure and loot == null and o.guard() == null:
			loot = o
	check(camp != null and camp.alive().size() > 0 and ruin != null and loot != null, "the host runs the objects: a camp with its monsters, a ruin, a treasure")
	game.fog.reveal(Vector2(camp.tile), 2.5, v1.id)  # (the client's village finds the camp)
	game.unlock("summoner", v0, v0.hero)
	ruin.claim(v0)
	loot.mark_looted()
	game.world.remove_tree(_tree_near(game.map, v1.center))  # (as a forester does: the client should see it gone)
	v1.hero.max_hp = 5000.0
	v1.hero.hp = 5000.0
	var ordered := await wait_until(func() -> bool: return v1.hero.camp_target == camp, 60.0)
	check(ordered, "the client's order: its hero sets off to attack the camp")
	var recruited := await wait_until(func() -> bool: return v1.army.units.size() >= 1)
	check(recruited and v1.army.units[0].original_owner == v1 and v0.army.units.is_empty(), "the client's command recruits an archer in its own village")
	var caravan := await wait_until(func() -> bool: return v0.events.entries.any(func(e: Dictionary) -> bool: return str(e["text"]).begins_with("Caravan from %s arrived" % CLIENT_NAME)), 120.0)
	check(caravan, "the client's caravan arrives at the host's village")
	check(game.speed_index == 0, "the client couldn't change the speed")
	# Pause for a moment: the client should notice.
	game.command("set_speed", {"index": 3})
	await get_tree().process_frame
	check(game.hud._pause_gray.visible and game.hud._pause_gray.offset_top >= game.hud._topbar.get_global_rect().end.y - 0.5, "paused: our game turns grey, except the top bar")
	await seconds(3.0)
	game.command("set_speed", {"index": 0})
	var left := await wait_until(func() -> bool: return not Net.players.has(cid) or not Net.players[cid]["online"])
	check(left and v0.events.entries.any(func(e: Dictionary) -> bool: return e["text"] == "%s left the game" % CLIENT_NAME), "when the client leaves, its village stays and everyone is told")


## The map file the custom session plays: three villages on a 100x100 map.
static func custom_map() -> MapData:
	var g := MapGenerator.generate(77, 3, "temperate", 100)
	g.meta = {"name": "Net bot map", "origin": {"generator_seed": 77, "edited": false, "game_version": ""}}
	return MapJson.read(MapJson.write(g))["map"]


func _host_custom() -> void:
	check(Net.host(HOST_NAME, 0) == "" and Net.is_host(), "custom: hosting a lobby")
	var m := custom_map()
	Net.set_custom_map(m)
	check(Net.custom_map == m and Net.max_players() == 3 and int(Net.players[1]["slot"]) == 0, "a map file with three villages: at most 3 players, the host on village 1")
	var joined := await wait_until(func() -> bool: return _client_id() > 0)
	check(joined, "a client joins")
	if not joined:
		return
	var cid := _client_id()
	check(int(Net.players[cid]["slot"]) == 1, "the client gets the first free village (2)")
	Net.set_slot(cid, 2)
	check(int(Net.players[cid]["slot"]) == 2, "the host gives it village 3")
	Net.set_slot(cid, 0)
	check(int(Net.players[cid]["slot"]) == 0 and int(Net.players[1]["slot"]) == 2, "taking the host's village swaps the two")
	Net.set_slot(1, 0)
	check(int(Net.players[1]["slot"]) == 0 and int(Net.players[cid]["slot"]) == 2, "and back")
	var ready := await wait_until(func() -> bool: return Net.players.has(cid) and Net.players[cid]["ready"])
	check(ready and Net.can_start() and Net.start_game(), "it gets ready; the host starts")
	var loaded := await wait_until(func() -> bool: return Net.game != null and Net.players[cid]["loaded"])
	check(loaded, "the client loaded the level")
	if not loaded:
		return
	var game := Net.game
	check(game.villages.size() == 2 and game.villages[0].center == m.villages[0]["center"] and game.villages[1].center == m.villages[2]["center"], "two villages, on the map's villages 1 and 3")
	check(game.map.abandoned.size() == 1 and game.map.abandoned[0]["center"] == m.villages[1]["center"], "village 2 is nobody's")
	var ruins := game.world.buildings.filter(func(b: Building) -> bool: return b.has_meta("abandoned"))
	check(ruins.size() == 25 and ruins.all(func(b: Building) -> bool: return b.village == null), "it stands as ruins")
	await seconds(4.0)


func _client_custom() -> void:
	check(Net.discovery.start_listening() == "", "custom: listening")
	var found := await wait_until(func() -> bool: return Net.discovery.games().any(func(g: Dictionary) -> bool: return g["name"] == HOST_NAME), 30.0)
	check(found, "the host's game shows up")
	if not found:
		return
	var g: Dictionary = Net.discovery.games().filter(func(x: Dictionary) -> bool: return x["name"] == HOST_NAME)[0]
	check(g["max"] == 3, "it says 3 players at most (the map's villages)")
	check(Net.join("%s:%d" % [g["address"], g["port"]], CLIENT_NAME, 0) == "", "joining it")
	var got_map := await wait_until(func() -> bool: return Net.custom_map != null and Net.players.size() == 2)
	check(got_map and MapJson.map_name(Net.custom_map) == "Net bot map" and Net.custom_map.villages.size() == 3, "the lobby shows us the host's map file (its name, three villages)")
	var me := Net.my_id()
	var mine_slot := await wait_until(func() -> bool: return int(Net.players[me].get("slot", -1)) == 2, 20.0)
	check(mine_slot, "and that we play its village 3")
	Net.set_ready(true)
	var started := await wait_until(func() -> bool: return Net.game != null and Net.game.is_client)
	check(started, "the host starts")
	if not started:
		return
	var game := Net.game
	var mine := game.player_village
	var want := custom_map()
	await wait_until(func() -> bool: return mine.buildings().size() >= 27)
	check(mine.id == 1 and mine.center == want.villages[2]["center"], "we play village 3 of the map")
	check(game.map.abandoned.size() == 1 and game.map.meta.get("name") == "Net bot map", "we got the host's map, village 2 abandoned")
	var ruins := await wait_until(func() -> bool: return game.world.buildings.filter(func(b: Building) -> bool: return b.has_meta("abandoned")).size() == 25, 30.0)
	check(ruins, "its ruins reach us, nobody's")
	var huts := game.world.buildings.filter(func(b: Building) -> bool: return b.has_meta("abandoned") and b is Hut)
	check(huts.size() == 9 and huts.all(func(h: Hut) -> bool: return h.village == null and not h.is_intact()), "every hut of it a ruin")
	check(game.building_info(huts[0])["actions"].is_empty(), "and no actions on them")


# --- resuming a saved co-op game ---------------------------------------------------------------

## A game of two villages made here (no network) and saved: village 1 has an
## extra watchtower, village 2 a farm more. Returns the save's path.
func _make_save() -> String:
	SaveGame.dir_override = SAVE_DIR
	var game: Game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = 5
	game.test_villages = 2
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	for v in game.villages:
		v.economy.add("materials", 500)
		var kind := "tower" if v.id == 0 else "farm"
		for r in range(4, 12):
			var t := v.center + Vector2i(r, r % 3)
			if v.construction.placement_error(kind, t) == "":
				v.construction.complete(v.construction.place(kind, t))
				break
	var h := SaveGame.header(game, "Net bot co-op", false)
	var path := SaveGame.path_for("Net bot co-op")
	var err := SaveGame.write(path, h, SaveGame.capture(game))
	check(err == "" and h["coop"], "a co-op game of two villages is saved (%s)" % err)
	game.queue_free()
	await get_tree().process_frame
	return path


func _host_resume() -> void:
	var path := await _make_save()
	var saved: Array = SaveGame.read(path, false)["header"]["villages"]
	check(Net.host(HOST_NAME, 0) == "" and Net.is_host(), "resume: hosting a lobby")
	check(Net.set_resume(path) == "" and Net.resume_villages() == 2 and Net.max_players() == 2, "the host picks the save: two villages, two players at most")
	check(not Net.can_start(), "alone it can't start: the save needs two players")
	var joined := await wait_until(func() -> bool: return _client_id() > 0)
	check(joined, "a client joins")
	if not joined:
		return
	var cid := _client_id()
	check(int(Net.players[1]["slot"]) == 0 and int(Net.players[cid]["slot"]) == 1, "the players get the saved villages in join order")
	check(Net.join_decision(Net.PROTOCOL, "Thirdhold") == "The game is full", "a third player is turned away")
	Net.set_slot(cid, 0)
	check(int(Net.players[cid]["slot"]) == 0 and int(Net.players[1]["slot"]) == 1, "the host gives the client village 1: they swap")
	var ready := await wait_until(func() -> bool: return Net.players.has(cid) and Net.players[cid]["ready"])
	check(ready and Net.can_start() and Net.start_game(), "it gets ready; the host starts")
	var loaded := await wait_until(func() -> bool: return Net.game != null and Net.players[cid]["loaded"])
	check(loaded, "the client loaded the level")
	if not loaded:
		return
	var game := Net.game
	var mine := game.player_village
	check(game.loaded and mine.id == 1 and game.host_village() == mine and game.is_host_player(), "the host plays saved village 2 and runs the game")
	check(mine.village_name == HOST_NAME and game.villages[0].village_name == CLIENT_NAME, "each village takes its new player's name")
	check(mine.color == Color(str(saved[1]["color"])) and game.villages[0].color == Color(str(saved[0]["color"])), "and keeps its saved colour")
	check(mine.buildings().any(func(b: Building) -> bool: return b is Farm and b.complete) and game.villages[0].buildings().filter(func(b: Building) -> bool: return b.kind == "tower").size() == 1,
		"the saved buildings stand in their villages")
	var lines: Array = mine.events.entries.map(func(e: Dictionary) -> String: return str(e["text"]))
	check(lines.has("Village %s is now played as %s" % [saved[1]["name"], HOST_NAME]), "the log says who plays which village now")
	check(game.camera.position.distance_to(Iso.tile_to_world(mine.center)) < 1.0, "the host's view starts on its village")
	await seconds(4.0)
	SaveGame.delete(path)
	SaveGame.dir_override = ""


func _client_resume() -> void:
	check(Net.discovery.start_listening() == "", "resume: listening")
	var found := await wait_until(func() -> bool: return Net.discovery.games().any(func(g: Dictionary) -> bool: return g["name"] == HOST_NAME and g["max"] == 2), 60.0)
	check(found, "the host's game shows up, for two players")
	if not found:
		return
	var g: Dictionary = Net.discovery.games().filter(func(x: Dictionary) -> bool: return x["name"] == HOST_NAME)[0]
	check(Net.join("%s:%d" % [g["address"], g["port"]], CLIENT_NAME, 0) == "", "joining it")
	var got := await wait_until(func() -> bool: return not Net.resume.is_empty() and Net.resume_map != null and Net.players.size() == 2)
	check(got and Net.resume_villages() == 2 and str(Net.resume.get("name", "")) == "Net bot co-op", "the lobby shows us the saved game")
	var saved: Array = Net.resume.get("villages", [])
	var me := Net.my_id()
	var mine_slot := await wait_until(func() -> bool: return int(Net.players[me].get("slot", -1)) == 0, 20.0)
	check(mine_slot, "the host gives us the save's village 1")
	Net.set_ready(true)
	var started := await wait_until(func() -> bool: return Net.game != null and Net.game.is_client)
	check(started, "the host starts")
	if not started:
		return
	var game := Net.game
	var mine := game.player_village
	check(mine.id == 0 and mine.village_name == CLIENT_NAME and mine.color == Color(str(saved[0]["color"])), "we play village 1 under our name, in its saved colour")
	var tower := await wait_until(func() -> bool: return mine.buildings().filter(func(b: Building) -> bool: return b.kind == "tower").size() == 1, 30.0)
	check(tower, "with its saved watchtower")
	var lines: Array = mine.events.entries.map(func(e: Dictionary) -> String: return str(e["text"]))
	check(lines.has("Village %s is now played as %s" % [saved[0]["name"], CLIENT_NAME]), "the log says who plays which village now")
	check(game.camera.position.distance_to(Iso.tile_to_world(mine.center)) < 1.0, "our view starts on our village")


## The tree nearest `c` on `map` (the same tile on host and client: the
## host's map at the start, the client's generated again).
func _tree_near(map: MapData, c: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for t: Vector2i in map.props:
		var d := Vector2(t).distance_squared_to(Vector2(c)) + map.index(t) * 1e-6
		if map.is_forest(t) and d < best_d:
			best_d = d
			best = t
	return best


# --- client --------------------------------------------------------------------------------

func _client() -> void:
	var err := Net.discovery.start_listening()
	check(err == "", "listening for games on the network %s" % err)
	var found := await wait_until(func() -> bool: return Net.discovery.games().any(func(g: Dictionary) -> bool: return g["name"] == HOST_NAME), 30.0)
	check(found, "the host's game shows up by LAN discovery")
	if not found:
		return
	var g: Dictionary = Net.discovery.games().filter(func(x: Dictionary) -> bool: return x["name"] == HOST_NAME)[0]
	check(g["players"] == 1 and g["max"] == Config.MAX_PLAYERS and g["proto"] == Net.PROTOCOL, "with its player count and version")
	var messages: Array[String] = []
	Net.lobby_message.connect(func(t: String) -> void: messages.append(t))
	check(Net.join("%s:%d" % [g["address"], g["port"]], CLIENT_NAME, 0) == "", "joining it")
	var in_lobby := await wait_until(func() -> bool: return Net.players.size() == 2)
	check(in_lobby, "in the lobby with the host")
	if not in_lobby:
		return
	var me := Net.my_id()
	check(int(Net.players[me]["color"]) != 0 and messages.any(func(t: String) -> bool: return "colour" in t), "the host's colour was taken: we got another one, and were told")
	Net.set_identity(HOST_NAME, 3)
	var told := await wait_until(func() -> bool: return messages.any(func(t: String) -> bool: return "taken" in t and "name" in t), 10.0)
	check(told and Net.players[me]["name"] == CLIENT_NAME, "the host's village name can't be taken")
	var lobby_map := await wait_until(func() -> bool: return Net.map_type == MAP_TYPE and Net.map_seed == MAP_SEED, 20.0)
	check(lobby_map, "the host's map settings show in our lobby (%s, %d)" % [Net.map_type, Net.map_seed])
	Net.set_ready(true)
	var started := await wait_until(func() -> bool: return Net.game != null and Net.game.is_client)
	check(started, "the host starts: we get the map and the level")
	if not started:
		return
	var game := Net.game
	var mine := game.player_village
	var synced := await wait_until(func() -> bool: return mine.buildings().size() >= 27 and mine.population.count() == Config.START_CIVILIANS.size() and mine.hero.nid > 0)
	check(synced, "our village arrives from the host: %d buildings, %d villagers, the hero" % [mine.buildings().size(), mine.population.count()])
	check(mine.id == 1 and mine.village_name == CLIENT_NAME and game.villages[0].village_name == HOST_NAME, "we play the second village")
	# The world: the host's map exactly, its objects' states, the unlocks.
	var same := MapGenerator.generate(MAP_SEED, 2, MAP_TYPE)
	var felled := _tree_near(same, mine.center)
	var expect := same.terrain.duplicate()
	expect[game.map.index(felled)] = game.map.terrain[game.map.index(felled)]  # (the host fells it: checked below)
	check(game.map.map_type == MAP_TYPE and game.map.terrain == expect and game.map.zones == same.zones and game.map.objects.size() == same.objects.size() and game.world.map_objects.size() == same.objects.size(), "we get the host's map: %s, seed %d, the same terrain, zones and %d objects" % [game.map.map_type, game.map.seed_value, game.world.map_objects.size()])
	var unl := await wait_until(func() -> bool: return game.is_unlocked("summoner"), 30.0)
	check(unl, "an unlock on the host reaches us (the summoner)")
	var states := await wait_until(func() -> bool:
		return game.world.map_objects.any(func(o: MapObject) -> bool: return o is RuinedTower and o.village == game.villages[0]) and game.world.map_objects.any(func(o: MapObject) -> bool: return o is Treasure and o.looted), 30.0)
	check(states, "object states reach us: the host's claimed ruin, a looted treasure")
	var camp: MonsterCamp = null
	for o in game.world.map_objects:
		if o is MonsterCamp:
			camp = o
			break
	var found_camp := await wait_until(func() -> bool: return camp != null and game.fog.is_explored_by(mine.id, camp.tile), 30.0)
	check(found_camp and camp.info()["actions"].any(func(a: Dictionary) -> bool: return a["label"] == "Attack with the hero"), "a camp we found offers Attack with the hero")
	var gone := await wait_until(func() -> bool: return not game.world.is_tree(felled) and not game.world._props.has(felled), 30.0)
	check(gone and game.world.pathing.is_walkable(felled), "a tree the host fells is gone for us too (%s)" % felled)
	game.command("attack_camp", {"camp": camp.nid})
	check(is_equal_approx(mine.economy.amount("gold"), Config.START_RESOURCES["gold"]), "with our own starting gold")
	var host_huts := game.villages[0].huts()
	var host_civs := get_tree().get_nodes_in_group("replicated").filter(func(n) -> bool: return n is Civilian and not (n is Hero) and n.village == game.villages[0])
	check(host_huts.size() == 9 and host_civs.is_empty(), "the host's huts are public, its villagers stay unseen")
	check(game.fog.is_explored_by(1, mine.center) and game.fog.is_explored_by(1, game.villages[0].center) and not game.fog.is_explored_by(1, game.villages[0].center + Vector2i(5, 0)), "our fog: our land, and only the walls of the other village")
	check(game.fog.local == mine.id and game.fog.map.explored == game.fog.explored_of[mine.id] and game.fog.map.explored[game.map.index(mine.center + Vector2i(4, 0))] == 1, "the fog drawn is our village's, our start area included")
	var props: Dictionary = game.world._props
	var wrong := props.keys().filter(func(t: Vector2i) -> bool: return props[t].visible != (game.fog.map.explored[game.map.index(t)] == 1))
	check(wrong.is_empty(), "trees show exactly on our explored tiles (%d wrong of %d)" % [wrong.size(), props.size()])
	game.command("recruit_unit", {"kind": "archer"})
	var got := await wait_until(func() -> bool: return mine.army.units.size() == 1)
	check(got and is_equal_approx(mine.economy.amount("gold"), Config.START_RESOURCES["gold"] - Config.MILITARY["archer"]["cost"]["gold"]), "a command goes to the host; the new archer and the gold come back")
	var refused := []
	Net.command_refused.connect(func(t: String, e: String) -> void: refused.append([t, e]))
	game.command("set_speed", {"index": 1})
	var no := await wait_until(func() -> bool: return refused.any(func(r: Array) -> bool: return r[0] == "set_speed" and r[1] == "The host sets the speed"), 10.0)
	check(no and game.hud._speed_button.disabled, "only the host sets the speed (our speed button is off)")
	game.command("send_caravan", {"target": 0, "gold": 50})
	var paid := await wait_until(func() -> bool: return mine.economy.amount("gold") <= Config.START_RESOURCES["gold"] - Config.MILITARY["archer"]["cost"]["gold"] - 50 + 0.5, 10.0)
	check(paid, "sending a caravan to the host's village")
	game.hud.open_settings()
	check(game.hud._settings.visible and not get_tree().paused and not game.hud._gray.visible and game.hud._settings_title_button.text == "Leave game", "our settings don't pause the game (it keeps running)")
	game.hud.close_settings()
	var saw_pause := await wait_until(func() -> bool: return game.hud._paused_banner != null and game.hud._paused_banner.visible, 150.0)
	check(saw_pause, "when the host pauses, we see it")
	await seconds(1.0)
	var hud: Hud = game.hud
	check(hud._pause_gray.visible and hud._pause_gray.offset_top >= hud._topbar.get_global_rect().end.y - 0.5 and hud._paused_banner.get_index() > hud._pause_gray.get_index(), "while paused the game is grey below the top bar (top bar and banner stay in colour)")
	# The host is gone: one way out, not two.
	hud.show_session_ended("The host left the game")
	await get_tree().process_frame
	var outs := hud._overlay.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree())
	check(outs.size() == 1 and outs[0].text == "Main menu" and not hud._pause_gray.visible, "the session-ended dialog has a single Main menu button (%s)" % str(outs.map(func(b: Button) -> String: return b.text)))
