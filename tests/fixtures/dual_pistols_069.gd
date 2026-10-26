extends "res://scripts/weapon.gd"
## Original compact dual Uzis. Each trigger is automatic; each occupied hand flicks up.
class PairedUzi extends "res://scripts/compact_smg.gd":
	var pair
	var side:=0
	var _flick_time:=0.0
	var _flick_history:Array[Dictionary]=[]
	var _flick_neutral:=0.0
	var _flick_ready:=false
	var spin_root:Node3D
	var spin_elapsed:=.36
	const SPIN_SECONDS:=.36
	var reload_arrow:Node3D
	var shotgun_mode:=false
	var _semi_armed:=true
	var _laser:MeshInstance3D
	var _laser_mesh:ImmediateMesh
	func _vr_active()->bool:return pair!=null and pair._vr_active()
	func refresh_hands()->bool:
		if pair==null:return false
		var hand:XRController3D=pair.hand_for(side)
		var other:XRController3D=pair.hand_for(1-side)
		var changed:=right_hand!=hand or left_hand!=other
		right_hand=hand;left_hand=other
		if changed and model!=null:_on_dominance_changed();_suspend_gestures()
		return changed
	func _weapon_hand_climbing()->bool:return pair.hand_climbing(right_hand) if pair!=null else false
	func _reserve_support_hand(_value:bool)->void:pass
	func get_shot_transform()->Transform3D:
		return Transform3D(model.global_basis,model.to_global(Vector3(0,.045,-.37 if shotgun_mode else -.46)))
	func _update_support(_delta:float)->void:
		supported=false;_support_weight=0;_release_support_visual()
	func _poll_vr()->void:
		if not _input_allowed() or not _hand_input_ready(right_hand) or _weapon_hand_climbing():_suspend_gestures();return
		var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
		if not trigger:_requires_trigger_release=false;_semi_armed=true
		elif not _requires_trigger_release:fire()
	func fire()->void:
		if pair==null or not pair.visible:return
		if player.has_method("update_objective_grips"):player.update_objective_grips()
		if player.has_method("is_hand_grip_reserved") and player.is_hand_grip_reserved(right_hand):return
		if not shotgun_mode:super.fire();return
		if not _semi_armed or cooldown>0 or reload_state!="ready" or not _input_allowed():return
		if _vr_active() and (not _hand_input_ready(right_hand) or _weapon_hand_climbing() or player.get("head_obstructed")):return
		if ammo<=0:eject_magazine();return
		ammo-=1;_semi_armed=false;cooldown=fire_interval;_flash_time=.05
		var pose:=get_firing_pose();var directions:Array[Vector3]=[]
		for i in 8:
			var angle:=TAU*i/8.0;var radius:=tan(deg_to_rad(5.0))*(.4 if i%2==0 else 1.0)
			directions.append((-pose.basis.z+pose.basis.x*cos(angle)*radius+pose.basis.y*sin(angle)*radius).normalized())
		emit_signal("pellet_shot",pose.origin,directions,damage);_kick_recoil(.065,deg_to_rad(7));_play_shot();_haptic(right_hand,.6,.06)
		if ammo==0:eject_magazine()
	func eject_magazine()->void:
		if ammo<=0:reload_state="needs_mag";_requires_trigger_release=true
	func grab_magazine()->void:pass
	func insert_magazine()->void:pass
	func rack_bolt()->void:pass
	func reload_flick()->bool:
		if not _input_allowed() or _weapon_hand_climbing():return false
		if player.has_method("is_hand_grip_reserved") and player.is_hand_grip_reserved(right_hand):return false
		if ammo>=magazine_size:
			# An already full gun still performs the requested cosmetic upward flip.
			spin_elapsed=0;cooldown=maxf(cooldown,SPIN_SECONDS);_requires_trigger_release=true
			_flick_ready=false;_flick_neutral=0;_flick_history.clear();return true
		var remaining:=ammo
		var returned:=refund_rounds(remaining)
		ammo-=returned
		if returned<remaining:update_ammo_display();return false
		ammo=take_reserve(magazine_size)
		reload_state="ready" if ammo>0 else "needs_mag"
		_requires_trigger_release=true;cooldown=maxf(cooldown,SPIN_SECONDS);spin_elapsed=0
		_haptic(right_hand,.45,.065);_play(AudioBank.sample("mag_insert"));update_ammo_display()
		_flick_ready=false;_flick_neutral=0;_flick_history.clear()
		return ammo>0
	func flick_sample(point:Vector3,forward:Vector3,delta:float,valid:bool,trigger:bool)->void:
		if not valid or not point.is_finite() or not forward.is_finite() or not is_finite(delta) or delta<=0 or delta>.15 or not _input_allowed() or _weapon_hand_climbing():_reset_flick();return
		_flick_time+=delta
		var newest:Dictionary=_flick_history.back() if not _flick_history.is_empty() else {}
		if not newest.is_empty() and point.distance_to(newest.point)>.7:_reset_flick();return
		var speed:=point.distance_to(newest.point)/delta if not newest.is_empty() else 0.0
		var angular:=forward.angle_to(newest.forward)/delta if not newest.is_empty() else 0.0
		if not trigger and speed<.20 and angular<.8:
			_flick_neutral+=delta
			if _flick_neutral>=.12:_flick_ready=true
		else:_flick_neutral=0
		while not _flick_history.is_empty() and _flick_time-float(_flick_history[0].time)>.28:_flick_history.pop_front()
		if _flick_ready and not _flick_history.is_empty():
			var first:Dictionary=_flick_history[0]
			var elapsed:=maxf(.001,_flick_time-float(first.time))
			var rise:=point.y-float(first.point.y)
			var pitch:=forward.y-float(first.forward.y)
			# Upward translation or an upward wrist pitch; downward/lateral motion never reloads.
			if (rise>=.10 and rise/elapsed>=.55) or (pitch>=.60 and pitch/elapsed>=2.0):
				if reload_flick():return
		_flick_history.append({"point":point,"forward":forward,"time":_flick_time})
	func _reset_flick()->void:
		_flick_history.clear();_flick_neutral=0;_flick_ready=false
	func _suspend_gestures()->void:
		super._suspend_gestures();_reset_flick();spin_elapsed=SPIN_SECONDS
		if spin_root!=null:spin_root.basis=Basis.IDENTITY
	func _process(delta:float)->void:
		super._process(delta)
		spin_elapsed=minf(SPIN_SECONDS,spin_elapsed+maxf(delta,0.0))
		if spin_root!=null:spin_root.rotation.x=TAU*smoothstep(0.0,SPIN_SECONDS,spin_elapsed) if spin_elapsed<SPIN_SECONDS else 0.0
		if _vr_active():
			# Head motion cannot turn a stationary gun into an upward flick.
			# Match the single-gun closure frame and remove artificial locomotion.
			var frame:=Transform3D(player.global_basis,player.get_locomotion_anchor_position())
			var pose:Transform3D=frame.affine_inverse()*corrected_grip_transform(right_hand.global_transform)
			var trigger:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
			flick_sample(pose.origin,-pose.basis.z,delta,_hand_input_ready(right_hand),trigger)
		for part in [loose_magazine,hip_source,guide,insertion_arrow,charging_arrow]:part.hide()
		reload_arrow.visible=ammo==0 and _input_allowed()
		# A world-up cue remains upward even while the player rolls the gun.
		if reload_arrow.visible:reload_arrow.global_basis=Basis.IDENTITY
	func _update_laser()->void:
		if _laser==null:
			_laser=MeshInstance3D.new();_laser.name="OriginalUziAimLaser";_laser.top_level=true;_laser_mesh=ImmediateMesh.new();_laser.mesh=_laser_mesh;add_child(_laser)
			var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;finish.albedo_color=Color(1,.015,.01);finish.cull_mode=BaseMaterial3D.CULL_DISABLED;_laser.material_override=finish;_laser.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_laser.layers=1<<18
		_laser.visible=not shotgun_mode and is_visible_in_tree() and model.is_visible_in_tree() and ammo>0 and reload_state=="ready" and _input_allowed() and not _weapon_hand_climbing() and player.get("head_obstructed")!=true and (not _vr_active() or _hand_input_ready(right_hand))
		_laser_mesh.clear_surfaces()
		if not _laser.visible:return
		var pose:=get_shot_transform();var endpoint:=pose.origin-pose.basis.z*180.0
		var exclude:Array[RID]=[]
		if player is CollisionObject3D:exclude.append(player.get_rid())
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin,endpoint,1|4|8,exclude))
		if not hit.is_empty():endpoint=hit.position
		var side:Vector3=(endpoint-pose.origin).cross(camera.global_position-pose.origin).normalized()*.0015
		_laser_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [pose.origin-side,pose.origin+side,endpoint+side,pose.origin-side,endpoint+side,endpoint-side]:_laser_mesh.surface_add_vertex(point)
		_laser_mesh.surface_end()
	func _build_model()->void:
		# Request the original compact geometry only while constructing an Uzi.
		var original_uzi:=pair==null or not bool(pair.shotgun_mode)
		var had_choice:=has_meta("_paired_uzi_visual_063")
		var previous_choice=get_meta("_paired_uzi_visual_063",false)
		if original_uzi:set_meta("_paired_uzi_visual_063",true)
		super._build_model()
		if original_uzi:
			if had_choice:set_meta("_paired_uzi_visual_063",previous_choice)
			else:remove_meta("_paired_uzi_visual_063")
		magazine.position.z=.005 # Grip-fed compact profile, original authored geometry.
		if pair!=null and pair.shotgun_mode:
			for part in model.get_children():part.hide()
			ammo_label.show()
			load("res://scripts/matador_finish_064.gd").matador(self)
			magazine.hide();muzzle_flash.position=Vector3(0,.045,-.38)
		else:
			load("res://scripts/handgun_finish_063.gd").uzi(self)
		reload_arrow=Node3D.new();reload_arrow.name="OccupiedHandUpFlick";model.add_child(reload_arrow)
		reload_arrow.position=Vector3(.09,.07,-.10)
		var cue:=_material(Color(1,.72,.16),.15,.5,1)
		_box(Vector3(.009,.09,.006),Vector3(0,.045,0),cue,reload_arrow)
		for sign_x in [-1.0,1.0]:
			var arm:=_box(Vector3(.009,.035,.006),Vector3(sign_x*.01,.077,0),cue,reload_arrow);arm.rotation.z=sign_x*.65
		spin_root=Node3D.new();spin_root.name="OriginalUpFlickFullTurn";spin_root.position=Vector3(0,-.057,.025)
		for child in model.get_children():
			model.remove_child(child);spin_root.add_child(child)
			if child is Node3D:child.position-=spin_root.position
		model.add_child(spin_root)

