extends Node
## Autoload "Net": the LAN multiplayer session (docs/multiplayer-design.md §3, §8).
##
## Host-authoritative: the host runs the only simulation. Clients send
## commands (the same dictionaries as Game.command) and draw what the host's
## Replicator sends them. Everything goes through Godot's MultiplayerPeer, so
## a WebSocket / WebRTC transport can replace ENet later without touching the
## game.
##
## Lobby: players pick a unique village name and colour, tick "ready", and the
## host starts. The host generates the map and sends it (not a seed) to
## everyone. No late joining: once started, only a player who dropped can come
## back, by joining with the same village name.

signal lobby_changed
## Something the multiplayer screen should show (name taken, version mismatch...).
signal lobby_message(text: String)
## The session is over (host left, connection lost, refused); back to the title.
signal session_ended(reason: String)
## A command this client sent was refused by the host.
signal command_refused(type: String, error: String)

enum Role { NONE, HOST, CLIENT }

const GAME_ID := "velirons-outpost"
const PROTOCOL := 2
const GAME_PORT := 47111
const DISCOVERY_PORT := 47110
## The ports in use (tests pick their own: --port=N, discovery on N - 1).
var game_port := GAME_PORT
var discovery_port := DISCOVERY_PORT
const GAME_SCENE := "res://scenes/main.tscn"
## ENet peer timeout (ms): generous, because host and clients each stop
## answering for a few seconds while the level is built / loaded.
const TIMEOUT_MIN := 15000
const TIMEOUT_MAX := 60000
const TITLE_SCENE := "res://scenes/title.tscn"

var role := Role.NONE
## peer id -> {"name", "color", "ready", "village", "slot", "online", "loaded"}
var players: Dictionary = {}
var difficulty := 1  # Settings.Difficulty
## The host's choice of map type (or "random") and seed (0: random).
var map_type := "temperate"
var map_seed := 0
## A map from a file instead of a generated one (docs/map-editor-design.md §8):
## the host's pick, which every client gets a copy of in the lobby (for its
## name and preview). Each player then has a village of it ("slot" in
## `players`), assigned by the host.
var custom_map: MapData = null
## A co-op save to resume instead (docs/save-design.md §6): the host's pick.
## Everyone has its header (the villages' names and colours, the wave) and
## map (`resume_map`, for the preview); each player has one of its villages
## ("slot" in `players`), assigned by the host. The lobby needs exactly as
## many players as it has villages.
var resume: Dictionary = {}
var resume_map: MapData = null
## Host: the save's body, for the level scene (Game takes it).
var resume_body: Dictionary = {}
var _resume_path := ""
var in_game := false
## Set for the level scene: {"seed", "villages": [{"name", "color", "peer"}], "difficulty",
## "local", "map_type"}. (A client before the game: {"name", "color"}.)
var setup: Dictionary = {}
## Client: the map the host sent (MapData), for the level scene.
var map: MapData
## The running game (set by Game on the host and on clients).
var game: Game
var discovery: LanDiscovery
var _peer: MultiplayerPeer
var _last_address := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			game_port = int(a.trim_prefix("--port="))
			discovery_port = game_port - 1
	discovery = LanDiscovery.new()
	discovery.name = "Discovery"
	add_child(discovery)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return role != Role.NONE


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


# --- hosting and joining ---------------------------------------------------------------

## Opens a lobby on this device. Returns "" or why it failed.
func host(p_name: String, color: int) -> String:
	var err := Settings.name_error(p_name)
	if err != "":
		return err
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(game_port, Config.MAX_PLAYERS - 1) != OK:
		return "Can't host: port %d is in use" % game_port
	_peer = peer
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	in_game = false
	difficulty = Settings.difficulty
	map_type = Settings.map_type
	map_seed = Settings.map_seed
	players = {1: {"name": p_name.strip_edges(), "color": color, "ready": true, "village": 0, "slot": 0, "online": true, "loaded": true}}
	custom_map = null
	discovery.start_announcing(_announcement)
	lobby_changed.emit()
	return ""


## Connects to a host at `address`; the lobby follows when it accepts.
func join(address: String, p_name: String, color: int) -> String:
	var err := Settings.name_error(p_name)
	if err != "":
		return err
	leave()
	var parts := address.strip_edges().split(":")
	var port := int(parts[1]) if parts.size() > 1 else game_port
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(parts[0], port) != OK:
		return "Can't connect to %s" % address
	_peer = peer
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	in_game = false
	players = {}
	setup = {"name": p_name.strip_edges(), "color": color}
	_last_address = address
	lobby_changed.emit()
	return ""


