class_name AshEnemy
extends CharacterBody3D
const AudioBank = preload("res://scripts/audio_bank.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")
const DetailedVisual = preload("res://scripts/enemy_visual.gd")
var _detail_visual
## Original KESTREL security units. Telegraphs lock before firing; cover and
## lateral movement both defeat attacks. Procedural geometry is authored here.
signal defeated(enemy)
signal hit_player(amount: float)
signal shot_visual(origin: Vector3, endpoint: Vector3)
const SHOT_STREAK_POOL_SIZE := 3
const SHOT_STREAK_SECONDS := 0.065
var _weapon_muzzle: Marker3D
var _shot_streaks: Array[MeshInstance3D] = []
var _shot_streak_times: Array[float] = []
var _shot_streak_cursor := 0
var _tactical_slot := -1
var _standing_eye_height := 1.65
var _standing_height_calibrated := false
var _humanoid_collider: CollisionShape3D
const TACTICAL_SEPARATION := 1.8
const HUMANOID_EYE_ABOVE_SUPPORT := 1.66 - (0.88 - 1.65 * 0.5)

enum State { PATROL, PURSUE, WINDUP, RECOVER, DEAD }
var health: float = 85.0
var healthmax: float = 85.0
var variant_label: String = "KESTREL PATROL"
var boss_phase: int = 1
var core_exposed: bool = false
var last_damage_blocked: bool = false
var last_damage_multiplier: float = 1.0
var detection_level: float = 0.0
var target_exposure: float = 1.0
var alert_memory: float = 0.0
var target: Node3D
var variant: int = 0
var state: State = State.PATROL
var state_time: float = 0.0
var age: float = 0.0
var home: Vector3
var locked_aim: Vector3
var attack_cooldown: float = 1.5
var _built: bool = false
var _phase: float = 0.0
var _recoil: float = 0.0
var _sight_timer: float = 0.0
var _sight_elapsed: float = 0.0
var _last_sensed_aim := Vector3.ZERO
var _has_sensed_aim := false
var _motion_observation_valid_071:=false
var _motion_position_071:=Vector3.ZERO
var _motion_velocity_071:=Vector3.ZERO
var _motion_time_071:=0.0
var _exposure_provider: Node
var _has_sight: bool = false
var _last_seen: Vector3
var _last_seen_aim := Vector3.ZERO
var _has_last_known := false
var _guard_yaw := 0.0
var _cue_time := 0.0
var _cue_position := Vector3.ZERO
var _audio_variation := 0
var difficulty := 0.5
var damage_multiplier := 1.0
func get_damage_scale() -> float:
	return (3.0 if difficulty > .66 else 1.0) * damage_multiplier
@export var challenging_pressure := 2.35
@export var challenging_reaction := 0.56
@export var challenging_dodge_window := 0.28
@export var challenging_move_gain := 1.45
@export var patrol_engage_range := 54.0
@export var drone_engage_range := 58.0
@export var heavy_engage_range := 48.0
@export var warden_engage_range := 100.0
@export var patrol_sight_range := 72.0
@export var drone_sight_range := 80.0
@export var heavy_sight_range := 64.0
@export var warden_sight_range := 120.0

func engage_range() -> float:
	return [patrol_engage_range,drone_engage_range,heavy_engage_range,warden_engage_range][clampi(variant,0,3)]

func sight_range() -> float:
	if variant == 3 and _warden_alert_time > 0: return 200.0
	return [patrol_sight_range,drone_sight_range,heavy_sight_range,warden_sight_range][clampi(variant,0,3)]
var _radio_cooldown := 0.0
var _aim_error := Vector3.ZERO
var _search_side := 1.0
var navigation_provider: Node
var _route_follow
var _route_goal := Vector3.INF
var _route_attempted := false

func set_navigation_provider(provider: Node) -> void:
	navigation_provider = provider
	_route_follow = null
	_route_attempted = false

func _route_active() -> bool:
	return _route_follow != null and not _route_follow.finished and not _route_follow.aborted

func _prepare_route() -> void:
	if variant in [1, 3] or not _has_last_known or not is_instance_valid(navigation_provider): return
	if not navigation_provider.has_method("begin_route"): return
	if _route_attempted and _route_goal.distance_to(_last_seen) <= 2.0: return
	# Only a different observed destination renews a completed/aborted investigation.
	if absf(_last_seen.y - global_position.y) < 1.25:
		# A lost same-floor observation may be across a building, not an open flank.
		# Queue once per remembered goal; provider checks current support and cover.
		if _has_sight or _lost_time < 0.4 or global_position.distance_to(_last_seen) < 2.5: return
	_route_goal = _last_seen
	_route_attempted = true
	var speed := (1.4 if variant == 2 else 2.2) * _move_gain()
	if navigation_provider.has_method("request_route"):
		_route_follow = navigation_provider.request_route(self, global_position, _route_goal, speed, difficulty)
	else:
		_route_follow = navigation_provider.begin_route(global_position, _route_goal, speed, difficulty)

func _follow_route(delta: float) -> Vector3:
	var direction: Vector3 = _route_follow.direction(global_position, delta)
	if _route_follow.finished:
		_lost_time = 0.0 # A bounded local search begins after physically reaching the report.
	elif _route_follow.aborted:
		_change_state(State.PATROL)
	return direction

func set_difficulty(value: float) -> void:
	difficulty = clampf(value, 0.0, 1.0) if is_finite(value) else 0.5

func _pressure_scale() -> float:
	return lerpf(0.65, 1.0, difficulty * 2.0) if difficulty <= 0.5 else lerpf(1.0, challenging_pressure, (difficulty - 0.5) * 2.0)

func _reaction_duration() -> float:
	return lerpf(1.34, 1.04, difficulty * 2.0) if difficulty <= 0.5 else lerpf(1.04, challenging_reaction, (difficulty - 0.5) * 2.0)

func _dodge_window() -> float:
	return lerpf(0.42, challenging_dodge_window, maxf(0.0, (difficulty - 0.5) * 2.0))

func _move_gain() -> float:
	return lerpf(0.85, 1.0, difficulty * 2.0) if difficulty <= 0.5 else lerpf(1.0, challenging_move_gain, (difficulty - 0.5) * 2.0)

func _search_duration() -> float:
	return lerpf(5.0, 11.0, difficulty)

