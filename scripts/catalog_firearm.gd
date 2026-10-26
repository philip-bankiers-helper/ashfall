extends "res://scripts/weapon.gd"
## Original assets and bounded base reload; unmeasured timing stays configurable.
var profile_id:="cx4"
var mode:="auto"
var _semi_armed:=true
var barrel_length:=.5
var magazine_home:=Vector3(0,-.11,-.15)
func get_magazine_offer_point()->Vector3:
	if profile_id=="s85":return Vector3(0,OFFER_POINT.y,magazine_home.z)+Vector3.UP*(.1524/visual_model_scale())
	if has_meta("downloaded_model_077"):return Vector3(0,-.28 if profile_id=="rfb" else OFFER_POINT.y,magazine_home.z)
	if profile_id in ["1911","tec9","mp9"]:return Vector3(0,OFFER_POINT.y,magazine_home.z)
	if profile_id=="rfb":return Vector3(0,-.28,.14)
	return super.get_magazine_offer_point()
func get_magazine_insert_point()->Vector3:
	if has_meta("downloaded_model_077"):return Vector3(0,-.10 if profile_id=="rfb" else INSERT_POINT.y,magazine_home.z)
	if profile_id in ["1911","tec9","mp9"]:return Vector3(0,INSERT_POINT.y,magazine_home.z)
	if profile_id=="rfb":return Vector3(0,-.10,.14)
	return super.get_magazine_insert_point()
func allows_world_reticle()->bool:return profile_id!="mp9"
func get_reload_zones()->Array:
	if profile_id=="s85" and reload_state=="held_mag":return [{"position":get_magazine_offer_point()+Vector3.UP*(.20/visual_model_scale()),"radius":.14}]
	if profile_id!="rfb":return super.get_reload_zones()
	match reload_state:
		"needs_mag":return [{"position":get_magazine_offer_point(),"radius":.14}]
		"held_mag":return [{"position":get_magazine_insert_point(),"radius":.14}]
		"needs_rack":return [{"position":Vector3(.065,.055,-.10),"radius":.13}]
	return []
func _in_reload_reach(point:Vector3,target:Vector3,radius:float)->bool:
	if profile_id=="s85" and reload_state=="held_mag" and (target.is_equal_approx(get_magazine_insert_point()) or target.is_equal_approx(get_magazine_offer_point()+Vector3.UP*(.20/visual_model_scale()))):
		var from_offer:Vector3=(point-get_magazine_offer_point())*visual_model_scale()
		return from_offer.y>=.045 and from_offer.y<=.40 and Vector2(from_offer.x,from_offer.z).length()<=.16
	return super._in_reload_reach(point,target,radius)
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	if profile_id=="s85" and has_meta("ring_sight"):
		get_meta("ring_sight").position.y=-.0381/model.global_basis.get_scale().y
	if profile_id=="mp9":
		motion_damping=0.0
		var laser:=preload("res://scripts/mp9_laser_091.gd").new();add_child(laser);laser.setup(self)
	damage={"cx4":25.0,"mp5":19.0,"mp9":15.0,"1911":45.0,"tec9":18.0,"akm":34.0,"rfb":25.0,"fal":40.0,"s85":60.0}.get(profile_id,25.0)
	if get_meta("imported_tactical_1911",false):
		for i in range(CASING_POOL_SIZE,_debris.size()):_debris[i].mesh=magazine.mesh;_debris[i].material_override=null
	preload("res://scripts/downloaded_firearm_model.gd").replace_debris(self)
	preload("res://scripts/playtest_fit_088.gd").hide_seated_clip(self)
func fire()->void:
	if mode!="auto" and not _semi_armed:return
	var before:=ammo;super.fire()
	if ammo<before:
		_semi_armed=false
		if mode=="bolt" and ammo>0:
			_seated_rounds=ammo;ammo=0;_set_stage("needs_rack","");_rack_grabbed=false;_grip_previous=true
func set_weapon_settings(settings:Dictionary)->void:
	super.set_weapon_settings(settings)
	if profile_id=="mp9":motion_damping=0.0;_aim_filter_ready=false
func _apply_aim_filter(delta:float)->void:
	if profile_id=="mp9":motion_damping=0.0
	super._apply_aim_filter(delta)
