extends Node
## Autoload "Sfx": tiny procedurally synthesized sound effects, so the game ships
## without audio files. Call Sfx.play("shoot").

const RATE := 22050
const VOICES := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
## Nothing plays (the title screen's background game).
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)

	_streams["shoot"] = _synth(0.14, func(t: float) -> float:
		var f := lerpf(950.0, 320.0, t / 0.14)
		return (sin(TAU * f * t) * 0.6 + randf_range(-0.3, 0.3)) * exp(-t * 28.0))
	_streams["hit"] = _synth(0.09, func(t: float) -> float:
		return (randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 140.0 * t) * 0.5) * exp(-t * 45.0))
	_streams["coin"] = _synth(0.22, func(t: float) -> float:
		var f := 1320.0 if t < 0.06 else 1760.0
		return signf(sin(TAU * f * t)) * 0.28 * exp(-maxf(t - 0.06, 0.0) * 18.0))
	_streams["build"] = _synth(0.28, func(t: float) -> float:
		return (sin(TAU * 170.0 * t) * 0.8 + randf_range(-0.4, 0.4)) * exp(-t * 16.0))
	_streams["raid"] = _synth(0.5, func(t: float) -> float:
		return (sin(TAU * 70.0 * t) * 0.7 + randf_range(-0.6, 0.6)) * exp(-t * 7.0))
	_streams["death"] = _synth(0.35, func(t: float) -> float:
		var f := lerpf(420.0, 160.0, t / 0.35)
		return sin(TAU * f * t) * 0.35 * (1.0 - t / 0.35))
	_streams["place"] = _synth(0.1, func(t: float) -> float:
		return (sin(TAU * 520.0 * t) * 0.4 + randf_range(-0.2, 0.2)) * exp(-t * 40.0))
	_streams["recruit"] = _synth(0.3, func(t: float) -> float:
		var f := 440.0 if t < 0.12 else 660.0
		return sin(TAU * f * t) * 0.35 * exp(-fmod(t, 0.12) * 10.0))
	_streams["horn"] = _synth(1.1, func(t: float) -> float:
		var f := 147.0 if t < 0.45 else 131.0
		f *= 1.0 + 0.01 * sin(TAU * 5.0 * t)
		var env := minf(t * 12.0, 1.0) * clampf((1.1 - t) * 5.0, 0.0, 1.0)
		var ph := fmod(f * t, 1.0)
		return (ph * 2.0 - 1.0) * 0.35 * env)
	_streams["chime"] = _synth(0.7, func(t: float) -> float:  # (a tutorial step done)
		var f := 784.0 if t < 0.14 else 1175.0
		var k := t if t < 0.14 else t - 0.14
		return (sin(TAU * f * t) + 0.3 * sin(TAU * 2.0 * f * t)) * 0.25 * exp(-k * 6.0))
	_streams["lose"] = _synth(1.2, func(t: float) -> float:
		var notes := [294.0, 247.0, 220.0, 147.0]
		var f: float = notes[mini(int(t / 0.28), 3)]
		return signf(sin(TAU * f * t)) * 0.18 * clampf((1.2 - t) * 3.0, 0.0, 1.0))


func play(sound: String, pitch_jitter: float = 0.08) -> void:
	if muted or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _synth(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s: float = gen.call(float(i) / RATE)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
