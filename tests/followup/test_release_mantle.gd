extends SceneTree
var failures:=0
var passes:=0
var scene:Node3D
var body:CharacterBody3D
var shape:CollisionShape3D
var helper=load("res://scripts/release_mantle.gd")
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	if ok: passes+=1; print("PASS ",label)
	else: failures+=1; printerr("FAIL ",label)
func box(center:Vector3,size:Vector3):
	var wall:=StaticBody3D.new()
	wall.collision_layer=1
	var collision:=CollisionShape3D.new()
	var mesh:=BoxShape3D.new()
	mesh.size=size
	collision.shape=mesh
	wall.add_child(collision)
	scene.add_child(wall)
	wall.position=center
	return wall
func reset_case(top:float,width:float=3.0):
	if scene!=null:
		scene.queue_free()
		await physics_frame
	scene=Node3D.new()
	root.add_child(scene)
	body=CharacterBody3D.new()
	body.collision_layer=2
	body.collision_mask=5
	shape=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.25
	capsule.height=1.65
	shape.shape=capsule
	shape.position.y=.825
	body.add_child(shape)
	scene.add_child(body)
	body.position=Vector3(0,0,.34)
	box(Vector3(0,top*.5,-1),Vector3(width,top,2))
	await physics_frame
	await physics_frame
func plan(top:float,head_y:float=1.75)->Dictionary:
	return helper.plan(body,shape,Vector3(0,head_y,-.08),Vector3(0,top,0),Vector3.FORWARD)
func run():
	await reset_case(.5)
	check(not plan(.5,1.7).is_empty(),"low ledge release route")
	box(Vector3(0,-.1,0),Vector3(5,.2,5))
	await physics_frame
	check(not plan(.5,1.7).is_empty(),"low ledge remains valid with feet resting on floor")
	await reset_case(1.4)
	var valid:=plan(1.4)
	check(not valid.is_empty(),"head over high ledge while feet below")
	check(plan(1.4,1.45).is_empty(),"head below clearance threshold rejects")
	await reset_case(1.8)
	check(plan(1.8,2.1).is_empty(),"excessive lift rejects")
	await reset_case(1.4,.3)
	check(plan(1.4).is_empty(),"narrow rail cannot support standing footprint")
	await reset_case(1.4)
	box(Vector3(0,2.9,-.1),Vector3(3,.2,3))
	await physics_frame
	check(plan(1.4).is_empty(),"blocked ceiling rejects before movement")
	await reset_case(1.4)
	box(Vector3(0,2,-.65),Vector3(.5,1,.4))
	await physics_frame
	check(plan(1.4).is_empty(),"occupied destination rejects")
	await reset_case(1.4)
	body.position.x=1.4
	await physics_frame
	check(helper.plan(body,shape,Vector3(1.4,1.75,-.08),Vector3(1.4,1.4,0),Vector3.FORWARD).is_empty(),"platform corner unsupported footprint rejects")
	await reset_case(1.4)
	check(helper.plan(body,shape,Vector3(0,1.75,-.08),Vector3(8,1.4,0),Vector3.FORWARD).is_empty(),"remote contact rejects")
	check(helper.plan(body,shape,Vector3(0,1.75,-.08),Vector3(0,1.4,0),Vector3.ZERO).is_empty(),"invalid direction rejects")
	valid=plan(1.4)
	if valid.is_empty():
		check(false,"high ledge route remains available before capsule sweep")
		quit(failures)
		return
	var collided:=false
	for target in [valid.raised,valid.target]:
		for i in range(160):
			var motion:Vector3=(target-body.global_position).limit_length(.03)
			if body.move_and_collide(motion)!=null: collided=true; break
			if body.global_position.distance_to(target)<.001: break
	check(not collided and body.global_position.distance_to(valid.target)<.005,"full two-stage capsule sweep reaches high ledge")
	await reset_case(1.4)
	valid=plan(1.4)
	box(Vector3(0,2.05,.34),Vector3(1,.1,1))
	await physics_frame
	var stopped:=false
	for i in range(160):
		var motion:Vector3=(valid.raised-body.global_position).limit_length(.03)
		if body.move_and_collide(motion)!=null: stopped=true; break
	check(stopped and body.global_position.y<.4 and not shape.disabled,"new obstacle aborts swept motion without disabling collider")
	scene.queue_free()
	await process_frame
	print("RELEASE_MANTLE_RESULT passes=",passes," failures=",failures)
	quit(0 if failures==0 else 1)
