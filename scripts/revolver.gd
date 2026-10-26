extends "res://scripts/pistol.gd"
## Seven visible rounds. Empty cylinder opens automatically; forward load, upward close.
const CAPACITY:=7
const OPEN_POINT:=Vector3(-.10,.035,-.10)
const ROUND_OFFER:=Vector3(-.18,.095,.13)
const LOAD_TRAVEL:=.06
const CLOSE_TRAVEL:=.05
var chambers:Array[String]=["live","live","live","live","live","live","live"]
var cylinder:Node3D
var cartridges:Array[MeshInstance3D]=[]
var closure=preload("res://scripts/closure_flick.gd").new()
var offered_rounds:Array[Node3D]=[]
var offered:Node3D
var reload_arrow:Node3D
var _gesture_previous:=true
var _contact:=""
var _gesture_start:=Vector3.ZERO
var _index:=0
func reload_grip_in_progress()->bool:return _contact!=""
func get_reload_zones()->Array:
	if reload_state not in ["cylinder_open","cylinder_loaded"]:return []
	return [{"position":get_reload_grab_point(),"radius":.18}]
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	magazine_size=CAPACITY;damage=86;fire_interval=.36;_sync()
func mirror_point(point:Vector3)->Vector3:
	return Vector3(-point.x if player!=null and right_hand==player.get("left_hand") else point.x,point.y,point.z)
func get_reload_grab_point()->Vector3:
	return mirror_point(ROUND_OFFER if reload_state=="cylinder_open" else OPEN_POINT)
func _sync()->void:
	# Safely normalize an older six-chamber serialized/fixture state.
	while chambers.size()<CAPACITY:chambers.append("empty")
	if chambers.size()>CAPACITY:chambers.resize(CAPACITY)
	ammo=chambers.count("live")
	for i in cartridges.size():cartridges[i].visible=chambers[i]=="live"
	update_ammo_display()
func get_loaded_rounds()->int:return chambers.count("live")
func fire()->void:
	if not _semi_armed or cooldown>0 or reload_state!="ready" or not _input_allowed():return
	if _vr_active() and (not _hand_input_ready(right_hand) or _weapon_hand_climbing() or (_has_head_obstruction and player.get("head_obstructed"))):return
	var slot:=chambers.find("live",_index)
	if slot<0:slot=chambers.find("live")
	if slot<0:eject_magazine();return
	chambers[slot]="empty";_index=(slot+1)%CAPACITY;_sync()
	_semi_armed=false;cooldown=fire_interval;_flash_time=.045
	var pose:=get_firing_pose()
	_kick_recoil(.065,deg_to_rad(7.0))
	shot.emit(camera.global_position if not _vr_active() else pose.origin,-pose.basis.z,damage)
	_play_shot();_haptic(right_hand,.65,.06)
	if ammo==0:eject_magazine()
func eject_magazine()->void:
	if reload_state!="ready" or not _input_allowed():return
	_set_stage("cylinder_open","");_contact="";_gesture_previous=true;_requires_trigger_release=true
	_update_reload_visuals()
func grab_magazine()->void:pass # No extra cartridge acquisition step.
func insert_magazine()->void:
	if reload_state!="cylinder_open" or not _mechanism_allowed():return
	var count:=take_reserve(CAPACITY-get_loaded_rounds())
	if count<=0 and get_loaded_rounds()==0:return
	for i in CAPACITY:
		if chambers[i]!="live" and count>0:chambers[i]="live";count-=1
	_set_stage("cylinder_loaded","");_sync();_update_reload_visuals()
func rack_bolt()->void:
	if reload_state!="cylinder_loaded" or not _mechanism_allowed():return
	_close_cylinder()
func _close_cylinder()->void:
	if reload_state!="cylinder_loaded" or not _input_allowed() or _weapon_hand_climbing():return
	_set_stage("ready","");_requires_trigger_release=true;_semi_armed=false;_index=0;_contact=""
	_update_reload_visuals()
func eject_cases()->void:pass # Fired round meshes already disappear, as requested.
func _mechanism_allowed()->bool:
	return _input_allowed() and not _support_hand_climbing() and not _weapon_hand_climbing() and not _support_grip_reserved()
