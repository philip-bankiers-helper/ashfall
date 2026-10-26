extends "res://scripts/weapon.gd"
## Historical interaction family with original art and explicitly original tolerances.
signal melee_contact(target:Node3D,point:Vector3,amount:float,direction:Vector3)
const Assets=preload("res://scripts/blade_assets.gd")
const Shield=preload("res://scripts/directional_shield.gd")
const SUPPORT_POINT:=Vector3(0,-.190,.025)
const SHIELD_CENTRE:=Vector3(0,.34,-.08)
const SHIELD_RADII:=Vector2(.48768,.6096) * preload("res://scripts/measurement_calibration.gd").FACTOR # Corrected0.97536×1.2192m; same measured rectangle for art and bullet tests.
const MIN_SPEED:=.20
const FULL_SPEED:=2.0
@export_range(.1,10.0,.1) var full_damage_hand_speed:=FULL_SPEED
const EXIT_HYSTERESIS:=.008
const FULL_TRAVEL:=.50
const CONTACT_RADIUS:=.026
const WHOOSH_SPEED:=1.4
const WHOOSH_TRAVEL:=.12
var archetype:="katana"
var hand_grip_center:=Assets.GRIP
var blade_base:Marker3D
var blade_tip:Marker3D
var shield_visual:MeshInstance3D
var grip_cue:MeshInstance3D
var shield_active:=false
var _shield_support_outside_085:=false
var shield_hint:Label3D
var _shield_raise:AudioStreamPlayer3D
var _hum:AudioStreamPlayer3D
var _history_valid:=false
var _previous_base:=Vector3.ZERO
var _previous_tip:=Vector3.ZERO
var _swing_travel:=0.0
var _rest_time:=0.0
var _contact_targets:Dictionary={}
var _previous_grip:=Vector3.ZERO
var _target_next_ms:Dictionary={} # Legacy diagnostic API only; no damage cooldown.
var _desktop_swing:=0.0
var _stroke_direction:=Vector3.ZERO
var _reverse_motion:=Vector3.ZERO
var _swing_sound_played:=false
var _swing_sound_next_ms:=0
var swing_audio_events:=0
var _gold_trail097:Node3D
var _trail_local_base0992:=Vector3.ZERO
var _trail_local_tip0992:=Vector3.ZERO
var _trail_motion_ready0992:=false
func setup(owner_player:Node3D,connect_desktop:bool=true)->void:
	player=owner_player
	_has_player_input_gate=true;_has_climb_state=true;_has_hand_reservation=true;_has_head_obstruction=true
	right_hand=player.get_weapon_hand();left_hand=player.get_support_hand();camera=player.get_view_camera()
	magazine_size=0;ammo=0;reload_state="ready"
	model=Node3D.new();model.name="OriginalSwordArt";add_child(model)
	var authored:Dictionary=Assets.build(model,archetype);blade_base=authored.base;blade_tip=authored.tip
	# One original whoosh per deliberate stroke: speed AND travel gates prevent
	# walking bob or resting contact from looping the close-range sound.
	_sound=AudioStreamPlayer3D.new();_sound.bus="SFX";_sound.max_db=-12;_sound.volume_db=-13;_sound.max_distance=15;_sound.stream=_sword_audio(false);add_child(_sound)
	_hum=AudioStreamPlayer3D.new();_hum.bus="SFX";_hum.max_distance=18;_hum.volume_db=-7;_hum.max_db=-7;_hum.stream=_sword_audio(true);add_child(_hum)
	_shield_raise=AudioStreamPlayer3D.new();_shield_raise.bus="SFX";_shield_raise.volume_db=-7;_shield_raise.max_distance=15;_shield_raise.stream=AshAudioBank.sample("katana_shield_raise");add_child(_shield_raise)
	_build_guard()
	if archetype in ["cyberblade","excalibur","katana"]:
		_gold_trail097=preload("res://scripts/blade_sweep099.gd").new();add_child(_gold_trail097)
		if archetype=="cyberblade":_gold_trail097.trail_color=Color("ffe22a")
	if connect_desktop and player.has_signal("fired"):player.fired.connect(fire)