func _process(delta:float)->void:
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click") if _vr_active() else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not trigger:_semi_armed=true
	super._process(delta)
	# Bullpup insertion target and physical magazine agree; no forward-well fiction.
	magazine.position=magazine_home
	if profile_id=="rfb":
		insertion_arrow.position=Vector3(0,-.20,get_magazine_insert_point().z)
		charging_arrow.position=Vector3(.065,.07,-.10)
		bolt.position.x=.065
		if reload_state=="needs_rack":guide.position=Vector3(.065,.055,-.10)
	elif profile_id in ["1911","tec9","mp9"]:
		insertion_arrow.position.z=magazine_home.z
	if get_meta("imported_tactical_1911",false) and reload_state=="ready":bolt.position.z=-.10+sin(clampf(_carrier_time/.095,0.0,1.0)*PI)*.035
	preload("res://scripts/playtest_fit_088.gd").hide_seated_clip(self)
	if profile_id=="s85" and loose_magazine.visible:
		loose_magazine.global_basis=model.global_basis # Vertical relative to the rifle, including controller roll

func _set_stage(stage:String,message:String)->void:
	super._set_stage(stage,message)
	if magazine!=null:preload("res://scripts/playtest_fit_088.gd").hide_seated_clip(self)

func reset_weapon()->void:
	super.reset_weapon()
	preload("res://scripts/playtest_fit_088.gd").hide_seated_clip(self)
func _poll_vr()->void:
	if profile_id!="rfb":super._poll_vr();return
	if not _input_allowed() or not _hand_input_ready(right_hand):_suspend_gestures();return
	var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if not trigger:_requires_trigger_release=false;_semi_armed=true
	elif not _requires_trigger_release:fire()
	var click:=right_hand.is_button_pressed("primary_click")
	if click and not _eject_click_previous:eject_magazine()
	_eject_click_previous=click
	if not _hand_input_ready(left_hand) or _support_grip_reserved():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	var point:=reload_local_point(left_hand.global_position)
	var offer:=get_magazine_offer_point();var well:=get_magazine_insert_point()
	if reload_state=="needs_mag" and grip and not _grip_previous and _in_reload_reach(point,offer,.14):grab_magazine()
	elif reload_state=="held_mag":
		if grip and point.y-_mag_grab_local.y>=.06 and _in_reload_reach(point,well,.14):insert_magazine()
		elif not grip:_set_stage("needs_mag","")
	elif reload_state=="needs_rack":
		if grip and not _grip_previous and not _rack_grabbed and _in_reload_reach(point,Vector3(.065,.055,-.10),.13):_rack_grabbed=true;_rack_start=point
		if grip and _rack_grabbed and point.z-_rack_start.z>=.08:rack_bolt()
	_grip_previous=grip
func get_offered_magazine_transform()->Transform3D:
	if profile_id=="s85":
		#0991 direct gun-space basis cancels the former left45-degree offer cant.
		return super.get_offered_magazine_transform()
	return Transform3D(global_basis,reload_world_point(get_magazine_offer_point())) if profile_id=="rfb" else super.get_offered_magazine_transform()
