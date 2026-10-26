extends "res://scripts/weapon.gd"
const HeavyModelFinish=preload("res://scripts/heavy_model_finish.gd")
## Six-round automatic M10-style shotgun: UP shell pack, BACK charging handle.
signal pellet_shot(origin:Vector3,directions:Array[Vector3],damage:float)
const LOAD_OFFER:=Vector3(0,-.25,-.14)
const LOAD_SOCKET:=Vector3(0,-.10,-.14)
const HANDLE:=Vector3(.06,.045,-.10)
var _contact:=""
var _motion_start:=Vector3.ZERO
var _previous:=true
var shell_pack:Node3D
var reload_arrow:Node3D
func reload_grip_in_progress()->bool:return _contact!=""
func get_reload_zones()->Array:
	if reload_state not in ["needs_mag","held_mag","needs_rack"]:return []
	return [{"position":get_reload_grab_point(),"radius":.115}]
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop);magazine_size=6;ammo=6;damage=8;fire_interval=.28;update_ammo_display()
func fire()->void:
	if model==null or cooldown>0 or reload_state!="ready" or not _input_allowed():return
	if _vr_active() and (not _hand_input_ready(right_hand) or _weapon_hand_climbing() or player.get("head_obstructed")):return
	if ammo<=0:eject_magazine();return
	ammo-=1;cooldown=maxf(.001,fire_interval-_cooldown_overrun);_cooldown_overrun=0;_flash_time=.055;_carrier_time=.095
	var pose:=get_firing_pose();var origin:=pose.origin;var directions:Array[Vector3]=[]
	if not _vr_active():origin=camera.global_position
	for i in 8:
		var angle:=TAU*i/8.0;var radius:=tan(deg_to_rad(3.5))*(.4 if i%2==0 else 1.0)
		directions.append((-pose.basis.z+pose.basis.x*cos(angle)*radius+pose.basis.y*sin(angle)*radius).normalized())
	pellet_shot.emit(origin,directions,damage);_kick_recoil(.075,deg_to_rad(8));_play_shot();_haptic(right_hand,.7,.07);_eject_casing()
	if ammo==0:eject_magazine()
	update_ammo_display()
func get_reload_grab_point()->Vector3:
	var point:=LOAD_OFFER if reload_state in ["needs_mag","held_mag"] else HANDLE
	if right_hand==player.get("left_hand"):point.x=-point.x
	return point
func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand):_suspend_gestures();return
	var click:=right_hand.is_button_pressed("primary_click")
	if click and not _eject_click_previous and manual_click_eject_allowed():eject_magazine()
	_eject_click_previous=click
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:_requires_trigger_release=false
	elif not _requires_trigger_release:fire()
	var stick:=right_hand.get_vector2("primary")
	if stick.length()<.25:_eject_previous=false
	elif stick.y<-.7 and absf(stick.x)<.5 and not _eject_previous:eject_magazine();_eject_previous=true
	if not _hand_input_ready(left_hand) or _support_grip_reserved():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	reload_sample(reload_local_point(left_hand.global_position),grip,true)
func reload_sample(point:Vector3,grip:bool,valid:bool)->void:
	if not valid or not _input_allowed() or _support_hand_climbing() or _weapon_hand_climbing():_contact="";_previous=true;return
	if not grip:_contact=""
	elif _contact=="" and _in_reload_reach(point,get_reload_grab_point(),.115):
		if not _previous:
			_contact="load" if reload_state=="needs_mag" else ("charge" if reload_state=="needs_rack" else "")
			_motion_start=point
	if grip and _contact=="load" and point.y-_motion_start.y>=.10 and _in_reload_reach(point,LOAD_SOCKET,.11):
		grab_magazine();insert_magazine();_contact=""
	elif grip and _contact=="charge":
		bolt.position=get_reload_grab_point()+Vector3(0,0,clampf(point.z-_motion_start.z,0,.10))
		if point.z-_motion_start.z>=.085:rack_bolt();_contact=""
	_previous=grip
func _suspend_left_gestures()->void:
	super._suspend_left_gestures();_contact="";_previous=true
