class_name AshPlayer
extends CharacterBody3D

signal fired
signal reload_requested
signal movement_changed(mode: String)
signal tracking_changed(available: bool)
signal vertical_combat_calibrated(measurement: Dictionary)
signal objective_grip_requested(target_id: String, hand: Node3D)
var objective_grip_provider: Callable
var _objective_grip_arbiter = preload("res://scripts/objective_grip_arbiter.gd").new()
var _objective_grip_frame: int = -1

# Al's 2026-10-20 correction: each reported "meter" was two feet. Convert
# raw measured reference speeds once here; saved tuning remains dimensionless.
const MEASURED_REFERENCE_UNIT_METERS := 0.6096 * preload("res://scripts/measurement_calibration.gd").FACTOR
const WALK_SPEED := 6.5 * MEASURED_REFERENCE_UNIT_METERS # 3.9624 m/s
const RUN_SPEED := 7.5 * MEASURED_REFERENCE_UNIT_METERS # 4.572 m/s
const SPRINT_SPEED := 9.5 * MEASURED_REFERENCE_UNIT_METERS # 5.7912 m/s
const GLIDE_SPEED := 12.0 * MEASURED_REFERENCE_UNIT_METERS # 7.3152 m/s
const GLIDE_RATIO := 7.0 # 42 corrected reference units horizontal / 6 vertical.
const COMFORT_WALK_SPEED := 2.6 # Pre-existing SI comfort tuning, not a measured reference speed.
# Al specified six feet to the TOP of the head, not the tracked eye point.
const DEFAULT_PLAYER_TOP_HEIGHT_M := 1.8288
# Authored upright rig/collider policy, not a measurement of Al's anatomy.
# Retain the existing upper head envelope while separating eyes from vertex.
const AUTHORED_HEAD_TOP_TO_EYE_M := .120
const DEFAULT_EYE_HEIGHT_M := DEFAULT_PLAYER_TOP_HEIGHT_M-AUTHORED_HEAD_TOP_TO_EYE_M
const DEFAULT_PLAYER_HEIGHT := DEFAULT_EYE_HEIGHT_M # Deprecated eye-height alias.
const GLIDE_BANK_AUTHORITY := 0.715 # 10% more hand-height steering than the previous .65.
const GRAVITY := 16.2
const AIR_STEERING := 6.0
const AIR_DRAG := 0.8
const INPUT_REARM_TIME := 0.08
const MANTLE_COMPLETION_SECONDS := 0.20
var move_speed := WALK_SPEED
var glide_speed_mps: float:
	get: return get_effective_glide_speed()
	set(_legacy_value): pass # Legacy absolute saves cannot apply reference-unit conversion again.
var network_flight_multiplier:=1.0
var walk_speed_multiplier := 1.0
var sprint_binding := "left_stick_click"
var sprinting := false
# User-rounded video measurements; custom settings still scale the defaults.
var sprint_slow_gain := RUN_SPEED / WALK_SPEED
var sprint_fast_gain := SPRINT_SPEED / WALK_SPEED
var sprint_double_press_window := 0.32
var sprint_stamina_seconds := 6.0
var sprint_recovery_seconds := 4.0
var _sprint_mode := 0 # 0 walk, 1 slow, 2 fast
var _sprint_click_held := false
var _sprint_click_age := INF
var _sprint_stamina := -1.0
var sprint_conflict_provider: Node
var held_item_provider: Node
var dominant_hand := "right"
var snap_degrees := 30.0
var forward_reference := "head"
var turning_style := "smooth"
var smooth_turn_speed := 360.0
var smooth_ease_in := false
var smooth_analog := true
var _smooth_turn_rate := 0.0
const TURN_EASE_SECONDS := 0.12
# Displayed scale: 1.0 is 100%; physical gain is 1.25 times the original baseline.
var fling_power := 1.0
var _auto_snap_timer := 0.0
var xr_enabled := false
var exposure_provider: Node
var left_hand: XRController3D
var right_hand: XRController3D
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var desktop_camera: Camera3D
var climbing := false
var climbing_right: bool:
	get:
		return right_hand != null and _grabs.has(right_hand)
var climbing_left: bool:
	get:
		return left_hand != null and _grabs.has(left_hand)
var gliding := false
var movement_mode := "ground"
var tracking_available := true
var head_obstructed := false
var inventory_open:=false
var _movement_heading_local_089:=Vector3.FORWARD
var _movement_heading_ready_089:=false
var _input_requested := true
var input_enabled: bool:
	get:
		return _input_requested and tracking_available and not vertical_combat_initializing
	set(value):
		_input_requested = value
var left_hand_reserved := false
var mantling := false
var _mantle_outward := Vector3.ZERO
var _mantle_target := Vector3.ZERO
var _mantle_raised := Vector3.ZERO
var _mantle_phase := 0
var _mantle_speed := 0.0
var _mantle_route:Array[Vector3]=[]
var _mantle_elapsed:=0.0
var _mantle_length:=0.0
var _mantle_travelled:=0.0
var _grab_cooldown := 0.0
var _jump_button_held := false
var _configured := false
var _snap_ready := true
var _desktop_glide := false
var _pitch := 0.0
var _grabs: Dictionary = {}
var _release_velocity := Vector3.ZERO
var _climb_launch_pending := false
var _glide_bank := 0.0
var glide_steering_gain := 0.875
const GLIDE_HORIZONTAL_SPREAD := 0.95890625
const HEAD_RADIUS := 0.12
var _supported := false
var _last_head := Vector3.INF
var _artificial_origin_offset:=Vector3.ZERO
var _body_shape: CollisionShape3D
var _jump_requested := false
var _grab_shape := SphereShape3D.new()
var _head_probe: Shape3D
var _hand_visuals: Dictionary = {}
var _finger_joints: Dictionary = {}
var _hand_input_ready: Dictionary = {}
var _hand_neutral_time: Dictionary = {}
var vertical_combat_initialized := false
var vertical_combat_initializing := false
var vertical_combat_tracking_baseline := DEFAULT_EYE_HEIGHT_M
var vertical_combat_origin_lift := 0.0
# Top-of-head settings are explicit. A configured target takes effect only on
# the next gaze calibration. The stored world baseline below remains eye level.
var vertical_combat_target_top_height_m := DEFAULT_PLAYER_TOP_HEIGHT_M
var vertical_combat_world_baseline_m := DEFAULT_EYE_HEIGHT_M
# Legacy programmatic API is eye height only; old persisted settings are
# deliberately not reinterpreted as a top-of-head target by AshMenu.
var vertical_combat_target_height_m: float:
	get: return get_target_eye_height_m()
	set(value): vertical_combat_target_top_height_m=value+AUTHORED_HEAD_TOP_TO_EYE_M