func _build_guard()->void:
	shield_visual=MeshInstance3D.new();shield_visual.name="DirectionalBulletShield"
	var plane:=QuadMesh.new();plane.size=SHIELD_RADII*2.0;shield_visual.mesh=plane;shield_visual.position=SHIELD_CENTRE
	var shader:=load("res://assets/materials/field_guard_064.gdshader") as Shader
	var finish:=ShaderMaterial.new();finish.shader=shader;shield_visual.material_override=finish;shield_visual.layers=1<<18;shield_visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;model.add_child(shield_visual);shield_visual.hide()
	#084 opaque edge geometry remains readable even when the translucent pane is faint.
	var edge_finish:=Assets.material(Color("24f85b"),.0,.5,true)
	for side in [-1.0,1.0]:
		var vertical:=MeshInstance3D.new();vertical.name="ShieldVerticalEdge084";var bar:=BoxMesh.new();bar.size=Vector3(.008,SHIELD_RADII.y*2,.005);vertical.mesh=bar;vertical.material_override=edge_finish;vertical.layers=1<<18;vertical.position=Vector3(side*SHIELD_RADII.x,0,.001);shield_visual.add_child(vertical)
		var horizontal:=MeshInstance3D.new();horizontal.name="ShieldHorizontalEdge084";var rail:=BoxMesh.new();rail.size=Vector3(SHIELD_RADII.x*2,.008,.005);horizontal.mesh=rail;horizontal.material_override=edge_finish;horizontal.layers=1<<18;horizontal.position=Vector3(0,side*SHIELD_RADII.y,.001);shield_visual.add_child(horizontal)
	grip_cue=MeshInstance3D.new();grip_cue.name="SwordSupportGripCue";var ring:=TorusMesh.new();ring.inner_radius=.028;ring.outer_radius=.032;ring.rings=16;ring.ring_segments=5;grip_cue.mesh=ring;grip_cue.position=SUPPORT_POINT;grip_cue.material_override=Assets.material(Color("52c9d9"),.2,.4,true);grip_cue.layers=1<<18;model.add_child(grip_cue)
	shield_hint=Label3D.new();shield_hint.name="KatanaShieldGripHint085";shield_hint.text="";shield_hint.font_size=28;shield_hint.pixel_size=.00065;shield_hint.position=SUPPORT_POINT+Vector3(.09,-.03,0);shield_hint.no_depth_test=false;shield_hint.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;shield_hint.layers=1<<18;model.add_child(shield_hint)
func _process(delta:float)->void:
	cooldown=maxf(0,cooldown-delta);_desktop_swing=maxf(0,_desktop_swing-delta)
	_pose_weapon();_update_guard()
	if _gold_trail097!=null:
		var base_local:=player.to_local(blade_base.global_position);var tip_local:=player.to_local(blade_tip.global_position)
		var moving:=_trail_motion_ready0992 and delta>0 and maxf(base_local.distance_to(_trail_local_base0992),tip_local.distance_to(_trail_local_tip0992))/maxf(delta,.0001)>.5
		_gold_trail097.sample_blade(blade_base.global_position,blade_tip.global_position,delta,_usable() and moving)
		_trail_local_base0992=base_local;_trail_local_tip0992=tip_local;_trail_motion_ready0992=_usable()
func _physics_process(delta:float)->void:
	_pose_weapon();_update_guard();sample_motion(delta)
func _pose_weapon()->void:
	refresh_hands()
	if _vr_active():global_transform=corrected_grip_transform(right_hand.global_transform)
	elif camera!=null:
		global_transform=camera.global_transform*Transform3D(Basis(Vector3.FORWARD,-.65),Vector3(.25,-.38,-.65))
		if _desktop_swing>0:rotate_object_local(Vector3.UP,sin((.28-_desktop_swing)/.28*PI)*1.25)
	model.visible=not _weapon_hand_climbing() and (not _vr_active() or _hand_valid(right_hand))
func _usable()->bool:
	return is_visible_in_tree() and model.is_visible_in_tree() and _input_allowed() and not player.get("head_obstructed") and not _weapon_hand_climbing() and (not _vr_active() or _hand_input_ready(right_hand))
