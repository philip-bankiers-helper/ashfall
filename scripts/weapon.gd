class_name AshWeapon
extends Node3D
signal network_reload_stage1000(stage:String)
const AudioBank = preload("res://scripts/audio_bank.gd")
const WeaponFinish = preload("res://scripts/weapon_finish.gd")
## Kestrel service rifle. All input paths use the same reload state machine.
signal shot(origin: Vector3, direction: Vector3, damage: float)
signal feedback(text: String)

var ammo: int = 24
var magazine_size: int = 24
var reload_state: String = "ready"
var player: Node3D
var right_hand: XRController3D
var left_hand: XRController3D
var camera: Camera3D
var cooldown: float = 0.0
var _displayed_shot_pose:=Transform3D.IDENTITY
var _displayed_pose_valid:=false
var _external_aim_publication:=false
var recoil: float = 0.0
var recoil_pitch: float = 0.0
var recoil_yaw:float=0.0
var recoil_pattern_index:=0
var recoil_idle:=0.0
var _reticle_bounce_pitch_071:=0.0
var _bounce_events_091:Array[Vector2]=[]
var _reference_clock:=0.0
var _reference_shots:Array[float]=[]
var _measured_recoil_target:=0.0
const EndpointExperiment=preload("res://scripts/recoil_endpoint_experiment.gd")
const ObservedRecoil=preload("res://scripts/recoil_observation.gd")
var _observed_burst_time:=0.0
var _observed_burst_active:=false
var _observed_shot_supported:=false
const RECOIL_PATTERN:Array[Vector2]=[Vector2(1,0),Vector2(0.94,-0.12),Vector2(1.04,0.18),Vector2(0.98,0.10),Vector2(1.08,-0.20),Vector2(0.92,-0.08)]
const VERTICAL_RECOIL_PROFILES:Dictionary={
	"weapon":[1.0,.28,.42,.31,.55,.37],"compact_smg":[1.0,.18,.27,.24,.36,.22],
	"burst_carbine":[1.0,.44,.28,.50,.34,.42],"pistol":[1.0,.60,.74,.55,.81,.64],
	"revolver":[1.0,.75,.95,.82,1.05,.87,.69],"belt_lmg":[1.0,.20,.26,.35,.29,.45,.31,.38],
	"auto_shotgun":[1.0,.56,.43,.72,.61,.47],"shotgun":[1.0,.70],"dt11":[1.0,.70],
	"precision_rifle":[1.0,.90,.70,.85,1.10],"top_feed_pdw":[1.0,.20,.33,.27,.40,.24],
	"spr":[1.0,.39,.50,.32,.56,.42],"uzi":[1.0,.16,.26,.21,.31,.24],
	"matadors":[1.0,.44,.68,.51,.72,.48,.63,.54]
}
const FOREGRIP_ACQUIRE:=0.25
const FOREGRIP_RELEASE:=0.45
const FOREGRIP_POINT := Vector3(0, -0.025, -0.36)
var _attached_visual: Node3D
var _attached_rest := Transform3D.IDENTITY
var _cooldown_overrun:=0.0
var fire_interval: float = 0.115
var damage: float = 34.0
var supported: bool = false
## Project defaults preserve the existing feel; these are not reference-game defaults.
var motion_damping := 1.0
const RECOIL_GAIN_089:=1.25
var offhand_influence := 0.0
var grip_toggle := false
var _support_latched := false
var _support_grip_previous := false
var _aim_filter_ready := false
var _filtered_aim := Basis.IDENTITY
var _aim_player_basis := Basis.IDENTITY
var _support_weight: float = 0.0
var model: Node3D
var sight_front: Marker3D
var sight_rear: Marker3D
var magazine: MeshInstance3D
var loose_magazine: MeshInstance3D
var muzzle_flash: MeshInstance3D
var bolt: MeshInstance3D
var firing_carrier: MeshInstance3D
var _carrier_time := 0.0
var ammo_provider:Node
var ammo_slot:=-1
var ammo_panel:Node3D
var _seated_rounds:=0
var ammo_label: Label3D
var guide: MeshInstance3D
var hip_source: Node3D
var charging_arrow: Node3D
var insertion_arrow: Node3D
const INSERT_POINT := Vector3(0, -0.18, -0.15)
## Move the offer 30% along its actual travel toward the magazine well.
const OFFER_POINT := Vector3(0, -0.278, -0.15)
## Gun-local reload reach: 3.5cm wider each side, 4cm farther toward muzzle.
## Vertical and rear limits stay unchanged. Shared by rifle and Cinder gestures.
const RELOAD_LATERAL_EXTRA := 0.035
const RELOAD_FORWARD_EXTRA := 0.04
var _mag_grab_local := OFFER_POINT
var _bolt_finish: StandardMaterial3D
var _reload_finish: StandardMaterial3D
var _grip_previous: bool = false
var _eject_previous: bool = false
var _eject_click_previous: bool = true
var _trigger_previous: bool = false
var _requires_trigger_release: bool = false
var _resume_grip_release: bool = false
var _rack_grabbed: bool = false
var _rack_start: Vector3
var _flash_time: float = 0.0
var _empty_click: float = 0.0
var _desktop_signals: bool = false
var _has_player_input_gate: bool = false
var _has_climb_state: bool = false
var _has_hand_reservation: bool = false
var _has_head_obstruction: bool = false
var _sound: AudioStreamPlayer3D
var _sound_fire: AudioStreamWAV
var _sound_click: AudioStreamWAV
var _shot_voices: Array[AudioStreamPlayer3D] = []
var _shot_voice_cursor := 0
var _audio_variant := 0
const CASING_POOL_SIZE := 12
const MAGAZINE_POOL_SIZE := 3
var _debris: Array[MeshInstance3D] = []
var _debris_velocity: Array[Vector3] = []
var _debris_spin: Array[Vector3] = []
var _debris_life: Array[float] = []
var _debris_rest: Array[bool] = []
var _casing_cursor := 0
var _magazine_cursor := 0
var _cosmetic_rng := RandomNumberGenerator.new()

func setup(owner_player: Node3D, connect_desktop: bool = true) -> void:
	player = owner_player
	for property in player.get_property_list():
		if property.name == "input_enabled":
			_has_player_input_gate = true
		if property.name == "climbing_right":
			_has_climb_state = true
		if property.name == "left_hand_reserved":
			_has_hand_reservation = true
		if property.name == "head_obstructed":
			_has_head_obstruction = true
	right_hand = player.get_weapon_hand() if player.has_method("get_weapon_hand") else player.get("right_hand") as XRController3D
	left_hand = player.get_support_hand() if player.has_method("get_support_hand") else player.get("left_hand") as XRController3D
	if player.has_method("get_view_camera"):
		camera = player.call("get_view_camera") as Camera3D
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if player.has_signal("fired"):
		if connect_desktop: player.connect("fired", fire)
		_desktop_signals = true
	if player.has_signal("reload_requested"):
		if connect_desktop: player.connect("reload_requested", desktop_reload_step)
	_build_model()
	preload("res://scripts/model_scale_084.gd").apply(self)
	if muzzle_flash!=null:muzzle_flash.hide()
	for label in model.find_children("*","Label3D",true,false):
		if label!=ammo_label:label.free()
	ammo_panel=load("res://scripts/ammo_panel.gd").new()
	ammo_panel.name="AmmoReadoutPanel"
	model.add_child(ammo_panel)
	ammo_panel.setup(ammo_label)
	update_ammo_display()
	AudioBank.ensure_buses()
	AudioBank.warmup(["rifle","dry","mag_eject","pouch","mag_insert","bolt"])
	_sound = AudioStreamPlayer3D.new()
	_sound.bus = "SFX"
	_sound.max_distance = 14.0
	_sound.volume_db = -10.0
	_sound.max_polyphony = 1
	add_child(_sound)
	_sound_fire = AudioBank.sample("rifle")
	_sound_click = AudioBank.sample("dry")
	for i in range(6):
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "SFX"
		voice.max_distance = 85.0
		voice.unit_size = 2.0
		voice.volume_db = -5.0
		voice.max_polyphony = 1
		voice.position = Vector3(0,0.04,-0.69)
		add_child(voice)
		_shot_voices.append(voice)

func _vr_active() -> bool:
	return right_hand != null and get_viewport().use_xr