func setup(use_xr: bool) -> void:
	xr_enabled = use_xr
	tracking_available = not use_xr
	if _configured:
		return
	_configured = true
	collision_layer = 2
	collision_mask = 5
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(65.0)
	_body_shape = CollisionShape3D.new()
	_body_shape.shape = _make_goggle_head_shape()
	_body_shape.position.y = DEFAULT_EYE_HEIGHT_M
	add_child(_body_shape)
	_grab_shape.radius = 0.18
	_head_probe = _body_shape.shape
	xr_origin = XROrigin3D.new()
	xr_origin.name = "XROrigin3D"
	add_child(xr_origin)
	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	xr_camera.near = 0.045
	xr_camera.far = 650.0
	xr_origin.add_child(xr_camera)
	left_hand = _create_hand("left_hand", Vector3(-0.28, 1.25, -0.4))
	right_hand = _create_hand("right_hand", Vector3(0.28, 1.25, -0.4))
	desktop_camera = Camera3D.new()
	desktop_camera.name = "DesktopCamera"
	desktop_camera.position.y = DEFAULT_EYE_HEIGHT_M
	desktop_camera.near = 0.045
	desktop_camera.far = 650.0
	desktop_camera.fov = 85.0
	add_child(desktop_camera)
	xr_origin.visible = xr_enabled
	xr_camera.current = xr_enabled
	desktop_camera.current = not xr_enabled
	if not xr_enabled and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _create_hand(tracker_name: String, fallback: Vector3) -> XRController3D:
	var hand := XRController3D.new()
	hand.name = tracker_name
	hand.tracker = tracker_name
	hand.pose = "grip"
	hand.position = fallback
	xr_origin.add_child(hand)
	_build_glove(hand, tracker_name == "left_hand")
	return hand

func _build_glove(hand: XRController3D, is_left: bool) -> void:
	var rig := Node3D.new()
	rig.name = "ArticulatedGlove"
	# Keep the back of the hand below the receiver and its sight line.
	# Visual-only forward pitch; raw tracked controller stays unchanged.
	# Pitch the glove into grip space, then roll around its own forward axis.
	# Opposite rolls put each thumb above its palm without changing tracking.
	rig.basis = Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.FORWARD, -PI / 2.0 if is_left else PI / 2.0)
	rig.position = Basis(Vector3.RIGHT,-PI/2.0)*Vector3(0,-.052,.035)
	hand.add_child(rig)
	rig.set_meta("rest_transform",rig.transform)
	rig.set_meta("is_left",is_left)
	_hand_visuals[hand] = rig
	# Palm skin lies beside the grip, while curled segments cross its front.
	# Keeping this offset inside the rig also works with weapon support snaps.
	var root:=Node3D.new();root.name="GripSurface";root.position.y=.032;rig.add_child(root)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.105, 0.13, 0.14)
	cloth.roughness = 0.94
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.032, 0.042, 0.045)
	rubber.roughness = 0.77
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.22, 0.27, 0.27)
	armor.roughness = 0.62
	armor.metallic = 0.16
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(0.72, 0.32, 0.10)
	stripe.roughness = 0.82
	_glove_box(root, Vector3(0.072, 0.028, 0.082), Vector3.ZERO, cloth)
	root.get_child(root.get_child_count()-1).name="PalmSurface"
	_glove_box(root, Vector3(0.061, 0.008, 0.058), Vector3(0.0, -0.017, 0.0), rubber)
	_glove_box(root, Vector3(0.058, 0.011, 0.046), Vector3(0.0, 0.019, 0.0), armor)
	_glove_box(root, Vector3(0.074, 0.04, 0.031), Vector3(0.0, 0.0, 0.052), rubber)
	_glove_box(root, Vector3(0.061, 0.035, 0.045), Vector3(0.0, 0.0, 0.084), cloth)
	_glove_box(root, Vector3(0.044, 0.003, 0.006), Vector3(0.0, 0.023, 0.052), stripe)
	var joints: Array[Dictionary] = []
	var mirror := 1.0 if is_left else -1.0
	var lengths := [0.059, 0.069, 0.064, 0.049]
	for finger in range(4):
		var base := Node3D.new()
		base.name = ["Index", "Middle", "Ring", "Little"][finger]
		base.position = Vector3((0.027 - float(finger) * 0.018) * mirror, -0.002, -0.038)
		root.add_child(base)
		var proximal: float = lengths[finger] * 0.54
		var distal: float = lengths[finger] * 0.46
		_glove_segment(base, proximal, 0.008 if finger < 3 else 0.007, cloth)
		_glove_box(base, Vector3(0.012, 0.005, 0.014), Vector3(0.0, 0.008, -0.01), armor)
		var tip := Node3D.new()
		tip.position.z = -proximal
		base.add_child(tip)
		_glove_segment(tip, distal, 0.0075 if finger < 3 else 0.0065, rubber)
		var contact:=Marker3D.new();contact.name="FingertipContact";contact.position.z=-distal;tip.add_child(contact)
		joints.append({"base": base, "tip": tip, "contact":contact,"length":distal,"index": finger == 0, "thumb": false})
	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(0.029 * mirror, -0.006, 0.018)
	thumb.rotation.y = -0.85 * mirror
	root.add_child(thumb)
	_glove_segment(thumb, 0.029, 0.01, cloth)
	var thumb_tip := Node3D.new()
	thumb_tip.position.z = -0.029
	thumb.add_child(thumb_tip)
	_glove_segment(thumb_tip, 0.025, 0.009, rubber)
	var thumb_contact:=Marker3D.new();thumb_contact.name="FingertipContact";thumb_contact.position.z=-.025;thumb_tip.add_child(thumb_contact)
	joints.append({"base": thumb, "tip": thumb_tip,"contact":thumb_contact,"length":.025, "index": false, "thumb": true})
	_finger_joints[hand] = joints
	if not preload("res://scripts/asset_quality.gd").lightweight():
		root.hide()
		var skinned:=preload("res://scripts/grip_hand_086.gd").new();rig.add_child(skinned);skinned.setup(is_left)
	rig.visible = false

