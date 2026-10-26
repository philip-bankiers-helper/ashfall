class_name AshMusic
extends Node
## Original synchronized score. All stems share tempo, duration and harmony.
## No synthesis, allocations or resource loading in the frame callback.
const STEM_PATHS := [
	"res://assets/audio/music/exploration.wav",
	"res://assets/audio/music/combat.wav",
	"res://assets/audio/music/extraction.wav"
]
const BUS_NAME := &"Music"
var _players: Array[AudioStreamPlayer] = []
var _intensity := 0.0
var _extraction := false
var _paused := false
var _radio := false
var _volume := 0.65
var _level := 0.0
var _combat_mix := 0.0
var _extraction_mix := 0.0
var _pause_mix := 1.0
var _duck_mix := 1.0
var _ready_audio := false

func _ready() -> void:
	if AudioServer.get_bus_index(BUS_NAME) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS_NAME)
		AudioServer.set_bus_send(index, &"Master")
	for path in STEM_PATHS:
		var stream := load(path) as AudioStreamWAV
		if stream == null:
			push_error("Music stem unavailable: " + path)
			return
		# Per-player resource copy avoids modifying shared imported resources.
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
		var player := AudioStreamPlayer.new()
		player.name = path.get_file().get_basename().capitalize() + "Stem"
		player.bus = BUS_NAME
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	# Start all stems in one frame. Keep silent stems advancing so later
	# intensity/extraction changes preserve beat and harmonic alignment.
	for player in _players:
		player.play()
	_ready_audio = true

func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)

func set_extraction(value: bool) -> void:
	_extraction = value

func set_paused(value: bool) -> void:
	_paused = value
	if not value:
		for player in _players:
			player.stream_paused = false

func set_radio_active(value: bool) -> void:
	_radio = value

func set_volume(value: float) -> void:
	# Linear gain; zero mutes. The Music bus remains available to user controls.
	_volume = clampf(value, 0.0, 1.0)

func get_volume() -> float:
	return _volume

func shutdown() -> void:
	# Idempotent; stop mixing before releasing each duplicated loop resource.
	# Main may await a short timer after stopping all game audio before quit.
	_ready_audio = false
	set_process(false)
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.queue_free()
	_players.clear()

func _exit_tree() -> void:
	# Also covers scene replacement; explicit shutdown allows a mixer grace
	# period while the tree still runs, which this synchronous hook cannot.
	shutdown()

func _process(delta: float) -> void:
	if not _ready_audio:
		return
	_combat_mix = move_toward(_combat_mix, _intensity, delta / 2.5)
	_extraction_mix = move_toward(_extraction_mix, 1.0 if _extraction else 0.0, delta / 4.0)
	_pause_mix = move_toward(_pause_mix, 0.0 if _paused else 1.0, delta / 0.3)
	_duck_mix = move_toward(_duck_mix, 0.24 if _radio else 1.0, delta / (0.25 if _radio else 1.4))
	_level = move_toward(_level, _volume, delta / 1.2)
	var master := _level * _pause_mix * _duck_mix
	_set_gain(_players[0], master * lerpf(0.85, 0.65, _combat_mix))
	_set_gain(_players[1], master * _combat_mix * 0.9)
	_set_gain(_players[2], master * _extraction_mix * 0.85)
	if _paused and _pause_mix <= 0.0:
		for player in _players:
			player.stream_paused = true

func _set_gain(player: AudioStreamPlayer, value: float) -> void:
	player.volume_db = linear_to_db(value) if value > 0.0001 else -80.0
