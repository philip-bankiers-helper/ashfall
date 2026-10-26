extends "res://scripts/weapon.gd"
## Cinder-2 original break action. Base provides tracking, support, damping and audio pool.
const BreakState=preload("res://scripts/break_action_state.gd")
signal pellet_shot(origin:Vector3,directions:Array[Vector3],damage:float)
var action=BreakState.new()
var hinge:Node3D
var shell_pair:Node3D
var shell_offer:Node3D
var latch_guide:MeshInstance3D
var seated_shells:Node3D
var insert_guide:Node3D
var _shell_start:=Vector3.ZERO
var _close_start:=Vector3.ZERO
var _closing:=false
var _opening:=false
var _open_start:=Vector3.ZERO
var _semi_release:=true
var _hinge_angle:=0.0
var _mechanisms:Dictionary={}
const CHAMBER:=Vector3(0,0.01,-0.16)
## Move the offer 30% along its actual travel toward the chamber.
const SHELL_OFFER:=Vector3(0,0.115,-0.16)
var _shell_pool:Array[MeshInstance3D]=[]
var _shell_velocity:Array[Vector3]=[]
var _shell_life:Array[float]=[]
var _shell_cursor:=0
var _chamber_occupied:=true
var chamber_states:Array[String]=["live","live"]
var chamber_live:Array[MeshInstance3D]=[]
var chamber_spent:Array[MeshInstance3D]=[]
var chamber_markers:Array[Marker3D]=[]
var fore_end_marker:Marker3D
const BREECH_PIVOT_DROP:=.11
var open_contact_cue:Node3D
var chamber_contact_cue:Node3D
var close_contact_cue:Node3D
var _affordance_finish:StandardMaterial3D

func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	magazine_size=2
	ammo=2
	damage=11.0
	fire_interval=0.3
	for cue in ["blast","open","insert","close"]: _mechanisms[cue]=_bake_cue(cue)
	_sound_fire=_mechanisms.blast
	_hide_closed_reload_props()

func _process(delta:float)->void:
	if model==null:return
	cooldown=maxf(0,cooldown-delta)
	_recover_recoil(delta)
	_flash_time=maxf(0,_flash_time-delta)
	muzzle_flash.visible=_flash_time>0
	_apply_recoil_visual()
	if _vr_active():
		global_transform=corrected_grip_transform(right_hand.global_transform)
		_update_support(delta)
		_apply_aim_filter(delta)
		_poll_vr()
		_update_support_visual()
		model.visible=_hand_valid(right_hand) and not (_weapon_hand_climbing())
	elif camera!=null:
		global_transform=camera.global_transform
		position+=global_basis*Vector3(0.22,-0.24,-0.55)
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):_semi_release=true
	if not _input_allowed():
		_suspend_gestures()
		_sound.stop()
		for voice in _shot_voices:voice.stop()
	reload_state=action.state
	ammo=action.ammo
	var open_angle:=0.72 if action.state!="ready" else 0.0
	if not _closing:_hinge_angle=move_toward(_hinge_angle,open_angle,delta*5)
	hinge.rotation.x=-_hinge_angle
	shell_offer.visible=action.state=="open_empty" and _input_allowed() and reserve_rounds()!=0
	shell_pair.visible=action.state=="holding_shells" and _input_allowed() and (not _vr_active() or _hand_valid(left_hand))
	if shell_pair.visible and _vr_active():shell_pair.global_transform=corrected_grip_transform(left_hand.global_transform)
	latch_guide.visible=action.state=="open_loaded" and _input_allowed()
	seated_shells.hide()
	shell_offer.position=get_shell_offer_point()
	_update_chamber_visuals()
	insert_guide.visible=action.state in ["open_empty","holding_shells"] and _input_allowed()
	update_ammo_display()
	_update_reload_affordances()

func _suspend_left_gestures()->void:
	super._suspend_left_gestures()
	_opening=false
	_closing=false
	# Support-hand climb/reload arbitration must not disarm the firing-hand trigger.
	if action.state=="holding_shells":action.release()
	if action.state!="ready":_hinge_angle=0.72