func _glove_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _glove_segment(parent: Node3D, length_value: float, radius: float, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = length_value + radius * 2.0
	capsule.radial_segments = 8
	capsule.rings = 2
	instance.mesh = capsule
	instance.rotation.x = PI * 0.5
	instance.position.z = -length_value * 0.5
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _ready()->void:
	process_priority=90 # Weapon transforms first, then gloves, then body/HUD.

func _process(delta: float) -> void:
	if not _configured or not xr_enabled:
		return
	for hand in _hand_visuals:
		var tracked := is_hand_tracked(hand)
		_hand_visuals[hand].visible = tracked
		if tracked:
			animate_hand(hand, hand.get_float("grip"), hand.get_float("trigger"), delta)

func animate_hand(hand: XRController3D, grip: float, trigger: float, delta: float) -> void:
	if not _finger_joints.has(hand):
		return
	if is_instance_valid(sprint_conflict_provider) and sprint_conflict_provider.has_method("get_hand_grip_pose"):
		var forced_grip := clampf(float(sprint_conflict_provider.get_hand_grip_pose(hand)),0.0,1.0)
		grip = maxf(grip, forced_grip)
		trigger = maxf(trigger, forced_grip * .55)
	var contact:=get_hand_art_contact(hand)
	var rig:Node3D=_hand_visuals[hand]
	if contact.role=="firing":
		var weapon:Node3D=contact.weapon
		var roll:=Basis(Vector3.FORWARD,-PI/2.0 if hand==left_hand else PI/2.0)
		rig.global_transform=Transform3D(weapon.model.global_basis.orthonormalized()*preload("res://scripts/playtest_fit_088.gd").hand_basis(weapon)*roll,weapon.model.to_global(contact.center))
	elif contact.role=="free":rig.transform=rig.get_meta("rest_transform")
	var skinned:=rig.get_node_or_null("SkinnedGlove086")
	if skinned!=null:skinned.update_pose(grip,trigger,contact,delta)
	var holding:bool=contact.role!="free"
	var blend := 1.0 - exp(-18.0 * delta)
	for joint in _finger_joints[hand]:
		var curl := clampf(trigger if joint.index else grip, 0.0, 1.0)
		if holding:
			var id:String=str(contact.weapon.get_meta("reference_id","")) if is_instance_valid(contact.weapon) else ""
			curl=preload("res://scripts/grip_hand_086.gd").closure_amount(id,contact.profile,joint.index,curl)
		var base: Node3D = joint.base
		var tip: Node3D = joint.tip
		var target_base := -0.1 - curl * (0.65 if joint.thumb else 1.05)
		var target_tip := -0.08 - curl * 1.25
		base.rotation.x = lerpf(base.rotation.x, target_base, blend)
		tip.rotation.x = lerpf(tip.rotation.x, target_tip, blend)
		if joint.thumb:
			var mirror:=1.0 if hand==left_hand else -1.0
			base.rotation.y=lerpf(base.rotation.y,-mirror*(.85+.25*curl),blend)

func _hand_art_property(object:Object,key:String,fallback:Variant=null)->Variant:
	for entry in object.get_property_list():
		if entry.name==key:return object.get(key)
	return fallback

func get_hand_art_contact(hand:XRController3D)->Dictionary:
	var free:={"role":"free","weapon":null,"center":Vector3.ZERO,"profile":"free"}
	if _grabs.has(hand):return free
	if not is_instance_valid(sprint_conflict_provider):return free
	var rack:=sprint_conflict_provider
	if bool(_hand_art_property(rack,"is_holstered",false)) or bool(_hand_art_property(rack,"is_selecting",false)):return free
	var weapons:Array=_hand_art_property(rack,"weapons",[])
	var selected:int=int(_hand_art_property(rack,"selected",0))
	if selected<0 or selected>=weapons.size():return free
	if rack.has_method("has_weapon") and not rack.has_weapon(selected):return free
	var weapon:Node3D=weapons[selected]
	if not weapon.visible:return free
	var paired:Array=_hand_art_property(weapon,"guns",[])
	if not paired.is_empty():
		var stowed:Array=_hand_art_property(weapon,"stowed",[])
		var chosen:Node3D=null
		for i in range(paired.size()):
			if i<stowed.size() and stowed[i]:continue
			if paired[i].right_hand==hand or (paired[i].supported and paired[i].left_hand==hand):chosen=paired[i];break
		if chosen==null:return free
		weapon=chosen
	var role:="firing" if weapon.right_hand==hand else ("support" if weapon.supported and weapon.left_hand==hand else "free")
	if role=="free" or weapon._weapon_hand_climbing():return free
	var path:=""
	var script:Script=weapon.get_script()
	while script!=null:
		path+=" "+script.resource_path
		script=script.get_base_script()
	var profile:="revolver" if "revolver" in path else ("pistol" if "pistol" in path else "longgun")
	# Original model grip centers: compact pistols sit forward of rifle grips.
	var center:=Vector3(0,-.057,.025)
	if weapon.has_method("sample_motion"):profile="sword";center=weapon.hand_grip_center
	if profile=="pistol":center=Vector3(0,-.065,-.13)
	elif profile=="revolver":center=Vector3(0,-.045,-.065)
	if "explosive_weapon" in path:center=weapon.hand_grip_center
	if weapon.has_meta("primary_grip_084"):center=weapon.get_meta("primary_grip_084")
	if role=="firing":center+=preload("res://scripts/playtest_fit_088.gd").hand_offset(weapon)
	return {"role":role,"weapon":weapon,"center":center,"profile":profile}

func get_view_camera() -> Camera3D:
	return xr_camera if xr_enabled else desktop_camera

func get_aim_transform() -> Transform3D:
	if xr_enabled and is_hand_tracked(right_hand):
		return right_hand.global_transform
	return get_view_camera().global_transform

func get_aim_position() -> Vector3:
	return get_view_camera().global_position

func _unhandled_input(event: InputEvent) -> void:
	if not _configured or xr_enabled:
		return
	# Desktop mouse look stands in for head turning during gaze initialization;
	# movement, firing and reload stay suspended by the normal input gate.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (input_enabled or (vertical_combat_initializing and _input_requested)):
		rotate_y(-event.relative.x * 0.002)
		_pitch = clampf(_pitch - event.relative.y * 0.002, -1.45, 1.45)
		desktop_camera.rotation.x = _pitch
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: reload_requested.emit()
			KEY_SPACE: _jump_requested = true
			KEY_G: _desktop_glide = not _desktop_glide
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not _configured:
		return
	update_tracking()
	_apply_vertical_combat_ceiling()
	if xr_enabled:
		update_hand_input_rearm(delta)
	_sync_head_shape()
	if not climbing and not mantling: _resolve_support(0.02, false)
	update_head_obstruction()
	update_objective_grips()
	if not input_enabled:
		return
	_grab_cooldown = maxf(0.0, _grab_cooldown - delta)
	if mantling:
		if xr_enabled:_sync_body_to_head()
		_step_mantle(delta)
		update_head_obstruction()
		return
	var move_input := Vector2.ZERO
	var wants_glide := _desktop_glide
	if xr_enabled:
		_sync_body_to_head()
		if is_hand_input_ready(left_hand):
			move_input = left_hand.get_vector2("primary")
			_update_grab(left_hand, not inventory_open and left_hand.get_float("grip") > 0.65)
		else:
			_update_grab(left_hand, false, false)
		if mantling:
			update_head_obstruction()
			return
		if is_hand_input_ready(right_hand):
			_update_grab(right_hand, not inventory_open and right_hand.get_float("grip") > 0.65)
			if mantling:
				update_head_obstruction()
				return
			var turn := get_turn_axis(right_hand.get_vector2("primary"))
			apply_turn_input(0.0 if inventory_open else turn, delta)
		else:
			_update_grab(right_hand, false, false)
			_snap_ready = true
			_auto_snap_timer = 0.0
			_smooth_turn_rate = 0.0
		var support := get_support_hand()
		var jump_pressed := not inventory_open and is_hand_input_ready(support) and support.is_button_pressed("ax_button")
		_jump_requested = jump_pressed and not _jump_button_held
		_jump_button_held = jump_pressed
		var hand_offset := left_hand.global_position - right_hand.global_position
		wants_glide = not inventory_open and is_hand_input_ready(left_hand) and is_hand_input_ready(right_hand) and Vector2(hand_offset.x, hand_offset.z).length() > GLIDE_HORIZONTAL_SPREAD
	else:
		if not inventory_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			fired.emit()
		move_input = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
		if not inventory_open:_update_desktop_climb(delta)
	if mantling:
		update_head_obstruction()
		return
	climbing = not _grabs.is_empty()
	if climbing:
		_sprint_mode = 0
		_sprint_click_held = xr_enabled and left_hand.is_button_pressed("primary_click")
		var pull := Vector3.ZERO
		for hand in _grabs:
			pull += _grabs[hand] - hand.global_position
		pull /= float(_grabs.size())
		apply_climb_motion(pull, delta)
		gliding = false
	else:
		gliding = wants_glide and not is_supported()
		var forward := get_movement_forward()
		var right := forward.cross(Vector3.UP)
		var direction := (right * move_input.x + forward * move_input.y).limit_length()
		if direction.length() < 0.15:
			direction = Vector3.ZERO
		sprinting = sprint_requested(delta)
		apply_locomotion_motion(direction, forward, wants_glide, sprinting, delta)
	_jump_requested = false
	update_head_obstruction()
	_last_head = get_view_camera().global_position
	var next_mode := "climb" if climbing else ("glide" if gliding else ("ground" if is_supported() else "air"))
	if movement_mode != next_mode:
		movement_mode = next_mode
		movement_changed.emit(movement_mode)

func apply_locomotion_motion(direction: Vector3, forward: Vector3, wants_glide: bool, sprint_active: bool, delta: float) -> void:
	_sync_head_shape()
	if not _climb_launch_pending: _resolve_support(0.02, false)
	var grounded:=is_supported() and not _climb_launch_pending
	var gain := (sprint_fast_gain if _sprint_mode == 2 else sprint_slow_gain) if sprint_active else 1.0
	if is_instance_valid(sprint_conflict_provider) and sprint_conflict_provider.has_method("get_ground_speed_gain"):gain=sprint_conflict_provider.get_ground_speed_gain(gain)
	var walk_target:=direction * effective_walk_speed() * gain
	var target:=walk_target
	gliding=wants_glide and not grounded
	# Ground and glide input apply immediately; free fall keeps air steering/drag.
	var acceleration:=AIR_DRAG if direction==Vector3.ZERO else AIR_STEERING
	if gliding:
		var hands_ready:=xr_enabled and is_hand_input_ready(left_hand) and is_hand_input_ready(right_hand)
		var banked:=update_glide_heading(forward,left_hand.global_position,right_hand.global_position,hands_ready,delta)
		target=(banked+direction*.35).normalized()*glide_speed_mps
		velocity.y=-glide_speed_mps/GLIDE_RATIO
	else:
		_glide_bank=0.0
		velocity.y-=GRAVITY*delta
	var horizontal:=Vector2(target.x,target.z) if grounded or gliding else Vector2(velocity.x,velocity.z).move_toward(Vector2(target.x,target.z),acceleration*delta)
	velocity.x=horizontal.x
	velocity.z=horizontal.y
	if grounded and _jump_requested: velocity.y=6.0
	_climb_launch_pending=false
	# Sweep the standing foot plane over support on descent; the head sphere
	# alone would otherwise land with eyes near the floor at high fall speed.
	if velocity.y < 0.0:
		var landing := _support_hit()
		if not landing.is_empty() and landing.normal.y >= cos(floor_max_angle):
			var gap: float = landing.position.y - global_position.y
			if gap <= .005 and gap >= velocity.y * delta:
				velocity.y = gap / maxf(delta, .001)
	var before_motion := global_transform
	move_and_slide()
	if grounded and direction != Vector3.ZERO and not _jump_requested:
		_try_ground_step(before_motion, walk_target * delta)
	if not grounded and velocity.y <= 0.0: _resolve_support(head_support_rise(), false)
	# Arms already spread take effect on the exact tick crossing the support edge.
	if wants_glide and not is_supported():
		gliding = true
		velocity.y = -glide_speed_mps/GLIDE_RATIO
		var ready := xr_enabled and is_hand_input_ready(left_hand) and is_hand_input_ready(right_hand)
		var immediate_heading := update_glide_heading(forward,left_hand.global_position,right_hand.global_position,ready,delta)
		var immediate_target := (immediate_heading+direction*.35).normalized()*glide_speed_mps
		velocity.x = immediate_target.x
		velocity.z = immediate_target.z
	if is_supported():
		# Landing consumes airborne momentum; ground input has no acceleration tail.
		velocity.x=walk_target.x
		velocity.z=walk_target.z
		gliding=false
		_glide_bank=0.0

func is_supported() -> bool:
	return _supported

func measured_eye_height() -> float:
	return clampf(get_view_camera().global_position.y - global_position.y, 0.55, 2.2)

func get_head_top_height() -> float:
	# Match the actual upper collider point, including deep physical crouches;
	# the older reported-eye-height clamp must not move this authored vertex.
	return get_view_camera().global_position.y-global_position.y+AUTHORED_HEAD_TOP_TO_EYE_M

func get_standing_head_top_height() -> float:
	return get_standing_eye_height()+AUTHORED_HEAD_TOP_TO_EYE_M

func get_target_eye_height_m() -> float:
	return vertical_combat_target_top_height_m-AUTHORED_HEAD_TOP_TO_EYE_M

func get_tracking_eye_baseline_m() -> float:
	# Raw tracking-space consumers must compare against this physical baseline,
	# not the normalized virtual eye or head-top height.
	return vertical_combat_tracking_baseline if vertical_combat_initialized else get_standing_eye_height()

func _apply_vertical_combat_ceiling()->void:
	if not xr_enabled or not tracking_available or not vertical_combat_initialized:return
	var raw:=xr_camera.position.y
	if not is_finite(raw):return
	# Offset only the origin: preserve runtime camera/controller poses and crouch 1:1.
	# Incremental correction preserves collision/mantle translations on the origin.
	var correction:=maxf(0.0,raw-vertical_combat_tracking_baseline)
	xr_origin.position.y+=_vertical_ceiling_correction-correction
	_vertical_ceiling_correction=correction

var _vertical_ceiling_correction:=0.0
func initialize_vertical_combat_system() -> Dictionary:
	# Floor calibration is a translation, not a world-scale change. Corrected
	# object dimensions and a 10 cm physical crouch retain their SI lengths.
	# Never edit the runtime-owned camera/controller local pose.
	if not _configured or (xr_enabled and not tracking_available): return {}
	var camera := get_view_camera()
	var tracked_height := xr_camera.position.y if xr_enabled else desktop_camera.position.y
	if not is_finite(tracked_height) or tracked_height < .1 or tracked_height > 4.0: return {}
	var target_top := vertical_combat_target_top_height_m
	var target := get_target_eye_height_m()
	if not is_finite(target) or target < .55 or target > 2.2: return {}
	var lift := target - (camera.global_position.y-global_position.y)
	if xr_enabled:
		xr_origin.global_position += Vector3.UP*lift
		vertical_combat_origin_lift = xr_origin.position.y
	else:
		desktop_camera.position.y = target
		vertical_combat_origin_lift = 0.0
	_vertical_ceiling_correction=0.0
	vertical_combat_tracking_baseline = tracked_height
	vertical_combat_world_baseline_m = target
	vertical_combat_initialized = true
	_standing_eye_height = target
	_has_standing_measurement = true
	reset_motion()
	require_neutral_input()
	_sync_head_shape()
	_last_head = camera.global_position
	var measurement := {"tracked_baseline_m":tracked_height,"world_baseline_m":target,"world_eye_baseline_m":target,"world_head_top_baseline_m":target_top,"head_top_to_eye_m":AUTHORED_HEAD_TOP_TO_EYE_M,"height_semantics":"standing_head_top","origin_lift_m":vertical_combat_origin_lift,"world_scale":1.0}
	vertical_combat_calibrated.emit(measurement)
	return measurement

var _standing_eye_height := DEFAULT_EYE_HEIGHT_M
var _has_standing_measurement := false
func get_standing_eye_height() -> float:
	if vertical_combat_initialized: return vertical_combat_world_baseline_m
	# Tracking-space height excludes climbing, origin collision correction and
	# artificial body translation. Remember standing height through crouches.
	if xr_enabled and tracking_available and is_instance_valid(xr_camera):
		var height := xr_camera.position.y
		if is_finite(height) and height >= 1.25 and height <= 2.2:
			_standing_eye_height = maxf(_standing_eye_height, height) if _has_standing_measurement else height
			_has_standing_measurement = true
	return _standing_eye_height

func head_support_rise() -> float:
	# A camera center just above a surface is enough; no extra head-radius gate.
	return measured_eye_height()+.0025

func _make_goggle_head_shape() -> ConvexPolygonShape3D:
	# The goggles define the lower collision plane. Preserve the 12cm lateral
	# envelope and authored eye-to-top extent, without an invisible chin that
	# demands another12cm of lift before a ledge can be crossed.
	var points:=PackedVector3Array()
	for ring in range(7):
		var elevation:=float(ring)*PI/12.0
		for segment in range(24):
			var angle:=TAU*float(segment)/24.0
			points.append(Vector3(cos(angle)*cos(elevation)*HEAD_RADIUS,sin(elevation)*AUTHORED_HEAD_TOP_TO_EYE_M,sin(angle)*cos(elevation)*HEAD_RADIUS))
	var shape:=ConvexPolygonShape3D.new();shape.points=points
	return shape

func _sync_head_shape() -> void:
	_body_shape.position = to_local(get_view_camera().global_position)

func _support_hit() -> Dictionary:
	var head := get_view_camera().global_position
	var query := PhysicsRayQueryParameters3D.create(head+Vector3.UP*.015, Vector3(head.x, minf(global_position.y - 3.0, head.y - 3.0), head.z), 5, [get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	# Query starts above a grazing coplanar rim; never treats a taller wall as floor.
	if not hit.is_empty() and hit.position.y>head.y+.0025:return {}
	return hit

func _resolve_support(max_rise: float, allow_drop_snap: bool = true) -> bool:
	var hit := _support_hit()
	_supported = false
	if hit.is_empty() or hit.normal.y < cos(floor_max_angle): return false
	var rise: float = hit.position.y - global_position.y
	var drop_allowance := .03
	if hit.normal.y < .999:
		drop_allowance += Vector2(velocity.x,velocity.z).length() * get_physics_process_delta_time() * tan(floor_max_angle)
	if rise > max_rise + .005 or (rise < -drop_allowance and not allow_drop_snap): return false
	if rise < -.27: return false
	if rise < -.01 and velocity.y > .05: return false
	# Only the head is swept on elevation. A ceiling can limit standing height.
	_sync_head_shape()
	var collision := move_and_collide(Vector3.UP * rise) if absf(rise) > .0001 else null
	# A sloped rock can already touch the lower goggle rim while the camera
	# center is clear. Resolve upward-facing recovery contacts by continuing
	# away from that surface; side walls and ceilings still stop the sweep.
	for recovery in range(4):
		if collision==null or rise<=0 or collision.get_normal().y<cos(floor_max_angle):break
		var remaining:float=hit.position.y-global_position.y
		if remaining<=.0001:break
		collision=move_and_collide(Vector3.UP*remaining)
	if collision != null and absf(global_position.y - hit.position.y) > .015: return false
	_supported = true
	velocity.y = 0.0
	return true

func _try_ground_step(_start: Transform3D, _desired: Vector3) -> bool:
	return _resolve_support(head_support_rise(), false)
func update_glide_heading(forward:Vector3,left_position:Vector3,right_position:Vector3,tracked:bool,_delta:float)->Vector3:
	# Keep immediate steering. Banking is relative to current travel heading,
	# including head/hand reference changes independent of artificial body yaw.
	if not tracked or not left_position.is_finite() or not right_position.is_finite():
		_glide_bank=0.0
		return forward
	var local_left:=to_local(left_position)
	var local_right:=to_local(right_position)
	var difference:=local_left.y-local_right.y
	_glide_bank=signf(difference)*clampf((absf(difference)-.08)/.32,0.0,1.0)
	var right:=forward.cross(Vector3.UP)
	right.y=0.0
	var heading:=forward+right.normalized()*_glide_bank*GLIDE_BANK_AUTHORITY*glide_steering_gain
	heading.y=0.0
	return heading.normalized()
func snap_turn(angle: float) -> void:
	var pivot := get_view_camera().global_position
	rotate_y(angle)
	var correction := pivot - get_view_camera().global_position
	correction.y = 0.0
	global_position += correction
	_artificial_origin_offset += correction

func get_locomotion_anchor_position()->Vector3:
	# UI follows locomotion, not the logical origin's pivot/recenter corrections.
	return global_position-_artificial_origin_offset

func get_movement_forward() -> Vector3:
	var forward := -get_view_camera().global_basis.z
	if xr_enabled and forward_reference == "hand" and is_hand_input_ready(left_hand):
		forward = continuous_controller_heading_089(left_hand.global_basis)
	else:_movement_heading_ready_089=false
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = -global_basis.z
		forward.y = 0.0
	return forward.normalized()

func apply_turn_input(axis: float, delta: float) -> void:
	# Project tuning: repeat cadence and smooth speed are not claimed Pop:One constants.
	if not input_enabled:
		_smooth_turn_rate = 0.0
		return
	_auto_snap_timer = maxf(0.0, _auto_snap_timer - delta)
	if absf(axis) < 0.3:
		_snap_ready = true
		_auto_snap_timer = 0.0
		_smooth_turn_rate = 0.0
		return
	if turning_style == "smooth":
		var amount := inverse_lerp(0.3, 1.0, minf(absf(axis), 1.0)) if smooth_analog else 1.0
		var target_rate := -signf(axis) * amount * smooth_turn_speed
		# Original tuning: reach full configured speed from rest in 120ms.
		# Neutral, tracking loss and pause stop immediately, never ease out.
		_smooth_turn_rate = move_toward(_smooth_turn_rate, target_rate, smooth_turn_speed * delta / TURN_EASE_SECONDS) if smooth_ease_in else target_rate
		snap_turn(deg_to_rad(_smooth_turn_rate) * delta)
	else:
		_smooth_turn_rate = 0.0
		if absf(axis) > 0.7 and (_snap_ready or (turning_style == "auto_snap" and _auto_snap_timer <= 0.0)):
			snap_turn(-signf(axis) * deg_to_rad(snap_degrees))
			_snap_ready = false
			_auto_snap_timer = 0.3

func get_turn_axis(stick: Vector2) -> float:
	# Reserve the rifle's manual eject gesture, including its diagonal tolerance.
	return 0.0 if stick.y < -0.7 and absf(stick.x) < 0.5 else stick.x

func update_tracking() -> bool:
	# OpenXR publishes the HMD as tracker "head", pose "default".
	# A still-initialized interface alone says nothing about headset presence.
	var available := not xr_enabled
	if xr_enabled:
		var interface := XRServer.find_interface("OpenXR") as OpenXRInterface
		var head := XRServer.get_tracker("head") as XRPositionalTracker
		if interface != null and interface.is_initialized() and head != null:
			var pose := head.get_pose("default")
			available = is_pose_tracking_valid(pose)
			available = available and interface.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED
			if interface.is_user_presence_supported():
				available = available and interface.is_user_present()
	if not available:
		reset_motion()
		require_neutral_input()
	if available != tracking_available:
		tracking_available = available
		tracking_changed.emit(available)
	return tracking_available

func is_hand_tracked(hand: XRController3D) -> bool:
	if not tracking_available or hand == null or not hand.get_is_active():
		return false
	var tracker := XRServer.get_tracker(hand.tracker) as XRPositionalTracker
	if tracker == null:
		return false
	var pose := tracker.get_pose(hand.pose)
	return is_pose_tracking_valid(pose)

func is_pose_tracking_valid(pose: XRPose) -> bool:
	# Godot 4.7.2 may publish an uninitialized head confidence before its
	# first active frame. Reject all values outside the defined live states.
	return pose != null and pose.has_tracking_data and (pose.tracking_confidence == XRPose.XR_TRACKING_CONFIDENCE_LOW or pose.tracking_confidence == XRPose.XR_TRACKING_CONFIDENCE_HIGH)

func is_hand_input_ready(hand: XRController3D) -> bool:
	# Pose visibility and gesture eligibility are separate: the hand may be
	# visible immediately, but a held input cannot become a new press.
	return is_hand_tracked(hand) and bool(_hand_input_ready.get(hand, false))

func require_neutral_input() -> void:
	_auto_snap_timer = 0.0
	_smooth_turn_rate = 0.0
	_hand_input_ready.clear()
	_hand_neutral_time.clear()
	_jump_requested = false
	_jump_button_held = false
	_snap_ready = true
	_sprint_click_held = false
	_sprint_click_age = INF
	_sprint_mode = 0

func update_hand_input_rearm(delta: float) -> void:
	for hand in [left_hand, right_hand]:
		if not is_hand_tracked(hand):
			_hand_input_ready[hand] = false
			_hand_neutral_time[hand] = 0.0
			_update_grab(hand, false, false)
			continue
		if bool(_hand_input_ready.get(hand, false)):
			continue
		var neutral: bool = hand.get_float("grip") < 0.2 and hand.get_float("trigger") < 0.2
		neutral = neutral and hand.get_vector2("primary").length() < 0.25
		neutral = neutral and not hand.is_button_pressed("ax_button") and not hand.is_button_pressed("by_button") and not hand.is_button_pressed("primary_click") and not hand.is_button_pressed("menu_button")
		_hand_neutral_time[hand] = float(_hand_neutral_time.get(hand, 0.0)) + delta if neutral else 0.0
		if float(_hand_neutral_time[hand]) >= INPUT_REARM_TIME:
			_hand_input_ready[hand] = true

func _sync_body_to_head() -> void:
	# Correct the origin, never the tracked camera local pose.
	var desired := xr_camera.global_position
	_assist_grazing_lip(desired)
	desired=xr_camera.global_position
	if _last_head.is_finite():
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _head_probe
		query.transform = Transform3D(Basis.IDENTITY, _last_head)
		query.motion = desired - _last_head
		query.collision_mask = 5
		query.exclude = [get_rid()]
		var fractions := get_world_3d().direct_space_state.cast_motion(query)
		if fractions[0] < 1.0:
			var safe := _last_head + query.motion * maxf(0.0, fractions[0] - .002)
			xr_origin.global_position += safe - desired
	# Recenter only the logical feet under the safe head, preserving all XR poses.
	var recenter := xr_camera.global_position - global_position
	recenter.y = 0.0
	global_position += recenter
	_artificial_origin_offset += recenter
	xr_origin.global_position -= recenter
	_sync_head_shape()
	_last_head = xr_camera.global_position
func update_head_obstruction() -> bool:
	head_obstructed = xr_enabled and tracking_available and is_head_position_obstructed(xr_camera.global_position)
	return head_obstructed

func is_head_position_obstructed(head_position: Vector3) -> bool:
	# The swept tracked-head path is enforced in _sync_body_to_head. A
	# torso-to-head ray would wrongly block a body clipped through a ledge.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _head_probe
	query.transform = Transform3D(Basis.IDENTITY, head_position)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
func find_grab_surface(point: Vector3) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _grab_shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.get_rest_info(query)

func _update_grab(hand: Node3D, pressed: bool, allow_launch: bool = true) -> void:
	if not pressed:
		if _grabs.has(hand):
			var released_anchor:Vector3=_grabs[hand]
			_grabs.erase(hand)
			if _grabs.is_empty():
				if allow_launch and try_start_release_mantle(released_anchor): return
				velocity = _release_velocity.limit_length(7.0) * clampf(fling_power, 0.0, 5.0) * 1.25 if allow_launch else Vector3.ZERO
				_climb_launch_pending=allow_launch and velocity.length_squared()>.001
				if not allow_launch:
					_release_velocity = Vector3.ZERO
		return
	# Reload/objective reservations gate new claims, never revoke an existing
	# physical wall anchor. Only grip release (or tracking loss) releases it.
	# left_hand_reserved includes every waiting reload stage, even when an
	# empty gun has no part in this hand. Only actual reload proximity/held
	# parts, objectives and a drawn weapon can prevent a new physical anchor.
	if not _grabs.has(hand) and (is_hand_grip_reserved(hand) or _reload_claims_hand(hand) or _hand_holds_item(hand) or (is_instance_valid(sprint_conflict_provider) and sprint_conflict_provider.has_method("is_hand_holding_weapon") and sprint_conflict_provider.is_hand_holding_weapon(hand))):
		return
	if _grab_cooldown <= 0.0 and not _grabs.has(hand) and not find_grab_surface(hand.global_position).is_empty():
		_grabs[hand] = hand.global_position
		_release_velocity = Vector3.ZERO

func apply_climb_motion(displacement: Vector3, delta: float) -> void:
	_assist_grazing_lip(get_view_camera().global_position+displacement)
	_sync_head_shape()
	_supported = false
	# Head sweeps block walls/ceilings; torso may pass through a ledge.
	velocity = displacement.limit_length(0.3) / maxf(delta, 0.001)
	move_and_slide()
	_release_velocity = _release_velocity.lerp(velocity, 0.35)

func _assist_grazing_lip(target_head:Vector3)->void:
	# A coplanar lower goggle rim can be classified as a lateral collision.
	# Resolve only the numerical contact band with a real, <=6mm upward sweep.
	# Taller walls, missing floor and ceilings never receive a crossing bypass.
	var head:=get_view_camera().global_position
	var from:=Vector3(target_head.x,head.y+.012,target_head.z)
	var to:=Vector3(target_head.x,head.y-.012,target_head.z)
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()]))
	if hit.is_empty() or hit.normal.y<.98:return
	var top:float=hit.position.y
	if absf(top-head.y)>.0025 or top-global_position.y<.15:return
	var lift:=clampf(top-head.y+.003,.001,.006)
	_sync_head_shape()
	move_and_collide(Vector3.UP*lift)