func get_shot_transform()->Transform3D:
	if has_meta("download_muzzle_084"):return fitted_download_shot()
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,.045,-barrel_length-.12)))
func _build_model()->void:
	super._build_model()
	for child in model.get_children():
		if child not in [magazine,bolt,firing_carrier,guide,muzzle_flash,ammo_label,insertion_arrow,charging_arrow]:child.hide()
	var steel:=_material(Color("566b74"),.75,.35)
	var dark:=_material(Color("18242c"),.18,.75)
	var accent:=_material(Color({"cx4":"46685d","mp5":"687782","mp9":"354d57","1911":"b5bdc0","tec9":"76694e","akm":"8e5935","rfb":"6b7860","fal":"475359","s85":"907458"}.get(profile_id,"46685d")),.2,.6)
	var compact:bool=profile_id in ["1911","tec9","mp9"]
	var length:=.30 if compact else (.64 if profile_id in ["akm","fal","s85"] else .50)
	barrel_length=length
	_beveled(Vector3(.065,.075,length*.66),Vector3(0,.035,-length*.33),steel,.009)
	var grip_z:float=-.035 if profile_id in ["1911","tec9"] else (-.040 if profile_id in ["mp5","mp9"] else .025)
	var grip_core:=_beveled(Vector3(.052,.12,.065),Vector3(0,-.065,grip_z),accent,.01)
	if profile_id in ["1911","tec9","mp5","mp9"]:grip_core.name="CatalogGripCore"
	_rod(Vector3(0,.045,-length*.55),Vector3(0,.045,-length-.12),.014,steel,14)
	if profile_id=="mp9":_rod(Vector3(0,.045,-.29),Vector3(0,.045,-.43),.026,dark,16)
	if not compact and profile_id not in ["cx4","mp5","akm","rfb","fal","s85"]:
		_beveled(Vector3(.06,.10,.22),Vector3(0,-.025,.13),accent,.012)
		_beveled(Vector3(.066,.11,.025),Vector3(0,-.025,.25),dark,.005)
		_beveled(Vector3(.06,.052,.16),Vector3(0,-.005,-.34),accent,.009)
	magazine_home=Vector3(0,-.13,.14 if profile_id=="rfb" else (-.015 if compact else -.15))
	magazine.position=magazine_home;magazine.mesh=BoxMesh.new();magazine.mesh.size=Vector3(.038,.15,.065);magazine.material_override=dark
	if profile_id=="rfb":
		insertion_arrow.position=Vector3(0,-.20,.14);charging_arrow.position=Vector3(.065,.07,-.10);bolt.position.x=.065
	if profile_id=="akm":
		for child in magazine.get_children():child.free()
		magazine.mesh=preload("res://scripts/authored_catalog_detail.gd").curved_magazine()
	if profile_id=="rfb":_beveled(Vector3(.07,.12,.19),Vector3(0,-.005,.18),accent,.01)
	if profile_id=="1911":_beveled(Vector3(.055,.050,.26),Vector3(0,.060,-.115),accent,.005)
	if profile_id=="tec9":
		for i in 5:_box(Vector3(.067,.014,.008),Vector3(0,.048,-.17-i*.025),dark)
	if profile_id in ["cx4","mp5","mp9","1911","tec9","akm","rfb","fal","s85"]:
		preload("res://scripts/authored_catalog_detail.gd").build(self,steel,dark,accent)
	_build_profile_magazine_offers()
	var sights:Node3D
	if profile_id in ["cx4","akm","s85"]:
		sights=preload("res://scripts/authored_ring_dot_sight.gd").build(model,profile_id,-.015,-length+.035,Vector3(0,.045,-length-.12),steel)
		set_meta("ring_sight",sights)
	else:sights=WeaponFinish.zeroed_sights(model,-.015,-length+.035,.11,Vector3(0,.045,-length-.12),80,steel,dark)
	sight_rear=sights.find_child("RearReference",true,false);sight_front=sights.find_child("FrontReference",true,false)
	muzzle_flash.position=Vector3(0,.045,-length-.14)
	if profile_id=="1911" and not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/tactical_1911_model.gd").build(self)
	if preload("res://scripts/downloaded_firearm_model.gd").available(profile_id):preload("res://scripts/downloaded_firearm_model.gd").build(self,profile_id)

func _build_profile_magazine_offers()->void:
	# All three visible states use the actual authored magazine, including AK curvature.
	loose_magazine.free()
	loose_magazine=magazine.duplicate() as MeshInstance3D
	loose_magazine.position=Vector3.ZERO;loose_magazine.rotation=Vector3.ZERO
	add_child(loose_magazine);loose_magazine.hide()
	for child in hip_source.get_children():child.free()
	var offered=magazine.duplicate() as MeshInstance3D
	offered.position=Vector3.ZERO;hip_source.add_child(offered)
	var bounds:AABB=magazine.mesh.get_aabb()
	for child in magazine.get_children():
		if child is MeshInstance3D and child.mesh!=null:bounds=bounds.merge(child.transform*child.mesh.get_aabb())
	bounds=Transform3D(magazine.basis,Vector3.ZERO)*bounds
	var cyan:=_material(Color(.05,.72,.75),.2,.4,.65)
	var low:Vector3=bounds.position-Vector3(.008,.008,0)
	var high:Vector3=bounds.end+Vector3(.008,.008,.006)
	for x in [low.x,high.x]:_rod(Vector3(x,low.y,high.z),Vector3(x,high.y,high.z),.0015,cyan,6,hip_source)
	for y in [low.y,high.y]:_rod(Vector3(low.x,y,high.z),Vector3(high.x,y,high.z),.0015,cyan,6,hip_source)