func fire()->void:
	if model==null or cooldown>0 or not _input_allowed() or not _semi_release:return
	if _vr_active() and (not _hand_input_ready(right_hand) or (_has_head_obstruction and player.get("head_obstructed")) or (_weapon_hand_climbing())):return
	var fired_index:int=chamber_states.find("live")
	if not action.fire():return
	if fired_index>=0 and fired_index<2:chamber_states[fired_index]="spent"
	_update_chamber_visuals()
	_semi_release=false
	ammo=action.ammo
	cooldown=fire_interval
	_flash_time=0.05
	var shot_pose:=get_firing_pose()
	_kick_recoil(0.095,deg_to_rad(11.0))
	var origin:=shot_pose.origin
	var forward:Vector3=-shot_pose.basis.z
	var basis:=shot_pose.basis
	if not _vr_active() and camera!=null:
		origin=camera.global_position
		forward=-shot_pose.basis.z
		basis=shot_pose.basis
	var directions:Array[Vector3]=[]
	for i in range(8):
		var a:=i*TAU/8.0
		var radius:=tan(deg_to_rad(4.0))*(0.45 if i%2==0 else 1.0)
		directions.append((forward+basis.x*cos(a)*radius+basis.y*sin(a)*radius).normalized())
	pellet_shot.emit(origin,directions,damage)
	_haptic(right_hand,0.8,0.085)
	var voice:=_shot_voices[_shot_voice_cursor]
	_shot_voice_cursor=(_shot_voice_cursor+1)%_shot_voices.size()
	voice.stream=_mechanisms.blast
	voice.play()

func get_shot_transform()->Transform3D:
	if model==null:return Transform3D(global_basis,to_global(Vector3(0,0.04,-0.65)))
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,0.04,-0.65)))

func eject_magazine()->void:
	if action.state!="ready":return
	var remaining:int=action.ammo
	var returned:=refund_rounds(remaining)
	if returned<remaining:
		for i in range(chamber_states.size()):
			if returned>0 and chamber_states[i]=="live":chamber_states[i]="empty";returned-=1;action.ammo-=1
		action.loaded=action.ammo;ammo=action.ammo;_update_chamber_visuals();return
	if action.open():
		if _chamber_occupied:
			for side in [-1.0,1.0]:
				var index:=_shell_cursor
				_shell_cursor=(_shell_cursor+1)%8
				_shell_pool[index].global_transform=global_transform
				_shell_pool[index].global_position=chamber_markers[0 if side<0 else 1].global_position
				_shell_pool[index].visible=true
				_shell_velocity[index]=global_basis*Vector3(side*0.3,1.3,0.9)
				_shell_life[index]=2.0
		_chamber_occupied=false
		chamber_states=["empty","empty"]
		_update_chamber_visuals()
		_changed("Breech open - seat the paired shells","open")
func grab_magazine()->void:
	if _support_hand_climbing() or reserve_rounds()==0:return
	if action.grab():
		_shell_start=reload_local_point(left_hand.global_position) if left_hand!=null else SHELL_OFFER
		_changed("Push the shell pair down into the open chambers","")
func insert_magazine()->void:
	if _support_hand_climbing():return
	if action.state!="holding_shells":return
	var rounds:=take_reserve(2)
	if rounds<=0:return
	if action.insert():
		action.loaded=rounds
		chamber_states=["live","live" if rounds==2 else "empty"]
		_update_chamber_visuals()
		_changed("Release grip, grip the fore-end and lift to close","insert")
func rack_bolt()->void:
	if _support_hand_climbing():return
	if action.close():
		_chamber_occupied=true
		_closing=false
		_changed("CINDER-2 ready / %d rounds" % action.ammo,"close")
func _changed(message:String,cue:String)->void:
	reload_state=action.state
	ammo=action.ammo
	network_reload_stage1000.emit(reload_state)
	_requires_trigger_release=true
	_semi_release=false
	_support_latched=false
	supported=false
	_support_weight=0
	if _has_hand_reservation:_reserve_support_hand(action.state!="ready")
	if not cue.is_empty():_play(_mechanisms[cue])
	# Reload affordances are geometry, motion, mechanical audio and haptics only.
	_haptic(left_hand,0.45,0.06)
	cooldown=0.15
	update_ammo_display()
func desktop_reload_step()->void:
	if not _input_allowed():return
	match action.state:
		"ready":eject_magazine()
		"open_empty":
			grab_magazine()
			insert_magazine()
		"holding_shells":insert_magazine()
		"open_loaded":rack_bolt()
