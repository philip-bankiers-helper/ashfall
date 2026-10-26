extends "res://scripts/weapon.gd"
const RemainingFinish=preload("res://scripts/remaining_firearm_finish.gd")
## Original compact semi-automatic. Magazine travel and slide pull use tracked base mechanics.
var _semi_armed := true
const LOWER_ASSEMBLY_SHIFT := Vector3(0,0,.04)
const PISTOL_SUPPORT_POINT := Vector3(0,-0.065,-0.095)
func get_magazine_insert_point()->Vector3:
	if has_meta("downloaded_model_077"):return Vector3(0,INSERT_POINT.y,get_meta("download_magazine_home_077").z)
	return super.get_magazine_insert_point()+LOWER_ASSEMBLY_SHIFT
func get_magazine_offer_point()->Vector3:
	if has_meta("downloaded_model_077"):return Vector3(0,OFFER_POINT.y,get_meta("download_magazine_home_077").z)
	return super.get_magazine_offer_point()+LOWER_ASSEMBLY_SHIFT
func setup(actor: Node3D, connect_desktop: bool = true) -> void:
	super.setup(actor, connect_desktop)
	magazine_size=12
	ammo=12
	damage=42.0
	fire_interval=0.21
	preload("res://scripts/downloaded_firearm_model.gd").replace_debris(self)
func _process(delta: float) -> void:
	var held := right_hand.get_float("trigger")>0.65 or right_hand.is_button_pressed("trigger_click") if _vr_active() else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not held: _semi_armed=true
	super._process(delta)
	if has_meta("downloaded_model_077"):magazine.position=get_meta("download_magazine_home_077");insertion_arrow.position.z=magazine.position.z
	if reload_state=="ready":bolt.position.z=-0.10+sin(clampf(_carrier_time/0.095,0.0,1.0)*PI)*0.035
func fire() -> void:
	if not _semi_armed:return
	var before:=ammo
	super.fire()
	if ammo<before:_semi_armed=false
func _update_support(delta: float) -> void:
	if not _input_allowed() or not _hand_input_ready(right_hand) or not _hand_input_ready(left_hand) or _support_grip_reserved():
		_suspend_left_gestures()
		return
	var was_supported := supported
	var gripping := left_hand.get_float("grip") > .55 or left_hand.is_button_pressed("grip_click")
	var fresh := gripping and not _support_grip_previous
	var ready := reload_state == "ready" and not _resume_grip_release
	var free:bool = not (_has_climb_state and (player.get("climbing_left") or player.get("climbing_right")))
	var reach := FOREGRIP_RELEASE if was_supported else FOREGRIP_ACQUIRE
	var close := left_hand.global_position.distance_to(reload_world_point(PISTOL_SUPPORT_POINT)) < reach
	if not ready or not free or not close:
		_support_latched=false
	elif grip_toggle and fresh:
		_support_latched=not _support_latched
	supported=ready and free and close and (_support_latched if grip_toggle else gripping)
	_support_grip_previous=gripping
	_support_weight=move_toward(_support_weight,1.0 if supported else 0.0,maxf(delta,0.0)*9.0)
	# A cupped pistol grip has no forward lever arm. Keep the firing hand's aim;
	# stabilization changes deterministic recoil rather than steering toward a hand.
	if supported and not was_supported:_haptic(left_hand,.16,.035)
	if _has_hand_reservation:_reserve_support_hand(reload_state!="ready" or supported)
	_update_support_visual()
func _update_support_visual() -> void:
	if not supported or not visible or left_hand==null:
		_release_support_visual()
		return
	var visual := left_hand.get_node_or_null("ArticulatedGlove") as Node3D
	if visual==null:return
	if _attached_visual!=visual:
		_release_support_visual()
		_attached_visual=visual
		_attached_rest=visual.transform
	var relative_roll := corrected_grip_transform(left_hand.global_transform).basis.inverse()*(left_hand.global_basis*_attached_rest.basis)
	visual.global_transform=Transform3D(unit_model_basis()*relative_roll,model.to_global(PISTOL_SUPPORT_POINT))
func _kick_recoil(distance: float, angle: float) -> void:
	super._kick_recoil(distance*0.60,angle*1.10)
func _build_model() -> void:
	super._build_model()
	for child in model.get_children():
		if child not in [magazine,bolt,firing_carrier,guide,muzzle_flash,ammo_label,insertion_arrow,charging_arrow]:child.hide()
	var steel:=_material(Color("4d5860"),0.8,0.3)
	var grip:=_material(Color("20272a"),0.15,0.8)
	_beveled(Vector3(0.049,0.025,0.23),Vector3(0,-0.002,-0.13),grip,0.006)
	var slide:=BoxMesh.new()
	slide.size=Vector3(0.052,0.058,0.27)
	bolt.mesh=slide
	bolt.position=Vector3(0,0.04,-0.10)
	var grip_frame:=Node3D.new();grip_frame.name="PX4Grip075";grip_frame.position=Vector3(0,-.07,-.13)+LOWER_ASSEMBLY_SHIFT;grip_frame.rotation.x=-.16;model.add_child(grip_frame)
	var grip_core:=_beveled(Vector3(.052,.13,.074),Vector3.ZERO,grip,.008,grip_frame);grip_core.name="PX4GripCore"
	_rod(Vector3(0,0.04,-0.25),Vector3(0,0.04,-0.274),0.013,steel)
	magazine.scale=Vector3(0.7,0.75,0.7)
	magazine.position+=LOWER_ASSEMBLY_SHIFT
	insertion_arrow.position+=LOWER_ASSEMBLY_SHIFT
	muzzle_flash.position.z+=0.42
	sight_front.get_parent().hide()
	var sights:=WeaponFinish.zeroed_sights(model,-0.015,-0.245,0.083,Vector3(0,0.045,-0.29),35.0,steel,grip)
	sight_rear=sights.find_child("RearReference",true,false)
	sight_front=sights.find_child("FrontReference",true,false)
	RemainingFinish.pistol(self)
	if preload("res://scripts/downloaded_firearm_model.gd").available("px4"):preload("res://scripts/downloaded_firearm_model.gd").build(self,"px4")
func get_shot_transform() -> Transform3D:
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,0.045,-0.29)))
func rack_bolt() -> void:
	super.rack_bolt()




