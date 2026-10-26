extends "res://scripts/compact_smg.gd"
## Crest P90-style PDW: automatic ejection, magazine FORWARD then handle BACK.
const TOP_SEAT:=Vector3(0,0.113,-0.17)
const TOP_OFFER:=Vector3(0,0.113,0.0)
func get_top_seat()->Vector3:return _top_rest if has_meta("downloaded_model_077") else TOP_SEAT
func get_top_offer()->Vector3:
	var previous:Vector3=get_top_seat()+Vector3.BACK*.17 if has_meta("downloaded_model_077") else TOP_OFFER
	return previous+Vector3(0,.0508,.0508)/visual_model_scale() # fresh physical inches, independent of visual fit
func get_reload_zones()->Array:
	match reload_state:
		"needs_mag":return [{"position":get_top_offer(),"radius":.25}]
		"held_mag":return [{"position":get_top_seat(),"radius":.25}]
		"needs_rack":return [{"position":get_charge_point(),"radius":.12}]
	return []
var _top_rest:=Vector3.ZERO
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	#0991 move the flash's rear face onto the visible muzzle, retaining the shot datum.
	var muzzle:Vector3=get_meta("download_muzzle_084",Vector3(0,.045,-.46))
	var rear:Vector3=muzzle_flash.transform*(muzzle_flash.mesh.get_aabb().get_center()-Vector3.UP*muzzle_flash.mesh.get_aabb().size.y*.5)
	muzzle_flash.position+=muzzle-rear
	magazine_size=40
	ammo=40
	damage=17.0
	fire_interval=0.08
	update_ammo_display()
	preload("res://scripts/downloaded_firearm_model.gd").replace_debris(self)
func _build_model()->void:
	super._build_model()
	var cue:=preload("res://scripts/reload_visuals_089.gd").yellow()
	# Compact base creates empty cue nodes; give both real, readable arrow meshes.
	_rod(Vector3.ZERO,Vector3(0,.10,0),.003,cue,8,insertion_arrow)
	for side in [-1.0,1.0]:_rod(Vector3(0,.10,0),Vector3(side*.018,.072,0),.003,cue,8,insertion_arrow)
	_rod(Vector3.ZERO,Vector3(0,0,.10),.003,cue,8,charging_arrow)
	for side in [-1.0,1.0]:_rod(Vector3(0,0,.10),Vector3(side*.018,0,.072),.003,cue,8,charging_arrow)
	magazine.free()
	loose_magazine.free()
	hip_source.free()
	var polymer:=_material(Color("77744b"),0.2,0.66)
	var dark:=_material(Color("242b2c"),0.4,0.48)
	# Broad low-profile magazine and a receiver saddle are unmistakably above bore.
	magazine=_beveled(Vector3(0.083,0.036,0.245),TOP_SEAT,polymer,0.008)
	_top_rest=TOP_SEAT
	for x in [-0.042,0.042]:
		for i in range(6):
			_box(Vector3(0.002,0.021,0.006),Vector3(x,0,-0.096+i*0.035),dark,magazine)
	_beveled(Vector3(0.086,0.013,0.255),TOP_SEAT-Vector3(0,0.027,0),dark,0.004)
	loose_magazine=_beveled(Vector3(0.083,0.036,0.245),Vector3.ZERO,polymer,0.008,self)
	loose_magazine.hide()
	hip_source=Node3D.new()
	add_child(hip_source)
	_beveled(Vector3(0.083,0.036,0.245),Vector3.ZERO,polymer,0.008,hip_source)
	hip_source.hide()
	# Raised references clear the top magazine; original stock remains open.
	sight_rear.get_parent().free()
	var sight:=WeaponFinish.zeroed_sights(model,-0.025,-0.36,0.16,Vector3(0,0.045,-0.46),35.0,dark,polymer)
	sight_rear=sight.find_child("RearReference",true,false)
	sight_front=sight.find_child("FrontReference",true,false)
	preload("res://scripts/long_gun_finish_064.gd").p90(self)
	if preload("res://scripts/downloaded_firearm_model.gd").available("p90"):preload("res://scripts/downloaded_firearm_model.gd").build(self,"p90")
func get_offered_magazine_transform()->Transform3D:
	return Transform3D(global_basis.scaled(Vector3.ONE*visual_model_scale()),reload_world_point(get_top_offer()))
func eject_magazine()->void:
	if reload_state not in ["ready","needs_rack"]:return
	if not _return_magazine_rounds():return
	_requires_trigger_release=true
	_set_stage("needs_mag","")
	magazine.hide()