func _update_desktop_climb(delta: float) -> void:
	if _grab_cooldown > 0.0:
		return
	var pressed := Input.is_physical_key_pressed(KEY_E)
	if not pressed:
		_update_grab(desktop_camera, false)
		return
	if _grabs.has(desktop_camera):
		_grabs[desktop_camera] += Vector3.UP * 2.2 * delta
		return
	var camera := desktop_camera
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 1.35, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and absf(hit.normal.y) < 0.75:
		_grabs[camera] = camera.global_position

func try_start_release_mantle(_anchor: Vector3) -> bool:
	# Release uses the same head support as walking. A refused attempt is atomic:
	# no small inward shift or partial elevation survives a blocked standing path.
	if mantling or not _grabs.is_empty() or not input_enabled: return false
	_mantle_route.clear()
	var before:=global_transform
	var old_head:=_last_head
	var old_supported:=_supported
	var old_velocity:=velocity
	var hit:=_support_hit()
	if (hit.is_empty() or hit.normal.y<cos(floor_max_angle) or get_view_camera().global_position.y-hit.position.y>.065) and _recover_grazing_release(_anchor):hit=_support_hit()
	var rise:float=float(hit.get("position",global_position).y)-global_position.y
	if hit.is_empty() or rise<.02 or not _resolve_support(head_support_rise()):
		global_transform=before
		_last_head=old_head
		_supported=old_supported
		velocity=old_velocity
		_sync_head_shape()
		_mantle_route.clear()
		return false
	# The exact solver just preflighted the complete head-only route without
	# yielding. Restore the start before any frame is rendered, then traverse
	# the same segments over200ms, sweeping again against live geometry.
	var standing:=global_position
	var previous:=before.origin
	if not _mantle_route.is_empty():
		for motion:Vector3 in _mantle_route:previous+=motion
	_mantle_route.append(standing-previous)
	global_transform=before;_supported=false;_last_head=old_head;_sync_head_shape()
	_mantle_elapsed=0;_mantle_travelled=0;_mantle_length=0
	for motion:Vector3 in _mantle_route:_mantle_length+=motion.length()
	mantling=true
	velocity=Vector3.ZERO
	_release_velocity=Vector3.ZERO
	_climb_launch_pending=false
	climbing=false
	gliding=false
	_last_head=get_view_camera().global_position
	return true

