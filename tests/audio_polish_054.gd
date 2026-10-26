extends SceneTree
## CPU dispatch/sample audit. Never opens an audio device or establishes audition.
var checks := 0
var failures := 0
var heard: Array[String] = []
var sample_metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func advance(ambience, seconds: float) -> void:
	for frame in roundi(seconds * 90): ambience._physics_process(1.0 / 90.0)

func metrics(wav: AudioStreamWAV) -> Dictionary:
	var count := wav.data.size() / 2
	var peak := 0.0
	var square_sum := 0.0
	var clipped := 0
	for i in count:
		var sample_value := float(wav.data.decode_s16(i * 2)) / 32768.0
		peak = maxf(peak, absf(sample_value))
		square_sum += sample_value * sample_value
		if absf(sample_value) >= 32767.0 / 32768.0: clipped += 1
	return {"peak": peak, "rms": sqrt(square_sum / maxf(count, 1)), "clipped": clipped,
		"duration": wav.get_length(), "first": wav.data.decode_s16(0),
		"last": wav.data.decode_s16((count - 1) * 2)}

func run() -> void:
	var actor = load("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.xr_enabled = true
	actor.tracking_available = true
	actor.xr_camera.position.y = 1.7
	actor.get_standing_eye_height()
	actor._supported = true
	var ambience = load("res://scripts/ambience.gd").new()
	root.add_child(ambience)
	ambience.setup(actor, null)
	ambience.set_physics_process(false)
	ambience.movement_foley.connect(func(kind): heard.append(kind))
	actor.climbing = true
	# A realistic pull-pause-pull sequence must not need one unbroken .55s stroke.
	for stroke in 8:
		actor.velocity = Vector3.UP
		advance(ambience, .2)
		actor.velocity = Vector3.ZERO
		advance(ambience, .2)
	check(heard.count("climb") == 2 and heard.size() == 2,
		"eight brief climb pulls retain movement progress across stationary hand holds")
	heard.clear()
	advance(ambience, 2)
	check(heard.is_empty(), "stationary wall hold never emits a deferred climb contact")
	actor.climbing = false
	advance(ambience, .1)
	actor.climbing = true
	actor.velocity = Vector3.UP
	advance(ambience, .2)
	check(heard.is_empty(), "releasing the wall clears partial contact progress")
	ambience.set_paused(true)
	ambience.set_paused(false)
	advance(ambience, .4)
	check(heard.is_empty(), "pause clears partial movement so menu exit cannot synthesize a contact")
	actor.climbing = false
	actor._supported = true
	actor.velocity = Vector3(3.4, 0, 0)
	advance(ambience, .1)
	heard.clear()
	ambience._stride = 0
	advance(ambience, 6)
	check(heard.count("walk") == 12 and heard.size() == 12, "normal gait dispatches twelve footfalls in six seconds")
	heard.clear()
	ambience._stride = 0
	actor.sprinting = true
	actor.velocity.x = 1000
	advance(ambience, 6)
	check(heard.count("sprint") == 18 and heard.size() == 18, "extreme sprint remains eighteen footfalls in six seconds")
	heard.clear()
	ambience._physics_process(2.0)
	check(heard.size() == 1, "a long frame dispatches at most one footfall without a catch-up burst")
	heard.clear()
	actor.xr_camera.position.y = 1.0
	advance(ambience, 3)
	check(heard.is_empty(), "tracked crouch silences sprint as well as ordinary walking")
	actor.xr_camera.position.y = 1.7
	actor._supported = false
	actor.gliding = true
	advance(ambience, 2)
	check(heard.is_empty() and is_equal_approx(db_to_linear(ambience._glide.volume_db), .45),
		"airborne glide is footstep-free and reaches the existing louder bounded gain")
	actor.gliding = false
	advance(ambience, 2)
	check(ambience._glide.volume_db <= -65.0, "leaving glide fades the wind back to its silent floor")
	# Exercise production menu routing: its saved/user slider replaces bank defaults.
	var menu = load("res://scripts/menu.gd").new()
	root.add_child(menu)
	menu.setup(actor)
	menu.set_process(false)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))), .6),
		"production default Ambience bus is the menu's .6 user gain")
	var bank = load("res://scripts/audio_bank.gd")
	for kind in ["wind", "glide", "turbine", "climb", "concrete_step", "metal_step", "wood_step", "gravel_step", "frag_blast", "zone_arm", "zone_bloom", "rocket_launch", "rocket_flight", "rocket_impact"]:
		for variant in int(bank.VARIANTS.get(kind, 1)):
			var wav: AudioStreamWAV = bank.sample(kind, variant)
			var measured := metrics(wav)
			sample_metrics["%s_%02d" % [kind, variant]] = measured
			check(wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.mix_rate == 32000 and not wav.stereo
				and measured.clipped == 0 and measured.rms > .005 and measured.peak < .95,
				"%s variant%d actual PCM is nonempty mono and unclipped" % [kind, variant])
	var flight: AudioStreamWAV = bank.sample("rocket_flight")
	check(flight.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and flight.loop_begin == 0 and flight.loop_end == roundi(flight.get_length() * flight.mix_rate),
		"rocket flight bed spans full loop bounds instead of ending after 1.4s")
	var flight_voice := AudioStreamPlayer.new()
	flight_voice.stream = flight
	flight_voice.bus = "SFX"
	root.add_child(flight_voice)
	flight_voice.play()
	await create_timer(1.6).timeout
	check(flight_voice.playing, "Dummy-driver CPU playback remains active beyond the rocket sample's first pass")
	flight_voice.stop()
	flight_voice.stream = null
	flight_voice.queue_free()
	var glide_peak: float = sample_metrics.glide_00.peak * .45
	var wind_peak: float = sample_metrics.wind_00.peak * db_to_linear(-22.0)
	var turbine_peak: float = sample_metrics.turbine_00.peak * db_to_linear(-24.0) * 2.0
	var bed_bound := glide_peak + wind_peak + turbine_peak
	check(bed_bound < .3, "worst coincident ambience sample peaks retain headroom even at full user volume")
	menu.set_audio_volume("Ambience", 1.0)
	bank.ensure_buses()
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), 0.0),
		"audio bank preserves the user's full-volume bus choice")
	var limiter_count := 0
	var limiter_active := false
	var master := AudioServer.get_bus_index("Master")
	for i in AudioServer.get_bus_effect_count(master):
		var effect = AudioServer.get_bus_effect(master, i)
		if effect is AudioEffectHardLimiter:
			limiter_count += 1
			limiter_active = AudioServer.is_bus_effect_enabled(master, i) and effect.ceiling_db <= -1.0 and effect.pre_gain_db == 0
	check(limiter_count == 1 and limiter_active, "coincident combat mix retains one enabled -1dB master limiter")
	print("AUDIO_POLISH_054_SAMPLE_METRICS ", JSON.stringify(sample_metrics))
	print("AUDIO_POLISH_054_BED_PEAK_BOUND ", bed_bound, " default_bus=", bed_bound * .6)
	menu.free()
	ambience.shutdown()
	ambience.queue_free()
	actor.queue_free()
	await create_timer(.2).timeout
	print("AUDIO_POLISH_054 checks=", checks, " failures=", failures, " dispatch_tested=true auditioned=false")
	quit(failures)
