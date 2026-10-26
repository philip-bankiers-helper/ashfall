extends SceneTree
var passes:=0
var failures:=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	if ok: passes+=1; print("PASS ",label)
	else: failures+=1; printerr("FAIL ",label)
func run():
	var scene:=Node3D.new()
	root.add_child(scene)
	var floor:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(100,.2,100)
	collision.shape=shape
	floor.add_child(collision)
	scene.add_child(floor)
	floor.position.y=-.1
	var player=load("res://scripts/player.gd").new()
	scene.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	player.set_process(false)
	for dominant in ["left","right"]:
		player.dominant_hand=dominant
		player.reset_motion()
		player.position=Vector3(0,.01,0)
		for i in range(10):
			await physics_frame
			player.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/90)
		check(player.is_on_floor(),"ground fixture settled "+dominant)
		var speed:float=player.effective_walk_speed()
		player.apply_locomotion_motion(Vector3.FORWARD,Vector3.FORWARD,false,false,1.0/90)
		check(is_equal_approx(player.velocity.z,-speed),"walk reaches target in one step "+dominant)
		player.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/90)
		check(player.velocity.x==0 and player.velocity.z==0,"neutral stops in one step "+dominant)
		player.apply_locomotion_motion(Vector3.BACK,Vector3.FORWARD,false,false,1.0/90)
		check(is_equal_approx(player.velocity.z,speed),"reverse reaches opposite target in one step "+dominant)
		player.apply_locomotion_motion(Vector3.FORWARD,Vector3.FORWARD,false,true,1.0/90)
		check(is_equal_approx(player.velocity.z,-speed*player.sprint_slow_gain),"sprint transition immediate "+dominant)
		player.apply_locomotion_motion(Vector3.FORWARD,Vector3.FORWARD,false,false,1.0/90)
		check(is_equal_approx(player.velocity.z,-speed),"sprint release immediate "+dominant)
		player.position=Vector3(0,4,0)
		player.velocity=Vector3(12,5,0)
		player._climb_launch_pending=true
		await physics_frame
		player.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/90)
		check(player.velocity.x>11.9 and player.velocity.y>4.5,"neutral preserves fresh fling despite stale floor state "+dominant)
		player.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,true,false,1.0/90)
		check(player.gliding and player.velocity.x>11.7 and player.velocity.y>4,"glide keeps smooth airborne momentum "+dominant)
		player.position=Vector3(0,.03,0)
		player.velocity=Vector3(10,-3,0)
		for i in range(12):
			await physics_frame
			player.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/90)
			if player.is_on_floor():break
		check(player.is_on_floor() and player.velocity.x==0 and player.velocity.z==0,"landing consumes momentum on landing frame "+dominant)
	scene.queue_free()
	await process_frame
	print("INSTANT_LOCOMOTION_RESULT passes=",passes," failures=",failures," headset_verified=false")
	quit(0 if failures==0 else 1)