func _investigate_direction() -> Vector3:
	var goal := _last_seen
	var flat := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	# Search around the observed location, never the hidden player's current location.
	if difficulty > 0.55 and flat.length() < 6.0:
		var bearing := _guard_yaw + _search_side * (0.8 + _lost_time * 0.45)
		goal += Vector3(sin(bearing), 0, cos(bearing)) * 3.0
	return Vector3(goal.x - global_position.x, 0, goal.z - global_position.z).normalized()

func _share_observation() -> void:
	if difficulty < 0.65 or _radio_cooldown > 0.0 or not _has_sight:
		return
	_radio_cooldown = 2.0
	for ally in get_tree().get_nodes_in_group("enemies"):
		if ally == self or not ally is AshEnemy or ally.state == State.DEAD:
			continue
		if ally.global_position.distance_to(global_position) > 24.0 or ally._has_sight:
			continue
		ally._receive_observation(_last_seen, _last_seen_aim)

func _receive_observation(feet: Vector3, head: Vector3) -> void:
	if difficulty < 0.65 or _has_sight or state == State.DEAD:
		return
	_last_seen = feet
	_last_seen_aim = head
	_has_last_known = true
	_lost_time = 0.0
	# Radio directs investigation; it grants neither sight nor immediate acquisition.
	if state == State.PATROL:
		_change_state(State.PURSUE)
var _lost_time: float = 0.0
var _visual: Node3D
var _turret: Node3D
var _legs: Array[Node3D] = []
var _optic: StandardMaterial3D
var _beam: MeshInstance3D
var _flash: MeshInstance3D
var _camera: Camera3D
var _voice: AudioStreamPlayer3D
var _impact_voice: AudioStreamPlayer3D
var _stagger: float = 0.0
var _burst_tail: float = 0.0
var _hit_tween: Tween
var _avoid_direction := Vector3.ZERO
var _avoid_time: float = 0.0
var _rotors: Array[Node3D] = []
var _impact_marker: Node3D
var _impact_point := Vector3.ZERO
var _warden_area := false
var _warden_next_area := false
var _impact_flash := 0.0
var _warden_alert_time := 0.0
var _core_material: StandardMaterial3D
var _core_shutters: Array[Node3D] = []
static var _sound_bank: Dictionary = {}

func setup(player_target: Node3D, enemy_variant: int = 0) -> void:
	clear_shot_streaks()
	target = player_target
	variant = posmod(enemy_variant, 4)
	healthmax = [85.0, 60.0, 150.0, 350.0][variant]
	health = healthmax
	variant_label = ["KESTREL PATROL", "KESTREL SCOUT", "KESTREL BULWARK", "WARDEN TWINROTOR"][variant]
	if is_inside_tree() and not _built:
		_build()

func _ready() -> void:
	if not _built:
		_build()
	home = global_position
	_phase = randf() * TAU
	attack_cooldown += randf() * 1.5
	add_to_group("enemies")
	if _tactical_slot < 0:
		var occupied:Dictionary={}
		for peer in get_tree().get_nodes_in_group("enemies"):
			if peer!=self:occupied[int(peer.get("_tactical_slot"))]=true
		_tactical_slot=0
		while occupied.has(_tactical_slot):_tactical_slot+=1
	_update_standing_height()
	# Consecutive guards alternate sides independently of engine object allocation parity.
	_search_side = -1.0 if get_tree().get_nodes_in_group("enemies").size() % 2 == 0 else 1.0

