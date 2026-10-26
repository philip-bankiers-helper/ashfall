class_name AshAudioBank
extends RefCounted
## Cached authored fallback plus reviewed096 reference recordings, routed by action.
const VARIANTS := {"shot_awp":3,"shot_pistol":3,"shot_smg":3,"shot_shotgun":3,"shot_sniper":3,"shot_lmg":3,"shot_launcher":3,"shot_suppressed":3,"revive_charge":10,"build_place":3,"build_break":3,"consume_open":2,"consume_drink":2,"consume_shake":2,"rifle":4,"mag_eject":2,"pouch":2,"mag_insert":2,"bolt":2,"dry":2,"metal_step":3,"concrete_step":3,"gravel_step":3,"wood_step":3,"impact_metal":3,"impact_concrete":3,"hit":2,"hurt":2,"relay":1,"wind":1,"glide":1,"turbine":1,"creak":3,"climb":2,"enemy_fire":3,"enemy_charge":2,"enemy_break":3}
const LOOPS := ["wind","glide","turbine","rocket_flight","build_lightning","katana_shield","revive_shepard"]
static var _cache: Dictionary = {}

static func ensure_buses() -> void:
	for name_value in ["SFX","Ambience"]:
		if AudioServer.get_bus_index(name_value) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, name_value)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_db(index, -4.0 if name_value == "SFX" else -8.0)
	var master := AudioServer.get_bus_index("Master")
	for index in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master,index) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.resource_name = "Ashfall Peak Ceiling"
	limiter.ceiling_db = -1.0
	limiter.pre_gain_db = 0.0
	limiter.release = 0.12
	AudioServer.add_bus_effect(master,limiter)

static func warmup(kinds: Array) -> void:
	for kind in kinds:
		for variant in range(int(VARIANTS.get(kind,1))):
			sample(kind, variant)

static func sample(kind: String, variant: int = 0) -> AudioStreamWAV:
	var reference:AudioStreamWAV=preload("res://scripts/reference_audio_099.gd").generic(kind,variant)
	if reference!=null:return reference
	var key := "%s_%02d" % [kind, posmod(variant,int(VARIANTS.get(kind,1)))]
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/audio/sfx/" + key + ".wav"
	var wav: AudioStreamWAV
	if FileAccess.file_exists(path):
		wav = AudioStreamWAV.load_from_file(path)
	elif ResourceLoader.exists(path):
		wav = load(path) as AudioStreamWAV
	else:
		wav = synthesize(kind, variant)
	if kind in LOOPS:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length()*wav.mix_rate)
	_cache[key] = wav
	return wav

static func for_weapon(owner_gun:Node3D,kind:String,variant:int=0)->AudioStreamWAV:
	var reference:AudioStreamWAV=preload("res://scripts/reference_audio_099.gd").weapon(kind,owner_gun,variant)
	return reference if reference!=null else sample(owner_gun.shot_sound_kind_089() if kind=="shot" else kind,variant)
static func for_action(subject:String,kind:String,variant:int=0)->AudioStreamWAV:
	var reference:AudioStreamWAV=preload("res://scripts/reference_audio_099.gd").action(kind,subject,variant)
	return reference if reference!=null else sample(kind,variant)