## Leaves the session (and the game, if one is running).
func leave() -> void:
	discovery.stop_announcing()
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	role = Role.NONE
	players = {}
	in_game = false
	game = null
	custom_map = null
	resume = {}
	resume_map = null
	resume_body = {}
	_resume_path = ""
	lobby_changed.emit()


func _announcement() -> Dictionary:
	return {
		"game": GAME_ID, "proto": PROTOCOL, "name": players[1]["name"] if players.has(1) else "?",
		"players": players.size(), "max": max_players(), "port": game_port,
		"difficulty": Settings.NAMES[difficulty],
	}


func _patient(id: int) -> void:
	if _peer is ENetMultiplayerPeer:
		var pp := (_peer as ENetMultiplayerPeer).get_peer(id)
		if pp:
			pp.set_timeout(32, TIMEOUT_MIN, TIMEOUT_MAX)


func _on_connected() -> void:
	_patient(1)
	_hello.rpc_id(1, PROTOCOL, setup.get("name", ""), int(setup.get("color", 0)))


func _on_connection_failed() -> void:
	leave()
	lobby_message.emit("Couldn't reach the host")


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave.call_deferred()
	session_ended.emit("The host left the game" if was_in_game else "The host closed the lobby")


func _on_peer_connected(id: int) -> void:
	if is_host():
		_patient(id)  # (the peer introduces itself with _hello)


func _on_peer_disconnected(id: int) -> void:
	if not is_host() or not players.has(id):
		return
	if in_game:
		players[id]["online"] = false
		if game:
			game.log_all(EventLog.Level.INFO, "%s left the game" % players[id]["name"])
	else:
		players.erase(id)
		_broadcast_lobby()


# --- lobby (host decides) -------------------------------------------------------------------

## What the host does with a player who says hello: "" = welcome, else why not.
## (A player rejoining with the name of one who dropped is let back in.)
func join_decision(proto: int, p_name: String) -> String:
	if proto != PROTOCOL:
		return "Different game version (host %d, you %d)" % [PROTOCOL, proto]
	var err := Settings.name_error(p_name)
	if err != "":
		return err
	var taken := _player_named(p_name)
	if in_game:
		if taken >= 0 and not players[taken]["online"]:
			return ""  # rejoin
		return "The game has already started"
	if taken >= 0:
		return "The village name '%s' is taken" % p_name.strip_edges()
	if players.size() >= max_players():
		return "The game is full"
	return ""


## How many can play: Config.MAX_PLAYERS, a custom map's villages, or a save's.
func max_players() -> int:
	if not resume.is_empty():
		return resume_villages()
	return custom_map.villages.size() if custom_map else Config.MAX_PLAYERS


## The villages of the save to resume (0: none).
func resume_villages() -> int:
	return (resume.get("villages", []) as Array).size()


## Villages players are assigned to (a map file's, or a save's; 0: none: a generated map).
func slot_count() -> int:
	if not resume.is_empty():
		return resume_villages()
	return custom_map.villages.size() if custom_map else 0


func _player_named(p_name: String) -> int:
	for id in players:
		if str(players[id]["name"]).to_lower() == p_name.strip_edges().to_lower():
			return id
	return -1


func _free_color(wanted: int, except: int = -1) -> int:
	var used := {}
	for id in players:
		if id != except:
			used[int(players[id]["color"])] = true
	if not used.has(wanted):
		return wanted
	for c in Config.VILLAGE_COLORS.size():
		if not used.has(c):
			return c
	return wanted


@rpc("any_peer", "reliable")
func _hello(proto: int, p_name: String, color: int) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	var why := join_decision(proto, p_name)
	if why != "":
		_refused.rpc_id(id, why)
		_kick_later(id)
		return
	var old := _player_named(p_name)
	if in_game and old >= 0:  # a dropped player comes back
		var p: Dictionary = players[old]
		players.erase(old)
		p["online"] = true
		p["loaded"] = false
		players[id] = p
		game.log_all(EventLog.Level.INFO, "%s is back" % p["name"])
		_send_start(id)
		return
	var c := _free_color(clampi(color, 0, Config.VILLAGE_COLORS.size() - 1))
	players[id] = {"name": p_name.strip_edges(), "color": c, "ready": false, "village": -1, "slot": _free_slot(), "online": true, "loaded": false}
	if c != color:
		_message.rpc_id(id, "That colour was taken: you got another one")
	if custom_map:
		_lobby_map.rpc_id(id, custom_map.to_bytes())
	if not resume.is_empty():
		_lobby_resume.rpc_id(id, resume, resume_map.to_bytes())
	_broadcast_lobby()


