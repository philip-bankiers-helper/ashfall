extends "res://scripts/weapon.gd"
const HeavyModelFinish=preload("res://scripts/heavy_model_finish.gd")
## Original Atlas: observed box-up / belt-across / cover-down / charge-back reload.
const COVER_POINT:=Vector3(0,.11,-.16)
const BOX_POINT:=Vector3(-.09,-.09,-.08)
const BOX_OFFER:=Vector3(-.09,-.34,-.08)
const BELT_POINT:=Vector3(-.16,.09,-.11)
const FEED_TRAVEL:=.08
const HANDLE_POINT:=Vector3(.065,.045,-.10)
var cover:Node3D
var belt_box:MeshInstance3D
var belt:Node3D
var offered_box:Node3D
var held_box:Node3D
var charging_handle:MeshInstance3D
var belt_feed_grip:MeshInstance3D
var belt_fed:=true
var cover_grip:MeshInstance3D
var box_grip:MeshInstance3D
var offer_grip:MeshInstance3D
var held_grip:MeshInstance3D
var feed_socket:MeshInstance3D
var reload_arrow:Node3D
var _cue_active:Material
var _cue_idle:Material
var _motion_progress:=0.0
var _motion_stage:=""
var maximum_rps:=8.0
var spool_shots:=0
var seated:=60
var contact:=false
var previous:=true
var _sample_needs_neutral:=true
var start:=Vector3.ZERO
func reload_grip_in_progress()->bool:return contact or reload_state=="holding_box"
func get_reload_zones()->Array:
	if reload_state=="ready":return []
	return [{"position":get_reload_grab_point(),"radius":.105}]
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	magazine_size=60;ammo=60;seated=60;fire_interval=.105;damage=30
	update_ammo_display()
func eject_magazine()->void:
	begin_reload()
func get_loaded_rounds()->int:return ammo if reload_state=="ready" else seated
func get_reload_hint()->String:return ""
func _process(delta:float)->void:
	super._process(delta)
	for part in [magazine,loose_magazine,hip_source,guide,insertion_arrow,charging_arrow,bolt,firing_carrier]:part.hide()
	_update_reload_visuals()
	belt_box.visible=reload_state in ["ready","cover_open","needs_feed","box_seated","needs_charge"]
	belt.visible=seated>0 and belt_box.visible
	offered_box.visible=reload_state=="box_removed" and reserve_rounds()!=0 and _input_allowed()
	held_box.visible=reload_state=="holding_box" and _input_allowed()
	if held_box.visible and _vr_active():held_box.global_transform=corrected_grip_transform(left_hand.global_transform)
	update_ammo_display()
func fire()->void:
	if recoil_idle>.6:spool_shots=0
	fire_interval=1.0/lerpf(maximum_rps*.5,maximum_rps,minf(float(spool_shots)/10.0,1.0))
	var before:=ammo
	super.fire()
	if ammo<before:seated=ammo;spool_shots+=1
func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand) or _weapon_hand_climbing() or (_has_head_obstruction and player.get("head_obstructed")):_suspend_gestures();return
	var click:=right_hand.is_button_pressed("primary_click")
	if click and not _eject_click_previous and manual_click_eject_allowed():begin_reload()
	_eject_click_previous=click
	var stick:=right_hand.get_vector2("primary")
	if stick.length()<.25:_eject_previous=false
	elif stick.y<-.7 and absf(stick.x)<.5 and not _eject_previous:begin_reload();_eject_previous=true
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:_requires_trigger_release=false
	elif not _requires_trigger_release:fire()
	if not _hand_input_ready(left_hand) or _support_grip_reserved():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	reload_sample(reload_local_point(left_hand.global_position),grip,true)
