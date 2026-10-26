extends "res://scripts/weapon.gd"
## AWP reload: BACK to eject, magazine UP, then BACK to chamber.
## A nonfinal shot still needs only its normal single BACK cycle.
const SIGHT_DROP_DEGREES:=2.5 # User-requested lower sight calibration; original tuning.
const BOLT_REST:=Vector3(.072,.045,-.07)
const BOLT_LIFT:=.065
const BOLT_TRAVEL:=.115
var chambered:=true
var spent_chamber:=false
var bolt_phase:="locked"
var _bolt_contact:=false
var _bolt_previous:=true
var _bolt_origin:=Vector3.ZERO
var _bolt_grab:=Vector3.ZERO
var _bolt_lifted:=false
var _bolt_rear:=false
var bolt_handle:Node3D
var chamber_window:MeshInstance3D
var optic:Node3D
var _reload_pending:=false
var _bolt_release_required:=true
func get_magazine_offer_point()->Vector3:
	if has_meta("downloaded_model_077"):return Vector3(0,OFFER_POINT.y+.1016/visual_model_scale(),get_meta("download_magazine_home_077").z)
	return super.get_magazine_offer_point()
func get_magazine_insert_point()->Vector3:
	if has_meta("downloaded_model_077"):return Vector3(0,INSERT_POINT.y,get_meta("download_magazine_home_077").z)
	return super.get_magazine_insert_point()
func scoped_damping_multiplier(magnification:float,scoped:bool)->float:
	# 076: square-root zoom response time: 4x optic => 2x damping, no sensitivity change.
	if not scoped or OS.get_cmdline_user_args().has("--awp-baseline") or not ProjectSettings.get_setting("ashfall/awp_zoom_damping_experiment",true):return 1.0
	return sqrt(clampf(magnification,1.0,8.0))
func aim_smoothing_time_constant()->float:
	var scoped:bool=is_instance_valid(optic) and optic.alignment_allowed()
	var zoom:float=optic.zoom_magnification if is_instance_valid(optic) else 1.0
	return super.aim_smoothing_time_constant()*scoped_damping_multiplier(zoom,scoped)

func get_action_mode()->String:
	if reload_state=="ready":return "loaded_support"
	if reload_state=="needs_bolt":
		if _reload_pending or ammo<=0:return "reload_eject_bolt"
		return "cycle_spent_bolt" if spent_chamber else "chamber_inserted_magazine"
	return reload_state
func allows_world_reticle()->bool:return false
func reload_grip_in_progress()->bool:return _bolt_contact or super.reload_grip_in_progress()
func get_reload_zones()->Array:
	if reload_state=="ready":return [] # Loaded grip belongs to support, never reload.
	if reload_state=="needs_bolt":return [{"position":get_bolt_grip_point(),"radius":.20}]
	return [{"position":get_magazine_offer_point(),"radius":.25},{"position":get_magazine_insert_point(),"radius":.25}] if reload_state in ["needs_mag","held_mag"] else super.get_reload_zones()

func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	for voice in _shot_voices:
		voice.volume_db=-1.0;voice.max_distance=120.0
	magazine_size=3;ammo=3;damage=125.0;fire_interval=.95
	update_ammo_display()
	# Only this authored precision rifle opts into magnification.
	for part in model.find_children("*","VisualInstance3D",true,false):part.layers=1<<18
	optic=load("res://scripts/awp_scope.gd").new();model.add_child(optic);optic.setup(self)
	preload("res://scripts/downloaded_firearm_model.gd").replace_debris(self)

func get_loaded_rounds()->int:return ammo
func shot_sound_kind_089()->String:return "shot_awp"
func get_reload_hint()->String:return ""

func fire()->void:
	if model==null or cooldown>0 or reload_state!="ready" or not _input_allowed():return
	if _vr_active() and (not _hand_input_ready(right_hand) or _weapon_hand_climbing() or (_has_head_obstruction and player.get("head_obstructed"))):return
	if not chambered or ammo<=0:
		if _empty_click<=0:_play(_sound_click);_empty_click=.25
		_requires_trigger_release=true
		return
	ammo-=1;chambered=false;spent_chamber=true;_requires_trigger_release=true
	var pose:=get_firing_pose()
	_flash_time=.055;_kick_recoil(.052,deg_to_rad(5.5))
	var origin:=pose.origin # Optical center and discharge share the same published ray.
	shot.emit(origin,-pose.basis.z.normalized(),damage)
	_play_shot();_haptic(right_hand,.75,.08)
	bolt_phase="back";_set_stage("needs_bolt","");cooldown=fire_interval
	_bolt_contact=false;_bolt_previous=true;_bolt_lifted=false;_bolt_rear=false;_bolt_release_required=true
	if ammo==0:_reload_pending=true # The spent magazine stays until the first BACK.
	update_ammo_display()