func set_weapon_settings(settings: Dictionary) -> void:
	refresh_hands()
	motion_damping = clampf(float(settings.get("motion_damping",motion_damping)),0.0,2.0)
	offhand_influence = clampf(float(settings.get("offhand_influence",offhand_influence)),0.0,1.0)
	var next_toggle := bool(settings.get("grip_toggle",grip_toggle))
	if next_toggle != grip_toggle:
		_release_support_visual()
		_support_latched = false
		_support_grip_previous = true
		supported = false
		_support_weight = 0.0
		if _has_hand_reservation: _reserve_support_hand(reload_state!="ready")
	grip_toggle = next_toggle
	_aim_filter_ready = false

func aim_smoothing_time_constant()->float:
	return 0.006+0.09*motion_damping*motion_damping

func _apply_aim_filter(delta: float) -> void:
	if not _input_allowed() or not _hand_input_ready(right_hand):
		_aim_filter_ready = false
		return
	var target := global_basis.orthonormalized()
	var player_basis:Basis=player.global_basis.orthonormalized() if player!=null else Basis.IDENTITY
	if _aim_filter_ready:
		# Artificial locomotion yaw must not be treated as hand jitter.
		_filtered_aim=(player_basis*_aim_player_basis.inverse()*_filtered_aim).orthonormalized()
	_aim_player_basis=player_basis
	if not _aim_filter_ready or motion_damping<=0.0:
		_filtered_aim = target
		_aim_filter_ready = true
	else:
		# Original curve: 6-366ms orientation time constant (0-200%); legacy100%=96ms unchanged. Position is exact.
		var tau := aim_smoothing_time_constant()
		var blend := 1.0-exp(-maxf(delta,0.0)/tau)
		_filtered_aim = _filtered_aim.slerp(target,blend).orthonormalized()
	#086 Only the published crosshair/optic ray is damped; tracked geometry stays direct.

func _input_allowed() -> bool:
	if is_instance_valid(player) and player.get_meta("tactical_map1000",false):return false
	if has_meta("lobby_preview097"):return bool(get_meta("lobby_preview097"))
	return not _has_player_input_gate or (bool(player.get("input_enabled")) and player.get("inventory_open")!=true)

func _hand_valid(hand: XRController3D) -> bool:
	if hand == null:
		return false
	if player != null and player.has_method("is_hand_tracked"):
		return bool(player.call("is_hand_tracked", hand))
	return true

func _hand_input_ready(hand: XRController3D) -> bool:
	if not _hand_valid(hand):
		return false
	if player != null and player.has_method("is_hand_input_ready"):
		return bool(player.call("is_hand_input_ready", hand))
	return true

func get_hip_magazine_transform() -> Transform3D:
	# Legacy API retained for test/save compatibility; the source is now rifle-local.
	return get_offered_magazine_transform()


## Shared local forward-pitch correction for tracked grip art and weapon aim.
static func corrected_grip_transform(raw: Transform3D) -> Transform3D:
	return raw * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)

func get_offered_magazine_transform() -> Transform3D:
	return Transform3D(global_basis.scaled(Vector3.ONE*visual_model_scale()), reload_world_point(get_magazine_offer_point()))

func get_magazine_offer_point() -> Vector3:
	return OFFER_POINT

func get_magazine_insert_point() -> Vector3:
	return INSERT_POINT

func reset_weapon() -> void:
	_release_support_visual()
	ammo = magazine_size
	_seated_rounds=0
	_displayed_pose_valid=false;_external_aim_publication=false
	reload_state = "ready"
	cooldown = 0.0
	recoil = 0.0
	recoil_pitch = 0.0
	recoil_yaw=0.0
	recoil_pattern_index=0
	recoil_idle=0.0
	_reticle_bounce_pitch_071=0.0;_bounce_events_091.clear()
	_reference_clock=0.0;_reference_shots.clear()
	_measured_recoil_target=0.0
	_observed_burst_time=0.0;_observed_burst_active=false
	_observed_shot_supported=false
	supported = false
	_support_latched = false
	_support_grip_previous = true
	_aim_filter_ready = false
	_support_weight = 0.0
	_rack_grabbed = false
	_rack_start = Vector3.ZERO
	_grip_previous = false
	_eject_previous = false
	_eject_click_previous = true
	_trigger_previous = false
	_requires_trigger_release = true
	_resume_grip_release = false
	_flash_time = 0.0
	_empty_click = 0.0
	_carrier_time = 0.0
	_clear_debris()
	if _has_hand_reservation:
		_reserve_support_hand(false)
	if model != null:
		model.position = Vector3.ZERO
		model.rotation = Vector3.ZERO
		magazine.visible = true
		loose_magazine.visible = false
		muzzle_flash.visible = false
		guide.visible = false
		hip_source.visible = false
		charging_arrow.visible = false
		insertion_arrow.visible = false
		bolt.position = charging_rest_point()
		bolt.material_override = _bolt_finish
		firing_carrier.position.z = -0.11
		ammo_label.text = "%02d" % ammo
	if _sound != null:
		_sound.stop()
	for voice in _shot_voices:
		voice.stop()

func _suspend_gestures() -> void:
	_bounce_events_091.clear();_reticle_bounce_pitch_071=0.0
	_displayed_pose_valid=false;_external_aim_publication=false
	_suspend_left_gestures()
	_aim_filter_ready = false
	_eject_previous = true
	_eject_click_previous = true
	_requires_trigger_release = true

func _suspend_left_gestures() -> void:
	_release_support_visual()
	# Losing the offhand must cancel its mechanical contact as well as its input.
	_rack_grabbed = false
	_rack_start = Vector3.ZERO
	_grip_previous = true
	_resume_grip_release = true
	supported = false
	_support_latched = false
	_support_grip_previous = true
	_support_weight = 0.0
	if bolt != null:
		bolt.position = charging_rest_point()
	if _has_hand_reservation:
		_reserve_support_hand(reload_state != "ready")

func _process(delta: float) -> void:
	if model == null:
		return
	_reference_clock+=maxf(delta,0.0)
	while not _reference_shots.is_empty() and _reference_clock-_reference_shots[0]>1.2:_reference_shots.pop_front()
	if not _input_allowed():
		if _sound != null: _sound.stop()
		for voice in _shot_voices: voice.stop()
	_cooldown_overrun=clampf(delta-cooldown,0,fire_interval) if cooldown>0 and _input_allowed() else 0.0
	cooldown = maxf(0.0, cooldown - delta)
	_empty_click = maxf(0.0, _empty_click - delta)
	_recover_recoil(delta)
	_flash_time = maxf(0.0, _flash_time - delta)
	muzzle_flash.visible = _flash_time > 0.0
	_apply_recoil_visual()
	_carrier_time = maxf(0.0,_carrier_time-delta)
	# The internal carrier cycles; the player-operated charging handle never moves here.
	var cycle := clampf(_carrier_time/0.095,0.0,1.0)
	firing_carrier.position.z = -0.11 + sin(cycle*PI)*0.038
	if _vr_active():
		global_transform = corrected_grip_transform(right_hand.global_transform)
		_update_support(delta)
		_apply_aim_filter(delta)
		if not preload("res://scripts/reticle_bounce_071.gd").profile(self).is_empty():_apply_recoil_visual() #085 use current tracked roll axis
		_poll_vr()
		_update_support_visual()
		model.visible = _hand_valid(right_hand) and not (_weapon_hand_climbing())
	elif camera != null:
		global_transform = camera.global_transform
		position += global_basis * Vector3(0.22, -0.24, -0.55)
		if not _desktop_signals and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			fire()
	if loose_magazine != null:
		loose_magazine.visible = reload_state == "held_mag" and _input_allowed() and (not _vr_active() or _hand_valid(left_hand))
		if loose_magazine.visible and left_hand != null and _vr_active():
			loose_magazine.global_transform = corrected_grip_transform(left_hand.global_transform)*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*visual_model_scale()),Vector3.ZERO)
	magazine.visible = reload_state == "ready" or reload_state == "needs_rack"
	ammo_label.text = "%02d" % ammo if reload_state == "ready" else {"needs_mag":"MAG", "held_mag":"INSERT", "needs_rack":"RACK"}.get(reload_state, "")
	guide.hide() #089 arrows provide the whole spatial cue
	hip_source.visible = reload_state == "needs_mag" and _input_allowed() and reserve_rounds()!=0
	if hip_source.visible:
		hip_source.global_transform = get_offered_magazine_transform()
	insertion_arrow.visible = reload_state in ["needs_mag", "held_mag"] and _input_allowed()
	charging_arrow.visible = reload_state == "needs_rack" and _input_allowed()
	bolt.material_override = _reload_finish if reload_state == "needs_rack" else _bolt_finish
	guide.position = charging_grip_point() if reload_state == "needs_rack" else get_magazine_insert_point()
	guide.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.13)
	preload("res://scripts/reload_visuals_089.gd").apply(self)
	update_ammo_display()
	if _input_allowed() and model.visible and not _external_aim_publication:
		_displayed_shot_pose=get_visual_reticle_pose_071(get_shot_transform());_displayed_pose_valid=true