func _kick_later(id: int) -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	if _peer is ENetMultiplayerPeer and is_host():
		(_peer as ENetMultiplayerPeer).disconnect_peer(id)


## Lobby: change your village name / colour (before ticking ready).
func set_identity(p_name: String, color: int) -> void:
	if is_host():
		_apply_identity(1, p_name, color)
	elif is_client():
		_set_identity.rpc_id(1, p_name, color)


@rpc("any_peer", "reliable")
func _set_identity(p_name: String, color: int) -> void:
	if is_host():
		_apply_identity(multiplayer.get_remote_sender_id(), p_name, color)


func _apply_identity(id: int, p_name: String, color: int) -> void:
	if not players.has(id) or in_game:
		return
	var err := Settings.name_error(p_name)
	var other := _player_named(p_name)
	if err == "" and other >= 0 and other != id:
		err = "The village name '%s' is taken" % p_name.strip_edges()
	if err != "":
		_tell(id, err)
		return
	players[id]["name"] = p_name.strip_edges()
	var c := _free_color(clampi(color, 0, Config.VILLAGE_COLORS.size() - 1), id)
	if c != color:
		_tell(id, "That colour is taken")
	players[id]["color"] = c
	_broadcast_lobby()


func set_ready(v: bool) -> void:
	if is_host():
		return  # the host starts the game instead
	_set_ready.rpc_id(1, v)


