extends "res://scripts/weapon.gd"
## Original tube-fed pump: one chamber plus four tube rounds; no detachable magazine.
signal pellet_shot(origin:Vector3,directions:Array[Vector3],damage:float)
const PUMP_REST:=Vector3(0,-0.025,-0.36)
const PUMP_TRAVEL:=0.12
const SHELL_PORT:=Vector3(0,-0.065,-0.15)
const SHELL_OFFER:=Vector3(0,-0.20,-0.15)
var chambered:=true
var tube_rounds:=4
var spent_chamber:=false
var pump:MeshInstance3D
var shell_offer:Node3D
var held_shell:Node3D
var port_gate:MeshInstance3D
var chamber_round:MeshInstance3D
var _pump_contact:=false
var _pump_previous:=true
var _pump_start:=Vector3.ZERO
var _shell_grab:=Vector3.ZERO
var _shell_previous:=true
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	magazine_size=5;damage=9.0;fire_interval=.65
	_sync_rounds()
func _sync_rounds()->void:
	ammo=tube_rounds+(1 if chambered else 0)
	update_ammo_display()
func get_loaded_rounds()->int:return tube_rounds+(1 if chambered else 0)
func get_reload_hint()->String:return ""
func fire()->void:
	if model==null or cooldown>0 or reload_state!="ready" or not chambered or not _input_allowed():return
	if _vr_active() and (not _hand_input_ready(right_hand) or (_has_head_obstruction and player.get("head_obstructed")) or _weapon_hand_climbing()):return
	chambered=false;spent_chamber=true;_sync_rounds()
	var pose:=get_firing_pose();var origin:=pose.origin;var basis:=pose.basis
	_flash_time=.055;_kick_recoil(.085,deg_to_rad(10))
	if not _vr_active() and camera!=null:origin=camera.global_position
	var directions:Array[Vector3]=[]
	for i in range(8):
		var angle:=TAU*float(i)/8.0
		var radius:=tan(deg_to_rad(3.5))*(.4 if i%2==0 else 1.0)
		directions.append((-basis.z+basis.x*cos(angle)*radius+basis.y*sin(angle)*radius).normalized())
	pellet_shot.emit(origin,directions,damage);_play_shot();_haptic(right_hand,.8,.09)
	_set_stage("needs_pump_back","");cooldown=fire_interval
	_pump_contact=false;_pump_previous=true
func _process(delta:float)->void:
	super._process(delta)
	magazine.hide();loose_magazine.hide();hip_source.hide();guide.hide();insertion_arrow.hide();charging_arrow.hide();bolt.hide();firing_carrier.hide()
	shell_offer.visible=tube_rounds<4 and reserve_rounds()!=0 and reload_state!="held_shell" and _input_allowed()
	held_shell.visible=reload_state=="held_shell" and _input_allowed()
	if held_shell.visible and _vr_active():held_shell.global_transform=corrected_grip_transform(left_hand.global_transform)
	port_gate.rotation.x=-.65 if reload_state=="held_shell" else 0.0
	chamber_round.visible=chambered
	update_ammo_display()
func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand):_suspend_gestures();return
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:_requires_trigger_release=false
	elif not _requires_trigger_release:fire()
	if not _hand_input_ready(left_hand) or _support_grip_reserved():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	var point:=reload_local_point(left_hand.global_position)
	if reload_state=="held_shell":
		if not grip:_return_from_shell()
		elif point.y-_shell_grab.y>=.06 and _in_reload_reach(point,SHELL_PORT,.095):insert_magazine()
	elif grip and not _shell_previous and _in_reload_reach(point,SHELL_OFFER,.105) and tube_rounds<4:
		grab_magazine()
	elif not chambered:
		pump_sample(grip,point,true)
	_shell_previous=grip
func grab_magazine()->void:
	if _support_hand_climbing() or reserve_rounds()==0 or tube_rounds>=4 or _pump_contact:return
	_shell_grab=reload_local_point(left_hand.global_position) if left_hand!=null else SHELL_OFFER
	_set_stage("held_shell","");_play(AudioBank.sample("pouch"))
func insert_magazine()->void:
	if _support_hand_climbing() or reload_state!="held_shell" or tube_rounds>=4:return
	var rounds:=take_reserve(1)
	if rounds<=0:_return_from_shell();return
	tube_rounds+=rounds;_return_from_shell();_sync_rounds();_play(AudioBank.sample("mag_insert"));_haptic(left_hand,.45,.05)
func _return_from_shell()->void:
	_set_stage("ready" if chambered else "needs_pump_back","")
	_pump_previous=true
func eject_magazine()->void:
	# No detachable magazine exists. Manual reload intent exposes the shell port only.
	if chambered:reload_state="ready"
	update_ammo_display()
func rack_bolt()->void:pass # The only chambering path is the full held pump stroke.
func pump_sample(grip:bool,point:Vector3,valid:bool)->void:
	if chambered or reload_state=="held_shell":return
	if not valid or _support_hand_climbing():
		_pump_contact=false;_pump_previous=true;pump.position=PUMP_REST;reload_state="needs_pump_back";return
	if not grip:
		if _pump_contact:reload_state="needs_pump_back"
		_pump_contact=false;pump.position=PUMP_REST
	elif not _pump_previous and _in_reload_reach(point,PUMP_REST,.18):
		_pump_contact=true;_pump_start=point;reload_state="needs_pump_back"
	if _pump_contact and grip:
		var travel:=point.z-_pump_start.z
		pump.position=PUMP_REST+Vector3(0,0,clampf(travel,0,PUMP_TRAVEL))
		if reload_state=="needs_pump_back" and travel>=PUMP_TRAVEL:
			reload_state="needs_pump_forward"
			if spent_chamber:_eject_casing();spent_chamber=false
			_haptic(left_hand,.45,.045)
		elif reload_state=="needs_pump_forward" and travel<=.02:_finish_pump()
	_pump_previous=grip
