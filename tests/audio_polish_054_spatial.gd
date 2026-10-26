extends SceneTree
## Silent CPU capture measures production 3D gait gain after attenuation.
var checks := 0
var failures := 0
var capture: AudioEffectCapture

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func energy(frames: PackedVector2Array) -> float:
	var result := 0.0
	for frame in frames: result += frame.length_squared()
	return result

func foot_energy(ambience, actor, sprint: bool) -> float:
	capture.clear_buffer()
	actor.sprinting = sprint
	ambience._step_variant = 0
	ambience._step(false)
	ambience._foot.pitch_scale = 1.0
	await create_timer(.4).timeout
	return energy(capture.get_buffer(capture.get_frames_available()))

func run() -> void:
	var actor = load("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_physics_process(false)
	actor.set_process(false)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1.7, 0)
	camera.make_current()
	var ambience = load("res://scripts/ambience.gd").new()
	root.add_child(ambience)
	ambience.setup(actor, null)
	ambience.set_physics_process(false)
	ambience._foot.global_position = Vector3(0, .12, 0)
	var bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(bus, 0.0)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture)
	await create_timer(.1).timeout
	var walk: float = await foot_energy(ambience, actor, false)
	var sprint: float = await foot_energy(ambience, actor, true)
	check(walk > .0001 and sprint > .0001, "Dummy driver captures nonzero production spatial footstep samples")
	var gain_db := linear_to_db(sqrt(sprint / maxf(walk, .00000001)))
	check(gain_db > 6.5 and gain_db < 7.5, "standing listener hears sprint seven dB above walk after 3D attenuation")
	print("AUDIO_POLISH_054_SPATIAL walk_energy=", walk, " sprint_energy=", sprint, " difference_db=", gain_db)
	# Capture after the production limiter, while deliberately coincident voices
	# exceed full scale before it. Dummy mixes these on CPU without speaker output.
	var master_capture := AudioEffectCapture.new()
	master_capture.buffer_length = 1.0
	var master := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master, master_capture)
	var overload_voices: Array[AudioStreamPlayer] = []
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.stream = load("res://scripts/audio_bank.gd").sample("rocket_flight")
		voice.bus = "SFX"
		root.add_child(voice)
		overload_voices.append(voice)
		voice.play()
	await create_timer(.4).timeout
	var mixed := master_capture.get_buffer(master_capture.get_frames_available())
	var mixed_peak := 0.0
	for frame in mixed: mixed_peak = maxf(mixed_peak, maxf(absf(frame.x), absf(frame.y)))
	check(mixed.size() > 1000 and mixed_peak > .4, "coincident full-gain voices reach the post-limiter CPU capture")
	check(mixed_peak <= db_to_linear(-1.0) + .001, "actual coincident CPU mix stays below the -1dB master ceiling")
	print("AUDIO_POLISH_054_LIMITED_MIX frames=", mixed.size(), " peak=", mixed_peak)
	for voice in overload_voices:
		voice.stop()
		voice.stream = null
		voice.queue_free()
	AudioServer.remove_bus_effect(master, AudioServer.get_bus_effect_count(master) - 1)
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	capture = null
	ambience.shutdown()
	ambience.queue_free()
	actor.queue_free()
	camera.queue_free()
	await create_timer(.2).timeout
	print("AUDIO_POLISH_054_SPATIAL checks=", checks, " failures=", failures, " captured_cpu=true auditioned=false")
	quit(failures)