@rpc("any_peer", "reliable")
func _set_ready(v: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and players.has(id) and not in_game:
		players[id]["ready"] = v
		_broadcast_lobby()


func set_difficulty(d: int) -> void:
	if is_host() and not in_game:
		difficulty = d
		Settings.difficulty = d
		_broadcast_lobby()


func set_map(p_type: String, p_seed: int) -> void:
	if is_host() and not in_game:
		if not resume.is_empty():
			set_resume("")
		if custom_map:
			set_custom_map(null)
		map_type = p_type
		map_seed = p_seed
		Settings.map_type = p_type
		Settings.map_seed = p_seed
		_broadcast_lobby()


## Host: play the map `m` from a file (null: a generated map again). Every
## player gets a village of it (in join order); clients get a copy.
func set_custom_map(m: MapData) -> void:
	if not is_host() or in_game:
		return
	if m != null and players.size() > m.villages.size():
		_tell(1, "That map has room for %d players, the lobby has %d" % [m.villages.size(), players.size()])
		return
	if m != null and not resume.is_empty():
		set_resume("")
	custom_map = m
	var ids := players.keys()
	ids.sort()
	for i in ids.size():
		players[ids[i]]["slot"] = i
	_lobby_map.rpc(m.to_bytes() if m else PackedByteArray())
	_broadcast_lobby()


@rpc("authority", "reliable")
func _lobby_map(bytes: PackedByteArray) -> void:
	custom_map = MapData.from_bytes(bytes) if not bytes.is_empty() else null
	lobby_changed.emit()


## Host: resume the co-op save at `path` ("": none, a new game again). Each
## player gets one of its villages: the one with their name if there is one,
## else the free ones in join order. Returns "" or why not.
func set_resume(path: String) -> String:
	if not is_host() or in_game:
		return "Only the host picks the game"
	if path == "":
		resume = {}
		resume_map = null
		_resume_path = ""
		_lobby_resume.rpc({}, PackedByteArray())
		_broadcast_lobby()
		return ""
	var r := SaveGame.read(path)
	if r["error"] != "":
		return str(r["error"])
	var h: Dictionary = r["header"]
	var n := (h.get("villages", []) as Array).size()
	if n < 2:
		return "That isn't a co-op save"
	if players.size() > n:
		return "That save has %d villages, the lobby has %d players" % [n, players.size()]
	if custom_map:
		custom_map = null
		_lobby_map.rpc(PackedByteArray())
	resume = h
	resume_map = SaveGame.saved_map(r["body"])
	_resume_path = path
	difficulty = int(h.get("difficulty", difficulty))
	Settings.difficulty = difficulty as Settings.Difficulty
	# Villages by name first (the same players as before), then in join order.
	var ids := players.keys()
	ids.sort()
	for id in ids:
		players[id]["slot"] = -1
	for id in ids:
		for s in n:
			if str(h["villages"][s]["name"]).to_lower() == str(players[id]["name"]).to_lower():
				players[id]["slot"] = s
	for id in ids:
		if int(players[id]["slot"]) < 0:
			players[id]["slot"] = _free_slot()
	_lobby_resume.rpc(resume, resume_map.to_bytes())
	_broadcast_lobby()
	return ""


@rpc("authority", "reliable")
func _lobby_resume(header: Dictionary, map_bytes: PackedByteArray) -> void:
	resume = header
	resume_map = MapData.from_bytes(map_bytes) if not map_bytes.is_empty() else null
	lobby_changed.emit()


## Host: player `id` plays village `slot` of the custom map or the save
## (whoever had it swaps with them).
func set_slot(id: int, slot: int) -> void:
	if not is_host() or in_game or slot_count() == 0 or not players.has(id) or slot < 0 or slot >= slot_count():
		return
	var old := int(players[id].get("slot", -1))
	for other in players:
		if other != id and int(players[other].get("slot", -1)) == slot:
			players[other]["slot"] = old
	players[id]["slot"] = slot
	_broadcast_lobby()


## The first village of the custom map nobody has yet (-1: none, or no custom map).
func _free_slot() -> int:
	for s in slot_count():
		if not players.values().any(func(p: Dictionary) -> bool: return int(p.get("slot", -1)) == s):
			return s
	return -1


func can_start() -> bool:
	if not is_host() or in_game or not players.values().all(func(p: Dictionary) -> bool: return p["ready"]):
		return false
	if not resume.is_empty() and players.size() != resume_villages():
		return false
	if slot_count() > 0:
		var slots := {}
		for p in players.values():
			var s := int(p.get("slot", -1))
			if s < 0 or s >= slot_count() or slots.has(s):
				return false
			slots[s] = true
	return true


func _tell(id: int, text: String) -> void:
	if id == 1:
		lobby_message.emit(text)
	else:
		_message.rpc_id(id, text)


func _broadcast_lobby() -> void:
	lobby_changed.emit()
	if is_host():
		_lobby_state.rpc(players, difficulty, map_type, map_seed)


@rpc("authority", "reliable")
func _lobby_state(p_players: Dictionary, p_difficulty: int, p_map_type: String = "temperate", p_seed: int = 0) -> void:
	players = p_players
	difficulty = p_difficulty
	Settings.difficulty = p_difficulty
	map_type = p_map_type
	map_seed = p_seed
	lobby_changed.emit()


@rpc("authority", "reliable")
func _message(text: String) -> void:
	lobby_message.emit(text)


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	leave.call_deferred()
	lobby_message.emit(reason)


# --- starting the game ---------------------------------------------------------------------

## Host: everyone is ready. Villages go in join order (the host's is 0).
func start_game() -> bool:
	if not can_start():
		return false
	if not resume.is_empty():
		return _start_resumed()
	in_game = true
	discovery.stop_announcing()
	var ids := players.keys()
	ids.sort()
	var villages: Array = []
	for i in ids.size():
		players[ids[i]]["village"] = i
		villages.append({"name": players[ids[i]]["name"], "color": players[ids[i]]["color"], "peer": ids[i], "slot": int(players[ids[i]].get("slot", i))})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := map_seed if map_seed != 0 else rng.randi()
	setup = {"seed": s, "map_type": Settings.resolve_map_type(map_type, s), "villages": villages, "difficulty": difficulty, "local": 0}
	if custom_map:
		setup["seed"] = custom_map.seed_value
		setup["map_type"] = custom_map.map_type
		setup["map_name"] = MapJson.map_name(custom_map)
	Settings.difficulty = difficulty
	get_tree().change_scene_to_file(GAME_SCENE)
	return true


## Host: the save goes on with these players (docs/save-design.md §6.2):
## village i of the save is played by whoever has slot i, under their name,
## in the save's colour.
func _start_resumed() -> bool:
	var r := SaveGame.read(_resume_path)
	if r["error"] != "":
		_tell(1, str(r["error"]))
		return false
	in_game = true
	discovery.stop_announcing()
	resume_body = r["body"]
	var saved: Array = resume["villages"]
	var villages: Array = []
	for s in saved.size():
		for id in players:
			if int(players[id]["slot"]) == s:
				players[id]["village"] = s
				var col := Config.VILLAGE_COLORS.find(Color(str(saved[s]["color"])))
				villages.append({"name": players[id]["name"], "color": col if col >= 0 else s % Config.VILLAGE_COLORS.size(), "peer": id, "slot": s})
	var mine := int(players[1]["village"])
	setup = {"seed": int(resume.get("seed", 0)), "map_type": str(resume.get("map_type", "temperate")), "villages": villages,
		"difficulty": difficulty, "local": mine, "host": mine, "resumed": true}
	if resume.has("map_name"):
		setup["map_name"] = resume["map_name"]
	Settings.difficulty = difficulty as Settings.Difficulty
	get_tree().change_scene_to_file(GAME_SCENE)
	return true


## Host: the level is built (called by Game). Sends everyone the map.
func host_game_ready(p_game: Game) -> void:
	game = p_game
	for id in players:
		if id != 1 and players[id]["online"]:
			_send_start(id)


func _send_start(id: int) -> void:
	var s := setup.duplicate(true)
	s["local"] = players[id]["village"]
	_start.rpc_id(id, s, game.map.to_bytes())


@rpc("authority", "reliable")
func _start(p_setup: Dictionary, map_bytes: PackedByteArray) -> void:
	setup = p_setup
	map = MapData.from_bytes(map_bytes)
	in_game = true
	Settings.difficulty = int(setup.get("difficulty", 1))
	get_tree().change_scene_to_file(GAME_SCENE)


## Client: the level is built; ask the host for the full picture.
func client_game_ready(p_game: Game) -> void:
	game = p_game
	_loaded.rpc_id(1)


@rpc("any_peer", "reliable")
func _loaded() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and players.has(id) and game and game.replicator:
		players[id]["loaded"] = true
		game.replicator.reset_peer(id)


## The village a peer plays (host side).
func village_of_peer(id: int) -> Village:
	if game == null or not players.has(id):
		return null
	var vid: int = players[id]["village"]
	return game.villages[vid] if vid >= 0 and vid < game.villages.size() else null


## Loaded, connected clients (host side).
func client_peers() -> Array[int]:
	var out: Array[int] = []
	for id in players:
		if id != 1 and players[id]["online"] and players[id]["loaded"]:
			out.append(id)
	return out


# --- in the game: commands up, snapshots down -------------------------------------------------

## Client: send a player action to the host.
func send_command(type: String, args: Dictionary) -> void:
	_command.rpc_id(1, type, args)


@rpc("any_peer", "reliable")
func _command(type: String, args: Dictionary) -> void:
	if not is_host() or game == null:
		return
	var id := multiplayer.get_remote_sender_id()
	var v := village_of_peer(id)
	if v == null:
		return
	var r := game.commands.submit(v, type, args)
	if not r["ok"]:
		_command_result.rpc_id(id, type, r["error"])


@rpc("authority", "reliable")
func _command_result(type: String, error: String) -> void:
	command_refused.emit(type, error)


## Host -> one client: what it may know now (see Replicator).
func send_snapshot(id: int, data: Dictionary) -> void:
	_snapshot.rpc_id(id, data)


@rpc("authority", "reliable")
func _snapshot(data: Dictionary) -> void:
	if game and game.replicator:
		game.replicator.apply(data)


# --- statistics (docs/statistics-design.md) ----------------------------------------------------

## Client: ask the host for the statistics (the screen is open).
func request_stats() -> void:
	_stats_request.rpc_id(1)


@rpc("any_peer", "reliable")
func _stats_request() -> void:
	if not is_host() or game == null or game.stats == null:
		return
	_stats_data.rpc_id(multiplayer.get_remote_sender_id(), game.stats.to_net())


## Host -> every client: the final numbers at game over.
func broadcast_stats(data: Dictionary) -> void:
	for id in client_peers():
		_stats_data.rpc_id(id, data)


@rpc("authority", "reliable")
func _stats_data(data: Dictionary) -> void:
	if game and game.stats:
		game.stats.from_net(data)