func desktop_reload_step()->void:
	if not _input_allowed():return
	match reload_state:
		"ready":eject_magazine()
		"cylinder_open":insert_magazine()
		"cylinder_loaded":rack_bolt()
func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand):_suspend_gestures();return
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:_requires_trigger_release=false;_semi_armed=true
	elif not _requires_trigger_release:fire()
	var click:=right_hand.is_button_pressed("primary_click")
	if click and not _eject_click_previous and manual_click_eject_allowed():eject_magazine()
	_eject_click_previous=click
	var stick:=right_hand.get_vector2("primary")
	if stick.length()<.25:_eject_previous=false
	elif stick.y<-.7 and absf(stick.x)<.5 and not _eject_previous:eject_magazine();_eject_previous=true
	if not _hand_input_ready(left_hand) or not _mechanism_allowed():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	reload_sample(reload_local_point(left_hand.global_position),grip,true)
func reload_sample(point:Vector3,grip:bool,valid:bool)->void:
	if not valid or not _mechanism_allowed():_contact="";_gesture_previous=true;return
	if not grip:_contact=""
	elif not _gesture_previous and _contact=="" and _in_reload_reach(point,get_reload_grab_point(),.18):
		_contact="load" if reload_state=="cylinder_open" else ("close" if reload_state=="cylinder_loaded" else "")
		_gesture_start=point
	if grip and _contact=="load" and _gesture_start.z-point.z>=LOAD_TRAVEL and _in_reload_reach(point,mirror_point(OPEN_POINT),.18):
		insert_magazine()
		_contact="" # Release, then make a fresh grip for the closing stroke.
	elif grip and _contact=="close" and (point.x-_gesture_start.x>=CLOSE_TRAVEL or point.y-_gesture_start.y>=CLOSE_TRAVEL):
		rack_bolt()
	_gesture_previous=grip
	_update_reload_visuals()
func _suspend_left_gestures()->void:
	super._suspend_left_gestures();_contact="";_gesture_previous=true
func _on_dominance_changed()->void:
	_contact="";_gesture_previous=true
	_update_reload_visuals()
func reset_weapon()->void:
	_recovery_start=0
	chambers.assign(["live","live","live","live","live","live","live"]);_index=0
	super.reset_weapon();_gesture_previous=true;_contact="";_semi_armed=true;_sync();_update_reload_visuals()
func _process(delta:float)->void:
	super._process(delta)
	for part in [magazine,loose_magazine,hip_source,guide,insertion_arrow,charging_arrow,bolt,firing_carrier]:part.hide()

	if _vr_active():
		var frame:=Transform3D(player.global_basis,player.get_locomotion_anchor_position())
		var pose:Transform3D=frame.affine_inverse()*corrected_grip_transform(right_hand.global_transform)
		gun_flick_sample(pose.origin,-pose.basis.z,delta,_hand_input_ready(right_hand),right_hand.get_float("trigger")>.2 or right_hand.is_button_pressed("trigger_click"),pose.basis.y)
	_update_reload_visuals()
func _update_reload_visuals()->void:
	if cylinder==null:return
	cylinder.position=Vector3.ZERO if reload_state=="ready" else mirror_point(Vector3(-.10,0,0))
	_sync()

	offered.transform=Transform3D(Basis.IDENTITY,mirror_point(ROUND_OFFER))
	if _contact=="load" and _vr_active() and _hand_input_ready(left_hand):
		offered.global_transform=Transform3D(global_basis,left_hand.global_position)
	var available:=reserve_rounds()
	for i in offered_rounds.size():offered_rounds[i].visible=i<mini(CAPACITY-get_loaded_rounds(),CAPACITY if available<0 else available)
	offered.visible=reload_state=="cylinder_open" and reserve_rounds()!=0 and _input_allowed()
	reload_arrow.visible=reload_state in ["cylinder_open","cylinder_loaded"] and _input_allowed()
	if reload_arrow.visible:
		reload_arrow.position=get_reload_grab_point()
		var direction:=Vector3.FORWARD if reload_state=="cylinder_open" else Vector3.RIGHT
		reload_arrow.basis=Basis(Quaternion(Vector3.UP,direction))
