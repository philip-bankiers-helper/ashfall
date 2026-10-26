extends SceneTree

class MinimalMain extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _feedback(_message: String, _duration: float = 2.4): pass
	func _play_sound(_kind): pass

class ObservedMarks extends "res://scripts/impact_marks.gd":
	var hits: Array[Dictionary] = []
	func add_hit(point: Vector3, normal: Vector3, collider: Object, pellet: bool = false) -> bool:
		hits.append({"point":point,"normal":normal,"collider":collider,"pellet":pellet})
		return super.add_hit(point,normal,collider,pellet)

class DamageTarget extends StaticBody3D:
	var damage := 0.0
	var calls := 0
	var notifications := 0
	func take_damage(value: float):
		damage += value
		calls += 1
	func notify_gunshot(_origin: Vector3): notifications += 1

var passes := 0
var failures := 0
func check(value: bool, label: String):
	if value: passes += 1
	else: failures += 1
	print("PASS " if value else "FAIL ",label)
func _initialize(): call_deferred("run")
func shape(body: StaticBody3D):
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,4,0.5)
	collision.shape = box
	body.add_child(collision)
func run():
	var main := MinimalMain.new()
	root.add_child(main)
	main.player = CharacterBody3D.new()
	main.player.collision_layer = 0
	main.add_child(main.player)
	main.encounter_active = true
	var marks := ObservedMarks.new()
	main.add_child(marks)
	marks.set_process(false)
	main.impact_marks = marks
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	shape(wall)
	main.add_child(wall)
	wall.position = Vector3(0,0,-5)
	await physics_frame
	await physics_frame
	main._on_shot(Vector3.ZERO,Vector3.FORWARD,32.0)
	check(marks.hits.size()==1 and marks.accepted==1,"actual rifle ray creates one accepted static mark")
	check(marks.hits[0].point.distance_to(Vector3(0,0,-4.75))<0.001,"rifle mark receives actual front-face intersection")
	check(marks.hits[0].normal.is_equal_approx(Vector3.BACK) and marks.hits[0].collider==wall and not marks.hits[0].pellet,"rifle forwards hit normal, collider and non-pellet mode")
	check(marks.marks[0].global_position.distance_to(Vector3(0,0,-4.748))<0.001,"visible rifle mark sits 2 mm off actual surface")
	var rays: Array[Vector3] = [Vector3(-0.1,0,-1).normalized(),Vector3(0.1,0,-1).normalized()]
	main._on_pellet_shot(Vector3.ZERO,rays,10.0)
	check(marks.hits.size()==3 and marks.accepted==3,"two actual pellet intersections create two static marks")
	for i in range(2):
		var hit: Dictionary = marks.hits[i+1]
		check(hit.pellet and hit.collider==wall and hit.point.distance_to(rays[i]*(4.75/-rays[i].z))<0.001,"pellet %d forwards exact ray intersection and mode"%i)
	main._on_shot(Vector3.ZERO,Vector3.UP,32.0)
	main._on_pellet_shot(Vector3.ZERO,[Vector3.UP],10.0)
	check(marks.hits.size()==3,"rifle and pellet sky misses do not request marks")
	var target := DamageTarget.new()
	target.collision_layer = 4
	shape(target)
	main.add_child(target)
	target.position = Vector3(0,0,-2)
	main.enemies = [target]
	await physics_frame
	await physics_frame
	main._on_shot(Vector3.ZERO,Vector3.FORWARD,32.0)
	check(target.calls==1 and is_equal_approx(target.damage,32),"rifle damage preserved through impact integration")
	check(marks.accepted==3 and marks.rejected==1 and marks.hits[-1].collider==target,"damageable target rejects persistent marks instead of marking wall behind it")
	var same_rays: Array[Vector3] = []
	for i in range(8): same_rays.append(Vector3.FORWARD)
	main._on_pellet_shot(Vector3.ZERO,same_rays,10.0)
	check(target.calls==2 and is_equal_approx(target.damage,112),"eight pellets preserve one grouped 80 damage call")
	check(marks.accepted==3 and marks.rejected==9,"all enemy pellets reject persistent world marks")
	check(target.notifications==2,"enemy receives one notification per rifle or pellet discharge")
	main.paused = true
	var count := marks.hits.size()
	main._on_shot(Vector3.ZERO,Vector3.FORWARD,32.0)
	main._on_pellet_shot(Vector3.ZERO,same_rays,10.0)
	check(marks.hits.size()==count and target.calls==2,"paused shot handlers create neither hits nor damage")
	main.free()
	await process_frame
	print("IMPACT_INTEGRATION_RESULT passes=",passes," failures=",failures," actual_physics_rays=true headset_tested=false")
	quit(0 if failures==0 else 1)
