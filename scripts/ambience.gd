class_name AshAmbience
extends Node3D
const AudioBank = preload("res://scripts/audio_bank.gd")
## Original baked ambience, 32 kHz mono PCM. No recording dependencies.
## Quiet beds leave substantial headroom for weapon, voice and threat cues.
var _player: CharacterBody3D
var _world: Node3D
var _wind: AudioStreamPlayer
var _glide: AudioStreamPlayer
var _foot: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _sources: Array[Node] = []
var _paused := false
var _configured := false
var _stride := 0.0
var _next_creak := 13.0
var _was_grounded := false
var _last_vertical_speed := 0.0
var _glide_gain := 0.0
var _rng := RandomNumberGenerator.new()
var _impact_voices: Array[AudioStreamPlayer3D] = []
var _impact_cursor := 0
var _step_variant := 0
var _environment_timer := 0.0
var _sheltered := false
signal movement_foley(kind:String)
var _climb: AudioStreamPlayer3D
var _climb_elapsed := 0.0
var _climb_variant := 0
const GLIDE_LINEAR_GAIN := .45

func setup(player: Node3D, world: Node3D) -> void:
	_player = player as CharacterBody3D
	_world = world
	if is_inside_tree() and not _configured:
		_build()

func _ready() -> void:
	if is_instance_valid(_player) and not _configured:
		_build()

func _build() -> void:
	_configured = true
	_rng.seed = 71731
	AudioBank.ensure_buses()
	# Warm every waveform once during setup; no sample generation in frame callbacks.
	AudioBank.warmup(["wind", "glide", "turbine", "metal_step", "concrete_step", "gravel_step", "wood_step", "climb", "creak","impact_metal","impact_concrete"])
	_wind = _bed("wind", -25.0)
	_glide = _bed("glide", -65.0)
	_glide.bus="SFX" #0993 flight is movement feedback; environmental ambience can be muted independently.
	_foot = _spatial("concrete_step", -21.0, 4.0, 8.0)
	_foot.max_db = -15.0
	_climb = _spatial("climb", -25.0, 2.0, 5.0)
	_creak = _spatial("creak", -21.0, 10.0, 35.0)
	for i in range(8):
		_impact_voices.append(_spatial("impact_concrete",-12.0,2.0,55.0))
	var turbine_center := Vector3(-18, 9, -44)
	if is_instance_valid(_world):
		var objectives: Variant = _world.get("objective_positions")
		if objectives is Array and objectives.size() > 1:
			turbine_center = objectives[1]
	for side in [-1.0, 1.0]:
		var turbine := _spatial("turbine", -24.0, 7.0, 48.0)
		turbine.global_position = turbine_center + Vector3(side * 5.0, -2.0, 4.0)
		turbine.pitch_scale = 1.0 if side < 0.0 else 0.94
		turbine.play()
	set_paused(_paused)

func _bed(kind: String, volume: float) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.bus = "Ambience"
	voice.stream = waveform(kind)
	voice.volume_db = volume
	add_child(voice)
	_sources.append(voice)
	voice.play()
	return voice