func _recover_grazing_release(anchor:Vector3)->bool:
	_sync_head_shape()
	var route:=preload("res://scripts/release_mantle.gd").plan_grazing(self,_body_shape,get_view_camera().global_position,anchor)
	if route.is_empty():return false
	var before:=global_transform
	for motion:Vector3 in [route.lift,route.inward]:
		var expected:=global_position+motion
		if move_and_collide(motion)!=null or global_position.distance_to(expected)>.001:
			global_transform=before;_mantle_route.clear();return false
		_mantle_route.append(motion)
	return true

func try_start_mantle() -> bool:
	return false # No separate mantle gesture or route.

func _step_mantle(delta: float) -> void:
	if not mantling or not input_enabled or not is_finite(delta) or delta<=0:return
	_mantle_elapsed=minf(MANTLE_COMPLETION_SECONDS,_mantle_elapsed+delta)
	var t:=_mantle_elapsed/MANTLE_COMPLETION_SECONDS
	var wanted:=_mantle_length*t*t*(3.0-2.0*t) # Rapid rise, eased start/finish.
	var budget:=maxf(0,wanted-_mantle_travelled)
	while budget>.000001 and not _mantle_route.is_empty():
		var remaining:=_mantle_route[0]
		if remaining.length()<.000001:_mantle_route.pop_front();continue
		var motion:=remaining.limit_length(budget)
		_sync_head_shape()
		var start:=global_position
		var collision:=move_and_collide(motion)
		# Match normal support's numerical recovery at the lower goggle rim.
		for recovery in range(4):
			if collision==null or motion.y<=0 or collision.get_normal().y<cos(floor_max_angle):break
			var rest:=start+motion-global_position
			if rest.length()<.0001:break
			collision=move_and_collide(rest)
		if collision!=null and global_position.distance_to(start+motion)>.001:
			# A moved ceiling, wall or changed tracked head can invalidate the
			# route after preflight. Keep the solver's safe partial position.
			mantling=false;_mantle_route.clear();_supported=false;velocity=Vector3.ZERO
			_last_head=get_view_camera().global_position;return
		_mantle_route[0]-=motion
		budget-=motion.length();_mantle_travelled+=motion.length()
		if _mantle_route[0].length()<.000001:_mantle_route.pop_front()
	_last_head=get_view_camera().global_position
	velocity=Vector3.ZERO
	if _mantle_elapsed>=MANTLE_COMPLETION_SECONDS:
		mantling=false;_mantle_route.clear();_resolve_support(.02,false)