func _drop_spent_magazine()->void:
	# Automatic disappearance matches the game interaction; no extra extraction gesture.
	pass
func grab_magazine()->void:
	if _support_hand_climbing() or reserve_rounds()==0:return
	if reload_state=="needs_mag":
		_mag_grab_local=reload_local_point(left_hand.global_position) if _vr_active() else get_top_offer()
		_set_stage("held_mag","")
func desktop_reload_step()->void:
	if not _input_allowed():return
	match reload_state:
		"ready":eject_magazine()
		"needs_mag":
			grab_magazine()
			insert_magazine()
		"held_mag":insert_magazine()
		"needs_rack":rack_bolt()
func _process(delta:float)->void:
	super._process(delta)
	if reload_state=="held_mag" and _vr_active():
		loose_magazine.global_basis=global_basis.scaled(Vector3.ONE*visual_model_scale())
	guide.position=get_top_seat() if reload_state=="held_mag" else get_charge_point()
	insertion_arrow.visible=reload_state in ["needs_mag","held_mag"] and _input_allowed()
	charging_arrow.visible=reload_state=="needs_rack" and _input_allowed()
	insertion_arrow.position=(get_top_offer() if reload_state=="needs_mag" else get_top_seat())+Vector3.UP*.04/visual_model_scale()
	insertion_arrow.basis=Basis(Quaternion(Vector3.UP,Vector3.FORWARD))
	charging_arrow.position=get_charge_point()+Vector3.UP*.04/visual_model_scale()
	charging_arrow.basis=Basis.IDENTITY
	bolt.position.x=get_charge_point().x
func get_charge_point()->Vector3:
	return Vector3(.05 if right_hand==player.get("left_hand") else -.05,.064,-.10)
func _suspend_left_gestures()->void:
	super._suspend_left_gestures()
	if is_instance_valid(magazine):magazine.position=_top_rest
func reset_weapon()->void:
	super.reset_weapon()
	magazine.position=_top_rest
func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand):
		_suspend_gestures()
		return
	var trigger:=right_hand.get_float("trigger")>0.65 or right_hand.is_button_pressed("trigger_click")
	var click:=right_hand.is_button_pressed("primary_click")
	if click and not _eject_click_previous and manual_click_eject_allowed():eject_magazine()
	_eject_click_previous=click
	var stick:=right_hand.get_vector2("primary")
	if stick.length()<0.25:_eject_previous=false
	elif stick.y< -0.7 and absf(stick.x)<0.5 and not _eject_previous:
		eject_magazine()
		_eject_previous=true
	if not trigger:_requires_trigger_release=false
	if trigger and not _requires_trigger_release:fire()
	_trigger_previous=trigger
	if not _hand_input_ready(left_hand) or _support_grip_reserved():
		_suspend_left_gestures()
		return
	var grip:=left_hand.get_float("grip")>0.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	var point:=reload_local_point(left_hand.global_position)
	if reload_state=="needs_mag" and grip and not _grip_previous:
		if _in_reload_reach(point,get_top_offer(),.25):grab_magazine()
	elif reload_state=="held_mag":
		if grip and _mag_grab_local.z-point.z>=0.10 and _in_reload_reach(point,get_top_seat(),.25):insert_magazine()
		elif not grip:_set_stage("needs_mag","")
	elif reload_state=="needs_rack":
		if grip and not _grip_previous and not _rack_grabbed and _in_reload_reach(point,get_charge_point(),0.12):
			_rack_grabbed=true
			_rack_start=point
		if _rack_grabbed and grip:
			var travel:=point.z-_rack_start.z
			bolt.position.z=-0.10+clampf(travel,0,0.09)
			if travel>=0.075:rack_bolt()
		if not grip:
			_rack_grabbed=false
			bolt.position.z=-0.10
	_grip_previous=grip



func _kick_recoil(distance:float,angle:float)->void:
	if _endpoint_experiment_enabled():super._kick_recoil(distance,angle);return
	_record_reference_shot()
	var reduction:=.38 if supported else 1.0
	var shot_index:=recoil_pattern_index
	recoil_pattern_index+=1;recoil_idle=0
	var progress:=clampf(float(shot_index)/maxf(1,magazine_size-1),0,1)
	recoil=minf(recoil+distance*reduction,.13)
	recoil_pitch=angle*reduction*(1.0+progress*5.0+.03*sin(float(shot_index)*1.7))
	recoil_yaw=angle*reduction*(.08+.60*progress)*sin(float(shot_index)*.91)
	_apply_recoil_visual();_update_support_visual()