func _unhandled_input(event: InputEvent) -> void:
	if not _desktop_signals and not _vr_active() and event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == KEY_R:
			desktop_reload_step()

func fire() -> void:
	if model == null or cooldown > 0.0:
		return
	if not _input_allowed():
		return
	if _vr_active() and not _hand_input_ready(right_hand):
		return
	if _vr_active() and _has_head_obstruction and player.get("head_obstructed"):
		return
	if _vr_active() and _weapon_hand_climbing():
		return
	if reload_state != "ready":
		return
	if ammo <= 0:
		# Recover legacy ready/empty state through the same automatic eject path.
		eject_magazine()
		return
	ammo -= 1
	cooldown = maxf(.001,fire_interval-_cooldown_overrun)
	_cooldown_overrun=0
	_flash_time = 0.045
	_carrier_time = 0.095
	_eject_casing()
	var shot_pose := get_firing_pose()
	_kick_recoil(0.052, deg_to_rad(5.5))
	var origin: Vector3 = shot_pose.origin
	var direction: Vector3 = -shot_pose.basis.z
	if not _vr_active() and camera != null:
		# Desktop debug uses the exact crosshair ray, including nearby obstruction.
		origin = camera.global_position
		direction = -shot_pose.basis.z
	shot.emit(origin, direction.normalized(), damage)
	_haptic(right_hand, 0.5, 0.055)
	_play_shot()
	if ammo == 0:
		eject_magazine()

func eject_magazine() -> void:
	if reload_state not in ["ready","needs_rack"]:return
	if not _return_magazine_rounds():return
	_drop_spent_magazine()
	_requires_trigger_release = true
	_set_stage("needs_mag", "Grip the fresh magazine below the rifle and push it upward")
	_haptic(right_hand, 0.24, 0.07)

func grab_magazine() -> void:
	if _support_hand_climbing() or reserve_rounds()==0:return
	if reload_state == "needs_mag":
		_mag_grab_local = reload_local_point(left_hand.global_position) if left_hand != null else get_magazine_offer_point()
		_set_stage("held_mag", "Bring magazine to the illuminated well beneath the rifle")
		_haptic(left_hand, 0.34, 0.06)

func insert_magazine() -> void:
	if _support_hand_climbing():return
	if reload_state == "held_mag":
		_seated_rounds=take_reserve(magazine_size)
		if _seated_rounds<=0:return
		_set_stage("needs_rack", "Magazine seated — release grip, then pull the cyan charging handle back")
		_haptic(left_hand, 0.65, 0.085)
		_rack_grabbed = false

func rack_bolt() -> void:
	if _support_hand_climbing():return
	if reload_state == "needs_rack":
		ammo = _seated_rounds
		_seated_rounds=0
		_requires_trigger_release = true
		_set_stage("ready", "Chambered / %d rounds" % ammo)
		_haptic(left_hand, 0.5, 0.08)
		_rack_grabbed = false
		bolt.position = charging_rest_point()

func desktop_reload_step() -> void:
	if not _input_allowed():
		return
	match reload_state:
		"ready": eject_magazine()
		"needs_mag":
			grab_magazine()
			insert_magazine()
		"held_mag": insert_magazine()
		"needs_rack": rack_bolt()

func _set_stage(stage: String, message: String) -> void:
	var previous_stage:=reload_state
	reload_state = stage
	network_reload_stage1000.emit(stage)
	# Stage changes are immediately visible, including the final fired round.
	if magazine != null: magazine.visible = stage in ["ready", "needs_rack"]
	if loose_magazine != null: loose_magazine.visible = stage == "held_mag" and _input_allowed() and (not _vr_active() or _hand_valid(left_hand))
	if hip_source != null: hip_source.visible = stage == "needs_mag" and _input_allowed() and reserve_rounds()!=0
	if stage!="ready":
		_support_latched = false
		_support_grip_previous = true
		supported = false
		_support_weight = 0.0
	if _has_hand_reservation:
		_reserve_support_hand(stage != "ready" or supported)
	# Reload stages use geometry/audio/haptics; no instructional HUD text.
	var cue:String=reload_cue0991(previous_stage,stage)
	if not cue.is_empty():_play(AudioBank.for_weapon(self,cue,_audio_variant))
	_audio_variant += 1
	cooldown = 0.12
	update_ammo_display()

static func reload_cue0991(before:String,after:String)->String:
	# A fired bolt-action entering its empty-chamber state is not a magazine insertion.
	if after in ["needs_bolt","needs_rack"] and before=="ready":return ""
	return {"needs_mag":"mag_eject","held_mag":"pouch","needs_rack":"mag_insert","needs_bolt":"mag_insert","ready":"bolt","cylinder_open":"mag_eject","cylinder_loaded":"mag_insert","cover_open":"open","box_removed":"mag_eject","holding_box":"pouch","needs_feed":"mag_insert","box_seated":"mag_insert","needs_charge":"close"}.get(after,"")

func _poll_vr() -> void:
	if not _input_allowed() or not _hand_input_ready(right_hand):
		_suspend_gestures()
		return
	var trigger: bool = right_hand.get_float("trigger") > 0.65 or right_hand.is_button_pressed("trigger_click")
	var eject_click := right_hand.is_button_pressed("primary_click")
	if eject_click and not _eject_click_previous and manual_click_eject_allowed():
		eject_magazine()
	_eject_click_previous = eject_click
	var stick := right_hand.get_vector2("primary")
	if stick.length() < 0.25:
		_eject_previous = false
	elif stick.y < -0.7 and absf(stick.x) < 0.5 and not _eject_previous:
		eject_magazine()
		_eject_previous = true
	if not trigger:
		_requires_trigger_release = false
	if trigger and not _requires_trigger_release:
		fire()
	_trigger_previous = trigger
	if not _hand_input_ready(left_hand) or _support_grip_reserved():
		_suspend_left_gestures()
		return
	var grip: bool = left_hand.get_float("grip") > 0.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:
			return
		_resume_grip_release = false
	var hand_pos: Vector3 = left_hand.global_position
	if reload_state == "needs_mag" and grip and not _grip_previous:
		if _in_reload_reach(reload_local_point(hand_pos), get_magazine_offer_point(), 0.10):
			grab_magazine()
	elif reload_state == "held_mag":
		var upward_travel := reload_local_point(hand_pos).y - _mag_grab_local.y
		if grip and upward_travel >= 0.06 and _in_reload_reach(reload_local_point(hand_pos), get_magazine_insert_point(), 0.10):
			insert_magazine()
		elif not grip:
			_set_stage("needs_mag", "Magazine released - grip the fresh magazine below the rifle")
	elif reload_state == "needs_rack":
		if grip and not _grip_previous and not _rack_grabbed and _in_reload_reach(reload_local_point(hand_pos), charging_grip_point(), 0.18):
			_rack_grabbed = true
			_rack_start = reload_local_point(hand_pos)
			_haptic(left_hand, 0.25, 0.04)
		if _rack_grabbed and grip:
			var travel: float = reload_local_point(hand_pos).z - _rack_start.z
			bolt.position = charging_rest_point()+Vector3.BACK*clampf(travel, 0.0, 0.09)
			if travel >= 0.075:
				rack_bolt()
		if not grip:
			_rack_grabbed = false
			bolt.position = charging_rest_point()
	_grip_previous = grip

func _in_reload_reach(point: Vector3, center: Vector3, radius: float) -> bool:
	# Preserve the old spherical volume, plus modest lateral/forward reach.
	# Project added reach out before the original sphere test; no extra height.
	if not point.is_finite() or not center.is_finite() or point.distance_to(center)*reload_frame_scale()>.34:return false
	var offset := (point-center)*reload_frame_scale()
	offset.x = signf(offset.x)*maxf(0.0,absf(offset.x)-RELOAD_LATERAL_EXTRA)
	if offset.z < 0.0: offset.z = minf(0.0,offset.z+RELOAD_FORWARD_EXTRA)
	return offset.length() < minf(radius+.055,.30)

