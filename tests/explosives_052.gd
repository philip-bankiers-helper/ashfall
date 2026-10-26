extends SceneTree
class Game extends Node3D:
	var paused:=false
	var dead:=false
	var complete:=false
	var player:Node3D
	var calls:Array=[]
	func apply_explosive_damage(point:Vector3,radius:float,power:float,falloff:bool)->void:calls.append({"point":point,"radius":radius,"power":power,"falloff":falloff})
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var game:=Game.new();root.add_child(game);game.player=Node3D.new();game.add_child(game.player)
	var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5,5,.08);shape.shape=box;wall.add_child(shape);root.add_child(wall);wall.position=Vector3(0,0,-4)
	await physics_frame
	var rocket=load("res://scripts/explosive_projectile.gd").new();game.add_child(rocket);rocket.setup(game,{"kind":"smaw","origin":Vector3.ZERO,"velocity":Vector3.FORWARD*200})
	for i in 20:await physics_frame
	check(not game.calls.is_empty(),"200m/s rocket hits actual8cm wall with CCD")
	if not game.calls.is_empty():check(absf(game.calls[0].point.z+4)<.6,"fast rocket impact stays at wall")
	wall.free();await physics_frame
	var zone=load("res://scripts/explosive_projectile.gd").new();game.add_child(zone);zone.setup(game,{"kind":"zone","origin":Vector3(0,1,0),"velocity":Vector3.ZERO});zone.set_physics_process(false);zone._on_contact(game)
	zone._physics_process(2.69);check(not zone.zone_active and zone.zone_age==0,"zone contact arms delay, not immediate active field")
	zone._physics_process(.02);check(zone.zone_active and absf(zone.zone_age-.01)<.001,"zone activates after2.7s; only overrun advances field")
	var before:float=zone.zone_age;game.paused=true;zone._physics_process(.5);check(zone.zone_age==before,"zone fuse/field respects pause");game.paused=false
	var payload=load("res://scripts/explosive_weapon.gd").new();game.add_child(payload);payload.set_process(false)
	# Arc computation uses identical gravity and velocity, stopped by actual collision.
	wall=StaticBody3D.new();wall.collision_layer=1;shape=CollisionShape3D.new();box=BoxShape3D.new();box.size=Vector3(20,20,.08);shape.shape=box;wall.add_child(shape);root.add_child(wall);wall.position=Vector3(0,0,-5);await physics_frame
	payload.player=game.player;var points:PackedVector3Array=payload.trajectory_points(Vector3(0,2,0),Vector3(0,3,-20),game.get_world_3d().direct_space_state)
	check(points.size()>2 and points[-1].z> -5.1,"large arc is collision-clipped at real wall")
	check(absf(points[1].y-(2+3*.06-.5*9.8*.06*.06))<.001,"arc matches projectile ballistic equation")
	payload.free();wall.free();game.free();await create_timer(.15).timeout # Allow AudioServer deferred releases before shutdown.
	print("EXPLOSIVES_052 checks=",checks," failures=",failures," actual_physics=true sounds_auditioned=false")
	quit(failures)