class PairedMatador extends PairedUzi:
	signal pellet_shot(origin:Vector3,directions:Array[Vector3],damage:float)
var guns:Array=[]
func get_reload_zones()->Array:return [] # Occupied-hand flicks have no offhand grab.
var shotgun_mode:=false
signal pellet_shot(origin:Vector3,directions:Array[Vector3],damage:float)
var stowed:Array[bool]=[false,false] # Retained save/API field; both guns stay drawn.
var _published_cooldown:=0.0
func hand_for(index:int)->XRController3D:
	return player.get_weapon_hand() if index==0 else player.get_support_hand()
func hand_climbing(hand:XRController3D)->bool:
	var anchors=player.get("_grabs")
	return anchors is Dictionary and anchors.has(hand)
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	for part in model.get_children():part.hide()
	for i in range(2):
		var gun:PairedUzi=PairedMatador.new() if shotgun_mode else PairedUzi.new()
		gun.pair=self;gun.side=i;add_child(gun);gun.setup(actor,false);gun.refresh_hands()
		gun.shotgun_mode=shotgun_mode
		gun.set_meta("recoil_profile","matadors" if shotgun_mode else "uzi")
		if shotgun_mode:gun.magazine_size=8;gun.ammo=8;gun.fire_interval=.32;gun.damage=8
		gun._desktop_signals=true
		gun.set_process(false);gun.set_physics_process(false);gun.set_process_unhandled_input(false)
		gun.shot.connect(func(origin:Vector3,direction:Vector3,power:float):shot.emit(origin,direction,power))
		if gun.has_signal("pellet_shot"):gun.pellet_shot.connect(func(origin:Vector3,directions:Array[Vector3],power:float):pellet_shot.emit(origin,directions,power))
		guns.append(gun)
		var copy:Node3D=gun.model.duplicate(0);copy.name="CanonicalPairedUzi%d"%i
		copy.transform=Transform3D(Basis(Vector3.UP,-.12 if i==0 else .12),Vector3(.09 if i==0 else -.09,0,0))
		_strip_icon_scripts(copy);model.add_child(copy)
	model.hide();magazine_size=16 if shotgun_mode else 64;_sync_pair()