func _update_guard()->void:
	var was:=supported
	if archetype=="knife" or not _usable() or _support_grip_reserved() or (_vr_active() and not _hand_input_ready(left_hand)):supported=false
	elif _vr_active():
		var held:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
		if _resume_grip_release:
			var distance:float=left_hand.global_position.distance_to(model.to_global(SUPPORT_POINT))
			if not held:_resume_grip_release=false
			elif archetype=="katana" and distance<=.28 and _shield_support_outside_085:_resume_grip_release=false
			elif distance>.34:_shield_support_outside_085=true
			held=held and not _resume_grip_release
		var reach:=.34 if supported else .28 #084 forgiving two-hand hilt acquisition, world anchors still win.
		supported=held and left_hand.global_position.distance_to(model.to_global(SUPPORT_POINT))<=reach
	else:supported=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	shield_active=supported and archetype=="katana"
	shield_visual.visible=shield_active;grip_cue.visible=archetype=="katana" and _usable() and not supported
	shield_hint.hide()
	if supported and not was:_haptic(left_hand,.3,.04)
	if shield_active:
		if not _hum.playing:
			# Keep one sampled stream looping for the complete hold; no authored handoff.
			_hum.stream=_sword_audio(true);_hum.play();_shield_raise.play()
	else:_hum.stop()
	_update_support_visual()
func _update_support_visual()->void:
	if not supported or left_hand==null:_release_support_visual();return
	var visual:=left_hand.get_node_or_null("ArticulatedGlove") as Node3D
	if visual==null:return
	if _attached_visual!=visual:_release_support_visual();_attached_visual=visual;_attached_rest=visual.transform
	visual.global_transform=Transform3D(model.global_basis*Basis(Vector3.FORWARD,-PI*.5 if left_hand==player.left_hand else PI*.5),model.to_global(SUPPORT_POINT))
func get_movement_multiplier()->float:
	if not _usable():return 1.0
	return (.90 if shield_active else 1.15) if archetype in ["katana","knife"] else 1.25
func intercept_bullet(origin:Vector3,endpoint:Vector3)->Dictionary:
	# Re-evaluate grip/input at discharge; a stale rendered shield grants no protection.
	_update_guard()
	if not shield_active:return {}
	var hit:Dictionary=Shield.intersect_bullet(origin,endpoint,shield_visual.global_transform,SHIELD_RADII)
	if not hit.is_empty():_haptic(right_hand,.16,.025);_haptic(left_hand,.2,.025)
	return hit
func sample_motion(delta:float)->void:
	if not _usable() or delta<=0 or delta>.15:
		_history_valid=false;_contact_targets.clear();_reset_stroke();return
	var frame:Transform3D=player.global_transform
	var inverse:=frame.affine_inverse()
	var base:Vector3=inverse*blade_base.global_position
	var tip:Vector3=inverse*blade_tip.global_position
	# Relative to the player: locomotion is not hand motion. Grip translation,
	# not the much faster rotating tip, determines the requested damage curve.
	var grip:Vector3=inverse*(right_hand.global_position if _vr_active() else model.to_global(Assets.GRIP))
	if not _history_valid:
		_previous_base=base;_previous_tip=tip;_previous_grip=grip;_history_valid=true
		_contact_targets=_overlap_target_ids(blade_base.global_position,blade_tip.global_position)
		return # Equipping inside a body is not an entry strike.
	var travel:=maxf(base.distance_to(_previous_base),tip.distance_to(_previous_tip))
	var speed:=travel/delta
	var hand_speed:=grip.distance_to(_previous_grip)/delta
	if travel>1.0:
		_history_valid=false;_contact_targets.clear();_reset_stroke();return
	var tip_motion:=tip-_previous_tip;var base_motion:=base-_previous_base
	var local_motion:=tip_motion if tip_motion.length()>base_motion.length() else base_motion
	var local_direction:=local_motion.normalized()
	if speed<MIN_SPEED:
		_rest_time+=delta
		if _rest_time>=.15:_reset_stroke()
	else:
		# Stroke bookkeeping controls whoosh audio ONLY, never damage rearming.
		if _stroke_direction!=Vector3.ZERO and local_direction.dot(_stroke_direction)<-.35:_reset_stroke()
		_stroke_direction=local_direction;_rest_time=0;_swing_travel+=travel
		_play_swing_audio(speed)
	var amount:=_damage_for_swing(hand_speed,_swing_travel)
	_sample_contact_path(frame,_previous_base,_previous_tip,base,tip,speed>=MIN_SPEED,amount,frame.basis*local_direction)
	_previous_base=base;_previous_tip=tip;_previous_grip=grip