func reset_motion() -> void:
	_movement_heading_ready_089=false
	_supported = false
	_last_head = Vector3.INF
	_glide_bank=0.0
	# Mission advancement may reset motion from inside the grip signal. Keep
	# that consumed press reserved until physical release, including this tick.
	_objective_grip_arbiter.reset(true)
	_climb_launch_pending=false
	sprinting = false
	_sprint_mode = 0
	_sprint_click_held = false
	_sprint_click_age = INF
	_sprint_stamina = sprint_stamina_seconds
	_auto_snap_timer = 0.0
	_smooth_turn_rate = 0.0
	velocity = Vector3.ZERO
	_grabs.clear()
	climbing = false
	gliding = false
	_desktop_glide = false
	_release_velocity = Vector3.ZERO
	mantling = false
	_mantle_route.clear();_mantle_elapsed=0;_mantle_length=0;_mantle_travelled=0
	_grab_cooldown = 0.0
	_jump_button_held = false
	_jump_requested = false
	_snap_ready = true


func get_weapon_hand() -> XRController3D:
	return left_hand if dominant_hand=="left" else right_hand

func get_support_hand() -> XRController3D:
	return right_hand if dominant_hand=="left" else left_hand

func weapon_hand_climbing() -> bool:
	return climbing_left if dominant_hand=="left" else climbing_right