func eject_magazine()->void:
	if not _input_allowed() or _support_hand_climbing() or _bolt_contact:return
	if reload_state not in ["ready","needs_bolt"]:return
	# A reload request exposes the bolt, never ejects or refunds by itself.
	_reload_pending=true;chambered=false;_requires_trigger_release=true
	_bolt_release_required=left_hand!=null and (left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click"))
	bolt_phase="back";_bolt_lifted=false;_bolt_rear=false
	_set_stage("needs_bolt","")

func grab_magazine()->void:
	if _input_allowed() and not _support_hand_climbing() and reserve_rounds()!=0 and reload_state=="needs_mag":
		_mag_grab_local=reload_local_point(left_hand.global_position) if left_hand!=null else get_magazine_offer_point()
		_set_stage("held_mag","")

func insert_magazine()->void:
	if not _input_allowed() or _support_hand_climbing() or reload_state!="held_mag":return
	var rounds:=take_reserve(magazine_size)
	if rounds<=0:_set_stage("needs_mag","");return
	ammo=rounds;_seated_rounds=0;chambered=false;spent_chamber=false
	_reload_pending=false;bolt_phase="back";_bolt_contact=false;_bolt_previous=true;_bolt_lifted=false;_bolt_rear=false;_bolt_release_required=false
	_set_stage("needs_bolt","")

func rack_bolt()->void:pass # Physical back stroke remains required; no button bypass.

func _poll_vr()->void:
	if not _input_allowed() or not _hand_input_ready(right_hand):_suspend_gestures();return
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:_requires_trigger_release=false
	elif not _requires_trigger_release:fire()
	var click:=right_hand.is_button_pressed("primary_click")
	if click and not _eject_click_previous and manual_click_eject_allowed():eject_magazine()
	_eject_click_previous=click
	var stick:=right_hand.get_vector2("primary")
	if stick.length()<.25:_eject_previous=false
	elif stick.y<-.7 and absf(stick.x)<.5 and not _eject_previous:eject_magazine();_eject_previous=true
	if not _hand_input_ready(left_hand) or _support_grip_reserved():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	var point:=reload_local_point(left_hand.global_position)
	if reload_state=="needs_mag" and grip and not _grip_previous and _in_reload_reach(point,get_magazine_offer_point(),.25):grab_magazine()
	elif reload_state=="held_mag":
		if grip and point.y-_mag_grab_local.y>=.06 and _in_reload_reach(point,get_magazine_insert_point(),.25):insert_magazine()
		elif not grip:_set_stage("needs_mag","")
	elif reload_state=="needs_bolt":bolt_sample(point,grip,true)
	_grip_previous=grip

func bolt_sample(point:Vector3,grip:bool,valid:bool)->void:
	if reload_state!="needs_bolt":return
	if not valid or not _input_allowed() or _support_hand_climbing():_cancel_bolt_contact();return
	if not grip:
		_bolt_contact=false;_bolt_release_required=false
	elif not _bolt_previous and not _bolt_release_required and not _bolt_contact and _in_reload_reach(point,get_bolt_grip_point(),.20):
		_bolt_contact=true;_bolt_grab=point;_bolt_origin=get_bolt_grip_point()
	if grip and _bolt_contact:
		var travel:=point-_bolt_grab
		_set_bolt_visual(Vector3(0,0,clampf(travel.z,0,BOLT_TRAVEL)))
		if travel.z>=BOLT_TRAVEL:
			if spent_chamber:_eject_casing();spent_chamber=false
			_finish_cycle() # Spring return, chamber and lock are one accepted pull.
	_bolt_previous=grip

func _in_reload_reach(point:Vector3,center:Vector3,radius:float)->bool:
	if radius==.20:
		if not point.is_finite() or point.distance_to(center)>.42:return false
		var offset:=point-center
		return Vector3(offset.x/.24,offset.y/.20,offset.z/(.30 if offset.z<0 else .22)).length()<=1.0
	return super._in_reload_reach(point,center,radius)

func get_bolt_grip_point()->Vector3:
	return BOLT_REST+Vector3(0,BOLT_LIFT if _bolt_lifted else 0,BOLT_TRAVEL if _bolt_rear else 0)

func _set_bolt_visual(offset:Vector3)->void:
	if bolt_handle!=null:bolt_handle.position=BOLT_REST+offset

func _cancel_bolt_contact()->void:
	_bolt_contact=false;_bolt_previous=true;_bolt_release_required=true
	# The completed mechanical phase persists, but a partial stroke resets to its detent.
	_set_bolt_visual(get_bolt_grip_point()-BOLT_REST)

func _finish_cycle()->void:
	_bolt_contact=false;_bolt_lifted=false;_bolt_rear=false;bolt_phase="locked"
	if _reload_pending or ammo<=0:
		if not _return_magazine_rounds():return
		chambered=false;spent_chamber=false;_reload_pending=false
		_drop_spent_magazine();_set_bolt_visual(Vector3.ZERO);_requires_trigger_release=true
		_set_stage("needs_mag","");return
	chambered=ammo>0;_set_bolt_visual(Vector3.ZERO);_requires_trigger_release=true
	var remaining:=cooldown
	_set_stage("ready","");cooldown=maxf(remaining,cooldown)
	update_ammo_display()

func desktop_reload_step()->void:
	if not _input_allowed() or _support_hand_climbing():return
	match reload_state:
		"ready":eject_magazine();_finish_cycle()
		"needs_mag":grab_magazine();insert_magazine()
		"held_mag":insert_magazine()
		"needs_bolt":
			if spent_chamber:_eject_casing();spent_chamber=false
			_finish_cycle()

func _suspend_left_gestures()->void:
	super._suspend_left_gestures();_cancel_bolt_contact()
	if reload_state=="held_mag":_set_stage("needs_mag","")

func _on_dominance_changed()->void:
	super._on_dominance_changed();_cancel_bolt_contact()

func reset_weapon()->void:
	super.reset_weapon();chambered=true;spent_chamber=false;bolt_phase="locked";_reload_pending=false
	_bolt_lifted=false;_bolt_rear=false;_bolt_contact=false;_bolt_previous=true;_bolt_release_required=true
	_set_bolt_visual(Vector3.ZERO)

func _process(delta:float)->void:
	super._process(delta)
	if model==null:return
	bolt.hide();firing_carrier.hide();guide.hide();insertion_arrow.hide();charging_arrow.hide()
	insertion_arrow.visible=reload_state in ["needs_mag","held_mag"] and _input_allowed()
	charging_arrow.visible=reload_state=="needs_bolt" and _input_allowed()
	if charging_arrow.visible:
		charging_arrow.position=get_bolt_grip_point()+Vector3(.025,.025,0)
		var direction:Vector3={"lift":Vector3.UP,"back":Vector3.BACK,"forward":Vector3.FORWARD,"lower":Vector3.DOWN}.get(bolt_phase,Vector3.BACK)
		charging_arrow.basis=Basis(Quaternion(Vector3.BACK,direction))
	magazine.visible=reload_state not in ["needs_mag","held_mag"]
	chamber_window.visible=not _bolt_rear
	if optic!=null:
		if not _vr_active() and camera!=null and _input_allowed() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			global_transform=camera.global_transform
			position+=global_basis*Vector3(0,-optic.OCULAR.y,-.225)
			if not _external_aim_publication:_displayed_shot_pose=get_shot_transform();_displayed_pose_valid=true
		optic.refresh_optic(delta)

func _suspend_gestures()->void:
	super._suspend_gestures()
	if optic!=null:optic.shutdown()

func shutdown()->void:
	if optic!=null:optic.shutdown()
	super.shutdown()

func get_displayed_optic_pose()->Dictionary:
	return optic.get_displayed_pose() if optic!=null else {"valid":false,"pose":Transform3D.IDENTITY}
func get_scope_overlay_active()->bool:return optic!=null and optic.active

func get_shot_transform()->Transform3D:
	# Apply calibration to the actual ray as well as the optical view. Moving
	# only a reticle/overlay would make the new center disagree with impact.
	return Transform3D(model.global_basis*Basis(Vector3.RIGHT,-deg_to_rad(SIGHT_DROP_DEGREES)),model.to_global(Vector3(0,.047,-1.01)))

func _set_stage(stage:String,message:String)->void:
	super._set_stage(stage,message)
	if magazine!=null:magazine.visible=stage in ["ready","needs_bolt"]

func _build_model()->void:
	super._build_model()
	for child in model.get_children():
		if child not in [magazine,bolt,firing_carrier,guide,muzzle_flash,ammo_label,insertion_arrow,charging_arrow]:child.hide()
	var alloy:=_material(Color("3d484f"),.75,.32)
	var dark:=_material(Color("111a20"),.25,.6)
	var stock:=_material(Color("53645a"),.08,.7)
	var brass:=_material(Color("a88c54"),.8,.35)
	_beveled(Vector3(.069,.078,.34),Vector3(0,.028,-.14),alloy,.01)
	_beveled(Vector3(.068,.075,.35),Vector3(0,-.022,-.43),stock,.012)
	for i in range(7):
		_box(Vector3(.071,.005,.015),Vector3(0,.02,-.30-i*.035),dark)
	_rod(Vector3(0,.047,-.29),Vector3(0,.047,-1.01),.016,alloy,16)
	_rod(Vector3(0,.047,-.955),Vector3(0,.047,-1.015),.022,dark,16)
	_rod(Vector3(0,.047,-1.015),Vector3(0,.047,-1.017),.012,dark,16)
	_beveled(Vector3(.065,.10,.21),Vector3(0,-.045,.13),stock,.015)
	_beveled(Vector3(.08,.12,.025),Vector3(0,-.045,.246),dark,.008)
	_beveled(Vector3(.064,.032,.125),Vector3(0,.024,.13),dark,.008)
	var grip:=_beveled(Vector3(.048,.12,.07),Vector3(0,-.087,.017),stock,.012);grip.rotation.x=.28
	for i in range(5):_box(Vector3(.050,.003,.049),Vector3(0,-.052-i*.016,.014),dark)
	_rod(Vector3(0,-.038,-.025),Vector3(0,-.102,-.038),.0035,dark,8)
	_rod(Vector3(0,-.102,-.038),Vector3(0,-.102,-.11),.0035,dark,8)
	_rod(Vector3(0,-.102,-.11),Vector3(0,-.036,-.11),.0035,dark,8)
	magazine.mesh=BoxMesh.new();magazine.mesh.size=Vector3(.050,.095,.090);magazine.position=Vector3(0,-.073,-.15);magazine.material_override=dark
	loose_magazine.mesh=magazine.mesh
	for i in range(4):_box(Vector3(.052,.005,.073),Vector3(0,-.035+i*.020,0),alloy,magazine)
	chamber_window=_box(Vector3(.006,.023,.105),Vector3(.037,.05,-.12),brass)
	bolt_handle=Node3D.new();bolt_handle.name="PullBackAutomaticReturnBolt";model.add_child(bolt_handle);bolt_handle.position=BOLT_REST
	_rod(Vector3(-.032,0,0),Vector3(.020,-.023,0),.006,alloy,12,bolt_handle)
	var knob:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.017;sphere.height=.034;knob.mesh=sphere;knob.position=Vector3(.022,-.025,0);knob.material_override=dark;bolt_handle.add_child(knob)
	# An unobstructed aperture/iron sight is usable in both eyes. No opaque fake magnifier.
	var zero_target:=Vector3(0,.047,-1.01)+Basis(Vector3.RIGHT,-deg_to_rad(SIGHT_DROP_DEGREES))*Vector3.FORWARD*120.0
	var front_height:=lerpf(.105,zero_target.y,(-.92+.035)/(zero_target.z+.035))
	var sights:=WeaponFinish.iron_sights(model,-.035,-.92,.105,alloy,dark,front_height)
	sight_rear=sights.find_child("RearReference",true,false);sight_front=sights.find_child("FrontReference",true,false)
	muzzle_flash.position=Vector3(0,.047,-1.04)
	# Inventory clones this model before inactive weapons receive their first frame.
	# Hide replaced inherited hardware immediately, while retaining its base API nodes.
	for obsolete in [bolt,firing_carrier,guide,insertion_arrow,charging_arrow]:obsolete.hide()
	preload("res://scripts/long_gun_finish_064.gd").awp(self)
	if preload("res://scripts/downloaded_firearm_model.gd").available("awp"):preload("res://scripts/downloaded_awp_model.gd").build(self)