func get_reload_zones()->Array:
	match reload_state:
		"needs_mag":return [{"position":get_magazine_offer_point(),"radius":.10}]
		"held_mag":return [{"position":get_magazine_insert_point(),"radius":.10}]
		"needs_rack":return [{"position":charging_grip_point(),"radius":.18}]
	return []

func reload_grip_in_progress()->bool:return reload_state=="held_mag" or _rack_grabbed

func reload_claims_hand(hand:Node3D)->bool:
	# Proximity arbitration never steals an existing wall/objective grip.
	if hand!=left_hand or not is_visible_in_tree() or not _input_allowed() or _support_hand_climbing():return false
	if player!=null and player.has_method("is_hand_input_ready") and not player.is_hand_input_ready(hand):return false
	if player!=null and player.has_method("is_hand_grip_reserved") and player.is_hand_grip_reserved(hand):return false
	if hand.get_float("grip")>.2 and reload_grip_in_progress():return true
	var point:=reload_local_point(hand.global_position)
	for zone in get_reload_zones():
		if _in_reload_reach(point,zone.position,zone.radius):return true
	return false

func _update_support(delta: float) -> void:
	if not _input_allowed() or not _hand_input_ready(right_hand) or not _hand_input_ready(left_hand) or _support_grip_reserved():
		_suspend_left_gestures()
		return
	var was_supported: bool = supported
	supported = false
	var gripping: bool = left_hand.get_float("grip") > 0.55 or left_hand.is_button_pressed("grip_click")
	var fresh_grip := gripping and not _support_grip_previous
	if left_hand != null and reload_state == "ready" and not _resume_grip_release:
		var can_support: bool = not (_has_climb_state and (player.get("climbing_left") or player.get("climbing_right")))
		# Use the un-kicked grip frame: muzzle recoil must not break an attached grip.
		var fore_end: Vector3 = reload_world_point(FOREGRIP_POINT)
		var reach: float = FOREGRIP_RELEASE if was_supported else FOREGRIP_ACQUIRE
		var distance := left_hand.global_position.distance_to(fore_end)
		if not can_support or distance>=reach:
			_support_latched = false
		elif grip_toggle and fresh_grip:
			_support_latched = not _support_latched
		supported = can_support and distance<reach and (_support_latched if grip_toggle else gripping)
	else:
		_support_latched = false
	_support_grip_previous = gripping
	_support_weight = move_toward(_support_weight, 1.0 if supported else 0.0, delta * 9.0)
	if _support_weight > 0.001 and left_hand != null:
		var grip_basis: Basis = corrected_grip_transform(right_hand.global_transform).basis
		var forward: Vector3 = left_hand.global_position + grip_basis.y * 0.025 - right_hand.global_position
		if forward.length() > 0.15:
			forward = forward.normalized()
			# Right controller remains authoritative; blend only within a plausible cone.
			if forward.dot(-grip_basis.z) > 0.80:
				var support_basis: Basis = Basis.looking_at(forward, grip_basis.y)
				global_basis = grip_basis.slerp(support_basis, _support_weight * offhand_influence).orthonormalized()
	if supported and not was_supported:
		_haptic(left_hand, 0.16, 0.035)
	if _has_hand_reservation:
		_reserve_support_hand(reload_state != "ready" or supported)
	_update_support_visual()

func _recover_recoil(delta: float) -> void:
	var presentation:Dictionary=preload("res://scripts/reticle_bounce_071.gd").profile(self)
	if not presentation.is_empty():
		_reticle_bounce_pitch_071=0
		for i in range(_bounce_events_091.size()-1,-1,-1):
			_bounce_events_091[i].x+=maxf(0,delta)
			if _bounce_events_091[i].x>=float(presentation.end_s):_bounce_events_091.remove_at(i);continue
			_reticle_bounce_pitch_071+=_bounce_events_091[i].y*preload("res://scripts/reticle_bounce_071.gd").pulse(_bounce_events_091[i].x,presentation)
		var cap:float=deg_to_rad(float(presentation.peak_deg))*1.5
		_reticle_bounce_pitch_071=clampf(_reticle_bounce_pitch_071,-cap,cap)
	if _endpoint_experiment_enabled():
		var recovery:=exp(-maxf(delta,0.0)*9.0)
		recoil*=recovery;recoil_idle+=maxf(delta,0.0)
		if recoil_idle>maxf(.18,minf(fire_interval*1.15,.5)):
			recoil_pitch*=recovery;recoil_yaw*=recovery
		if recoil_idle>=.8:recoil_pattern_index=0;recoil=0;recoil_pitch=0;recoil_yaw=0
		return
	var reference_id:=str(get_meta("reference_id",""))
	if ObservedRecoil.has_profile(reference_id):
		recoil_idle+=maxf(delta,0.0);recoil*=exp(-maxf(delta,0.0)*9.0)
		if _observed_burst_active:
			if recoil_idle<=float(ObservedRecoil.manifest().release_hold_s):
				_observed_burst_time+=maxf(delta,0.0)
				# Empty/reload can release the support grip after the final shot.
				# Recovery retains that shot's hand condition; no unearned one-hand jump.
				var observed:Vector2=ObservedRecoil.sample(reference_id,_observed_shot_supported,_observed_burst_time)*(1.1 if reference_id=="mp5" else 1.0)
				# Film yaw is positive RIGHT; Godot positive Y Euler turns LEFT.
				recoil_pitch=deg_to_rad(observed.x);recoil_yaw=-deg_to_rad(observed.y)
			else:
				var release:=exp(-maxf(delta,0.0)*float(ObservedRecoil.manifest().release_decay))
				recoil_pitch*=release;recoil_yaw*=release
		if recoil_idle>=float(ObservedRecoil.manifest().reset_s):
			recoil_pattern_index=0;recoil=0;recoil_pitch=0;recoil_yaw=0
			_observed_burst_time=0;_observed_burst_active=false
		return
	var measured:Dictionary=preload("res://scripts/reference_response.gd").manifest().get("recoil_fits",{}).get(str(get_meta("reference_id","")),{})
	if not measured.is_empty():
		recoil_idle+=maxf(delta,0.0);recoil*=exp(-maxf(delta,0.0)*9.0)
		if recoil_idle>float(measured.release_hold_s):_measured_recoil_target*=exp(-maxf(delta,0.0)*float(measured.release_decay))
		recoil_pitch=lerpf(recoil_pitch,_measured_recoil_target,1.0-exp(-maxf(delta,0.0)/float(measured.rise_time_constant_s)))
		if recoil_idle>=.8:recoil_pattern_index=0;recoil=0;recoil_pitch=0;recoil_yaw=0;_measured_recoil_target=0
		return
	# ~77ms half-life gives the kick several visible frames at headset refresh.
	# Al's requested FAL settling time is 30% faster; other guns retain recovery.
	var semi_return:float=.85 if reference_id in ["spr","matadors"] else 1.0
	var recovery := exp(-maxf(delta, 0.0) * 9.0 * semi_return * (2.0 if reference_id=="s85" else (1.3 if reference_id=="fal" else 1.0)))
	recoil *= recovery
	recoil_idle+=maxf(delta,0.0)
	# Hold accumulated angular kick between sustained shots. Releasing a burst
	# lets it settle; no random aim offsets or per-frame hidden drift are used.
	if recoil_idle>(.08 if reference_id=="s85" else maxf(.18,minf(fire_interval*1.15,.5))):
		recoil_pitch *= recovery
		recoil_yaw *= recovery
	if recoil_idle>=0.8:
		recoil_pattern_index=0
		recoil=0.0;recoil_pitch=0.0;recoil_yaw=0.0

func _rfb_support_scale0992()->float:
	return .4 if supported and str(get_meta("reference_id",""))=="rfb" else 1.0

func _apply_recoil_visual() -> void:
	if model == null: return
	model.position.z = recoil*RECOIL_GAIN_089*_rfb_support_scale0992()
	model.rotation=Vector3(recoil_pitch,recoil_yaw,0)*RECOIL_GAIN_089*_rfb_support_scale0992()
	#085 align the visible semi-auto barrel with its shared upward reticle pulse.
	if not preload("res://scripts/reticle_bounce_071.gd").profile(self).is_empty():
		var fitted:=model.scale
		var forward:Vector3=-global_basis.z.normalized();var axis:Vector3=forward.cross(Vector3.UP)
		if axis.length_squared()<.00000001:axis=Vector3.RIGHT-forward*forward.dot(Vector3.RIGHT)
		var rise:=clampf(_reticle_bounce_pitch_071*RECOIL_GAIN_089,-acos(clampf(forward.dot(Vector3.DOWN),-1,1)),acos(clampf(forward.dot(Vector3.UP),-1,1)))
		model.basis=(global_basis.inverse()*Basis(axis.normalized(),rise)*global_basis).scaled(fitted)