func get_effective_glide_speed() -> float:
	return effective_walk_speed() * GLIDE_SPEED / WALK_SPEED * network_flight_multiplier

func effective_walk_speed() -> float:
	return move_speed * clampf(walk_speed_multiplier,0.25,3.0)

func sprint_requested(delta: float = 0.0) -> bool:
	_sprint_click_age += maxf(delta, 0.0)
	if _sprint_stamina < 0.0:
		_sprint_stamina = sprint_stamina_seconds
	else:
		_sprint_stamina = clampf(_sprint_stamina, 0.0, sprint_stamina_seconds)
	var eligible := xr_enabled and input_enabled and is_hand_input_ready(left_hand)
	eligible = eligible and is_supported() and not climbing and not mantling and _grabs.is_empty()
	if sprint_binding == "left_grip": eligible = eligible and not left_hand_reserved and not is_hand_grip_reserved(left_hand)
	if sprint_binding == "left_grip" and is_instance_valid(sprint_conflict_provider) and sprint_conflict_provider.has_method("blocks_sprint"):
		eligible = eligible and not sprint_conflict_provider.blocks_sprint()
	if not eligible:
		_sprint_click_held = xr_enabled and is_instance_valid(left_hand) and (left_hand.get_float("grip") > 0.65 if sprint_binding == "left_grip" else left_hand.is_button_pressed("primary_click"))
		# Transient arbitration suspends speed but preserves the latched tier.
		if not input_enabled or climbing or mantling: _sprint_mode = 0
	else:
		var grip_binding := sprint_binding == "left_grip"
		var pressed := left_hand.get_float("grip") > 0.65 if grip_binding else left_hand.is_button_pressed("primary_click")
		var grip_clear := not grip_binding or not pressed or find_grab_surface(left_hand.global_position).is_empty()
		if grip_binding and not grip_clear:
			# Climbing has priority; holding the grip as contact ends cannot
			# manufacture a new sprint press.
			_sprint_mode = 0
		if pressed and not _sprint_click_held and grip_clear:
			if _sprint_mode == 1:
				_sprint_mode = 2
			elif _sprint_mode != 0:
				_sprint_mode = 0
			elif _sprint_stamina >= sprint_stamina_seconds * 0.25:
				_sprint_mode = 1
			_sprint_click_age = 0.0
		_sprint_click_held = pressed
	var moving := eligible and left_hand.get_vector2("primary").length() > 0.3
	# Releasing locomotion cancels either tier. Preserve the sampled click latch:
	# resuming movement while holding it cannot manufacture a fresh sprint edge.
	if xr_enabled and left_hand.get_vector2("primary").length() <= 0.3:
		_sprint_mode = 0
	if _sprint_mode != 0 and moving:
		_sprint_stamina = maxf(0.0, _sprint_stamina - maxf(delta, 0.0))
		if _sprint_stamina <= 0.0:
			_sprint_mode = 0
	else:
		_sprint_stamina = minf(sprint_stamina_seconds, _sprint_stamina + maxf(delta, 0.0) * sprint_stamina_seconds / maxf(sprint_recovery_seconds, 0.01))
	return moving and _sprint_mode != 0

