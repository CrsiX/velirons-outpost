class_name LanDiscovery
extends Node
## Finding games on the local network (docs/multiplayer-design.md §8.2).
## A host announces itself once a second by UDP broadcast (and to 127.0.0.1,
## so a game on the same machine is found too); clients listen and list every
## host heard in the last HOST_TIMEOUT seconds. Keyed by address and port.
## This is the LAN implementation of "finding games"; a lobby-server finder can
## offer the same `games()` / `games_changed` later (web version).

signal games_changed

const ANNOUNCE_INTERVAL := 1.0
const HOST_TIMEOUT := 3.0

## Interface name prefixes whose addresses no other device nearby can reach:
## Android's mobile data (a carrier address), container and VM bridges
## (Docker, LXC/LXD, libvirt, VirtualBox, VMware) and VPN tunnels.
const NOT_LAN: Array[String] = ["rmnet", "docker", "br-", "veth", "lxcbr", "lxdbr", "virbr", "vboxnet", "vmnet", "tun", "tap", "wg", "tailscale", "zt"]

var _announce: PacketPeerUDP
var _listen: PacketPeerUDP
var _payload: Callable  # host: returns the announcement Dictionary
var _timer := 0.0
## "ip:port" -> {"address", "port", "name", "players", "max", "difficulty", "proto", "seen"}
var _games: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Host: start announcing; `payload` builds the announcement each time.
func start_announcing(payload: Callable) -> void:
	stop_announcing()
	_payload = payload
	_announce = PacketPeerUDP.new()
	_announce.set_broadcast_enabled(true)
	_timer = 0.0


func stop_announcing() -> void:
	if _announce:
		_announce.close()
	_announce = null


## Client: start listening for announcements. Returns an error text or "".
func start_listening() -> String:
	stop_listening()
	_listen = PacketPeerUDP.new()
	var err := _listen.bind(Net.discovery_port)
	if err != OK:
		_listen = null
		return "Can't listen for games on this device (port %d busy)" % Net.discovery_port
	return ""


func stop_listening() -> void:
	if _listen:
		_listen.close()
	_listen = null
	_games.clear()


func is_listening() -> bool:
	return _listen != null


## The addresses other devices on the local network can reach this one at,
## shown to the host in the lobby (docs/multiplayer-design.md §8.2).
static func local_addresses() -> PackedStringArray:
	return lan_addresses(IP.get_local_interfaces())


## The private IPv4 addresses of `interfaces` (as `IP.get_local_interfaces()`
## gives them), in interface order. Loopback, link-local, IPv6 and the
## interfaces in NOT_LAN are left out.
static func lan_addresses(interfaces: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for i: Dictionary in interfaces:
		var iname := str(i.get("name", ""))
		if NOT_LAN.any(func(prefix: String) -> bool: return iname.begins_with(prefix)):
			continue
		for a: String in i.get("addresses", []):
			if is_lan_address(a) and not out.has(a):
				out.append(a)
	return out


## A private-range IPv4 address (10/8, 172.16/12, 192.168/16).
static func is_lan_address(a: String) -> bool:
	if not a.is_valid_ip_address() or a.contains(":"):
		return false
	var p := a.split(".")
	var b := int(p[1])
	return p[0] == "10" or (p[0] == "172" and b >= 16 and b <= 31) or (p[0] == "192" and b == 168)


## Games heard recently, sorted by name.
func games() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in _games.values():
		out.append(g)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return out


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if _announce:
		_timer -= delta / maxf(Engine.time_scale, 0.001)
		if _timer <= 0.0:
			_timer = ANNOUNCE_INTERVAL
			var bytes := JSON.stringify(_payload.call()).to_utf8_buffer()
			for addr in ["255.255.255.255", "127.0.0.1"]:
				_announce.set_dest_address(addr, Net.discovery_port)
				_announce.put_packet(bytes)
	if _listen:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet()
			var ip := _listen.get_packet_ip()
			var d = JSON.parse_string(pkt.get_string_from_utf8())
			if not (d is Dictionary) or d.get("game", "") != Net.GAME_ID:
				continue
			var key := "%s:%d" % [ip, int(d.get("port", Net.game_port))]
			var g := {
				"address": ip, "port": int(d.get("port", Net.game_port)), "name": str(d.get("name", "?")),
				"players": int(d.get("players", 0)), "max": int(d.get("max", Config.MAX_PLAYERS)),
				"difficulty": str(d.get("difficulty", "")), "proto": int(d.get("proto", 0)), "seen": t,
			}
			if not _games.has(key) or _games[key]["players"] != g["players"] or _games[key]["name"] != g["name"]:
				changed = true
			_games[key] = g
		for key in _games.keys():
			if t - float(_games[key]["seen"]) > HOST_TIMEOUT:
				_games.erase(key)
				changed = true
		if changed:
			games_changed.emit()