func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand):
		_suspend_gestures()
		return
	var stick:=right_hand.get_vector2("primary")
	if stick.length()<0.25:_eject_previous=false
	elif stick.y< -0.7 and absf(stick.x)<0.5 and not _eject_previous:
		eject_magazine()
		_eject_previous=true
	var trigger:=right_hand.get_float("trigger")>0.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:
		_semi_release=true
		_requires_trigger_release=false
	elif not _requires_trigger_release:fire()
	if not _hand_input_ready(left_hand) or _support_grip_reserved():
		_suspend_left_gestures()
		return
	var grip:=left_hand.get_float("grip")>0.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	var pos:=reload_local_point(left_hand.global_position)
	if action.state=="ready":
		if grip and not _grip_previous and _in_reload_reach(pos,get_open_grip_point(),.10):
			_opening=true;_open_start=pos
		if _opening and grip and _open_start.y-pos.y>=.05:
			eject_magazine();_opening=false
		if not grip:_opening=false
	if action.state=="open_empty" and grip and not _grip_previous and _in_reload_reach(pos,get_shell_offer_point(),0.10):grab_magazine()
	elif action.state=="holding_shells":
		if not grip:
			action.release()
		elif _shell_start.y-pos.y>=0.06 and _in_reload_reach(pos,get_chamber_insert_point(),0.09):insert_magazine()
	elif action.state=="open_loaded":
		if grip and not _grip_previous and _in_reload_reach(pos,get_close_grip_point(),0.18):
			_closing=true
			_close_start=pos
		if _closing and grip:
			var progress:=clampf((pos.y-_close_start.y)/0.10,0,1)
			_hinge_angle=0.72*(1-progress)
			if progress>=0.8:rack_bolt()
		if not grip:_closing=false
	_grip_previous=grip

func reset_weapon()->void:
	action.reset()
	ammo=2
	reload_state="ready"
	cooldown=0
	recoil=0
	recoil_pitch=0
	recoil_yaw=0.0;recoil_pattern_index=0;recoil_idle=0.0
	supported=false;_support_latched=false;_support_weight=0.0
	_apply_recoil_visual()
	_closing=false
	_hinge_angle=0
	_chamber_occupied=true
	chamber_states=["live","live"]
	_update_chamber_visuals()
	for i in range(_shell_pool.size()):
		_shell_pool[i].visible=false
		_shell_life[i]=0
	_suspend_gestures()
	if _has_hand_reservation:_reserve_support_hand(false)
	_flash_time=0.0
	_hide_closed_reload_props()
func get_reload_hint()->String:return ""