func _sync_pair()->void:
	if guns.is_empty():return
	ammo=get_loaded_rounds();cooldown=maxf(guns[0].cooldown,guns[1].cooldown);_published_cooldown=cooldown
	# One empty gun must not block the loaded gun or its reticle.
	reload_state="ready" if ammo>0 else "needs_mag";supported=false;_rack_grabbed=false
func get_loaded_rounds()->int:
	return guns[0].ammo+guns[1].ammo if guns.size()==2 else 64
func update_ammo_display()->void:
	if ammo_panel!=null:ammo_panel.hide()
	for gun in guns:gun.ammo_provider=ammo_provider;gun.ammo_slot=ammo_slot;gun.update_ammo_display()
func get_shot_transform()->Transform3D:
	return guns[0].get_shot_transform() if not guns.is_empty() else super.get_shot_transform()
func get_reload_hint()->String:return ""
func is_hand_holding_weapon(hand:XRController3D)->bool:return hand==hand_for(0) or hand==hand_for(1)
func toggle_stow(_index:int)->bool:return false
func _process(delta:float)->void:
	if guns.size()!=2:return
	refresh_hands();update_ammo_display()
	if cooldown>_published_cooldown+.000001:
		for gun in guns:gun.cooldown=cooldown
	if not _input_allowed():_suspend_gestures();return
	for i in range(2):
		var gun=guns[i];gun.visible=true;gun._process(delta)
		if not _vr_active():
			gun.global_position+=camera.global_basis.x*(-.40 if i==1 else 0.0)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if i==0 else MOUSE_BUTTON_RIGHT):gun.fire()
		gun._update_laser() # Use the final per-hand pose, including desktop separation.
	_sync_pair()