static func synthesize(kind: String, variant: int = 0) -> AudioStreamWAV:
	var durations := {"rifle":0.68,"mag_eject":0.19,"pouch":0.27,"mag_insert":0.24,"bolt":0.28,"dry":0.10,"metal_step":0.32,"concrete_step":0.23,"gravel_step":0.38,"wood_step":0.28,"impact_metal":0.55,"impact_concrete":0.27,"hit":0.12,"hurt":0.34,"relay":1.1,"wind":8.0,"glide":6.0,"turbine":6.0,"creak":1.7,"climb":.30,"enemy_fire":0.44,"enemy_charge":0.7,"enemy_break":0.8}
	var duration: float = durations.get(kind,0.2)
	var rate := 32000
	var count := int(duration * rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 917324 + kind.hash() + variant * 1973
	var low := 0.0
	var mid := 0.0
	var peak := 0.0
	var detune := 1.0 + (variant - 1) * 0.027
	for i in range(count):
		var t := float(i)/rate
		var n := rng.randf_range(-1.0,1.0)
		low = lerpf(low,n,0.025)
		mid = lerpf(mid,n,0.24)
		var high := n-mid
		var s := 0.0
		match kind:
			"rifle", "enemy_fire":
				# Muzzle crack, low gas body, bolt cycle and dispersed valley reflections.
				var weight := 1.0 if kind == "rifle" else 0.75
				s = high * exp(-t*165.0)*0.9 + mid*exp(-t*30.0)*1.6
				s += sin(TAU*(78.0*detune*t+18.0*(1.0-exp(-t*20.0))))*exp(-t*35.0)*0.55*weight
				for delay in [0.027,0.071,0.13,0.205]:
					var u: float = t-delay
					if u>0: s += mid*exp(-u*15.0)*0.18*(1.0-delay*2.0)
				var bolt_t := t-0.047
				if bolt_t>0: s += (high*0.35+sin(TAU*940.0*bolt_t)*0.1)*exp(-bolt_t*120.0)
			"mag_eject", "mag_insert", "bolt", "dry":
				var delay: float = {"mag_eject":0.06,"mag_insert":0.09,"bolt":0.13,"dry":0.025}[kind]
				var u := maxf(0.0,t-delay)
				s = (high*0.55+sin(TAU*1471.0*detune*t)*0.16)*exp(-t*110.0)
				if kind=="bolt": s += mid*0.45*exp(-pow((t-0.07)/0.045,2.0))
				if t>delay:
					s += (mid*0.75+sin(TAU*(210.0 if kind=="mag_insert" else 421.0)*detune*u)*0.3)*exp(-u*55.0)
				if kind=="dry": s *= 0.55
			"pouch":
				s = (mid*0.7+high*0.16)*sin(PI*t/duration)*exp(-t*5.0)
				s *= 0.65+0.35*absf(sin(TAU*31.0*t))
			"metal_step", "concrete_step", "gravel_step", "wood_step":
				var u := maxf(0.0,t-0.035)
				s = low*2.2*exp(-t*31.0)+mid*0.35*exp(-t*28.0)
				if t>0.035: s += mid*0.45*exp(-u*24.0)
				match kind:
					"metal_step": s += (sin(TAU*137.0*detune*t)*0.23+sin(TAU*537.0*detune*t)*0.10+sin(TAU*917.0*t)*0.035)*exp(-t*18.0)
					"concrete_step": s += high*0.18*exp(-t*43.0)
					"gravel_step": s += high*0.36*exp(-t*9.0)*pow(absf(sin(TAU*(23.0+variant)*t)),8.0)
					"wood_step": s += (sin(TAU*94.0*detune*t)*0.22+sin(TAU*231.0*t)*0.09)*exp(-t*23.0)
			"impact_metal", "impact_concrete", "hit", "enemy_break":
				s = high*0.6*exp(-t*95.0)+mid*0.45*exp(-t*32.0)
				if kind in ["impact_metal","enemy_break"]:
					s += (sin(TAU*1133.0*detune*t)*0.13+sin(TAU*1729.0*t)*0.07+sin(TAU*317.0*t)*0.15)*exp(-t*13.0)
				if kind=="impact_concrete": s += high*0.18*pow(absf(sin(TAU*27.0*t)),6.0)*exp(-t*17.0)
				if kind=="enemy_break": s += mid*0.5*exp(-t*7.0)*pow(absf(sin(TAU*19.0*t)),5.0)
			"hurt":
				s = (low*1.8+mid*0.38)*exp(-t*16.0)+sin(TAU*66.0*t)*0.2*exp(-t*22.0)
			"relay":
				# Physical contactor clunks and motor spin-up, not an electronic beep.
				for delay in [0.0,0.19,0.36]:
					if t>=delay: s += (mid*0.55+sin(TAU*173.0*(t-delay))*0.15)*exp(-(t-delay)*55.0)
				s += (low*0.3+sin(TAU*(42.0*t+24.0*t*t))*0.06)*sin(PI*t/duration)
			"wind", "glide":
				s = (low*1.7+mid*(0.22 if kind=="wind" else 0.6))*(0.67+0.18*sin(TAU*t/duration)+0.1*sin(TAU*3.0*t/duration))
			"turbine":
				s = (sin(TAU*48.0*t)*0.13+sin(TAU*96.0*t)*0.045+low*0.65+mid*0.04)*(0.85+0.15*sin(TAU*3.0*t))
			"climb":
				# Short cloth/leather drag followed by a muted glove contact.
				s=(mid*.35+high*.08)*pow(sin(PI*t/duration),2.0)
				s+=(low*.55+sin(TAU*121.0*detune*t)*.035)*exp(-pow((t-.14)/.035,2.0))
			"creak", "enemy_charge":
				s = (mid*0.3+sin(TAU*(149.0*detune*t+37.0*t*t))*0.10+sin(TAU*317.0*t)*0.035)*pow(sin(PI*t/duration),2.0)
		# All endpoints fade to zero, preventing discontinuities in loops/transients.
		var edge := 0.035 if kind in LOOPS else 0.002
		s *= minf(1.0,t/edge)*minf(1.0,(duration-t)/edge)
		samples[i] = s
		peak = maxf(peak,absf(s))
	var target := 0.78 if kind=="rifle" else (0.45 if kind in LOOPS else 0.62)
	var gain := target/maxf(peak,0.001)
	var data := PackedByteArray()
	data.resize(count*2)
	for i in range(count): data.encode_s16(i*2,int(samples[i]*gain*32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