func _sample_contact_path(frame:Transform3D,previous_base:Vector3,previous_tip:Vector3,base:Vector3,tip:Vector3,can_damage:bool,amount:float,direction:Vector3)->void:
	# Spatial subdivision checks exit/reentry along the swept trajectory, including
	# crossings whose two frame endpoints are both outside. No wall-clock gate.
	var before:=previous_tip-previous_base;var after:=tip-base
	var arc_travel:=before.angle_to(after)*maxf(before.length(),after.length())
	var travel:=maxf(previous_base.distance_to(base)+arc_travel,previous_tip.distance_to(tip))
	var steps:=maxi(1,ceili(travel/CONTACT_RADIUS))
	var last_base:=frame*previous_base;var last_tip:=frame*previous_tip
	for i in range(1,steps+1):
		var t:=float(i)/steps
		var lower:=previous_base.lerp(base,t)
		var along:=before.normalized().slerp(after.normalized(),t)*lerpf(before.length(),after.length(),t)
		var next_base:=frame*lower;var next_tip:=frame*(lower+along)
		var contacts:=_find_contacts(last_base,last_tip,next_base,next_tip)
		var touching:=_overlap_target_ids(next_base,next_tip)
		var retained:=_overlap_target_ids(next_base,next_tip,EXIT_HYSTERESIS)
		# Resolve all contacts before callbacks can remove colliders. Contact state
		# is independent per target and updates even below the damage-speed floor.
		var entered:Array[Dictionary]=[]
		for contact in contacts:
			var target:Node3D=contact.target
			if not is_instance_valid(target):continue
			var id:=target.get_instance_id()
			if not _contact_targets.has(id) and can_damage:entered.append(contact)
			_contact_targets[id]=true
		for id in _contact_targets.keys():
			if not retained.has(id):_contact_targets.erase(id)
		for id in touching:_contact_targets[id]=true
		for contact in entered:
			var target:Node3D=contact.target
			if not is_instance_valid(target):continue
			melee_contact.emit(target,contact.position,amount,direction.normalized())
			_haptic(right_hand,.65,.06)
		last_base=next_base;last_tip=next_tip
func _overlap_target_ids(base:Vector3,tip:Vector3,extra_margin:float=0.0)->Dictionary:
	var query:=_sweep_query(base,tip,base,tip);query.margin+=extra_margin
	if player is CollisionObject3D:query.exclude=[player.get_rid()]
	var result:Dictionary={}
	for overlap in get_world_3d().direct_space_state.intersect_shape(query,64):
		var target=overlap.collider
		if target is Node3D:result[target.get_instance_id()]=true
	return result
func _reset_stroke()->void:
	_swing_travel=0;_stroke_direction=Vector3.ZERO;_reverse_motion=Vector3.ZERO;_swing_sound_played=false
func _damage_for_swing(speed:float,_travel:float)->float:
	return swing_damage(speed,0.0,full_damage_hand_speed)
static func swing_damage(speed:float,_travel:float=0.0,full_speed:float=FULL_SPEED)->float:
	return lerpf(25.0,75.0,clampf(maxf(speed,0)/maxf(full_speed,.01),0,1))
func _play_swing_audio(speed:float)->void:
	var now:=Time.get_ticks_msec()
	if _swing_sound_played or speed<WHOOSH_SPEED or _swing_travel<WHOOSH_TRAVEL or now<_swing_sound_next_ms:return
	_swing_sound_played=true;_swing_sound_next_ms=now+180;swing_audio_events+=1
	_sound.pitch_scale=clampf(.85+speed*.045,.90,1.25);_sound.play()
func _find_contacts(previous_base:Vector3,previous_tip:Vector3,base:Vector3,tip:Vector3)->Array[Dictionary]:
	var contacts:Array[Dictionary]=[];var seen:Dictionary={};var space:=get_world_3d().direct_space_state
	var exclude:Array[RID]=[]
	if player is CollisionObject3D:exclude.append(player.get_rid())
	# A continuous thick swept volume replaces13 sparse rays. Intermediate
	# orientations also cover the outside of the rotating blade's tip arc.
	var query:=_sweep_query(previous_base,previous_tip,base,tip);query.exclude=exclude
	var overlaps:=space.intersect_shape(query,32)
	for overlap in overlaps:
		var target=overlap.collider
		if not target is Node3D or seen.has(target.get_instance_id()):continue
		if not target.has_method("take_damage") and not target.has_method("take_melee_damage") and not (target.is_in_group("field_construction") and target.has_method("hit")):continue
		# Isolate this body for a real surface contact instead of using its origin,
		# which is often at an enemy's feet. All other swept bodies are excluded.
		var others:Array[RID]=exclude.duplicate()
		for other in overlaps:
			if other.rid!=overlap.rid and not others.has(other.rid):others.append(other.rid)
		query.exclude=others
		var rest:=space.get_rest_info(query)
		if rest.is_empty() or rest.collider_id!=target.get_instance_id():continue
		var point:Vector3=rest.point
		var blocked:=false
		for segment in [[camera.global_position,base],[base,point]]:
			if segment[0].distance_squared_to(segment[1])<.00001:continue
			var barrier:=PhysicsRayQueryParameters3D.create(segment[0],segment[1],1|8,exclude);barrier.hit_from_inside=true
			var obstacle:=space.intersect_ray(barrier)
			if not obstacle.is_empty() and obstacle.collider!=target:blocked=true;break
		if not blocked:seen[target.get_instance_id()]=true;contacts.append({"target":target,"position":point})
	return contacts