func _kick_recoil(distance: float, angle: float) -> void:
	if _endpoint_experiment_enabled():
		_record_reference_shot()
		var id:=str(get_meta("reference_id",""))
		var pattern:Vector2=RECOIL_PATTERN[recoil_pattern_index%RECOIL_PATTERN.size()]
		var reduction:=.38 if supported and id!="rfb" else 1.0
		recoil_pattern_index+=1;recoil_idle=0.0
		# Current ray was captured before this kick. Set the next shot endpoint,
		# avoiding time-sample aliasing and repeated six-shot vertical spikes.
		var next:Vector2=EndpointExperiment.sample(id,supported and id!="rfb",recoil_pattern_index)
		recoil_pitch=deg_to_rad(next.x)
		if EndpointExperiment.keep_yaw(id):recoil_yaw=clampf(recoil_yaw+angle*reduction*pattern.y,-deg_to_rad(80),deg_to_rad(80))
		else:recoil_yaw=-deg_to_rad(next.y)
		recoil=minf(recoil+distance*reduction,.13)
		_apply_recoil_visual();_update_support_visual();return
	_record_reference_shot()
	var reference_id:=str(get_meta("reference_id",""))
	if ObservedRecoil.has_profile(reference_id):
		if not _observed_burst_active or recoil_idle>float(ObservedRecoil.manifest().release_hold_s):
			_observed_burst_time=0.0
		_observed_burst_active=true
		_observed_shot_supported=supported
		var observed:Vector2=ObservedRecoil.sample(reference_id,supported,_observed_burst_time)*(1.1 if reference_id=="mp5" else 1.0)
		recoil_pitch=deg_to_rad(observed.x);recoil_yaw=-deg_to_rad(observed.y)
		recoil_pattern_index+=1;recoil_idle=0.0
		recoil=minf(recoil+distance*(.38 if supported else 1.0),.13)
		_apply_recoil_visual();_update_support_visual();return
	var measured:Dictionary=preload("res://scripts/reference_response.gd").manifest().get("recoil_fits",{}).get(str(get_meta("reference_id","")),{})
	if not measured.is_empty():
		var increments:Array=measured.per_shot_pitch_increment_deg
		var gain:float=float(measured.supported_gain) if supported else 1.0
		var increment:float=float(increments[mini(recoil_pattern_index,increments.size()-1)])
		_measured_recoil_target=minf(_measured_recoil_target+deg_to_rad(increment)*gain,deg_to_rad(float(measured.supported_cap_deg) if supported else 45.0))
		recoil_pattern_index+=1;recoil_idle=0.0
		recoil=minf(recoil+distance*gain,.13)
		_apply_recoil_visual();_update_support_visual();return
	var reduction := 0.38 if supported and reference_id!="rfb" else 1.0
	if reference_id in ["spr","matadors"]:angle*=1.1 #085 modest semi-auto bounce
	var pattern:=RECOIL_PATTERN[recoil_pattern_index%RECOIL_PATTERN.size()]
	var vertical:Array=VERTICAL_RECOIL_PROFILES[get_recoil_profile_key()]
	var increment:float=vertical[recoil_pattern_index%vertical.size()]
	recoil_pattern_index+=1
	recoil_idle=0.0
	var cap_multiplier:=1.0
	recoil = minf(recoil + distance * reduction, 0.13*cap_multiplier)
	recoil_pitch = clampf(recoil_pitch + angle * reduction * increment,0.0,deg_to_rad(45.0)*cap_multiplier)
	recoil_yaw = clampf(recoil_yaw + angle * reduction * pattern.y,-deg_to_rad(80),deg_to_rad(80))
	_apply_recoil_visual()
	_update_support_visual()

func _record_reference_shot()->void:
	_reference_shots.append(_reference_clock)
	var presentation:Dictionary=preload("res://scripts/reticle_bounce_071.gd").profile(self)
	if not presentation.is_empty():
		var peak:float=deg_to_rad(float(presentation.peak_deg))*(.38 if supported else 1.0)
		_bounce_events_091.append(Vector2(0,peak))
		if _bounce_events_091.size()>8:_bounce_events_091.pop_front()
func get_visual_reticle_pose_071(ballistic_pose:Transform3D)->Transform3D:
	var bounce=preload("res://scripts/reticle_bounce_071.gd")
	var has_pulse:bool=not bounce.profile(self).is_empty() and model!=null
	# Smooth the neutral aim first. Rotating an already world-upright pulse
	# by a lagging wrist-roll correction would turn that pulse sideways.
	var pose:Transform3D=bounce.presentation_pose(self,ballistic_pose,0.0)
	if _aim_filter_ready and _vr_active():pose.basis=(_filtered_aim*global_basis.orthonormalized().inverse()*pose.basis).orthonormalized()
	if has_pulse:pose=bounce.upright_pulse(pose,_reticle_bounce_pitch_071*RECOIL_GAIN_089)
	return pose
func get_reference_bloom()->float:
	var p:Dictionary=preload("res://scripts/reference_response.gd").profile(self)
	var tau:float=float(p.get("bloom_tau_s",.055))
	var result:=0.0
	for stamp in _reference_shots:
		var age:=(_reference_clock-stamp)/maxf(tau,.001)
		result+=age*exp(1.0-age)
	var impulse:float=float(p.get("supported_bloom_impulse_px",p.get("bloom_impulse_px",0.0)) if supported else p.get("bloom_impulse_px",0.0))
	return minf(float(p.get("bloom_cap_px",120.0)),result*impulse)

func get_recoil_profile_key()->String:
	var configured:String=get_meta("recoil_profile","")
	if VERTICAL_RECOIL_PROFILES.has(configured):return configured
	var script:Script=get_script()
	while script!=null:
		var key:=script.resource_path.get_file().get_basename()
		if VERTICAL_RECOIL_PROFILES.has(key):return key
		script=script.get_base_script()
	return "weapon"

func get_shot_transform() -> Transform3D:
	if has_meta("download_muzzle_084"):return fitted_download_shot()
	# Every shot applies its deterministic kick before emission; this is the current visible barrel pose.
	if model == null: return Transform3D(global_basis,to_global(Vector3(0,0.045,-0.69)))
	return Transform3D(unit_model_basis(), model.to_global(Vector3(0, 0.045, -0.69)))

func _release_support_visual() -> void:
	if is_instance_valid(_attached_visual): _attached_visual.transform = _attached_rest
	_attached_visual = null

func _update_support_visual() -> void:
	if not supported or not visible or left_hand == null:
		_release_support_visual()
		return
	var visual := left_hand.get_node_or_null("ArticulatedGlove") as Node3D
	if visual == null: return
	if _attached_visual != visual:
		_release_support_visual()
		_attached_visual = visual
		_attached_rest = visual.transform
	# Snap only the rendered glove to contact. The XR pose remains authoritative for
	# distance/release and all reload, climbing and objective arbitration.
	var relative_roll := corrected_grip_transform(left_hand.global_transform).basis.inverse() * (left_hand.global_basis * _attached_rest.basis)
	visual.global_transform = Transform3D(unit_model_basis() * relative_roll, model.to_global(FOREGRIP_POINT))

func _haptic(hand: XRController3D, strength: float, duration: float) -> void:
	if hand != null and _vr_active():
		hand.trigger_haptic_pulse("haptic", 0.0, strength, duration, 0.0)

func _play(stream: AudioStreamWAV) -> void:
	if _sound != null and stream != null:
		_sound.stream = stream
		_sound.pitch_scale = randf_range(0.985, 1.015)
		_sound.play()

func _play_shot() -> void:
	if _shot_voices.is_empty():
		return
	var voice := _shot_voices[_shot_voice_cursor]
	_shot_voice_cursor = (_shot_voice_cursor+1)%_shot_voices.size()
	voice.stop()
	voice.stream = AudioBank.for_weapon(self,"shot",_audio_variant)
	_audio_variant += 1
	voice.pitch_scale = randf_range(0.985,1.015)
	voice.play()

