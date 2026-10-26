extends RigidBody3D
## All unspecified fuse/falloff/shrink/throw values are original configurable tuning.
signal warning_beep(kind:String,scheduled_age:float,remaining:float)
const GrenadeWarning=preload("res://scripts/grenade_warning.gd")
var game:Node
var kind:="frag"
var tuning:Dictionary={}
var age:=0.0
var stuck:=false
var finished:=false
var activation_age:=0.0
var zone_active:=false
var flight_sound:AudioStreamPlayer3D
var warning_sound:AudioStreamPlayer3D
var _warning_times:=PackedFloat32Array()
var _warning_next:=0
var _warning_duration:=0.0
var zone_age:=0.0
var zone_ticks:=0
var zone_visual:MeshInstance3D
var _paused:=false
var _saved_velocity:=Vector3.ZERO
var _saved_spin:=Vector3.ZERO
var _support_point:=Vector3.ZERO
var _support_normal:=Vector3.UP
var _has_support:=false
const MAX_GROUND_ROLL0991:=3.048
var ground_roll0991:=0.0
var _grounded0991:=false
var _roll_last0991:=Vector3.ZERO
func ground_roll_velocity0991(velocity:Vector3,normal:Vector3,delta:float,travel:float)->Vector3:
	var along:=velocity.slide(normal)
	if travel>=MAX_GROUND_ROLL0991:along=Vector3.ZERO
	else:along=along.move_toward(Vector3.ZERO,4.0*maxf(delta,0))
	return along+normal*minf(0.0,velocity.dot(normal))
func _integrate_forces(state:PhysicsDirectBodyState3D)->void:
	if kind=="frag" and not finished:
		var normal:=Vector3.ZERO
		for i in state.get_contact_count():
			var n:=state.get_contact_local_normal(i).normalized()
			if n.dot(Vector3.UP)>.45:normal=n;break
		if normal.length_squared()>.5:
			if _grounded0991:ground_roll0991+=state.transform.origin.distance_to(_roll_last0991)
			_grounded0991=true;_roll_last0991=state.transform.origin
			state.linear_velocity=ground_roll_velocity0991(state.linear_velocity,normal,state.step,ground_roll0991)
			state.angular_velocity=state.angular_velocity.move_toward(Vector3.ZERO,8.0*state.step)
		else:_grounded0991=false
	if kind!="zone" or stuck or state.get_contact_count()==0:return
	_support_point=state.get_contact_collider_position(0)
	_support_normal=state.get_contact_local_normal(0).normalized()
	_has_support=true