func set_guard_heading(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	_guard_yaw = atan2(-flat.x, -flat.z) - global_rotation.y
	if is_instance_valid(_visual):
		_visual.rotation.y = _guard_yaw

func _exit_tree() -> void:
	for voice in [_voice, _impact_voice]:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

func _mat(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.38 if metal > 0.0 else 0.8
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	if size.length() < 0.3:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _build() -> void:
	_built = true
	AudioBank.ensure_buses()
	AudioBank.warmup(["enemy_fire", "enemy_charge", "enemy_break", "impact_metal"])
	collision_layer = 4
	collision_mask = 5 # World plus other live enemies; steering avoids body pile-ups.
	floor_snap_length = 0.42
	floor_max_angle = deg_to_rad(48.0)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42 if variant != 2 else 0.55
	capsule.height = 1.65
	if variant == 3:
		capsule.radius = 0.85
		capsule.height = 2.2
	collider.shape = capsule
	collider.position.y = 0.88
	if variant == 3:
		collider.position.y = 1.1
	add_child(collider)
	if variant in [0, 2]:_humanoid_collider=collider
	_visual = Node3D.new()
	add_child(_visual)
	var armor := _mat(Color(0.19, 0.24, 0.25), 0.75)
	var edge := _mat(Color(0.48, 0.53, 0.5), 0.8)
	var dark := _mat(Color(0.035, 0.045, 0.05), 0.55)
	var warning := _mat(Color(0.9, 0.52, 0.08), 0.35)
	_optic = _mat(Color(0.18, 0.85, 1.0), 0.25, 2.5)
	_box(_visual, Vector3(0.72, 0.56, 0.42), Vector3(0, 1.04, 0), armor)
	_box(_visual, Vector3(0.62, 0.32, 0.07), Vector3(0, 1.09, -0.25), edge)
	_box(_visual, Vector3(0.28, 0.09, 0.08), Vector3(0, 1.1, -0.3), warning)
	# Layered sloped chest plates and recessed cooling slots give a manufactured silhouette.
	for side in [-1.0, 1.0]:
		var cheek := _box(_visual, Vector3(0.25, 0.37, 0.075), Vector3(side * 0.24, 1.1, -0.28), armor)
		cheek.rotation.z = side * -0.14
		_box(_visual, Vector3(0.025, 0.25, 0.085), Vector3(side * 0.31, 1.1, -0.29), warning)
		for vent in range(4):
			_box(_visual, Vector3(0.24, 0.022, 0.025), Vector3(side * 0.18, 0.91 + vent * 0.065, 0.225), dark)
		var piston := _cylinder(_visual, 0.027, 0.37, Vector3(side * 0.33, 0.65, 0.08), edge)
		piston.rotation.z = side * 0.15
	for x in [-0.25, 0.25]:
		for y in [0.98, 1.22]:
			_cylinder(_visual, 0.025, 0.06, Vector3(x, y, -0.3), dark).rotation.x = PI / 2
	_turret = Node3D.new()
	_turret.position.y = 1.5
	_visual.add_child(_turret)
	_box(_turret, Vector3(0.48, 0.26, 0.4), Vector3.ZERO, armor)
	_box(_turret, Vector3(0.4, 0.09, 0.04), Vector3(0, 0.02, -0.22), dark)
	_box(_turret, Vector3(0.25, 0.045, 0.045), Vector3(0, 0.02, -0.25), _optic)
	_cylinder(_turret, 0.018, 0.32, Vector3(0.17, 0.27, 0.05), dark)
	for x in [-0.48, 0.48]:
		_box(_visual, Vector3(0.23, 0.33, 0.35), Vector3(x, 1.12, 0), armor)
		var gun := _cylinder(_turret, 0.07, 0.56, Vector3(x * 0.85, -0.3, -0.27), dark)
		gun.rotation.x = PI / 2
		_cylinder(_turret, 0.085, 0.06, Vector3(x * 0.85, -0.3, -0.58), edge).rotation.x = PI / 2
		if variant in [1, 3]:
			_cylinder(_visual, 0.24, 0.16, Vector3(x * 1.45, 0.92, 0), dark)
			_cylinder(_visual, 0.18, 0.04, Vector3(x * 1.45, 0.82, 0), _optic)
		else:
			var leg := Node3D.new()
			leg.position = Vector3(x * 0.55, 0.8, 0)
			_visual.add_child(leg)
			_legs.append(leg)
			_cylinder(leg, 0.12, 0.2, Vector3(0, -0.1, 0), dark).rotation.z = PI / 2
			_box(leg, Vector3(0.17, 0.36, 0.2), Vector3(0, -0.24, 0), armor)
			_box(leg, Vector3(0.13, 0.27, 0.13), Vector3(0, -0.52, 0.06), edge)
			_box(leg, Vector3(0.24, 0.13, 0.38), Vector3(0, -0.71, -0.06), dark)
	if variant == 2:
		_box(_visual, Vector3(1.05, 0.16, 0.6), Vector3(0, 1.35, 0.03), armor)
		_box(_visual, Vector3(0.4, 0.65, 0.3), Vector3(0, 1.1, 0.35), dark)
	if variant == 3:
		_build_warden(armor, edge, dark, warning)
	_flash = _box(_turret, Vector3(0.18, 0.18, 0.25), Vector3(0.4, -0.3, -0.67), _mat(Color(1, 0.65, 0.18), 0, 5))
	_flash.visible = false
	_weapon_muzzle = Marker3D.new()
	_weapon_muzzle.name = "VisibleWeaponMuzzle"
	_turret.add_child(_weapon_muzzle)
	# Exact front face of the visible right-hand barrel's muzzle collar.
	_weapon_muzzle.position = Vector3(0.48 * 0.85, -0.3, -0.61)
	_flash.position = _weapon_muzzle.position + Vector3(0, 0, -0.075)
	_build_shot_streak_pool()
	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.004
	beam_mesh.bottom_radius = 0.004
	beam_mesh.height = 1.0
	beam_mesh.radial_segments = 6
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	_beam.mesh = beam_mesh
	var beam_shader := Shader.new()
	beam_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
void fragment() {
    // VERTEX is view-space here: each stereo eye independently rejects nearby
    // laser geometry rather than projecting a near-plane slice into a huge wedge.
    float clearance = smoothstep(0.65, 1.15, length(VERTEX));
    if (clearance < 0.01) { discard; }
    ALBEDO = vec3(1.0, 0.20, 0.045);
    EMISSION = vec3(0.65, 0.08, 0.01);
    ALPHA = 0.65 * clearance;
}
"""
	var beam_material := ShaderMaterial.new()
	beam_material.shader = beam_shader
	_beam.material_override = beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_beam.top_level = true
	_beam.visible = false
	_voice = _make_voice(-9.0)
	_impact_voice = _make_voice(-12.0)

	if variant in [0, 2]:
		_hide_legacy_ground_meshes(_visual)
		_detail_visual = DetailedVisual.new()
		_visual.add_child(_detail_visual)
		_detail_visual.setup(self, _optic, variant == 2)
	else:
		load("res://scripts/drone_detail.gd").new().attach_detail(_visual, _turret, variant)

func _hide_legacy_ground_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var retained_gun: bool = node.get_parent() == _turret and node.mesh is CylinderMesh and node.position.y < 0.0
		if node != _flash and not retained_gun: node.hide()
	for child in node.get_children(): _hide_legacy_ground_meshes(child)

func _build_warden(armor: Material, edge: Material, dark: Material, warning: Material) -> void:
	_visual.scale = Vector3.ONE * 1.3
	_box(_visual, Vector3(1.1, 0.6, 0.85), Vector3(0, 1.03, 0.12), armor)
	_box(_visual, Vector3(0.8, 0.17, 1.2), Vector3(0, 1.37, 0.2), edge)
	_box(_visual, Vector3(0.3, 0.14, 1.35), Vector3(0, 1.47, 0.2), warning)
	_core_material = _mat(Color(0.08, 0.45, 1.0), 0.35, 2.5)
	_box(_visual, Vector3(0.6, 0.43, 0.055), Vector3(0, 1.02, -0.34), _core_material)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.34, 1.02, -0.39)
		_visual.add_child(hinge)
		_core_shutters.append(hinge)
		_box(hinge, Vector3(0.32, 0.47, 0.055), Vector3(-side * 0.16, 0, 0), armor)
		_box(hinge, Vector3(0.035, 0.35, 0.025), Vector3(-side * 0.27, 0, -0.045), _core_material)
	for side in [-1.0, 1.0]:
		_box(_visual, Vector3(0.85, 0.15, 0.32), Vector3(side * 0.92, 1.13, 0.1), dark)
		var pod := Node3D.new()
		pod.position = Vector3(side * 1.35, 1.14, 0.1)
		_visual.add_child(pod)
		var housing := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.39
		ring.outer_radius = 0.58
		ring.rings = 20
		ring.ring_segments = 8
		housing.mesh = ring
		housing.material_override = armor
		pod.add_child(housing)
		_cylinder(pod, 0.13, 0.25, Vector3.ZERO, edge)
		var rotor := Node3D.new()
		rotor.position.y = 0.03
		pod.add_child(rotor)
		_rotors.append(rotor)
		for blade_index in range(3):
			var blade_root := Node3D.new()
			blade_root.rotation.y = blade_index * TAU / 3.0
			rotor.add_child(blade_root)
			_box(blade_root, Vector3(0.14, 0.025, 0.45), Vector3(0, 0, -0.22), dark)
		_box(_visual, Vector3(0.18, 0.23, 0.58), Vector3(side * 0.52, 0.69, -0.3), warning)
		for port in range(3):
			_cylinder(_visual, 0.045, 0.08, Vector3(side * 0.52, 0.68, -0.62 + port * 0.1), dark).rotation.x = PI / 2
	_impact_marker = Node3D.new()
	add_child(_impact_marker)
	_impact_marker.top_level = true
	var marking := MeshInstance3D.new()
	var marker_ring := TorusMesh.new()
	marker_ring.inner_radius = 2.05
	marker_ring.outer_radius = 2.2
	marker_ring.rings = 32
	marker_ring.ring_segments = 6
	marking.mesh = marker_ring
	marking.material_override = _mat(Color(1.0, 0.34, 0.03), 0, 3.0)
	marking.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_marker.add_child(marking)
	for axis in [0, 1]:
		var line := _box(_impact_marker, Vector3(0.07, 0.03, 0.7), Vector3.ZERO, marking.material_override)
		line.rotation.y = axis * PI / 2
	_impact_marker.visible = false

func _make_voice(volume: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.position.y = 1.2
	voice.unit_size = 9.0
	voice.max_distance = maxf(48.0, engage_range() * 1.15)
	voice.volume_db = volume
	voice.max_polyphony = 2
	voice.bus = "SFX"
	add_child(voice)
	return voice

func _sound(kind: String, variation: int = 0) -> AudioStreamWAV:
	var semantic: String = {"fire": "enemy_fire", "charge": "enemy_charge", "death": "enemy_break", "hit": "impact_metal"}.get(kind, "impact_metal")
	var key := "%s_%s" % [kind, posmod(variation, int(AudioBank.VARIANTS[semantic]))]
	if _sound_bank.has(key):
		return _sound_bank[key]
	var stream: AudioStreamWAV = AudioBank.sample(semantic, variation)
	_sound_bank[key] = stream
	return stream

func _play_sound(kind: String, impact: bool = false) -> void:
	var voice := _impact_voice if impact else _voice
	voice.stream = _sound(kind, _audio_variation)
	_audio_variation += 1
	voice.pitch_scale = 0.68 if variant == 3 else (0.83 if variant == 2 else (1.16 if variant == 1 else 1.0))
	voice.play()

func _aim_position() -> Vector3:
	if target.has_method("get_aim_position"):
		return target.call("get_aim_position")
	if not is_instance_valid(_camera):
		_camera = target.find_child("*Camera*", true, false) as Camera3D
	return _camera.global_position if is_instance_valid(_camera) else target.global_position + Vector3.UP * 1.35

func _clear_line(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, point, 7, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var object: Object = result.collider
	return object == target or (object is Node and target.is_ancestor_of(object as Node))

func _physics_process(delta: float) -> void:
	if state == State.DEAD or not is_instance_valid(target):
		return
	_update_standing_height()
	age += delta
	_radio_cooldown = maxf(0.0, _radio_cooldown - delta)
	_cue_time = maxf(0.0, _cue_time - delta)
	_stagger = maxf(0.0, _stagger - delta)
	_avoid_time = maxf(0.0, _avoid_time - delta)
	_burst_tail = maxf(0.0, _burst_tail - delta)
	if variant == 3:
		_warden_alert_time = maxf(0.0, _warden_alert_time - delta)
		_update_core_visual(delta)
		for index in range(_rotors.size()):
			_rotors[index].rotation.y += delta * (22.0 if index == 0 else -22.0)
		_impact_flash = maxf(0.0, _impact_flash - delta)
		if state != State.WINDUP:
			_impact_marker.visible = _impact_flash > 0.0
			_impact_marker.scale = Vector3.ONE * (1.0 + (0.35 - _impact_flash) * 2.0)
	state_time += delta
	attack_cooldown -= delta
	_recoil = move_toward(_recoil, 0.0, delta * 3.0)
	_flash.visible = _burst_tail > 0.0 and fmod(_burst_tail, 0.075) > 0.035
	_turret.position.z = _recoil * 0.12
	var aim := _aim_position()
	var difference := aim - (global_position + Vector3.UP * 1.4)
	var distance := difference.length()
	_sight_timer -= delta
	_sight_elapsed += delta
	if _sight_timer <= 0:
		_sight_timer = lerpf(0.14, 0.07, maxf(0.0, (difficulty - 0.5) * 2.0)) + randf() * 0.04
		_update_detection(aim, distance, _sight_elapsed)
		_sight_elapsed = 0.0
	if _has_sight:
		_lost_time = 0.0
	else:
		_lost_time += delta
	var observed := _last_seen_aim - (global_position + Vector3.UP * 1.4)
	var direction := Vector3(observed.x, 0, observed.z).normalized()
	var observed_distance := observed.length() if _has_last_known else INF
	_update_orientation(delta)
	var move_direction := Vector3.ZERO
	match state:
		State.PATROL:
			if _has_sight:
				_change_state(State.PURSUE)
		State.PURSUE:
			_prepare_route()
			if _lost_time > _search_duration() and not _route_active():
				_change_state(State.PATROL)
			elif _has_sight and attack_cooldown <= 0.0 and observed_distance < engage_range() and (_stagger <= 0.0 or variant == 3):
				locked_aim = _last_seen_aim
				_change_state(State.WINDUP)
			else:
				if _route_active():
					move_direction = _follow_route(delta)
				elif not _has_sight:
					move_direction = _investigate_direction()
				elif observed_distance > 14.0:
					move_direction = direction
				elif observed_distance < 5.0:
					move_direction = -direction
				else:
					move_direction = direction.cross(Vector3.UP) * sin(age * 0.7 + _phase)
				if not _route_active() and difficulty > 0.55 and _has_sight and observed_distance >= 5.0 and observed_distance <= 20.0:
					# Stable opposite approach sides reduce squad bunching; collision steering still applies.
					move_direction = (direction * 0.25 + direction.cross(Vector3.UP) * _search_side).normalized()
				if variant == 3 and _has_sight and observed_distance >= 5.0 and observed_distance <= 20.0:
					var cadence := 1.35 if boss_phase == 2 else 0.6
					move_direction = direction.cross(Vector3.UP) * sin(age * cadence + _phase)
		State.WINDUP:
			var windup_duration := 1.3 if variant == 3 else _reaction_duration()
			if variant == 3 and _warden_area:
				windup_duration = 1.85
				_impact_marker.visible = true
				_impact_marker.scale = Vector3.ONE * (1.0 + sin(state_time * 16.0) * 0.025)
				_draw_beam(get_weapon_muzzle_transform().origin, _impact_point)
			else:
				# A visible fixed aim precedes fire: 0.42s normal, 0.28s challenging.
				if state_time < (0.62 if variant == 3 else windup_duration - _dodge_window()) and _has_sight:
					locked_aim = _predicted_lock_071(maxf(0.0,windup_duration-state_time))
				_draw_beam(get_weapon_muzzle_transform().origin, locked_aim)
			_optic.emission = Color(1, 0.12 + sin(age * 35) * 0.1, 0.02)
			if state_time > windup_duration:
				_fire(aim)
		State.RECOVER:
			if state_time > (1.45 if variant == 3 else 0.45):
				_change_state(State.PURSUE)
	var speed := 2.2 if variant != 2 else 1.4
	# Ground soldiers occupy distinct stable slots around their last observation.
	# Existing routes retain authority when stairs/cover require a planned path.
	if variant in [0,2] and state==State.PURSUE and _has_last_known and _has_sight and not _route_active():
		var towards_slot:=tactical_destination()-global_position
		towards_slot.y=0
		move_direction=towards_slot.normalized() if towards_slot.length()>.65 else Vector3.ZERO
	move_direction=_separated_direction(move_direction)
	speed *= _move_gain()
	if variant == 3:
		speed = 3.2 if boss_phase == 2 else 2.0
		if observed_distance > 48.0:
			speed = 6.0
	if move_direction.length_squared() > 0.01:
		move_direction = _safe_direction(move_direction, variant not in [1, 3])
	if _stagger > 0.0 and variant != 3:
		speed *= 0.3
	velocity.x = move_toward(velocity.x, move_direction.x * speed, delta * 5)
	velocity.z = move_toward(velocity.z, move_direction.z * speed, delta * 5)
	if variant in [1, 3]:
		var desired_y := home.y + 2.0 + sin(age * 0.9 + _phase) * 0.5
		if _has_sight:
			desired_y = clampf(_last_seen_aim.y + 0.9, home.y + 1.0, home.y + 7.0)
		if variant == 3 and _has_last_known and _lost_time <= _search_duration():
			desired_y = clampf(_last_seen_aim.y + 2.1 + sin(age * 0.5) * 0.7, home.y + 2.0, home.y + 8.0)
		velocity.y = clampf((desired_y - global_position.y) * 1.7, -2.0, 2.0)
	else:
		velocity.y -= 18.0 * delta
		if is_on_floor():
			velocity.y = -0.1
			_try_step(delta)
	move_and_slide()
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(age * 8.0 + i * PI) * minf(velocity.length() * 0.16, 0.4)

	if _detail_visual != null:
		_detail_visual.update_pose(delta, is_on_floor(), state == State.WINDUP, _recoil, _turret.rotation.x)

func _world_ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()]))

func _update_orientation(delta: float) -> void:
	var desired_yaw := _guard_yaw + sin(age * TAU / 12.0 + _phase) * deg_to_rad(45.0)
	var desired_pitch := 0.0
	if _has_last_known and state != State.PATROL:
		var look_point := _last_seen_aim
		if state == State.WINDUP:
			look_point = _impact_point if variant == 3 and _warden_area else locked_aim
		var relative := look_point - (global_position + Vector3.UP * 1.4)
		if Vector2(relative.x, relative.z).length_squared() > 0.0001:
			desired_yaw = atan2(-relative.x, -relative.z) - global_rotation.y
		desired_pitch = clampf(atan2(relative.y, maxf(Vector2(relative.x, relative.z).length(), 0.1)), -0.6, 0.6)
	_visual.rotation.y += clampf(wrapf(desired_yaw - _visual.rotation.y, -PI, PI), -PI * delta, PI * delta)
	_turret.rotation.x = move_toward(_turret.rotation.x, desired_pitch, delta * 1.8)

func _within_fov(aim: Vector3, distance: float) -> bool:
	if distance <= 4.0:
		return true
	if _cue_time > 0.0 and aim.distance_to(_cue_position) <= 3.0:
		return true
	var relative := aim - (global_position + Vector3.UP * 1.4)
	var horizontal := Vector3(relative.x, 0, relative.z)
	var forward := -_visual.global_basis.z
	forward.y = 0.0
	var half_width := deg_to_rad(80.0 if variant == 3 else (75.0 if variant == 1 else 60.0))
	if horizontal.length_squared() > 0.0001 and forward.normalized().dot(horizontal.normalized()) < cos(half_width):
		return false
	var half_height := deg_to_rad(60.0 if variant in [1, 3] else 50.0)
	return absf(atan2(relative.y, maxf(horizontal.length(), 0.001))) <= half_height

func _update_detection(aim: Vector3, distance: float, elapsed: float) -> void:
	var detection_range := sight_range()
	var clear := distance < detection_range and _within_fov(aim, distance) and _clear_line(aim)
	_observe_motion_071(aim,elapsed,clear)
	var speed := 0.0
	if target is CharacterBody3D:
		speed = (target as CharacterBody3D).velocity.length()
	if _has_sensed_aim:
		speed = maxf(speed, aim.distance_to(_last_sensed_aim) / maxf(elapsed, 0.01))
	_last_sensed_aim = aim
	_has_sensed_aim = true
	if not is_instance_valid(_exposure_provider) and is_instance_valid(target):
		_exposure_provider = target.get("exposure_provider") as Node
	target_exposure = 1.0
	if is_instance_valid(_exposure_provider) and _exposure_provider.has_method("get_light_exposure"):
		target_exposure = clampf(float(_exposure_provider.call("get_light_exposure", aim)), 0.0, 1.0)
	if clear:
		if alert_memory > 0.0:
			detection_level = 1.0
		else:
			var motion := clampf((speed - 0.15) / 4.35, 0.0, 1.0)
			var proximity := clampf((detection_range - distance) / maxf(detection_range - 3.0, 1.0), 0.25, 1.0)
			var rate := 1.8 * _contrast_visibility(target_exposure) * proximity * (1.0 + 0.9 * motion) * _pressure_scale()
			if distance <= 4.0:
				rate = maxf(rate, 2.5)
			detection_level = minf(1.0, detection_level + rate * elapsed)
		_has_sight = detection_level >= 1.0
		if _has_sight:
			alert_memory = 6.0
			_last_seen = target.global_position
			_last_seen_aim = aim
			_has_last_known = true
			_share_observation()
	else:
		_has_sight = false
		detection_level = maxf(0.0, detection_level - elapsed * 0.35)
		alert_memory = maxf(0.0, alert_memory - elapsed)

func _observe_motion_071(aim:Vector3,elapsed:float,visible_now:bool)->void:
	# Infer motion only from consecutive visible perception samples, never the
	# target's private velocity or positions obtained through cover.
	if not visible_now:
		_motion_observation_valid_071=false;_motion_velocity_071=Vector3.ZERO;return
	if _motion_observation_valid_071 and elapsed>0:
		var observed:Vector3=(aim-_motion_position_071)/elapsed
		observed.y=0.0
		_motion_velocity_071=_motion_velocity_071.lerp(observed.limit_length(6.0),1.0-exp(-elapsed/.12))
	else:_motion_velocity_071=Vector3.ZERO
	_motion_position_071=aim;_motion_time_071=age;_motion_observation_valid_071=true
func _predicted_lock_071(remaining_windup:float)->Vector3:
	if variant==3 or not _motion_observation_valid_071:return _last_seen_aim+_aim_error
	# These rounds resolve instantly: compensate the observation/telegraph delay,
	# not invented projectile travel. Final dodge window remains locked, so late
	# reversals still evade. Partial, capped prediction retains tracking error.
	var horizon:=clampf(remaining_windup+maxf(0.0,age-_motion_time_071),0.0,.65)
	var gain:=lerpf(.82,.94,clampf(difficulty,0,1))
	return _last_seen_aim+(_motion_velocity_071*horizon*gain).limit_length(2.0)+_aim_error

func notify_gunshot(position: Vector3, loudness: float = 1.0) -> void:
	if state == State.DEAD or loudness <= 0.0:
		return
	if global_position.distance_to(position) > clampf(80.0 * loudness, 0.0, 120.0):
		return
	_last_seen = position
	_last_seen_aim = position
	_has_last_known = true
	_cue_position = position
	_cue_time = 1.0
	_lost_time = 0.0
	alert_memory = 6.0
	detection_level = maxf(detection_level, 0.55)
	if state == State.PATROL:
		_change_state(State.PURSUE)

func _core_is_open() -> bool:
	if variant != 3 or state == State.DEAD:
		return false
	if state == State.RECOVER:
		return true
	return state == State.WINDUP and state_time >= (1.55 if _warden_area else 1.05)

func _update_core_visual(delta: float) -> void:
	core_exposed = _core_is_open()
	var color := Color(1.0, 0.32, 0.035) if core_exposed else Color(0.08, 0.45, 1.0)
	_core_material.albedo_color = color
	_core_material.emission = color
	for index in range(_core_shutters.size()):
		var angle := (-1.0 if index == 0 else 1.0) * 1.15 if core_exposed else 0.0
		_core_shutters[index].rotation.y = move_toward(_core_shutters[index].rotation.y, angle, delta * 9.0)

func _safe_direction(desired: Vector3, avoid_ledges: bool = true) -> Vector3:
	var direction := desired.normalized()
	var origin := global_position + Vector3.UP * (0.65 if avoid_ledges else 1.05)
	var wall := _world_ray(origin, origin + direction * 1.0)
	if not wall.is_empty():
		var normal: Vector3 = wall.normal
		if _avoid_time <= 0.0:
			var tangent := normal.cross(Vector3.UP).normalized()
			# Retain a chosen flank instead of oscillating across a wall's centre.
			if sin(_phase) < 0.0:
				tangent = -tangent
			_avoid_direction = (tangent + normal * 0.08).normalized()
		_avoid_time = 0.7
	if _avoid_time > 0.0:
		direction = _avoid_direction
	# Ground units retain their vertical arena. They cannot blindly walk off catwalks.
	if avoid_ledges and is_on_floor():
		# Start above a walkable 1:2 stair slope; preserve the same -0.65m drop limit.
		var ahead := global_position + direction * 0.7 + Vector3.UP * 0.6
		if _world_ray(ahead, ahead - Vector3.UP * 1.25).is_empty():
			return Vector3.ZERO
	return direction

func _try_step(delta: float) -> void:
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length_squared() < 0.000001 or not test_move(global_transform, motion):
		return
	var rise := Vector3.UP * 0.39
	if test_move(global_transform, rise):
		return
	var elevated := global_transform
	elevated.origin += rise
	if not test_move(elevated, motion * 2.0):
		global_position += rise

func _change_state(next: State) -> void:
	state = next
	state_time = 0.0
	core_exposed = _core_is_open()
	_beam.visible = state == State.WINDUP
	if state == State.WINDUP:
		var error_radius := maxf(0.0, 0.5 - difficulty) * 1.6
		var error_angle := randf() * TAU
		_aim_error = Vector3(cos(error_angle), sin(error_angle) * 0.4, 0) * error_radius * sqrt(randf())
		locked_aim += _aim_error
		if variant == 3:
			_warden_area = _warden_next_area
			_warden_next_area = not _warden_next_area
			if _warden_area:
				var foot := _last_seen if _has_last_known else locked_aim - Vector3.UP * 1.35
				var ground := _world_ray(foot + Vector3.UP * 0.7, foot - Vector3.UP * 6.0)
				if ground.is_empty():
					_warden_area = false # No invisible airborne impact marker.
				else:
					_impact_point = ground.position + Vector3.UP * 0.06
					_impact_marker.global_position = _impact_point
					_impact_marker.scale = Vector3.ONE
		_play_sound("charge")
	if state != State.WINDUP:
		_optic.emission = Color(0.18, 0.85, 1.0)

func _draw_beam(from: Vector3, to: Vector3) -> void:
	var diff := to - from
	var distance := diff.length()
	_beam.visible = distance > 1.0
	if not _beam.visible:
		return
	var direction := diff / distance
	# Never run laser geometry into the aimed-at head. Locked aim/damage stay exact.
	var end := to - direction * 0.85
	var obstruction := _world_ray(from, end)
	if not obstruction.is_empty(): end = obstruction.position - direction * 0.03
	diff = end - from
	_beam.visible = diff.length() > 0.03
	if not _beam.visible: return
	var orientation := Basis(Quaternion(Vector3.UP, direction))
	_beam.global_transform = Transform3D(orientation.scaled_local(Vector3(1, diff.length(), 1)), (from + end) * 0.5)

func _fire(current_aim: Vector3) -> void:
	# Recheck range at discharge after movement during windup; no unlimited hitscan.
	var muzzle := get_weapon_muzzle_transform().origin
	if muzzle.distance_to(locked_aim) > engage_range():
		attack_cooldown = 0.5
		_change_state(State.RECOVER)
		return
	_recoil = 0.4
	_burst_tail = 0.25
	_play_sound("fire")
	if variant == 3 and _warden_area:
		_resolve_warden_impact(current_aim)
		attack_cooldown = (2.9 if boss_phase == 2 else 3.6) / _pressure_scale()
		_change_state(State.RECOVER)
		return
	# Never damage through cover, and only hit the position telegraphed before firing.
	# Resolve the telegraphed ray once: a destroyed panel still absorbs this shot.
	var cover_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, locked_aim, 7, [get_rid()]))
	var endpoint: Vector3 = cover_hit.position if not cover_hit.is_empty() else locked_aim
	var clear_shot := cover_hit.is_empty()
	if not clear_shot:
		var object: Object = cover_hit.collider
		# Snapshot obstruction ownership before construction damage can delete it.
		# Discharge fixtures/recycled enemies may temporarily have no live target.
		clear_shot = is_instance_valid(target) and is_instance_valid(object) and (object == target or (object is Node and target.is_ancestor_of(object as Node)))
	var construction_blocked := _damage_construction(cover_hit, 36.0 if variant == 3 else (32.0 if variant == 2 else 24.0), locked_aim - muzzle)
	var shield_blocked:=false
	if not construction_blocked and clear_shot and is_instance_valid(target) and target.has_method("intercept_bullet"):
		var shield_contact:Dictionary=target.intercept_bullet(muzzle,endpoint)
		if not shield_contact.is_empty():endpoint=shield_contact.position;shield_blocked=true
	_emit_shot_streak(muzzle, endpoint)
	if not shield_blocked and not construction_blocked and clear_shot and locked_aim.distance_to(current_aim) < 0.42:
		hit_player.emit((16.0 if variant == 3 else (12.0 if variant != 2 else 19.0))*get_damage_scale())
	attack_cooldown = (2.2 if variant != 2 else 3.1) + randf() * 0.7
	if variant == 3:
		attack_cooldown = 2.9 if boss_phase == 2 else 3.6
	attack_cooldown /= _pressure_scale()
	_change_state(State.RECOVER)

func _damage_construction(obstruction: Dictionary, amount: float, direction: Vector3) -> bool:
	if obstruction.is_empty(): return false
	var object: Object = obstruction.collider
	if object is Node and object.is_in_group("field_construction") and object.has_method("hit"):
		object.call("hit", amount*get_damage_scale(), obstruction.position, direction.normalized())
		return true
	return false

func _resolve_warden_impact(current_aim: Vector3) -> void:
	_impact_flash = 0.35
	_play_sound("death", true)
	var feet := target.global_position
	var horizontal := Vector2(feet.x - _impact_point.x, feet.z - _impact_point.z).length()
	# Airborne players above the marked ground blast are safe; so is solid cover.
	if horizontal >= 2.0 or absf(feet.y - _impact_point.y) > 1.5:
		return
	var query := PhysicsRayQueryParameters3D.create(_impact_point + Vector3.UP * 0.2, current_aim, 7, [get_rid()])
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty():
		if _damage_construction(obstruction, 40.0, current_aim - _impact_point): return
		var object: Object = obstruction.collider
		if object != target and not (object is Node and target.is_ancestor_of(object as Node)):
			return
	hit_player.emit(lerpf(18.0, 8.0, horizontal / 2.0)*get_damage_scale())

func take_damage(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	last_damage_blocked = variant == 3 and not _core_is_open()
	last_damage_multiplier = 0.25 if last_damage_blocked else 1.0
	health -= amount * last_damage_multiplier
	if is_instance_valid(target):
		_last_seen = target.global_position
		_last_seen_aim = _aim_position()
		_has_last_known = true
		_cue_position = _last_seen_aim
		_cue_time = 1.0
		_lost_time = 0.0
		detection_level = 1.0
		alert_memory = 6.0
	if variant == 3 and is_instance_valid(target):
		_warden_alert_time = 12.0
		if state in [State.PATROL, State.PURSUE]:
			attack_cooldown = minf(attack_cooldown, 0.45)
	if variant == 3 and health <= healthmax * 0.5:
		boss_phase = 2
	_recoil = 0.15
	_play_sound("hit", true)
	_stagger = 0.22
	if health <= 0.0:
		_die()
	else:
		if state == State.PATROL:
			_change_state(State.PURSUE)
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		_hit_tween = create_tween()
		_hit_tween.tween_property(_visual, "rotation:x", -0.075, 0.035)
		_hit_tween.tween_property(_visual, "rotation:x", 0.0, 0.15)

func _die() -> void:
	clear_shot_streaks()
	_change_state(State.DEAD)
	if is_instance_valid(_impact_marker):
		_impact_marker.visible = false
	_play_sound("death")
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	defeated.emit(self)
	var death_impulse := Vector3.UP * 1.4
	if _has_last_known:
		death_impulse += (global_position - _last_seen).normalized() * 2.5
	var corpse: Node3D
	if get_parent() is Node3D:
		corpse = Ragdoll.spawn(get_parent(), global_transform, death_impulse, variant, _visual)
	if is_instance_valid(corpse):
		_visual.visible = false
	_optic.emission = Color(1, 0.3, 0.03)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "rotation:z", 1.4, 0.6).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_visual, "position:y", -0.6, 0.6)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.03, 0.4).set_delay(1.1)
	tween.chain().tween_callback(queue_free)


func get_weapon_muzzle_transform() -> Transform3D:
	if _detail_visual != null and _detail_visual.has_method("get_muzzle_transform"):
		return _detail_visual.get_muzzle_transform()
	return _weapon_muzzle.global_transform if is_instance_valid(_weapon_muzzle) else global_transform

func _build_shot_streak_pool() -> void:
	if not _shot_streaks.is_empty():return
	var core := CylinderMesh.new()
	core.height=1.0;core.top_radius=.002;core.bottom_radius=.005;core.radial_segments=6;core.rings=1
	core.cap_top=false;core.cap_bottom=false
	var halo := CylinderMesh.new()
	halo.height=1.0;halo.top_radius=.007;halo.bottom_radius=.015;halo.radial_segments=6;halo.rings=1
	halo.cap_top=false;halo.cap_bottom=false
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0,0.65,0.25,1.0);
void fragment(){
    float clearance=smoothstep(0.45,0.85,length(VERTEX));
    float taper=pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),0.5);
    ALBEDO=tint.rgb; EMISSION=tint.rgb*0.7;
    ALPHA=tint.a*clearance*mix(0.6,1.0,taper);
}
"""
	var core_mat:=ShaderMaterial.new();core_mat.shader=shader;core_mat.set_shader_parameter("tint",Color(1.0,.77,.38,.90))
	var halo_mat:=ShaderMaterial.new();halo_mat.shader=shader;halo_mat.set_shader_parameter("tint",Color(1.0,.29,.05,.16))
	for i in range(SHOT_STREAK_POOL_SIZE):
		var streak:=MeshInstance3D.new();streak.name="EnemyShotStreak%d"%i;streak.mesh=core;streak.material_override=core_mat
		streak.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(streak);streak.top_level=true
		var bloom:=MeshInstance3D.new();bloom.name="SoftTracerHalo";bloom.mesh=halo;bloom.material_override=halo_mat
		bloom.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;streak.add_child(bloom)
		streak.hide();_shot_streaks.append(streak);_shot_streak_times.append(0.0)

func _emit_shot_streak(origin:Vector3,endpoint:Vector3)->void:
	shot_visual.emit(origin,endpoint)
	if _shot_streaks.is_empty() or origin.distance_to(endpoint)<.025:return
	var index:=_shot_streak_cursor
	_shot_streak_cursor=(_shot_streak_cursor+1)%SHOT_STREAK_POOL_SIZE
	var diff:=endpoint-origin
	_shot_streaks[index].global_transform=Transform3D(Basis(Quaternion(Vector3.UP,diff.normalized())).scaled_local(Vector3(1,diff.length(),1)),(origin+endpoint)*.5)
	_shot_streak_times[index]=SHOT_STREAK_SECONDS;_shot_streaks[index].show()

func clear_shot_streaks()->void:
	for i in range(_shot_streaks.size()):_shot_streak_times[i]=0;_shot_streaks[i].hide()
	_shot_streak_cursor=0

func _process(delta:float)->void:
	# Main pauses enemy physics during menus; lingering streaks must not freeze on screen.
	if not is_physics_processing() or state==State.DEAD or not visible or get_tree().paused:
		clear_shot_streaks();return
	for i in range(_shot_streaks.size()):
		_shot_streak_times[i]=maxf(0,_shot_streak_times[i]-delta)
		_shot_streaks[i].visible=_shot_streak_times[i]>0

func _notification(what:int)->void:
	if what==NOTIFICATION_PAUSED:clear_shot_streaks()

func _update_standing_height()->void:
	if variant not in [0,2] or not is_instance_valid(target) or not target.has_method("get_view_camera"):return
	var view:Camera3D=target.get_view_camera()
	if not is_instance_valid(view):return
	# Raw tracking-space height excludes world jumps, climbing and foot-origin offsets.
	var authoritative:=target.has_method("get_standing_eye_height")
	var height:=float(target.get_standing_eye_height()) if authoritative else (view.position.y if view.get_parent() is XROrigin3D else float(target.measured_eye_height()) if target.has_method("measured_eye_height") else 1.65)
	if view is XRCamera3D and target.get("tracking_available")!=true:return
	if not is_finite(height) or height<1.25 or height>2.2:return
	if _standing_height_calibrated and (absf(height-_standing_eye_height)<.015 if authoritative else height<=_standing_eye_height+.015):return
	_standing_eye_height=height;_standing_height_calibrated=true
	# Include the reference capsule's 5.5cm support offset so grounded eyes,
	# rather than eyes measured from the body's internal origin, match the player.
	var ratio:=height/HUMANOID_EYE_ABOVE_SUPPORT
	_visual.scale=Vector3.ONE*ratio
	if is_instance_valid(_humanoid_collider):
		var capsule:=_humanoid_collider.shape as CapsuleShape3D
		capsule.radius=(.55 if variant==2 else .42)*ratio
		capsule.height=1.65*ratio
		_humanoid_collider.position.y=.88*ratio

func tactical_destination()->Vector3:
	# No live target position is queried: unseen target motion cannot steer the slot.
	var center:=_last_seen if _has_last_known else home
	var slot:=maxi(0,_tactical_slot)
	var approach:=home-center;approach.y=0
	if approach.length_squared()<.01:approach=Vector3.BACK
	approach=approach.normalized()
	var right:=approach.cross(Vector3.UP)
	var side:=1.0 if slot%2==0 else -1.0
	var lane:=float((slot/2)%4)
	return center+approach*(7.0+float(slot/8)*2.0)+right*side*(4.0+lane*2.0)

func _separated_direction(desired:Vector3)->Vector3:
	if state==State.DEAD:return Vector3.ZERO
	var push:=Vector3.ZERO
	for peer in get_tree().get_nodes_in_group("enemies"):
		if peer==self or not is_instance_valid(peer) or peer.get("state")==State.DEAD:continue
		if absf(peer.global_position.y-global_position.y)>1.7:continue
		var away:Vector3=global_position-peer.global_position;away.y=0
		var distance:=away.length()
		var desired_gap:=TACTICAL_SEPARATION
		if variant==3 or peer.get("variant")==3:desired_gap=2.4
		if distance>=desired_gap:continue
		if distance<.001:
			# Antisymmetric tie-break separates coincident spawns without randomness.
			var axis:=float(mini(_tactical_slot,int(peer.get("_tactical_slot"))))*2.399963229728653
			away=Vector3(cos(axis),0,sin(axis))*(1.0 if _tactical_slot>int(peer.get("_tactical_slot")) else -1.0)
		else:away/=distance
		push+=away*(1.0-distance/desired_gap)*2.0
	if push.length_squared()<.0001:return desired
	# Windup stays stationary: a locked warning ray never slides because of crowding.
	if state==State.WINDUP:return desired
	return (desired+push*1.8).limit_length(1.0)

func _contrast_visibility(exposure:float)->float:
	# World exposure is a gameplay light sample: ambient=.12, direct sun=.84.
	# Preserve the previous direct-sun/full-light response, but distinguish low
	# ambient silhouette contrast from illumination instead of flattening shade
	# into a large linear visibility floor. Same curve for every difficulty.
	var light:=clampf(exposure,0.0,1.0)
	const SUN:=.84
	const SUN_VISIBILITY:=.18+.82*SUN
	if light>=SUN:return lerpf(SUN_VISIBILITY,1.0,(light-SUN)/(1.0-SUN))
	return SUN_VISIBILITY*(.06+.94*pow(light/SUN,1.35))