func shutdown() -> void:
	_release_support_visual()
	set_process(false)
	set_physics_process(false)
	_clear_debris()
	if _sound != null:
		_sound.stop()
		_sound.stream = null
	for voice in _shot_voices:
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	_release_support_visual()
	shutdown()

func _build_debris_pool() -> void:
	if not _debris.is_empty(): return
	_cosmetic_rng.seed = 814773
	var brass := _material(Color(0.45,0.30,0.10),0.72,0.36)
	var spent := _material(Color(0.28,0.25,0.19),0.25,0.64)
	for i in range(CASING_POOL_SIZE+MAGAZINE_POOL_SIZE):
		var piece: MeshInstance3D
		if i<CASING_POOL_SIZE:
			piece = _rod(Vector3(0,-0.014,0),Vector3(0,0.014,0),0.0045,brass,8,self)
		else:
			piece = _beveled(Vector3(0.047,0.155,0.072),Vector3.ZERO,spent,0.009,self)
		piece.name = "CosmeticCasing" if i<CASING_POOL_SIZE else "SpentMagazine"
		piece.top_level = true
		piece.visible = false
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_debris.append(piece)
		_debris_velocity.append(Vector3.ZERO)
		_debris_spin.append(Vector3.ZERO)
		_debris_life.append(0.0)
		_debris_rest.append(false)

func _clear_debris() -> void:
	for i in range(_debris.size()):
		_debris[i].visible = false
		_debris_life[i] = 0.0
		_debris_velocity[i] = Vector3.ZERO
		_debris_spin[i] = Vector3.ZERO
		_debris_rest[i] = false

func _eject_casing() -> void:
	if _debris.is_empty(): return
	var index := _casing_cursor
	_casing_cursor = (_casing_cursor+1)%CASING_POOL_SIZE
	var pose := Transform3D(unit_model_basis(),model.to_global(Vector3(0.043,0.043,-0.10)))
	var launch := model.global_basis*Vector3(_cosmetic_rng.randf_range(1.3,1.9),_cosmetic_rng.randf_range(0.6,1.0),0.2)
	_activate_debris(index,pose,launch,2.8)

func _drop_spent_magazine() -> void:
	if _debris.is_empty() or magazine==null: return
	var index := CASING_POOL_SIZE+_magazine_cursor
	_magazine_cursor = (_magazine_cursor+1)%MAGAZINE_POOL_SIZE
	var eject_pose := magazine.global_transform
	# Place the spent prop 30% closer to the gun grip than its seated-model offset.
	eject_pose.origin = model.to_global(magazine.position * 0.7)
	_activate_debris(index,eject_pose,global_basis*Vector3(0.08,-0.6,0.08),4.5)

func _activate_debris(index: int, pose: Transform3D, launch: Vector3, lifetime: float) -> void:
	_debris[index].global_transform = pose
	_debris[index].visible = true
	_debris_life[index] = lifetime
	_debris_rest[index] = false
	var inherited := Vector3.ZERO
	if player is CharacterBody3D: inherited = player.velocity.limit_length(7.0)
	_debris_velocity[index] = launch+inherited
	_debris_spin[index] = Vector3(_cosmetic_rng.randf_range(-8,8),_cosmetic_rng.randf_range(-9,9),_cosmetic_rng.randf_range(-7,7))