func reload_sample(point:Vector3,grip:bool,valid:bool)->void:
	if not valid or not _input_allowed() or _support_hand_climbing() or _weapon_hand_climbing():
		contact=false;previous=true;_sample_needs_neutral=true
		if reload_state=="holding_box":_set_stage("box_removed","")
		return
	var target:=get_reload_grab_point()
	if not grip:
		contact=false;_motion_progress=0.0;_sample_needs_neutral=false
		if reload_state=="holding_box":_set_stage("box_removed","" )
		if charging_handle!=null:charging_handle.position=get_handle_point()
	elif not previous and not contact and not _sample_needs_neutral and _in_reload_reach(point,target,.105):
		contact=true;start=point;_motion_progress=0.0;_motion_stage=reload_state
		if reload_state=="box_removed":grab_magazine()
	if contact and grip:
		match reload_state:
			"ready":contact=false # Reload intent opens/ejects automatically; no manual lift step.
			"cover_open":
				_motion_progress=clampf((start.y-point.y)/.09,0,1)
				if start.y-point.y>=.09:remove_box();contact=false
			"holding_box":
				if point.y-start.y>=.13 and _in_reload_reach(point,get_box_seat(),.09):insert_magazine();contact=false
			"needs_feed":
				_motion_progress=clampf(((point.x-start.x)*feed_direction())/FEED_TRAVEL,0,1)
				if (point.x-start.x)*feed_direction()>=FEED_TRAVEL:feed_belt();contact=false
			"box_seated":
				_motion_progress=clampf((start.y-point.y)/.075,0,1)
				if start.y-point.y>=.075:close_cover();contact=false
			"needs_charge":
				_motion_progress=clampf((point.z-start.z)/.11,0,1)
				charging_handle.position=get_handle_point()+Vector3(0,0,clampf(point.z-start.z,0,.11))
				if point.z-start.z>=.10:rack_bolt();contact=false;charging_handle.position=get_handle_point()
	previous=grip
	_update_reload_visuals()
func begin_reload()->bool:
	if reload_state!="ready" or not _input_allowed() or (ammo>0 and _support_hand_climbing()) or _weapon_hand_climbing():return false
	var remaining:=ammo
	var returned:=refund_rounds(remaining)
	ammo=remaining-returned;seated=ammo
	if returned<remaining:update_ammo_display();return false
	belt_fed=false;contact=false;previous=true;_motion_progress=0.0;_requires_trigger_release=true
	_set_stage("box_removed","");_update_reload_visuals();return true
func open_cover()->void:
	begin_reload()
func remove_box()->void:
	if reload_state=="cover_open" and _input_allowed() and not _support_hand_climbing() and not _weapon_hand_climbing():
		var remaining:=ammo if seated==ammo else seated
		var returned:=refund_rounds(remaining)
		ammo=remaining-returned;seated=ammo
		if returned<remaining:return
		_set_stage("box_removed","")
func grab_magazine()->void:
	if reload_state=="box_removed" and reserve_rounds()!=0 and _input_allowed() and not _support_hand_climbing() and not _weapon_hand_climbing():_set_stage("holding_box","")
func insert_magazine()->void:
	if reload_state!="holding_box" or not _input_allowed() or _support_hand_climbing() or _weapon_hand_climbing():return
	var count:=take_reserve(magazine_size)
	if count<=0:_set_stage("box_removed","");return
	seated=count;belt_fed=false;_set_stage("needs_feed","")
func close_cover()->void:
	if reload_state=="box_seated" and _input_allowed() and not _support_hand_climbing() and not _weapon_hand_climbing():_set_stage("needs_charge","")
func rack_bolt()->void:
	if reload_state=="needs_charge" and _input_allowed() and not _support_hand_climbing() and not _weapon_hand_climbing():
		ammo=seated;_set_stage("ready","");_requires_trigger_release=true
func desktop_reload_step()->void:
	match reload_state:
		"ready":open_cover()
		"cover_open":remove_box()
		"box_removed":grab_magazine();insert_magazine()
		"holding_box":insert_magazine()
		"needs_feed":feed_belt()
		"box_seated":close_cover()
		"needs_charge":rack_bolt()
func _suspend_left_gestures()->void:
	super._suspend_left_gestures();contact=false;previous=true;_motion_progress=0.0;_sample_needs_neutral=true
	_update_reload_visuals()
	if reload_state=="holding_box":_set_stage("box_removed","")
func _on_dominance_changed()->void:
	contact=false;previous=true
	if reload_state=="holding_box":_set_stage("box_removed","")
func reset_weapon()->void:
	super.reset_weapon();ammo=magazine_size;seated=magazine_size;spool_shots=0;contact=false;previous=true;belt_fed=true;update_ammo_display()