func _spatial(kind: String, volume: float, unit: float, distance: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.bus = "Ambience" if kind in ["wind","glide","turbine","creak"] else "SFX"
	voice.stream = waveform(kind)
	voice.volume_db = volume
	voice.unit_size = unit
	voice.max_distance = distance
	voice.max_db = volume
	voice.max_polyphony = 1
	add_child(voice)
	_sources.append(voice)
	return voice

func set_paused(value: bool) -> void:
	_paused = value
	for voice in _sources:
		# stop also cancels a 3D player's deferred first-frame play request.
		# Transient footsteps/creaks should not resume halfway through on menu exit.
		if value:
			voice.call("stop")
		else:
			var stream: AudioStreamWAV = voice.get("stream")
			if stream.loop_mode != AudioStreamWAV.LOOP_DISABLED and not bool(voice.get("playing")):
				voice.call("play")
	if value:
		_stride = 0.0
		_climb_elapsed = 0.0

func shutdown() -> void:
	_paused = true
	set_physics_process(false)
	for voice in _sources:
		voice.call("stop")
		voice.set("stream",null)

func _exit_tree() -> void:
	shutdown()

func _physics_process(delta: float) -> void:
	if not _configured or _paused or not is_instance_valid(_player):
		return
	var grounded: bool = _player.is_supported() if _player.has_method("is_supported") else _player.is_on_floor()
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_environment_timer -= delta
	if _environment_timer <= 0.0:
		_environment_timer = 0.4
		var head := _player.global_position+Vector3.UP*1.7
		var shelter_ray := PhysicsRayQueryParameters3D.create(head,head+Vector3.UP*7.0,1,[_player.get_rid()])
		_sheltered = not get_world_3d().direct_space_state.intersect_ray(shelter_ray).is_empty()
	var wind_target := -34.0 if _sheltered else -26.0+clampf(_player.global_position.y/12.0,0.0,4.0)
	_wind.volume_db = move_toward(_wind.volume_db,wind_target,delta*3.0)
	var is_gliding := bool(_player.get("gliding"))
	var glide_target := clampf((speed - 2.5) / 8.0, 0.0, 1.0) if is_gliding else 0.0
	_glide_gain = move_toward(_glide_gain, glide_target, delta * 2.0)
	# Flight follows SFX; environmental beds follow Ambience. The limiter
	# bounds coincident weapon/FX peaks without changing the source waveform.
	_glide.volume_db = linear_to_db(maxf(_glide_gain * GLIDE_LINEAR_GAIN*.6, 0.0005)) #Retain prior default effective gain after routing from the former0.6 ambience mix.
	_glide.pitch_scale = 0.85 + _glide_gain * 0.3
	_foot.global_position = _player.global_position + Vector3.UP * 0.12
	var crouched:=_crouch_walking()
	var climbing:=bool(_player.get("climbing"))
	if grounded and speed > 0.35 and not climbing and not is_gliding and not crouched:
		# Cadence is a gait clock, not metres travelled. Extreme speed settings
		# cannot turn footsteps into a machine gun or accumulate catch-up bursts.
		_stride += delta
		var interval:=.33 if bool(_player.get("sprinting")) else .48
		if _stride >= interval:
			_stride = fmod(_stride, interval)
			_step(false)
	else:
		_stride = 0.0
	_climb.global_position=_player.global_position+Vector3.UP*1.1
	if climbing and _player.velocity.length()>.12:
		_climb_elapsed+=delta
		if _climb_elapsed>=.55:
			_climb_elapsed=fmod(_climb_elapsed,.55)
			_climb.stream=AudioBank.sample("climb",_climb_variant);_climb_variant+=1
			_climb.pitch_scale=_rng.randf_range(.96,1.04);_climb.play();movement_foley.emit("climb")
	elif not climbing:
		# Short hand-over-hand pulls include stationary holds. Keep their active
		# movement progress while still gripping, without sounding during a hold.
		# Releasing the wall (or pausing) starts the next climb with a fresh clock.
		_climb_elapsed=0.0
	if grounded and not _was_grounded and _last_vertical_speed < -2.8 and not crouched and not climbing:
		_step(true)
	_was_grounded = grounded
	_last_vertical_speed = _player.velocity.y
	_next_creak -= delta
	if _next_creak <= 0.0:
		_next_creak = _rng.randf_range(14.0, 26.0)
		_creak.global_position = _player.global_position + Vector3(_rng.randf_range(-12, 12), _rng.randf_range(3, 9), _rng.randf_range(-16, 8))
		_creak.pitch_scale = _rng.randf_range(0.85, 1.12)
		_creak.stream = AudioBank.sample("creak",_rng.randi_range(0,2))
		_creak.play()

func _step(landing: bool) -> void:
	var surface_kind := "concrete"
	var from := _player.global_position + Vector3.UP * 0.3
	var ray := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 0.9, 1, [_player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider is Node:
		surface_kind = surface_type(hit.collider)
	var running:AudioStreamWAV=preload("res://scripts/reference_audio_099.gd").generic(surface_kind+"_run_step",_step_variant) if bool(_player.get("sprinting")) and not landing else null
	_foot.stream = running if running!=null else AudioBank.sample(surface_kind+"_step",_step_variant)
	_step_variant += 1
	_foot.pitch_scale = _rng.randf_range(0.96, 1.04) * (0.84 if landing else 1.0)
	_foot.volume_db = -18.0 if landing else (-15.0 if bool(_player.get("sprinting")) else -22.0)
	# The nearby listener is inside unit_size, where inverse attenuation boosts
	# both gaits to a shared ceiling. Match the ceiling to each gait so its
	# intended quiet walk / louder sprint difference survives the spatial mix.
	_foot.max_db = _foot.volume_db
	_foot.play()
	movement_foley.emit("landing" if landing else ("sprint" if bool(_player.get("sprinting")) else "walk"))

func _crouch_walking()->bool:
	if _player.get("xr_enabled")==true and _player.get("tracking_available")==true:
		var camera:Node3D=_player.get("xr_camera")
		if is_instance_valid(camera) and _player.has_method("get_tracking_eye_baseline_m"):
			return camera.position.y < float(_player.get_tracking_eye_baseline_m())*.75
		if is_instance_valid(camera) and _player.has_method("get_standing_eye_height"):
			return camera.position.y < float(_player.get_standing_eye_height())*.75
	return _player.get("xr_enabled")==false and Input.is_physical_key_pressed(KEY_CTRL)

static func surface_type(collider: Node) -> String:
	var value := str(collider.get_meta("surface",collider.name)).to_lower()
	if "metal" in value or "steel" in value or "grate" in value: return "metal"
	if "wood" in value or "timber" in value: return "wood"
	if "gravel" in value or "dirt" in value or "stone" in value: return "gravel"
	return "concrete"

func play_impact(position_value: Vector3, surface: String = "concrete") -> void:
	if _paused or _impact_voices.is_empty(): return
	var voice := _impact_voices[_impact_cursor]
	_impact_cursor = (_impact_cursor+1)%_impact_voices.size()
	voice.stop()
	voice.global_position = position_value
	voice.stream = AudioBank.sample("impact_metal" if surface in ["metal","steel","grate"] else "impact_concrete",_impact_cursor)
	voice.pitch_scale = _rng.randf_range(0.97,1.03)
	voice.play()

static func waveform(kind: String) -> AudioStreamWAV:
	return AudioBank.sample(kind)

