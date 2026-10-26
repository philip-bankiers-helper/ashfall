extends SceneTree
class Host extends Node:
	var player
	var paused:=false
	var dead:=false
	var complete:=false
	func apply_explosive_damage(_at:Vector3,_radius:float,_amount:float,_self:bool)->void:pass
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	Engine.physics_ticks_per_second=90
	var floor:=StaticBody3D.new();floor.collision_layer=1;floor.position=Vector3(0,-.1,0)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(300,.2,300);shape.shape=box;floor.add_child(shape);root.add_child(floor)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	await physics_frame;await physics_frame
	for data in [[0,6.5],[1,7.5],[2,9.5]]:
		actor.position=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor._supported=false;actor._sprint_mode=int(data[0]);var elapsed:=0.0
		while elapsed<1.0:
			await physics_frame;actor.apply_locomotion_motion(Vector3.FORWARD,Vector3.FORWARD,false,data[0]!=0,1.0/90);elapsed+=1.0/90
		var distance:=Vector2(actor.position.x,actor.position.z).length()
		check(absf(distance/elapsed-float(data[1]))<.05,"actual ground sweep mode%d reaches%.1fm/s over1s"%[data[0],data[1]])
	actor.position=Vector3(0,30,0);actor.velocity=Vector3.ZERO;actor._supported=false;var elapsed:=0.0
	while elapsed<1.0:
		await physics_frame;actor.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,true,false,1.0/90);elapsed+=1.0/90
	var horizontal:=Vector2(actor.position.x,actor.position.z).length();var drop:float=30-actor.position.y
	check(absf(horizontal/elapsed-12.0)<.05,"actual glide sweep12m/s")
	check(absf(horizontal/drop-7.0)<.02,"actual glide trajectory7horizontal per1vertical")
	actor.position=Vector3.ZERO
	var gun=load("res://scripts/explosive_weapon.gd").new();gun.profile_id="zone";root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun.model.global_position.y=2.0
	var host:=Host.new();host.player=actor;root.add_child(host)
	var origin:=Vector3(100,gun.get_shot_transform().origin.y,0);var velocity:Vector3=gun.prepared_velocity(Vector3(0,10,-10))
	var projectile=load("res://scripts/explosive_projectile.gd").new();host.add_child(projectile);projectile.setup(host,{"kind":"zone","origin":origin,"velocity":velocity})
	for i in 300:
		await physics_frame
		if projectile.stuck:break
	var distance:=Vector2(projectile.position.x-origin.x,projectile.position.z-origin.z).length()
	check(projectile.stuck and absf(distance-48.0)<.8,"actual undamped projectile contacts flat ground within0.8m of48m target; actual="+str(distance))
	var preview:PackedVector3Array=gun.trajectory_points(origin,velocity,root.get_world_3d().direct_space_state)
	var predicted:float=Vector2(preview[-1].x-origin.x,preview[-1].z-origin.z).length()
	check(absf(predicted-distance)<.8,"production preview and actual projectile agree at contact")
	projectile.free();host.free();gun.shutdown();gun.free();actor.free();floor.free();await create_timer(.2).timeout
	print("REFERENCE_MOTION_PHYSICS_059 checks=",checks," failures=",failures," actual_world_physics=true headset_tested=false");quit(failures)