func _build_model()->void:
	super._build_model()
	for child in model.get_children():child.hide()
	ammo_label.show()
	var steel:=_material(Color("59646b"),.85,.3)
	var dark:=_material(Color("161d20"),.25,.7)
	var brass:=_material(Color("b79548"),.8,.35)
	var cue:=_material(Color(1,.72,.16),.15,.5,1)
	# A real open frame window keeps the existing moving cylinder readable.
	_beveled(Vector3(.047,.014,.175),Vector3(0,.091,-.12),steel,.004)
	_beveled(Vector3(.048,.105,.027),Vector3(0,.027,-.025),steel,.005)
	_beveled(Vector3(.044,.080,.025),Vector3(0,.040,-.175),steel,.004)
	_beveled(Vector3(.05,.12,.065),Vector3(0,-.045,-.065),dark,.01)
	_rod(Vector3(0,.065,-.17),Vector3(0,.065,-.39),.018,steel)
	_rod(Vector3(0,.065,-.390),Vector3(0,.065,-.392),.012,dark)
	cylinder=Node3D.new();cylinder.name="SevenRoundCylinder";model.add_child(cylinder)
	_rod(Vector3(0,.035,-.065),Vector3(0,.035,-.155),.043,steel,21,cylinder)
	for i in CAPACITY:
		var angle:=TAU*i/CAPACITY
		var p:=Vector3(cos(angle)*.027,.035+sin(angle)*.027,-.062)
		_rod(p+Vector3(0,0,.001),p+Vector3(0,0,.003),.011,dark,12,cylinder)
		cartridges.append(_rod(p,p+Vector3(0,0,.007),.008,brass,12,cylinder))
	offered=Node3D.new();offered.name="SevenRoundOffer";model.add_child(offered)
	for i in CAPACITY:
		var angle:=TAU*i/CAPACITY
		var p:=Vector3(cos(angle)*.027,sin(angle)*.027,0)

		var round_root:=Node3D.new();round_root.name="OfferedCartridge%d"%i;offered.add_child(round_root);offered_rounds.append(round_root)
		_rod(p,p+Vector3(0,0,-.045),.009,brass,12,round_root)
		_rod(p+Vector3(0,0,-.045),p+Vector3(0,0,-.060),.007,steel,12,round_root)
	reload_arrow=Node3D.new();reload_arrow.name="ForwardThenUpReloadArrow";model.add_child(reload_arrow)
	_box(Vector3(.009,.075,.006),Vector3(0,.0375,0),cue,reload_arrow)
	for side in [-1.0,1.0]:
		var arm:=_box(Vector3(.009,.035,.006),Vector3(side*.010,.064,0),cue,reload_arrow);arm.rotation.z=side*.65
	var sights:=WeaponFinish.zeroed_sights(model,-.025,-.365,.104,Vector3(0,.065,-.392),45,steel,dark)
	sight_rear=sights.find_child("RearReference",true,false);sight_front=sights.find_child("FrontReference",true,false)
	muzzle_flash.position.z+=.328
	load("res://scripts/handgun_finish_063.gd").magnum(self)
	if not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/downloaded_magnum_model.gd").build(self)
func get_shot_transform()->Transform3D:
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,.065,-.392)))

func gun_flick_sample(point:Vector3,forward:Vector3,delta:float,valid:bool,trigger:bool,up:Vector3=Vector3.ZERO)->void:
	if reload_state not in ["cylinder_open","cylinder_loaded"]:closure.reset();return
	# RIGHT means player-space right for either dominance; not gun-local roll.
	if closure.sample(point,forward,Vector3.RIGHT,delta,valid and _input_allowed() and not _weapon_hand_climbing(),trigger,up) and reload_state=="cylinder_loaded":_close_cylinder()
func _suspend_gestures()->void:
	super._suspend_gestures();closure.reset()

var _recovery_start:=0.0
func _kick_recoil(distance:float,angle:float)->void:
	super._kick_recoil(distance,angle*1.1)
	_recovery_start=recoil_pitch
func _recover_recoil(delta:float)->void:
	super._recover_recoil(delta)