func _process(delta:float)->void:
	super._process(delta)
	magazine.hide();hip_source.hide();loose_magazine.hide();guide.hide();insertion_arrow.hide();charging_arrow.hide()
	shell_pack.visible=reload_state=="needs_mag" and reserve_rounds()!=0 and _input_allowed()
	reload_arrow.visible=reload_state in ["needs_mag","needs_rack"] and _input_allowed()
	if reload_arrow.visible:
		reload_arrow.position=get_reload_grab_point();reload_arrow.basis=Basis(Quaternion(Vector3.UP,Vector3.UP if reload_state=="needs_mag" else Vector3.BACK))
	if _contact!="charge":bolt.position=HANDLE*Vector3(-1,1,1) if right_hand==player.get("left_hand") else HANDLE
	if has_meta("downloaded_model_077"):
		bolt.scale.x=-1.0 if right_hand==player.get("left_hand") else 1.0
		if _contact!="charge" and reload_state=="ready":bolt.position.z+=sin(clampf(_carrier_time/.095,0.0,1.0)*PI)*.038
func _build_model()->void:
	super._build_model()
	for part in model.get_children():part.hide()
	ammo_label.show();bolt.show();firing_carrier.show()
	var alloy:=_material(Color("657378"),.8,.34);var dark:=_material(Color("18252b"),.25,.6);var brass:=_material(Color("b79548"),.8,.35)
	_beveled(Vector3(.08,.10,.28),Vector3(0,.03,-.14),alloy,.008)
	_beveled(Vector3(.055,.13,.07),Vector3(0,-.08,0),dark,.008)
	WeaponFinish.tapered_stock(model,dark)
	_rod(Vector3(0,.045,-.26),Vector3(0,.045,-.76),.022,alloy)
	_rod(Vector3(0,-.008,-.24),Vector3(0,-.008,-.71),.018,dark)
	_beveled(Vector3(.075,.055,.25),FOREGRIP_POINT,dark,.01)
	shell_pack=Node3D.new();shell_pack.name="SixShellReloadPack";shell_pack.position=LOAD_OFFER;model.add_child(shell_pack)
	for i in 6:_rod(Vector3(0,(i-2.5)*.035,0),Vector3(0,(i-2.5)*.035,-.06),.014,brass,10,shell_pack)
	reload_arrow=Node3D.new();reload_arrow.name="UpThenBackArrow";model.add_child(reload_arrow)
	_box(Vector3(.009,.09,.006),Vector3(0,.045,0),_reload_finish,reload_arrow)
	for side in [-1.0,1.0]:
		var arm:=_box(Vector3(.009,.035,.006),Vector3(side*.01,.077,0),_reload_finish,reload_arrow);arm.rotation.z=side*.65
	muzzle_flash.position=Vector3(0,.045,-.77)
	HeavyModelFinish.m1014(self)
	if not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/downloaded_m1014_model.gd").build(self)
func get_shot_transform()->Transform3D:return Transform3D(unit_model_basis(),model.to_global(Vector3(0,.045,-.77)))

##086 authored plateau experiment requested in playtest; original measured datasets remain intact.
## First shot uses the current zero; all subsequent pellet centres plateau, spread stays unchanged.
func _kick_recoil(distance:float,_angle:float)->void:
	_record_reference_shot();recoil_pattern_index+=1;recoil_idle=0.0
	recoil=minf(recoil+distance*(.38 if supported else 1.0),.13)
	recoil_pitch=deg_to_rad(2.0 if supported else 3.5);recoil_yaw=0.0
	_apply_recoil_visual();_update_support_visual()
func _recover_recoil(delta:float)->void:
	recoil_idle+=maxf(delta,0.0);recoil*=exp(-maxf(delta,0.0)*9.0)
	if recoil_idle>maxf(.35,fire_interval*1.15):recoil_pitch*=exp(-maxf(delta,0.0)*9.0)
	if recoil_idle>=.8:recoil_pattern_index=0;recoil_pitch=0;recoil_yaw=0;recoil=0