func _physics_process(delta: float) -> void:
	if not _input_allowed(): return
	var step := minf(delta,0.05)
	for i in range(_debris.size()):
		if _debris_life[i]<=0.0: continue
		_debris_life[i] = maxf(0.0,_debris_life[i]-delta)
		if _debris_life[i]<=0.0:
			_debris[i].visible = false
			continue
		if _debris_rest[i]: continue
		var piece := _debris[i]
		var start := piece.global_position
		_debris_velocity[i].y -= 9.8*step
		var target := start+_debris_velocity[i]*step
		var query := PhysicsRayQueryParameters3D.create(start,target,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var padding := 0.006 if i<CASING_POOL_SIZE else 0.042
			piece.global_position = hit.position+hit.normal*padding
			_debris_velocity[i] = _debris_velocity[i].bounce(hit.normal)*0.28
			_debris_spin[i] *= 0.4
			if _debris_velocity[i].length()<0.65:
				_debris_rest[i] = true
				# Spent magazines settle on their broad side; never enter pickup groups.
				if i>=CASING_POOL_SIZE and hit.normal.y>0.7:
					piece.rotation = Vector3(PI*0.5,piece.rotation.y,0)
		else:
			piece.global_position = target
		piece.rotation += _debris_spin[i]*step

func _material(color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	(parent if parent != null else model).add_child(mesh)
	mesh.position = pos
	return mesh

func _beveled(size: Vector3, pos: Vector3, mat: Material, bevel: float = 0.008, parent: Node3D = null) -> MeshInstance3D:
	# An eight-sided extrusion gives real edge normals rather than painted highlights.
	var x: float = size.x * 0.5
	var y: float = size.y * 0.5
	var z: float = size.z * 0.5
	var b: float = minf(bevel, minf(x, y) * 0.6)
	var ring: Array[Vector2] = [Vector2(-x+b,-y), Vector2(x-b,-y), Vector2(x,-y+b), Vector2(x,y-b), Vector2(x-b,y), Vector2(-x+b,y), Vector2(-x,y-b), Vector2(-x,-y+b)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a := Vector3(ring[i].x, ring[i].y, -z)
		var c := Vector3(ring[(i+1)%8].x, ring[(i+1)%8].y, -z)
		var d := Vector3(c.x, c.y, z)
		var e := Vector3(a.x, a.y, z)
		var normal: Vector3 = Vector3(c.y-a.y, a.x-c.x, 0).normalized()
		for vertex in [a,e,d,a,d,c]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
		for vertex in [Vector3(0,0,-z),a,c]:
			surface.set_normal(Vector3.FORWARD)
			surface.add_vertex(vertex)
		for vertex in [Vector3(0,0,z),d,e]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(vertex)
	surface.index()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = mat
	(parent if parent != null else model).add_child(mesh)
	mesh.position = pos
	return mesh

func _rod(a: Vector3, b: Vector3, radius: float, mat: Material, sides: int = 12, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = sides
	shape.rings = 1
	mesh.mesh = shape
	mesh.material_override = mat
	(parent if parent != null else model).add_child(mesh)
	mesh.position = (a+b) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return mesh

func _finish_grain() -> ImageTexture:
	# Restrained, original coating grain with mipmaps; no painted camouflage.
	var texture_image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81424
	for y in range(64):
		for x in range(64):
			var value: float = rng.randf_range(0.93, 1.0)
			texture_image.set_pixel(x, y, Color(value, value, value))
	texture_image.generate_mipmaps()
	return ImageTexture.create_from_image(texture_image)

func _merge_static_parts() -> void:
	# Keep moving parts separate, batch stationary hardware by shared finish.
	var groups: Dictionary = {}
	for child in model.get_children():
		if child is MeshInstance3D and child not in [magazine, bolt, firing_carrier, guide, muzzle_flash]:
			var mat: Material = child.material_override
			if not groups.has(mat):
				groups[mat] = []
			groups[mat].append(child)
	for mat in groups:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[mat]:
			for index in range(part.mesh.get_surface_count()):
				surface.append_from(part.mesh, index, part.transform)
			part.free()
		var merged := MeshInstance3D.new()
		merged.name = "StationaryHardware"
		merged.mesh = surface.commit()
		merged.material_override = mat
		model.add_child(merged)

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var steel := _material(Color(0.29, 0.32, 0.33), 0.65, 0.36)
	var edge := _material(Color(0.43, 0.44, 0.42), 0.8, 0.3)
	var dark := _material(Color(0.105, 0.12, 0.125), 0.45, 0.48)
	var rubber := _material(Color(0.13, 0.135, 0.12), 0.0, 0.82)
	var sand := _material(Color(0.37, 0.32, 0.23), 0.25, 0.6)
	var recess := _material(Color(0.018, 0.023, 0.026), 0.15, 0.78)
	var cyan := _material(Color(0.05, 0.72, 0.75), 0.2, 0.4, 0.65)
	var coating_grain := _finish_grain()
	for finish in [steel, dark, rubber, sand]:
		finish.albedo_texture = coating_grain
		finish.uv1_triplanar = true
		finish.uv1_scale = Vector3(12,12,12)
	_bolt_finish = steel
	_reload_finish = cyan
	_beveled(Vector3(0.073, 0.083, 0.32), Vector3(0, 0.035, -0.11), steel, 0.012)
	_beveled(Vector3(0.068, 0.034, 0.25), Vector3(0, -0.02, -0.10), dark, 0.006)
	_beveled(Vector3(0.068, 0.065, 0.235), Vector3(0, 0.036, -0.39), sand, 0.014)
	# Narrow machined shoulders catch the light; lower receiver has a distinct finish.
	for side in [-1.0,1.0]:
		_beveled(Vector3(0.003,0.006,0.24), Vector3(side*0.029,0.071,-0.11), edge, 0.001)
		_beveled(Vector3(0.002,0.021,0.094), Vector3(side*0.037,0.01,-0.207), dark, 0.0005)
		_box(Vector3(0.002,0.0015,0.19), Vector3(side*0.0365,-0.008,-0.10), recess)
	# Recessed top-cover groove stops before the sight and rear retaining pin.
	_box(Vector3(0.014,0.0015,0.057), Vector3(0,0.077,0.015), recess)
	_beveled(Vector3(0.009,0.002,0.048), Vector3(0,0.078,0.015), dark, 0.0005)
	# Barrel, collar and slotted muzzle brake are round, with a dark bore.
	_rod(Vector3(0,0.04,-0.49), Vector3(0,0.04,-0.66), 0.012, steel)
	_rod(Vector3(0,0.04,-0.50), Vector3(0,0.04,-0.54), 0.018, dark)
	_rod(Vector3(0,0.04,-0.65), Vector3(0,0.04,-0.71), 0.021, dark)
	_rod(Vector3(0,0.04,-0.711), Vector3(0,0.04,-0.713), 0.010, recess)
	for i in range(3):
		_box(Vector3(0.043,0.007,0.007), Vector3(0,0.04,-0.662-i*0.014), recess)
	# Stock has a buffer tube, open lower brace, cheek rest and rubber buttpad.
	_rod(Vector3(0,0.035,0.04), Vector3(0,0.035,0.235), 0.018, dark)
	var cheek := _rod(Vector3(0,0.043,0.105), Vector3(0,0.043,0.219), 0.025, sand, 16)
	cheek.scale.x = 1.12
	cheek.scale.z = 0.65
	_beveled(Vector3(0.049,0.012,0.11), Vector3(0,0.023,0.16), dark, 0.003)
	_rod(Vector3(0,-0.015,0.055), Vector3(0,-0.054,0.236), 0.009, steel)
	_beveled(Vector3(0.061,0.12,0.027), Vector3(0,0.0,0.24), rubber)
	# Stock adjustment latch and sling attachment are separated from the cushion.
	_beveled(Vector3(0.018,0.008,0.041), Vector3(-0.027,0.015,0.17), dark, 0.002)
	_rod(Vector3(-0.029,-0.026,0.205), Vector3(-0.034,-0.026,0.205), 0.008, steel, 12)
	_rod(Vector3(-0.034,-0.026,0.205), Vector3(-0.035,-0.026,0.205), 0.004, recess, 12)
	for i in range(6):
		_box(Vector3(0.062,0.003,0.004), Vector3(0,-0.045+i*0.017,0.255), dark)
	# Angled pistol grip, open trigger guard and inset curved trigger.
	var grip_mesh := _beveled(Vector3(0.043,0.115,0.058), Vector3(0,-0.083,0.012), rubber)
	grip_mesh.rotation.x = -0.24
	for i in range(5):
		_box(Vector3(0.045,0.003,0.036), Vector3(0,-0.055-i*0.015,0.008+i*0.003), dark)
	_rod(Vector3(0,-0.025,-0.013), Vector3(0,-0.068,-0.026), 0.004, dark)
	_rod(Vector3(0,-0.068,-0.026), Vector3(0,-0.068,-0.088), 0.004, dark)
	_rod(Vector3(0,-0.068,-0.088), Vector3(0,-0.025,-0.095), 0.004, dark)
	_rod(Vector3(0,-0.027,-0.056), Vector3(0,-0.052,-0.048), 0.003, steel)
	# Magazine ribs are children of the removable magazine, disappearing together.
	magazine = _beveled(Vector3(0.047,0.155,0.072), Vector3(0,-0.102,-0.15), sand, 0.009)
	magazine.rotation.x = -0.13
	for side in [-1.0,1.0]:
		for i in range(3):
			_beveled(Vector3(0.002,0.106,0.004), Vector3(side*0.024,-0.009,-0.022+i*0.021), dark, 0.0005, magazine)
	_beveled(Vector3(0.052,0.013,0.077), Vector3(0,-0.074,0), dark, 0.003, magazine)
	loose_magazine = _beveled(Vector3(0.047,0.155,0.072), Vector3(-0.2,-0.1,-0.2), sand, 0.009, self)
	loose_magazine.visible = false
	_beveled(Vector3(0.062,0.025,0.09), Vector3(0,-0.024,-0.15), dark, 0.008)
	# Recessed ejection port, pins, selector and a restrained charging handle.
	_box(Vector3(0.002,0.022,0.065), Vector3(0.037,0.038,-0.11), recess)
	firing_carrier = _beveled(Vector3(0.002,0.015,0.049), Vector3(0.038,0.038,-0.11), edge,0.0005)
	for side in [-1.0,1.0]:
		for z in [-0.225, -0.035, 0.025]:
			_rod(Vector3(side*0.034,0.02,z), Vector3(side*0.038,0.02,z), 0.005, edge, 8)
			_box(Vector3(0.001,0.0012,0.005), Vector3(side*0.0386,0.02,z), recess)
		_rod(Vector3(side*0.034,-0.001,0.009), Vector3(side*0.039,-0.001,0.009), 0.008, dark)
		_beveled(Vector3(0.002,0.003,0.016), Vector3(side*0.04,-0.002,0.014), steel, 0.0005)
	bolt = _beveled(Vector3(0.032,0.012,0.022), Vector3(-0.045,0.064,-0.10), steel, 0.003)
	_box(Vector3(0.002,0.012,0.085), Vector3(-0.037,0.064,-0.10), recess)
	# Vent apertures, mounting rail and four screws add scale without thick Lego bars.
	for i in range(6):
		for side in [-1.0,1.0]:
			_beveled(Vector3(0.002,0.013,0.023), Vector3(side*0.034,0.035,-0.48+i*0.031), recess, 0.003)
		_box(Vector3(0.038,0.004,0.011), Vector3(0,0.081,-0.24+i*0.04), dark)
	for side in [-1.0,1.0]:
		for z in [-0.485,-0.295]:
			_rod(Vector3(side*0.032,0.048,z), Vector3(side*0.035,0.048,z), 0.0035, steel, 8)
	_beveled(Vector3(0.038,0.009,0.25), Vector3(0,0.073,-0.12), dark, 0.003)
	_beveled(Vector3(0.052,0.018,0.14), Vector3(0,-0.006,-0.375), rubber, 0.006)
	for i in range(7):
		_box(Vector3(0.054,0.003,0.005), Vector3(0,-0.016,-0.43+i*0.018), dark)
	# Physical notch and bead zero against the unchanged hitscan ray at 50 metres.
	_beveled(Vector3(0.028,0.013,0.025),Vector3(0,0.088,-0.04),dark,0.003)
	_beveled(Vector3(0.014,0.034,0.023),Vector3(0,0.068,-0.60),dark,0.003)
	var sights := WeaponFinish.zeroed_sights(model,-0.04,-0.60,0.11,Vector3(0,0.045,-0.69),50.0,steel,_material(Color(0.7,0.59,0.34),0.5,0.5))
	sight_rear = sights.find_child("RearReference",true,false)
	sight_front = sights.find_child("FrontReference",true,false)
	guide = _box(Vector3(0.013,0.013,0.013), Vector3(0,-0.18,-0.15), cyan)
	guide.visible = false
	# Fresh magazine and gesture detection share the same rifle-local pose.
	hip_source = Node3D.new()
	add_child(hip_source)
	_beveled(Vector3(0.047,0.155,0.072), Vector3.ZERO, sand, 0.009, hip_source)
	_beveled(Vector3(0.051,0.012,0.077), Vector3(0,-0.073,0), dark, 0.003, hip_source)
	for x in [-0.027,0.027]:
		_rod(Vector3(x,-0.083,-0.04), Vector3(x,0.083,-0.04), 0.0015, cyan, 6, hip_source)
	for y in [-0.083,0.083]:
		_rod(Vector3(-0.027,y,-0.04), Vector3(0.027,y,-0.04), 0.0015, cyan, 6, hip_source)
	hip_source.visible = false
	insertion_arrow = Node3D.new()
	model.add_child(insertion_arrow)
	insertion_arrow.position = Vector3(-0.045,-0.28,-0.15)
	_rod(Vector3.ZERO, Vector3(0,0.09,0), 0.0018, cyan, 6, insertion_arrow)
	_rod(Vector3(0,0.09,0), Vector3(-0.012,0.066,0), 0.0018, cyan, 6, insertion_arrow)
	_rod(Vector3(0,0.09,0), Vector3(0.012,0.066,0), 0.0018, cyan, 6, insertion_arrow)
	insertion_arrow.visible = false
	charging_arrow = Node3D.new()
	model.add_child(charging_arrow)
	charging_arrow.position = Vector3(-0.065,0.089,-0.10)
	_rod(Vector3.ZERO, Vector3(0,0,0.105), 0.0018, cyan, 6, charging_arrow)
	_rod(Vector3(0,0,0.105), Vector3(-0.014,0,0.079), 0.0018, cyan, 6, charging_arrow)
	_rod(Vector3(0,0,0.105), Vector3(0.014,0,0.079), 0.0018, cyan, 6, charging_arrow)
	charging_arrow.visible = false
	ammo_label = Label3D.new()
	ammo_label.font_size = 28
	ammo_label.pixel_size = 0.00065
	ammo_label.position = Vector3(0.038,0.051,-0.013)
	ammo_label.rotation.y = PI * 0.5
	ammo_label.modulate = Color(0.72,0.81,0.68)
	model.add_child(ammo_label)
	muzzle_flash = _rod(Vector3(0,0.04,-0.72), Vector3(0,0.04,-0.79), 0.018, _material(Color(1,0.65,0.16),0,0.5,3.0), 5)
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.visible = false
	_merge_static_parts()
	_build_debris_pool()









func refresh_hands() -> bool:
	if player == null:return false
	var dominant: XRController3D = player.get_weapon_hand() if player.has_method("get_weapon_hand") else player.get("right_hand")
	var support: XRController3D = player.get_support_hand() if player.has_method("get_support_hand") else player.get("left_hand")
	if right_hand == dominant and left_hand == support:return false
	right_hand=dominant
	left_hand=support
	if model != null:
		_on_dominance_changed()
		_suspend_gestures()
		if _vr_active() and right_hand!=null:global_transform=corrected_grip_transform(right_hand.global_transform)
	return true

func _on_dominance_changed() -> void:
	# Unseated ammunition returns to its offer; seated ammunition and counts persist.
	if reload_state=="held_mag":_set_stage("needs_mag","Grip the offered magazine with your support hand")
	if loose_magazine!=null:loose_magazine.visible=false

func _weapon_hand_climbing() -> bool:
	if not _has_climb_state:return false
	return player.weapon_hand_climbing() if player.has_method("weapon_hand_climbing") else bool(player.get("climbing_right"))


func manual_click_eject_allowed() -> bool:
	# Physical left-stick click belongs exclusively to sprint when that binding is set.
	# Left-dominant rifle reload retains stick-down and automatic empty ejection.
	if player==null or right_hand!=player.get("left_hand"):return true
	var binding=player.get("sprint_binding")
	return binding!=null and str(binding)!="left_stick_click"

func _support_grip_reserved() -> bool:
	if _support_hand_climbing():return true
	if player==null or not player.has_method("is_hand_grip_reserved"):return false
	if player.has_method("update_objective_grips"):player.update_objective_grips()
	return player.is_hand_grip_reserved(left_hand)



func _support_hand_climbing()->bool:
	if player==null or left_hand==null:return false
	var anchors=player.get("_grabs")
	if anchors is Dictionary and anchors.has(left_hand):return true
	return bool(player.get("climbing_left")) if left_hand==player.get("left_hand") else bool(player.get("climbing_right"))
func _reserve_support_hand(value:bool)->void:
	# Reload intent only reserves a free support hand; a wall grip owns its anchor.
	if _has_hand_reservation:player.set("left_hand_reserved",value and not _support_hand_climbing())

func reserve_rounds()->int:
	return ammo_provider.get_ammo_display_state(ammo_slot).reserve if is_instance_valid(ammo_provider) else -1
func take_reserve(requested:int)->int:
	return ammo_provider.consume_weapon_reserve(ammo_slot,requested) if is_instance_valid(ammo_provider) else requested
func update_ammo_display()->void:
	if ammo_panel==null:return
	if hip_source!=null and reserve_rounds()==0:hip_source.visible=false
	ammo_panel.update_display(get_loaded_rounds(),reserve_rounds(),player!=null and right_hand==player.left_hand,camera)
func get_loaded_rounds()->int:
	return _seated_rounds if reload_state=="needs_rack" else ammo






func get_firing_pose()->Transform3D:
	return _displayed_shot_pose if _displayed_pose_valid else get_visual_reticle_pose_071(get_shot_transform())
func refund_rounds(rounds:int)->int:
	if rounds<=0:return 0
	if not is_instance_valid(ammo_provider):return rounds # Standalone debug has no finite reserve.
	if ammo_provider.has_method("refund_weapon_reserve"):
		return clampi(int(ammo_provider.refund_weapon_reserve(ammo_slot,rounds)),0,rounds)
	return 0 # Preserve loaded rounds when a finite provider cannot accept them.
func _return_magazine_rounds()->bool:
	var loaded:=_seated_rounds if reload_state=="needs_rack" else ammo
	var returned:=refund_rounds(loaded)
	if reload_state=="needs_rack":_seated_rounds=loaded-returned
	else:ammo=loaded-returned
	if returned<loaded:update_ammo_display();return false
	ammo=0;_seated_rounds=0
	return true
func suspend_for_selection()->void:
	var saved:Dictionary={}
	var fields:PackedStringArray=["ammo","_seated_rounds","chambered","tube_rounds","spent_chamber","bolt_phase","_bolt_lifted","_bolt_rear","handle_locked","handle_phase","seated","_index"]
	for property in get_property_list():
		if fields.has(property.name):saved[property.name]=get(property.name)
	var stage:=reload_state
	_suspend_gestures()
	for key in saved:set(key,saved[key])
	if stage=="held_mag":reload_state="needs_mag"
	elif stage not in ["held_shell","holding_shells","holding_box","held_round"]:reload_state=stage
	update_ammo_display()
func publish_displayed_aim(pose:Transform3D)->void:
	if not pose.basis.get_scale().is_equal_approx(Vector3.ONE):pose.basis=pose.basis.orthonormalized()
	_displayed_shot_pose=pose;_displayed_pose_valid=true;_external_aim_publication=true



func _endpoint_experiment_enabled()->bool:
	return bool(get_meta("endpoint_experiment_enabled",true)) and EndpointExperiment.enabled(str(get_meta("reference_id","")))



#084: logical reload frame, independently of transient visual recoil.
func visual_model_scale()->float:return float(get_meta("visual_fit_scale_084",1.0))
func reload_local_point(world_point:Vector3)->Vector3:return to_local(world_point)/visual_model_scale()
func reload_world_point(local_point:Vector3)->Vector3:return to_global(local_point*visual_model_scale())
func fitted_download_shot()->Transform3D:return Transform3D(unit_model_basis(),model.to_global(get_meta("download_muzzle_084")))

func reload_frame_scale()->float:return visual_model_scale()

func unit_model_basis()->Basis:
	return model.global_basis if model.global_basis.get_scale().is_equal_approx(Vector3.ONE) else model.global_basis.orthonormalized()

func charging_rest_point()->Vector3:return get_meta("charging_rest_089",Vector3(-.045,.064,-.10))
func charging_grip_point()->Vector3:
	return charging_rest_point()+get_meta("charging_mesh_center_089",Vector3.ZERO)

func shot_sound_kind_089()->String:
	var id:=str(get_meta("reference_id",""))
	if id=="mp9":return "shot_suppressed"
	if id in ["px4","1911","magnum","tec9"]:return "shot_pistol"
	if id in ["dt11","m1014","matadors"]:return "shot_shotgun"
	if id in ["s85","awp","spr"]:return "shot_sniper"
	if id in ["ump","mp5","p90","uzi"]:return "shot_smg"
	if id=="m60":return "shot_lmg"
	if id=="smaw":return "shot_launcher"
	return "rifle"