func get_shot_transform()->Transform3D:
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,.04,-.91)))
func _build_model()->void:
	super._build_model()
	for child in model.get_children():
		if child not in [magazine,bolt,firing_carrier,guide,muzzle_flash,ammo_label,insertion_arrow,charging_arrow]:child.hide()
	var metal:=_material(Color("47545b"),.8,.32)
	var dark:=_material(Color("172227"),.3,.6)
	var brass:=_material(Color("b58d43"),.8,.34)
	_beveled(Vector3(.10,.10,.34),Vector3(0,.02,-.17),metal)
	_beveled(Vector3(.08,.10,.22),Vector3(0,-.025,.19),dark)
	_beveled(Vector3(.045,.12,.07),Vector3(0,-.095,0),dark)
	# The unchanged -.91m muzzle plane is finished by the hollow crown below.
	_rod(Vector3(0,.04,-.31),Vector3(0,.04,-.89),.021,metal)
	_beveled(Vector3(.075,.07,.20),FOREGRIP_POINT,dark)
	cover=Node3D.new();cover.name="HingedFeedCover";cover.position=COVER_POINT;model.add_child(cover)
	_box(Vector3(.105,.025,.25),Vector3(0,0,-.07),metal,cover)
	belt_box=_beveled(Vector3(.14,.14,.16),BOX_POINT,dark);belt_box.name="DetachableBeltBox"
	belt=Node3D.new();belt.name="VisibleLinkedBelt";model.add_child(belt)
	for i in range(6):
		_rod(Vector3(-.10+i*.018,.075,-.15),Vector3(-.10+i*.018,.075,-.23),.006,brass,8,belt)
		_box(Vector3(.012,.005,.015),Vector3(-.10+i*.018,.075,-.19),dark,belt)
	offered_box=Node3D.new();offered_box.position=BOX_OFFER;model.add_child(offered_box)
	held_box=Node3D.new();add_child(held_box)
	for node in [offered_box,held_box]:_box(Vector3(.14,.14,.16),Vector3.ZERO,dark,node)
	offered_box.hide();held_box.hide()
	for part in [magazine,loose_magazine,hip_source,guide,insertion_arrow,charging_arrow,bolt,firing_carrier]:part.hide()
	charging_handle=_box(Vector3(.035,.02,.03),HANDLE_POINT,metal)
	var sights:=WeaponFinish.zeroed_sights(model,-.02,-.80,.12,Vector3(0,.04,-.91),80,metal,brass)
	sight_rear=sights.find_child("RearReference",true,false);sight_front=sights.find_child("FrontReference",true,false)
	muzzle_flash.position=Vector3(0,.04,-.93)
	_build_reload_affordances()
	HeavyModelFinish.m60(self)
	if not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/downloaded_m60_087.gd").apply(self)




func get_reload_grab_point()->Vector3:
	match reload_state:
		"cover_open":return get_box_seat()+mirror_point(Vector3(-.075,0,0))
		"box_removed":return get_box_offer()+mirror_point(Vector3(-.075,0,0))
		"holding_box":return get_box_seat()
		"needs_feed":return mirror_point(_fit_point_087("belt_grab",BELT_POINT))
		"needs_charge":return get_handle_point()
	if has_meta("m60_fit_087"):return cover.position+cover.basis*_fit_point_087("cover_grab",Vector3.ZERO)
	return COVER_POINT
func _build_reload_affordances()->void:
	_cue_idle=_material(Color("71818a"),.78,.38)
	_cue_active=_material(Color("e5b646"),.48,.3,.55)
	# Actual ribbed handles belong to their moving parts, never detached HUD labels.
	cover_grip=_beveled(Vector3(.065,.021,.025),Vector3(0,.014,0),_cue_idle,.004,cover);cover_grip.name="FeedCoverLiftGrip"
	for i in range(5):_box(Vector3(.003,.023,.027),Vector3(-.024+i*.012,0,0),_cue_idle,cover_grip)
	box_grip=_beveled(Vector3(.018,.07,.035),Vector3(-.075,0,0),_cue_idle,.004,belt_box);box_grip.name="BeltBoxPullGrip"
	offer_grip=_box(Vector3(.018,.07,.035),Vector3(-.075,0,0),_cue_idle,offered_box);offer_grip.name="OfferedBoxGrip"
	held_grip=_box(Vector3(.018,.07,.035),Vector3(-.075,0,0),_cue_idle,held_box);held_grip.name="HeldBoxGrip"
	feed_socket=_box(Vector3(.10,.015,.08),BOX_POINT+Vector3(0,.08,0),_cue_idle);feed_socket.name="BeltBoxSeatingSocket"
	belt_feed_grip=_beveled(Vector3(.035,.018,.045),Vector3(-.10,.09,-.11),_cue_idle,.004,belt);belt_feed_grip.name="LinkedBeltAcrossFeedGrip"
	charging_handle.name="RearwardChargingGrip"
	for i in range(4):_box(Vector3(.037,.003,.032),Vector3(0,-.007+i*.005,0),_cue_idle,charging_handle)
	reload_arrow=Node3D.new();reload_arrow.name="PhysicalReloadMotionChevron";add_child(reload_arrow)
	_rod(Vector3(0,-.025,0),Vector3(0,.025,0),.0025,_cue_active,8,reload_arrow)
	_rod(Vector3(0,.025,0),Vector3(-.012,.009,0),.0025,_cue_active,8,reload_arrow)
	_rod(Vector3(0,.025,0),Vector3(.012,.009,0),.0025,_cue_active,8,reload_arrow)
	_update_reload_visuals()
