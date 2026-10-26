extends SceneTree
const Ballistics=preload("res://scripts/grenade_ballistics.gd")
class Host extends Node:
	var player
	var paused:=false
	var dead:=false
	var complete:=false
	var detonations:Array[Vector3]=[]
	func apply_explosive_damage(at:Vector3,_radius:float,_amount:float,instant:bool)->void:
		if instant:detonations.append(at)
var checks:=0
var failures:=0
var records:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	Engine.physics_ticks_per_second=90
	var gravity:=9.8
	for pitch in [-80.0,-30.0,.0,25.0,80.0,90.0]:
		var aim:=Vector3.FORWARD.rotated(Vector3.RIGHT,deg_to_rad(pitch))
		var output:=Ballistics.launch_velocity(aim,2.0,gravity)
		check(output.is_finite() and absf(rad_to_deg(aim.angle_to(output))-45.0)<.001,"launch vector exactly 45 degrees from held aim at pitch "+str(pitch))
	var reference:=Ballistics.launch_velocity(Vector3.FORWARD,2.0,gravity)
	check(reference.y>0 and absf(reference.x)<.00001 and absf(reference.y+reference.z)<.0001,"horizontal held aim launches upward-forward at 45 degrees")
	var flight:=(reference.y+sqrt(reference.y*reference.y+2*gravity*(2.0-Ballistics.COLLISION_RADIUS)))/gravity
	check(absf(-reference.z*flight-48.0)<.0001 and flight<3.5,"analytic launch reaches 48 m ground contact before original 3.5 s fuse")
	check(Ballistics.launch_velocity(Vector3(NAN,0,0),2,gravity)==Vector3.ZERO and Ballistics.launch_velocity(Vector3.FORWARD,2,0)==Vector3.ZERO,"invalid aim/gravity cannot produce a nonfinite launch")
	var within_range:=true
	for i in range(-89,90):
		var output:=Ballistics.launch_velocity(Vector3.FORWARD.rotated(Vector3.RIGHT,deg_to_rad(i)),2,gravity)
		var end_time:=(output.y+sqrt(output.y*output.y+2*gravity*(2.0-Ballistics.COLLISION_RADIUS)))/gravity
		within_range=within_range and Vector2(output.x,output.z).length()*end_time<=48.001
	check(within_range,"all tested aim elevations respect 48 m flat foot-plane maximum")
	var floor:=StaticBody3D.new();floor.collision_layer=1;floor.position=Vector3(0,-.1,0)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(400,.2,400);shape.shape=box;floor.add_child(shape);root.add_child(floor)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var host:=Host.new();host.player=actor;root.add_child(host)
	await physics_frame;await physics_frame
	for kind in ["frag","zone"]:
		for height in [1.2,2.0]:
			var gun=load("res://scripts/explosive_weapon.gd").new();gun.profile_id=kind;root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			gun.model.global_transform=Transform3D(Basis.IDENTITY,Vector3(40,height-.045,0))
			var origin:Vector3=gun.get_shot_transform().origin
			var velocity:Vector3=gun.prepared_velocity(Vector3.ZERO)
			check(velocity.distance_to(gun.prepared_velocity(Vector3(14,-8,3)))<.0001,kind+" press throw remains aimed and fixed strength regardless of wrist velocity")
			var preview:PackedVector3Array=gun.trajectory_points(origin,velocity,root.get_world_3d().direct_space_state)
			var expected:float=Vector2(preview[-1].x-origin.x,preview[-1].z-origin.z).length()
			var projectile=load("res://scripts/explosive_projectile.gd").new();host.add_child(projectile);projectile.setup(host,{"kind":kind,"origin":origin,"velocity":velocity})
			var contacts:Array=[];projectile.body_entered.connect(func(_body):contacts.append(projectile.global_position))
			for i in 360:
				await physics_frame
				if not contacts.is_empty():break
			var contact:Vector3=contacts[0] if not contacts.is_empty() else projectile.global_position
			var distance:=Vector2(contact.x-origin.x,contact.z-origin.z).length()
			var elapsed:float=projectile.age
			check(not contacts.is_empty() and absf(distance-48.0)<.35,kind+" actual undamped RigidBody ground contact reaches 48 m within 0.35 m; hand "+str(height)+"; actual "+str(distance))
			check(absf(expected-distance)<.35,kind+" production preview and actual collision agree within 0.35 m")
			if kind=="frag":check(not projectile.finished and elapsed<float(projectile.tuning.frag_fuse_seconds),"actual frag lands before its fuse, hand "+str(height))
			else:check(projectile.stuck and projectile.activation_age<.04 and not projectile.zone_active,"zone impact starts its separate activation countdown")
			var record:Dictionary={"kind":kind,"hand_height_m":height,"velocity":str(velocity),"initial_elevation_degrees":rad_to_deg(Vector3.FORWARD.angle_to(velocity)),"first_contact_range_m":distance,"preview_contact_range_m":expected,"contact_age_seconds":elapsed,"frag_fuse_seconds":projectile.tuning.frag_fuse_seconds}
			if kind=="frag":
				var before:=host.detonations.size()
				for i in 90:
					await physics_frame
					if host.detonations.size()>before:break
				check(host.detonations.size()==before+1,"actual landed frag detonates once at original 3.5 s fuse")
				if host.detonations.size()>before:record["detonation_range_m"]=Vector2(host.detonations[-1].x-origin.x,host.detonations[-1].z-origin.z).length()
			else:projectile.free()
			records.append(record)
			gun.shutdown();gun.free();await physics_frame
	var file:=FileAccess.open("user://grenade-ballistics-061.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("BALLISTICS_RECORDS=",JSON.stringify(records))
	print("BALLISTICS_RECORD_PATH=",ProjectSettings.globalize_path("user://grenade-ballistics-061.json"))
	host.free();actor.free();floor.free();await create_timer(.1).timeout
	print("GRENADE_BALLISTICS_061 checks=",checks," failures=",failures," actual_rigid_body_contacts=true xr_mode=off native_rendered=false headset_tested=false")
	quit(failures)