func _build_model()->void:
	model=Node3D.new()
	add_child(model)
	var dark:=StandardMaterial3D.new()
	dark.albedo_color=Color(0.07,0.085,0.1)
	dark.metallic=0.8
	dark.roughness=0.35
	var copper:=StandardMaterial3D.new()
	copper.albedo_color=Color(0.45,0.24,0.10)
	copper.metallic=0.7
	var gripmat:=StandardMaterial3D.new()
	gripmat.albedo_color=Color(0.12,0.14,0.14)
	var cyan:=StandardMaterial3D.new()
	cyan.albedo_color=Color(0.1,0.8,0.8)
	cyan.emission_enabled=true
	cyan.emission=cyan.albedo_color
	var steel:=WeaponFinish.finish(Color(0.20,0.23,0.25),0.8,0.36)
	var charcoal:=WeaponFinish.finish(Color(0.06,0.075,0.085),0.65,0.44)
	var rubber:=WeaponFinish.finish(Color(0.035,0.043,0.045),0.0,0.9)
	var alloy:=WeaponFinish.finish(Color(0.32,0.34,0.31),0.75,0.42)
	_beveled(Vector3(0.086,0.094,0.18),Vector3(0,0,-0.06),steel,0.023)
	_beveled(Vector3(0.06,0.18,0.07),Vector3(0,-0.10,0.01),gripmat,0.012).rotation.x=-0.25
	WeaponFinish.tapered_stock(model,rubber)
	_beveled(Vector3(.035,.009,.035),Vector3(0,.065,-.025),cyan,.003)
	_rod(Vector3(0.043,0.027,-0.075),Vector3(0.051,0.027,-0.075),0.008,alloy,12)
	_beveled(Vector3(0.075,0.12,0.014),Vector3(0,-0.025,0.292),rubber,0.015)
	_rod(Vector3(0,0.024,0.09),Vector3(0,0.024,0.25),0.023,charcoal,16)
	_beveled(Vector3(0.026,0.036,0.025),Vector3(0,0.064,-0.02),charcoal,0.004)
	_rod(Vector3(-0.058,-0.02,-0.13),Vector3(0.058,-0.02,-0.13),0.016,copper,12)
	_rod(Vector3(0,-0.06,-0.08),Vector3(0,-0.12,-0.08),0.006,dark,8)
	_rod(Vector3(0,-0.12,-0.08),Vector3(0,-0.12,-0.015),0.006,dark,8)
	_rod(Vector3(0,-0.07,-0.045),Vector3(0,-0.10,-0.035),0.004,copper,8)
	hinge=Node3D.new()
	model.add_child(hinge)
	hinge.position=Vector3(0,-0.025,-0.13)
	_beveled(Vector3(0.014,0.024,0.023),Vector3(0,0.082,-0.49),charcoal,0.003,hinge)
	var sights:=WeaponFinish.zeroed_sights(model,-0.02,-0.62,0.095,Vector3(0,0.04,-0.65),50.0,dark,copper)
	sight_rear=sights.find_child("RearReference",true,false)
	sight_front=sights.find_child("FrontReference",true,false)
	sights.get_node("FrontAssembly").reparent(hinge,true)
	for x in [-0.027,0.027]:
		_rod(Vector3(x,0.045,-0.05),Vector3(x,0.045,-0.15),0.0258,steel,20,hinge)
		_rod(Vector3(x,0.045,-0.48),Vector3(x,0.045,-0.505),0.026,alloy,20,hinge)
		_rod(Vector3(x,0.045,0),Vector3(x,0.045,-0.52),0.025,dark,16,hinge)
		_rod(Vector3(x,0.045,0.002),Vector3(x,0.045,0.012),0.018,gripmat,16,hinge)
		_rod(Vector3(x,0.045,0.013),Vector3(x,0.045,0.014),0.018,gripmat,16,hinge)
		_rod(Vector3(x,0.045,-0.52),Vector3(x,0.045,-0.525),0.019,gripmat,16,hinge)
		var mouth:=MeshInstance3D.new();mouth.name="OpenChamberMouthLeft" if x<0 else "OpenChamberMouthRight"
		var ring:=TorusMesh.new();ring.inner_radius=.017;ring.outer_radius=.025;ring.rings=16;ring.ring_segments=8
		mouth.mesh=ring;mouth.material_override=alloy;mouth.position=Vector3(x,.045,.014);mouth.rotation.x=PI/2;hinge.add_child(mouth)
		var chamber:=Marker3D.new();chamber.name="ChamberInsertionLeft" if x<0 else "ChamberInsertionRight";chamber.position=Vector3(x,.045,.017);hinge.add_child(chamber);chamber_markers.append(chamber)
		var live:=_rod(Vector3(x,.045,.014),Vector3(x,.045,.020),.016,copper,12,hinge)
		live.name="LiveShellCap";chamber_live.append(live)
		var spent:=_rod(Vector3(x,.045,.014),Vector3(x,.045,.021),.015,charcoal,12,hinge)
		spent.name="SpentShellCap";chamber_spent.append(spent)
	_beveled(Vector3(0.012,0.006,0.33),Vector3(0,0.07,-0.30),charcoal,0.002,hinge)
	_box(Vector3(0.07,0.055,0.24),Vector3(0,-0.02,-0.27),gripmat,hinge)
	for z in range(7):_box(Vector3(0.075,0.005,0.009),Vector3(0,-0.047,-0.18-z*0.025),copper,hinge)
	latch_guide=_box(Vector3(0.006,0.006,0.10),Vector3(0,-0.05,-0.27),cyan,hinge)
	seated_shells=Node3D.new()
	hinge.add_child(seated_shells)
	for x in [-0.027,0.027]:_rod(Vector3(x,0.045,0.015),Vector3(x,0.045,0.018),0.017,copper,12,seated_shells)
	insert_guide=Node3D.new()
	model.add_child(insert_guide)
	insert_guide.position=Vector3(-0.07,0.09,-0.16)
	_rod(Vector3(0,0.045,0),Vector3(0,-0.035,0),0.002,cyan,6,insert_guide)
	_rod(Vector3(0,-0.035,0),Vector3(-0.012,-0.015,0),0.002,cyan,6,insert_guide)
	_rod(Vector3(0,-0.035,0),Vector3(0.012,-0.015,0),0.002,cyan,6,insert_guide)
	shell_offer=Node3D.new()
	model.add_child(shell_offer)
	shell_offer.position=SHELL_OFFER
	shell_pair=Node3D.new()
	add_child(shell_pair)
	for node in [shell_offer,shell_pair]:
		for x in [-0.024,0.024]:
			_rod(Vector3(x,-0.035,0),Vector3(x,0.035,0),0.016,copper,12,node)
			_rod(Vector3(x,0.03,0),Vector3(x,0.04,0),0.018,cyan,12,node)
	var flashmat:=StandardMaterial3D.new()
	flashmat.albedo_color=Color(1,0.65,0.14)
	flashmat.emission_enabled=true
	flashmat.emission=flashmat.albedo_color
	flashmat.emission_energy_multiplier=3
	muzzle_flash=_box(Vector3(0.10,0.08,0.10),Vector3(0,0.02,-0.67),flashmat)
	ammo_label=Label3D.new()
	ammo_label.position=Vector3(0.055,0.02,-0.05)
	ammo_label.rotation.y=PI/2
	ammo_label.pixel_size=0.0007
	model.add_child(ammo_label)
	# Dummy charging handle lets inherited loss cancellation remain harmless.
	bolt=MeshInstance3D.new()
	model.add_child(bolt)
	for i in range(8):
		var shell:=MeshInstance3D.new()
		var cylinder:=CylinderMesh.new()
		cylinder.top_radius=0.016
		cylinder.bottom_radius=0.016
		cylinder.height=0.07
		cylinder.radial_segments=10
		shell.mesh=cylinder
		shell.material_override=copper
		add_child(shell)
		shell.top_level=true
		shell.visible=false
		_shell_pool.append(shell)
		_shell_velocity.append(Vector3.ZERO)
		_shell_life.append(0.0)

	# Moving the pivot down while raising its children preserves the closed barrel pose.
	fore_end_marker=Marker3D.new();fore_end_marker.name="BreakActionForeEnd";fore_end_marker.position=Vector3(0,-.02,-.27);hinge.add_child(fore_end_marker)
	hinge.position.y-=BREECH_PIVOT_DROP
	for part in hinge.get_children():
		if part is Node3D:part.position.y+=BREECH_PIVOT_DROP
	_build_reload_affordances()