func _update_reload_visuals()->void:
	if cover_grip==null:return
	var active:=_input_allowed() and model.visible
	if _vr_active():active=active and _hand_input_ready(right_hand) and _hand_input_ready(left_hand)
	cover.rotation.x=0.0 if reload_state in ["ready","needs_charge"] else -1.35
	belt_box.position=get_box_seat()
	offered_box.position=get_box_offer()
	box_grip.position.x=-.075*feed_direction()
	offer_grip.position.x=-.075*feed_direction()
	held_grip.position.x=-.075*feed_direction()
	feed_socket.position=mirror_point(_fit_point_087("feed_home",BOX_POINT+Vector3(0,.08,0)))
	belt.scale.x=feed_direction()
	charging_handle.position=get_handle_point()
	var donor_delta:Vector3=get_meta("m60_donor_delta_088",Vector3.ZERO)
	belt.position.x=(donor_delta.x-(0.0 if belt_fed else FEED_TRAVEL))*feed_direction()
	if contact and _motion_stage==reload_state:
		match reload_state:
			"ready":cover.rotation.x=-1.35*_motion_progress
			"cover_open":belt_box.position.y-=.09*_motion_progress
			"needs_feed":belt.position.x=(donor_delta.x-FEED_TRAVEL*(1.0-_motion_progress))*feed_direction()
			"box_seated":cover.rotation.x=-1.35*(1.0-_motion_progress)
			"needs_charge":charging_handle.position.z+=.11*_motion_progress
	cover_grip.material_override=_cue_active if active and reload_state=="box_seated" else _cue_idle
	box_grip.material_override=_cue_active if active and reload_state=="cover_open" else _cue_idle
	offer_grip.material_override=_cue_active if active and reload_state=="box_removed" else _cue_idle
	held_grip.material_override=_cue_active if active and reload_state=="holding_box" else _cue_idle
	feed_socket.material_override=_cue_active if active and reload_state=="holding_box" else _cue_idle
	belt_feed_grip.material_override=_cue_active if active and reload_state=="needs_feed" else _cue_idle
	charging_handle.material_override=null if has_meta("articulated_m60_087") else (_cue_active if active and reload_state=="needs_charge" else _cue_idle)
	feed_socket.visible=reload_state in ["box_removed","holding_box"]
	var direction:=Vector3.UP
	match reload_state:
		"cover_open","box_seated":direction=Vector3.DOWN
		"needs_feed":direction=Vector3.RIGHT*feed_direction()
		"needs_charge":direction=Vector3.BACK
	reload_arrow.transform=model.transform*Transform3D(Basis(Quaternion(Vector3.UP,direction)),get_reload_grab_point()+Vector3(.06,0,0))
	reload_arrow.visible=active and reload_state not in ["ready","box_removed"]


func feed_belt()->void:
	if reload_state=="needs_feed" and _input_allowed() and not _support_hand_climbing() and not _weapon_hand_climbing():
		belt_fed=true;_set_stage("box_seated","")
func feed_direction()->float:
	return -1.0 if right_hand==player.get("left_hand") else 1.0
func mirror_point(point:Vector3)->Vector3:
	return Vector3(point.x*feed_direction(),point.y,point.z)
func _fit_point_087(key:String,fallback:Vector3)->Vector3:
	var fit:Dictionary=get_meta("m60_fit_087",{});return fit.get(key,fallback)
func get_box_offer()->Vector3:return mirror_point(_fit_point_087("box_offer",BOX_OFFER))
func get_box_seat()->Vector3:return mirror_point(_fit_point_087("box_home",BOX_POINT))
func get_handle_point()->Vector3:return mirror_point(_fit_point_087("handle_home",HANDLE_POINT))