static func _sweep_query(previous_base:Vector3,previous_tip:Vector3,base:Vector3,tip:Vector3)->PhysicsShapeQueryParameters3D:
	var origin:=(previous_base+previous_tip+base+tip)*.25
	var before:=previous_tip-previous_base;var after:=tip-base
	var steps:=maxi(1,ceili(before.angle_to(after)/.10))
	var points:=PackedVector3Array()
	for i in steps+1:
		var t:=float(i)/steps;var lower:=previous_base.lerp(base,t)
		var along:=before.normalized().slerp(after.normalized(),t)*lerpf(before.length(),after.length(),t)
		for at in [lower,lower+along]:
			for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:points.append(at-origin+axis*CONTACT_RADIUS)
	var hull:=ConvexPolygonShape3D.new();hull.points=points
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=hull;query.transform.origin=origin;query.collision_mask=1|4|8;query.margin=.001
	return query
func fire()->void:
	# Desktop debugging emulates a swing; VR requires actual tracked blade movement.
	if not _vr_active() and _usable() and cooldown<=0:_desktop_swing=.28;cooldown=.35
func desktop_reload_step()->void:pass
func eject_magazine()->void:pass
func grab_magazine()->void:pass
func insert_magazine()->void:pass
func rack_bolt()->void:pass
func update_ammo_display()->void:pass
func get_loaded_rounds()->int:return 0
func get_shot_transform()->Transform3D:return Transform3D(global_basis,model.to_global(Assets.GRIP))
func is_hand_holding_weapon(hand:Node3D)->bool:return _usable() and (hand==right_hand or (hand==left_hand and supported))
func _on_dominance_changed()->void:_suspend_gestures()
func _suspend_left_gestures()->void:
	supported=false;shield_active=false;_resume_grip_release=true;_shield_support_outside_085=false;_release_support_visual()
	if shield_visual!=null:shield_visual.hide()
	if _hum!=null:_hum.stop()
	if _shield_raise!=null:_shield_raise.stop()
func _suspend_gestures()->void:
	_suspend_left_gestures();_history_valid=false;_contact_targets.clear();_reset_stroke();_displayed_pose_valid=false;_desktop_swing=0;_requires_trigger_release=true;_rack_grabbed=false
	if _gold_trail097!=null:_gold_trail097.sample_blade(Vector3.ZERO,Vector3.ZERO,0,false)
func suspend_for_selection()->void:_suspend_gestures()
func reset_weapon()->void:
	ammo=0;reload_state="ready";cooldown=0;_target_next_ms.clear();_suspend_gestures()
func shutdown()->void:
	_suspend_gestures();set_process(false);set_physics_process(false)
	if _sound!=null:_sound.stop()
func _sword_audio(loop:bool)->AudioStreamWAV:
	var specific:AudioStreamWAV=preload("res://scripts/reference_audio_099.gd").action("shield_sustain" if loop else "sword_swing",archetype,0)
	return specific if specific!=null else AshAudioBank.sample("katana_shield" if loop else "sword_swing")

func _legacy_sword_audio(loop:bool)->AudioStreamWAV:
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var duration:=.5 if loop else .22;var count:=int(stream.mix_rate*duration);var bytes:=PackedByteArray();bytes.resize(count*2)
	var noise:=RandomNumberGenerator.new();noise.seed=19049
	for i in count:
		var t:=float(i)/stream.mix_rate
		var value:float=(sin(TAU*80*t)*.09+sin(TAU*160*t)*.035) if loop else noise.randf_range(-.40,.40)*pow(sin(PI*t/duration),1.4)
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	stream.data=bytes
	if loop:stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=count
	return stream