func _physics_process(delta:float)->void:
	if not _input_allowed():return
	var dt:=minf(delta,0.05)
	for i in range(_shell_pool.size()):
		if _shell_life[i]<=0:continue
		_shell_life[i]-=dt
		_shell_pool[i].visible=_shell_life[i]>0
		_shell_velocity[i]+=Vector3.DOWN*9.8*dt
		var start:=_shell_pool[i].global_position
		var finish:=start+_shell_velocity[i]*dt
		var query:=PhysicsRayQueryParameters3D.create(start,finish,1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():_shell_pool[i].global_position=finish
		else:
			_shell_pool[i].global_position=hit.position+hit.normal*0.02
			_shell_velocity[i]=_shell_velocity[i].bounce(hit.normal)*0.25

func _bake_cue(kind:String)->AudioStreamWAV:
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=32000
	var duration:=0.65 if kind=="blast" else 0.2
	var bytes:=PackedByteArray()
	bytes.resize(int(duration*32000)*2)
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash("Cinder2/"+kind)
	var low:=0.0
	for i in range(bytes.size()/2):
		var t:=float(i)/32000
		var noise:=rng.randf_range(-1,1)
		low=lerpf(low,noise,0.12)
		var value:float
		if kind=="blast":value=(noise*exp(-t*45)*0.55+low*exp(-t*8)*0.5+sin(TAU*72*t)*exp(-t*18)*0.25)
		else:
			var rate:=38.0 if kind=="close" else 24.0
			value=(noise*0.5+sin(TAU*(320 if kind=="insert" else 170)*t)*0.2)*exp(-t*rate)
		bytes.encode_s16(i*2,int(clampf(value,-0.85,0.85)*32767))
	stream.data=bytes
	return stream


func _on_dominance_changed() -> void:
	action.release()
	reload_state=action.state
	_closing=false
	if action.state!="ready":_hinge_angle=0.72
	if shell_pair!=null:shell_pair.visible=false








func get_loaded_rounds()->int:
	return action.loaded if action.state=="open_loaded" else ammo

func update_ammo_display()->void:
	super.update_ammo_display()
	if shell_offer!=null and reserve_rounds()==0:shell_offer.visible=false
func get_chamber_insert_point()->Vector3:
	return reload_local_point((chamber_markers[0].global_position+chamber_markers[1].global_position)*.5)
func get_shell_offer_point()->Vector3:
	return get_chamber_insert_point()+Vector3(0,.11-.0127/visual_model_scale(),0) #0991 shells half an inch lower
func _update_chamber_visuals()->void:
	for i in range(chamber_live.size()):
		chamber_live[i].visible=chamber_states[i]=="live"
		chamber_spent[i].visible=chamber_states[i]=="spent"


func get_close_grip_point()->Vector3:
	return reload_local_point(fore_end_marker.global_position)
func _hide_closed_reload_props()->void:
	for part in [muzzle_flash,shell_pair,shell_offer,seated_shells,latch_guide,insert_guide]:
		if is_instance_valid(part):part.hide()
	for part in [open_contact_cue,chamber_contact_cue,close_contact_cue]:
		if is_instance_valid(part):part.hide()

func get_open_grip_point()->Vector3:
	return reload_local_point(open_contact_cue.global_position) if open_contact_cue!=null else Vector3(0,.065,-.025)

func _build_reload_affordances()->void:
	_affordance_finish=_material(Color(.08,.67,.69,.58),.15,.48)
	_affordance_finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_affordance_finish.emission_enabled=true;_affordance_finish.emission=Color(.03,.38,.40)
	_affordance_finish.emission_energy_multiplier=.65
	open_contact_cue=Node3D.new();open_contact_cue.name="LatchGrabAndLowerCue";open_contact_cue.position=Vector3(0,.065,-.025);model.add_child(open_contact_cue)
	var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.021;torus.outer_radius=.025;torus.rings=16;torus.ring_segments=6;ring.mesh=torus;ring.material_override=_affordance_finish;open_contact_cue.add_child(ring)
	#0992 no permanent yellow arrow on a ready DT11.
	chamber_contact_cue=Node3D.new();chamber_contact_cue.name="PairedChamberSeatingCues";model.add_child(chamber_contact_cue)
	for i in range(2):
		var ghost:=Node3D.new();ghost.name="ChamberGhost%d"%i;chamber_contact_cue.add_child(ghost)
		var mouth:=MeshInstance3D.new();var shape:=TorusMesh.new();shape.inner_radius=.016;shape.outer_radius=.019;shape.rings=16;shape.ring_segments=6;mouth.mesh=shape;mouth.material_override=_affordance_finish;ghost.add_child(mouth)
		_cue_arrow(ghost,Vector3(0,.075,0),Vector3(0,.022,0),_affordance_finish)
	close_contact_cue=Node3D.new();close_contact_cue.name="ForeEndGrabAndLiftCue";model.add_child(close_contact_cue)
	var corners:Array[Vector3]=[Vector3(-.041,0,-.045),Vector3(.041,0,-.045),Vector3(.041,0,.045),Vector3(-.041,0,.045)]
	for i in range(4):_rod(corners[i],corners[(i+1)%4],.0018,_affordance_finish,6,close_contact_cue)
	_cue_arrow(close_contact_cue,Vector3(.05,0,0),Vector3(.05,.075,0),_affordance_finish)
	for part in [open_contact_cue,chamber_contact_cue,close_contact_cue]:part.hide()

func _cue_arrow(parent:Node3D,start:Vector3,finish:Vector3,material:Material)->void:
	_rod(start,finish,.0018,material,6,parent)
	var direction:Vector3=(finish-start).normalized()
	for side in [-1.0,1.0]:_rod(finish,finish-direction*.013+Vector3(side*.009,0,0),.0018,material,6,parent)

func _update_reload_affordances()->void:
	if open_contact_cue==null:return
	var usable:bool=_input_allowed() and not _support_hand_climbing() and not _weapon_hand_climbing()
	if _vr_active():usable=usable and _hand_input_ready(right_hand) and _hand_input_ready(left_hand)
	open_contact_cue.visible=usable and action.state=="ready"
	chamber_contact_cue.visible=usable and action.state in ["open_empty","holding_shells"] and reserve_rounds()!=0
	close_contact_cue.visible=usable and action.state=="open_loaded"
	close_contact_cue.position=model.to_local(fore_end_marker.global_position)
	for i in range(2):
		var ghost:Node3D=chamber_contact_cue.get_child(i)
		ghost.position=model.to_local(chamber_markers[i].global_position)
		ghost.get_child(0).basis=model.global_basis.inverse()*chamber_markers[i].global_basis*Basis(Vector3.RIGHT,PI/2)
		ghost.visible=reserve_rounds()<0 or i<reserve_rounds()
	# Original offer/held meshes also reflect a partial reserve rather than
	# suggesting that a single available shell will fill both chambers.
	for node in [shell_offer,shell_pair]:
		for i in range(node.get_child_count()):node.get_child(i).visible=reserve_rounds()<0 or i/2<reserve_rounds()
	insert_guide.hide();latch_guide.hide() # Replaced by cues at actual moving targets.