func is_hand_grip_reserved(hand:Node3D)->bool:
	return _objective_grip_arbiter.is_reserved(hand)
func _reload_claims_hand(hand:Node3D)->bool:
	return is_instance_valid(sprint_conflict_provider) and sprint_conflict_provider.has_method("reload_claims_hand") and sprint_conflict_provider.reload_claims_hand(hand)
func _hand_holds_item(hand:Node3D)->bool:
	return is_instance_valid(held_item_provider) and held_item_provider.has_method("hand_holds_item") and held_item_provider.hand_holds_item(hand)

func update_objective_grips()->void:
	# Weapon polling may run first; one shared arbitration pass per physics tick
	# makes objective claims visible before reload/support/climb consumers.
	var frame:=Engine.get_physics_frames()
	if frame==_objective_grip_frame:return
	_objective_grip_frame=frame
	if not xr_enabled or not input_enabled or mantling or head_obstructed:
		_objective_grip_arbiter.reset()
		return
	var samples:Array=[]
	for hand in [left_hand,right_hand]:
		if not is_instance_valid(hand):continue
		samples.append({"hand":hand,"ready":is_hand_input_ready(hand),"grip":hand.get_float("grip"),"position":hand.global_position,"reference":get_view_camera().global_position,"blocked":_grabs.has(hand) or _reload_claims_hand(hand)})
	var targets:Array=[]
	if objective_grip_provider.is_valid():
		var supplied=objective_grip_provider.call()
		if supplied is Array:targets=supplied
	var event:Dictionary=_objective_grip_arbiter.step(samples,targets,get_world_3d().direct_space_state,[get_rid()])
	if not event.is_empty():objective_grip_requested.emit(event.id,event.hand)




















func intercept_bullet(origin:Vector3,endpoint:Vector3)->Dictionary:
	if not input_enabled or not is_instance_valid(sprint_conflict_provider):return {}
	return sprint_conflict_provider.intercept_bullet(origin,endpoint) if sprint_conflict_provider.has_method("intercept_bullet") else {}





static func controller_horizontal_heading(pose:Basis)->Vector3:
	# Fold the aiming vector past the vertical pole. The controller top then carries heading.
	var forward:Vector3=-pose.z
	if pose.y.dot(Vector3.UP)<0.0:forward=-forward
	forward.y=0
	if forward.length_squared()<.001:
		forward=-pose.y*signf((-pose.z).y);forward.y=0
	return forward.normalized()

func continuous_controller_heading_089(pose:Basis)->Vector3:
	# A projected ray changes sign at the vertical pole. Keep azimuth continuous;
	# rolling the controller around its barrel must not reverse locomotion either.
	var flat:Vector3=-pose.z;flat.y=0
	var previous:Vector3=global_basis.orthonormalized()*_movement_heading_local_089
	if _movement_heading_ready_089:
		if flat.length_squared()<.001:return previous.normalized()
		flat=flat.normalized()
		if flat.dot(previous)<0:flat=-flat
	else:flat=controller_horizontal_heading(pose)
	if flat.length_squared()>.001:
		_movement_heading_local_089=global_basis.orthonormalized().inverse()*flat;_movement_heading_ready_089=true
	return flat
