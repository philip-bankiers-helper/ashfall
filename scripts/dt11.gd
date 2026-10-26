extends "res://scripts/shotgun.gd"
const HeavyModelFinish=preload("res://scripts/heavy_model_finish.gd")
## Empty automatically breaks open. DOWN inserts shells, UP closes: two swipes.
var closure=preload("res://scripts/closure_flick.gd").new()
var swipe_arrow:Node3D
var _swipe_previous:=true
var _swipe_contact:=false
var _swipe_start:=Vector3.ZERO
func reload_grip_in_progress()->bool:return _swipe_contact
func get_reload_zones()->Array:
	if action.state not in ["open_empty","open_loaded"]:return []
	return [{"position":get_reload_grab_point(),"radius":.24 if action.state=="open_loaded" else .16}]
func _build_model()->void:
	super._build_model()
	swipe_arrow=Node3D.new();swipe_arrow.name="UpCloseOnly";model.add_child(swipe_arrow)
	var cue:=_material(Color(1,.72,.16),.15,.5,1)
	_box(Vector3(.009,.09,.006),Vector3(0,.045,0),cue,swipe_arrow)
	for side in [-1.0,1.0]:
		var arm:=_box(Vector3(.009,.035,.006),Vector3(side*.01,.077,0),cue,swipe_arrow);arm.rotation.z=side*.65
	HeavyModelFinish.dt11(self)
	if not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/downloaded_dt11_model.gd").build(self)
func get_reload_grab_point()->Vector3:
	return get_close_grip_point()+Vector3.BACK*.06 if action.state=="open_loaded" else get_shell_offer_point()
func fire()->void:
	var before:int=action.ammo
	super.fire()
	if before>0 and action.ammo==0 and action.state=="ready":
		eject_magazine()
		_hinge_angle=.72;hinge.rotation.x=-_hinge_angle
		_update_reload_affordances()
func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand):_suspend_gestures();return
	var click:=right_hand.is_button_pressed("primary_click")
	if click and not _eject_click_previous:eject_magazine()
	_eject_click_previous=click
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:_semi_release=true;_requires_trigger_release=false
	elif not _requires_trigger_release:fire()
	if not _hand_input_ready(left_hand) or _support_grip_reserved():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	reload_sample(reload_local_point(left_hand.global_position),grip,true)
func reload_sample(point:Vector3,grip:bool,valid:bool)->void:
	if not valid or not _input_allowed() or _support_hand_climbing() or _weapon_hand_climbing():_swipe_contact=false;_swipe_previous=true;return
	if not grip:_swipe_contact=false
	elif not _swipe_contact and action.state in ["open_empty","open_loaded"] and _in_reload_reach(point,get_reload_grab_point(),.24 if action.state=="open_loaded" else .16):_swipe_contact=true;_swipe_start=point
	#086 Preserve085 physical stroke lengths when the imported art doubles.
	var stroke_scale:float=visual_model_scale()/.8 if has_meta("downloaded_model_077") else 1.0
	if grip and _swipe_contact:
		if action.state=="open_empty" and (_swipe_start.y-point.y)*stroke_scale>=.045:
			if action.state=="open_empty":grab_magazine();insert_magazine()
			if action.state=="open_loaded":_swipe_start=point
		elif action.state=="open_loaded" and (point.y-_swipe_start.y)*stroke_scale>=.05:
			rack_bolt();_swipe_contact=false
	_swipe_previous=grip
	_update_reload_affordances()
func desktop_reload_step()->void:
	if not _input_allowed() or _support_hand_climbing():return
	if action.state=="ready":eject_magazine();grab_magazine();insert_magazine()
	elif action.state=="open_empty":grab_magazine();insert_magazine()
	elif action.state=="open_loaded":rack_bolt()
func _suspend_left_gestures()->void:
	super._suspend_left_gestures();_swipe_contact=false;_swipe_previous=true
func _update_reload_affordances()->void:
	if swipe_arrow==null:return
	for part in [open_contact_cue,chamber_contact_cue,close_contact_cue,insert_guide]:
		if part!=null:part.hide()
	# The swipe stays in open_empty until insertion, but its shells are already
	# held. Keep the actual ammunition on that hand throughout the DOWN stroke.
	var loading:bool=action.state=="open_empty" and _input_allowed() and reserve_rounds()!=0
	var carried:bool=loading and _swipe_contact and _vr_active() and _hand_input_ready(left_hand)
	shell_offer.visible=loading and not carried
	shell_pair.visible=carried
	shell_offer.basis=hinge.basis*Basis(Vector3.RIGHT,-PI*.5)
	if carried:shell_pair.global_transform=Transform3D(hinge.global_basis*Basis(Vector3.RIGHT,-PI*.5),left_hand.global_position)
	var available:=reserve_rounds()
	for group in [shell_offer,shell_pair]:
		for shell in group.get_children():
			if shell is Node3D:shell.visible=available<0 or available>=2 or shell.position.x<0
	swipe_arrow.visible=_input_allowed() and action.state=="open_loaded"
	swipe_arrow.position=get_reload_grab_point()
	swipe_arrow.basis=Basis(Quaternion(Vector3.UP,Vector3.UP if action.state=="open_loaded" else Vector3.DOWN))

func gun_flick_sample(point:Vector3,forward:Vector3,delta:float,valid:bool,trigger:bool)->void:
	if action.state not in ["open_empty","open_loaded"]:closure.reset();return
	if closure.sample(point,forward,Vector3.UP,delta,valid and _input_allowed() and not _weapon_hand_climbing(),trigger) and action.state=="open_loaded":rack_bolt()
func rack_bolt()->void:
	# Offhand gestures gate that hand separately. Gun-only flick needs no offhand.
	if not _input_allowed() or _weapon_hand_climbing():return
	if action.close():
		_chamber_occupied=true;_closing=false;_changed("DT11 ready","close")
func _process(delta:float)->void:
	super._process(delta)
	if not _vr_active():return
	var frame:=Transform3D(player.global_basis,player.get_locomotion_anchor_position())
	var pose:Transform3D=frame.affine_inverse()*corrected_grip_transform(right_hand.global_transform)
	gun_flick_sample(pose.origin,-pose.basis.z,delta,_hand_input_ready(right_hand),right_hand.get_float("trigger")>.2 or right_hand.is_button_pressed("trigger_click"))
func _suspend_gestures()->void:
	super._suspend_gestures();closure.reset();_eject_click_previous=true