func _seat_zone_visual()->void:
	if not is_inside_tree():return
	var normal:=_support_normal if _has_support else Vector3.UP
	var point:=_support_point if _has_support else global_position-Vector3.UP*.035
	var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.12,global_position-Vector3.UP*.22,1|4|8,[get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():point=hit.position;normal=hit.normal
	if normal.length_squared()<.9:normal=Vector3.UP
	var forward:Vector3=-global_basis.z
	forward=(forward-normal*forward.dot(normal)).normalized()
	if forward.length_squared()<.5:forward=Vector3.FORWARD.slide(normal).normalized()
	if forward.length_squared()<.5:forward=Vector3.RIGHT.slide(normal).normalized()
	global_basis=Basis.looking_at(forward,normal)
	var minimum:=INF
	for part in find_children("*","MeshInstance3D",true,false):
		if part==zone_visual or not part.is_visible_in_tree():continue
		var bounds:AABB=part.get_aabb()
		for corner in 8:
			var offset:Vector3=part.to_global(bounds.get_endpoint(corner))-global_position
			minimum=minf(minimum,offset.dot(normal))
	if is_finite(minimum):global_position=point+normal*(.004-minimum)
	set_meta("zone_support_normal094",normal);set_meta("zone_support_point094",point)
func setup(owner_game:Node,spec:Dictionary)->void:
	game=owner_game;kind=spec.kind;tuning=load("res://scripts/arsenal_data.gd").tuning()
	name="OriginalProjectile_"+kind;mass=.35;collision_layer=16;collision_mask=1|2|4|8;continuous_cd=true
	contact_monitor=true;max_contacts_reported=4;body_entered.connect(_on_contact)
	global_position=spec.origin;linear_velocity=spec.velocity;gravity_scale=0 if kind=="smaw" else 1
	linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE;linear_damp=0.0 # Match the preview's gravity-only trajectory.
	if is_instance_valid(game.player) and game.player is PhysicsBody3D:add_collision_exception_with(game.player)
	var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.035;shape.shape=sphere;add_child(shape)
	_build_projectile_visual()
	if kind=="smaw":
		if linear_velocity.length()>.1:look_at(global_position+linear_velocity,Vector3.UP)
		flight_sound=AudioStreamPlayer3D.new();flight_sound.bus="SFX";flight_sound.stream=load("res://scripts/audio_bank.gd").sample("rocket_flight");flight_sound.max_distance=60;add_child(flight_sound);flight_sound.play()
	if kind=="zone":
		zone_visual=MeshInstance3D.new();var volume:=SphereMesh.new();volume.radius=1;volume.height=2;volume.radial_segments=24;volume.rings=12;zone_visual.mesh=volume
		var mist:=StandardMaterial3D.new();mist.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mist.albedo_color=Color(.55,.15,.95,.06);mist.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mist.cull_mode=BaseMaterial3D.CULL_DISABLED;zone_visual.material_override=mist;add_child(zone_visual);zone_visual.hide()
	if kind in ["frag","zone"]:
		warning_sound=AudioStreamPlayer3D.new();warning_sound.name="AcceleratingGrenadeWarning";warning_sound.bus="SFX";warning_sound.stream=GrenadeWarning.tone(kind);warning_sound.max_distance=60;warning_sound.volume_db=-7;add_child(warning_sound)
		if kind=="frag":_start_warning(float(tuning.get("frag_fuse_seconds",3.5)))
func _build_projectile_visual()->void:
	var art=load("res://scripts/explosive_finish_064.gd")
	if kind=="smaw":
		var round_art:Node3D=art.rocket(self)
		# Offered/carried round points +Z for front loading; flight remains -Z.
		round_art.rotation.y=PI #086 shared authored round now already faces -Z
		var plume:=MeshInstance3D.new();var tail:=CylinderMesh.new();tail.top_radius=.012;tail.bottom_radius=.09;tail.height=.8;plume.mesh=tail;plume.rotation.x=PI*.5;plume.position.z=.35
		var fire:=StandardMaterial3D.new();fire.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fire.albedo_color=Color("ffd978");plume.material_override=fire;add_child(plume)
	else:
		# Preserve the old distinction between held and flying visual size. The
		# real .035 m collider and all launch/impact physics are unchanged.
		art.grenade(self,kind,.035/.047)
func _physics_process(delta:float)->void:
	if finished:return
	if not is_instance_valid(game):queue_free();return
	if _paused or game.paused or game.dead or game.complete:
		# Main pauses the whole tree; this protects direct fixture/manual stepping too.
		return
	age+=delta
	if kind=="zone" and stuck:
		activation_age+=delta
		var delay:=float(tuning.get("zone_activation_delay",2.7))
		if not zone_active:_advance_warning(activation_age)
		if not zone_active and activation_age>=delay:_activate_zone()
		if zone_active:advance_zone(minf(delta,maxf(0,activation_age-delay)))
	elif kind=="frag":
		_advance_warning(age)
		if age>=float(tuning.get("frag_fuse_seconds",3.5)):detonate()
	elif age>=8:detonate() if kind=="smaw" else queue_free()
func set_paused(value:bool)->void:
	if value==_paused:return
	_paused=value
	if warning_sound!=null:warning_sound.stream_paused=value
	if value:
		_saved_velocity=linear_velocity;_saved_spin=angular_velocity;freeze=true
	else:
		freeze=stuck
		if not stuck:linear_velocity=_saved_velocity;angular_velocity=_saved_spin
func _on_contact(_body:Node)->void:
	if finished or stuck:return
	if kind=="smaw":detonate()
	elif kind=="zone":
		stuck=true;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO;set_deferred("freeze",true);set_deferred("collision_layer",0);set_deferred("collision_mask",0)
		_seat_zone_visual.call_deferred()
		_start_warning(float(tuning.get("zone_activation_delay",2.7)))
		var sound:=AudioStreamPlayer3D.new();sound.bus="SFX";sound.stream=load("res://scripts/audio_bank.gd").sample("zone_arm");sound.max_distance=35;add_child(sound);sound.play()
func advance_zone(delta:float)->void:
	var lifetime:=float(tuning.get("zone_lifetime",10.0));var tick:=float(tuning.get("zone_tick_seconds",.5))
	var target_age:=minf(lifetime,zone_age+maxf(delta,0.0))
	# Tick boundaries use their exact time, independent of frame partitioning.
	while float(zone_ticks+1)*tick<=target_age+.000001:
		zone_ticks+=1
		var at:=float(zone_ticks)*tick
		var radius:=float(tuning.get("zone_initial_radius",15.0))*maxf(0.0,1.0-at/lifetime)
		game.apply_explosive_damage(global_position,radius,float(tuning.get("zone_damage_per_tick",5.0)),false)
	zone_age=target_age
	if zone_visual!=null:zone_visual.scale=Vector3.ONE*maxf(.001,float(tuning.get("zone_initial_radius",15.0))*(1-zone_age/lifetime))
	if zone_age>=lifetime:finished=true;queue_free()
func detonate()->void:
	if finished:return
	finished=true;_stop_warning()
	var radius:=float(tuning.get("rocket_radius",4.0) if kind=="smaw" else tuning.get("frag_radius",10.0))
	var power:=float(tuning.get("rocket_damage",60.0) if kind=="smaw" else tuning.get("frag_damage",150.0))
	_spawn_effect(kind)
	game.apply_explosive_damage(global_position,radius,power,true)
	queue_free()

func _activate_zone()->void:
	_stop_warning();zone_active=true;zone_visual.show();zone_visual.scale=Vector3.ONE*float(tuning.get("zone_initial_radius",15.0));_spawn_effect("zone")
func _start_warning(duration:float)->void:
	_warning_duration=duration;_warning_times=GrenadeWarning.beat_times(duration);_warning_next=0
func _advance_warning(clock:float)->void:
	var due:=false
	while _warning_next<_warning_times.size() and float(_warning_times[_warning_next])<=clock+.000001:
		var at:=float(_warning_times[_warning_next]);_warning_next+=1
		warning_beep.emit(kind,at,maxf(0.0,_warning_duration-at));due=true
	# On a stalled frame, do not pile missed sounds on top of one another or
	# play a late warning over the explosion. The event times stay deterministic.
	if due and clock<_warning_duration and warning_sound!=null:warning_sound.play()
func _stop_warning()->void:
	_warning_times.clear();_warning_next=0
	if warning_sound!=null:warning_sound.stop()
func _spawn_effect(effect_kind:String)->void:
	var effect=load("res://scripts/explosive_effect.gd").new();get_parent().add_child(effect);effect.global_position=global_position;effect.setup(effect_kind)