func _physics_process(delta:float)->void:
	for gun in guns:gun._physics_process(delta)
func fire()->void:
	if not guns.is_empty():guns[0].fire();_sync_pair()
func desktop_reload_step()->void:
	for gun in guns:gun.reload_flick()
	_sync_pair()
func eject_magazine()->void:pass
func grab_magazine()->void:pass
func insert_magazine()->void:pass
func rack_bolt()->void:pass
func _suspend_gestures()->void:
	super._suspend_gestures()
	for gun in guns:gun._suspend_gestures()
func refresh_hands()->bool:
	var changed:=super.refresh_hands()
	for gun in guns:
		if gun.refresh_hands():changed=true
	return changed
func set_weapon_settings(settings:Dictionary)->void:
	super.set_weapon_settings(settings)
	for gun in guns:gun.set_weapon_settings(settings)
func reset_weapon()->void:
	super.reset_weapon();stowed=[false,false]
	for gun in guns:gun.reset_weapon()
	_sync_pair()
func shutdown()->void:
	for gun in guns:
		if is_instance_valid(gun):gun.shutdown()
	super.shutdown()
func _reserve_support_hand(_value:bool)->void:pass
func get_reticle_entries()->Array:
	var entries:Array=[]
	for i in range(guns.size()):entries.append({"hand":hand_for(i),"weapon":guns[i]})
	return entries
func _strip_icon_scripts(node:Node)->void:
	for child in node.get_children():_strip_icon_scripts(child)
	if node is Label3D:node.free();return
	if node.name in ["AmmoReadoutPanel","OccupiedHandUpFlick"]:node.hide()
	node.set_script(null)
func blocks_sprint()->bool:
	for gun in guns:
		if gun.right_hand.get_float("trigger")>.1 or gun.right_hand.is_button_pressed("trigger_click"):return true
	return false
func suspend_for_selection()->void:
	_displayed_pose_valid=false
	for gun in guns:gun.suspend_for_selection()
	_sync_pair()