func _finish_pump()->void:
	_pump_contact=false;pump.position=PUMP_REST
	if tube_rounds>0:tube_rounds-=1;chambered=true
	var remaining:=cooldown
	_set_stage("ready" if chambered else "needs_pump_back","")
	cooldown=maxf(cooldown,remaining);_requires_trigger_release=true;_sync_rounds()
func desktop_reload_step()->void:
	if _support_hand_climbing() or not _input_allowed():return
	if reload_state=="held_shell":insert_magazine()
	elif reload_state=="needs_pump_back" and tube_rounds>0:
		reload_state="needs_pump_forward";pump.position=PUMP_REST+Vector3(0,0,PUMP_TRAVEL)
		if spent_chamber:_eject_casing();spent_chamber=false
	elif reload_state=="needs_pump_forward":_finish_pump()
	else:grab_magazine();insert_magazine()
func _suspend_left_gestures()->void:
	super._suspend_left_gestures()
	_pump_contact=false;_pump_previous=true;_shell_previous=true
	if reload_state=="held_shell":reload_state="ready" if chambered else "needs_pump_back"
	if not chambered:reload_state="needs_pump_back"
	if pump!=null:pump.position=PUMP_REST
func reset_weapon()->void:
	chambered=true;tube_rounds=4;spent_chamber=false
	super.reset_weapon();_pump_contact=false;_pump_previous=true;_shell_previous=true
	if pump!=null:pump.position=PUMP_REST
	_sync_rounds()
func _build_model()->void:
	super._build_model()
	for child in model.get_children():
		if child not in [magazine,bolt,firing_carrier,guide,muzzle_flash,ammo_label,insertion_arrow,charging_arrow]:child.hide()
	var steel:=_material(Color("50595e"),.78,.33)
	var dark:=_material(Color("171e22"),.35,.64)
	var wood:=_material(Color("795238"),.05,.72)
	_beveled(Vector3(.075,.085,.29),Vector3(0,.025,-.11),steel,.012)
	_rod(Vector3(0,.04,-.24),Vector3(0,.04,-.80),.019,steel)
	_rod(Vector3(0,.04,-.800),Vector3(0,.04,-.802),.014,dark)
	_rod(Vector3(0,-.013,-.23),Vector3(0,-.013,-.70),.016,steel)
	WeaponFinish.tapered_stock(model,wood)
	_build_wood_wrist(wood)
	var guard_points:Array[Vector3]=[Vector3(0,-.018,-.07),Vector3(0,-.085,-.07),Vector3(0,-.095,.015),Vector3(0,-.04,.03)]
	for i in range(guard_points.size()-1):
		var guard:=_rod(guard_points[i],guard_points[i+1],.0035,steel,8)
		guard.name="TraditionalTriggerGuard%d"%i
	pump=_beveled(Vector3(.09,.075,.19),PUMP_REST,wood,.012)
	pump.name="SlidingForeEnd"
	for i in range(7):_box(Vector3(.094,.078,.006),Vector3(0,0,-.07+i*.023),dark,pump)
	var port=_box(Vector3(.045,.004,.09),SHELL_PORT,dark);port.name="UnderReceiverShellPort"
	port_gate=_box(Vector3(.034,.003,.07),SHELL_PORT+Vector3(0,-.003,0),steel)
	chamber_round=_rod(Vector3(.038,.035,-.13),Vector3(.039,.035,-.13),.014,wood)
	shell_offer=Node3D.new();shell_offer.position=SHELL_OFFER;model.add_child(shell_offer)
	held_shell=Node3D.new();add_child(held_shell)
	shell_offer.hide();held_shell.hide()
	for node in [shell_offer,held_shell]:
		_rod(Vector3(0,-.03,0),Vector3(0,.03,0),.013,wood,12,node)
		_rod(Vector3(0,-.032,0),Vector3(0,-.025,0),.015,steel,12,node)
	var sights:=WeaponFinish.zeroed_sights(model,-.025,-.74,.10,Vector3(0,.04,-.80),50,steel,wood)
	sight_rear=sights.find_child("RearReference",true,false);sight_front=sights.find_child("FrontReference",true,false)
	muzzle_flash.position.z-=.09
func get_shot_transform()->Transform3D:
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,.04,-.80)))
func _hide_rifle_parts()->void:
	for part in [magazine,loose_magazine,hip_source,guide,insertion_arrow,charging_arrow,bolt,firing_carrier]:
		if is_instance_valid(part):part.hide()
func update_ammo_display()->void:
	super.update_ammo_display()
	_hide_rifle_parts()
	if shell_offer!=null and reserve_rounds()==0:shell_offer.hide()
func _build_wood_wrist(wood:Material)->void:
	# Sloped tapered stock wrist, deliberately no vertical box-magazine silhouette.
	var vertices:PackedVector3Array=[Vector3(-.025,-.012,-.015),Vector3(.025,-.012,-.015),Vector3(.022,-.050,-.015),Vector3(-.022,-.050,-.015),Vector3(-.026,-.035,.10),Vector3(.026,-.035,.10),Vector3(.023,-.085,.10),Vector3(-.023,-.085,.10)]
	var indices:PackedInt32Array=[0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5]
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:surface.add_vertex(vertices[index])
	surface.generate_normals();surface.index()
	var wrist:=MeshInstance3D.new();wrist.name="TraditionalWoodWrist";wrist.mesh=surface.commit();wrist.material_override=wood;model.add_child(wrist)

