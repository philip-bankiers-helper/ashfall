extends SceneTree
var failures:=0
var passes:=0
var scene:Node3D
var player
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	if ok: passes+=1; print("PASS ",label)
	else: failures+=1; printerr("FAIL ",label)
func box(center:Vector3,size:Vector3):
	var wall:=StaticBody3D.new()
	wall.collision_layer=1
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	wall.add_child(collision)
	scene.add_child(wall)
	wall.position=center
func reset_case(blocked:bool=false):
	if scene!=null:
		scene.queue_free()
		await physics_frame
	scene=Node3D.new()
	root.add_child(scene)
	player=load("res://scripts/player.gd").new()
	scene.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	player.set_process(false)
	player.position=Vector3(0,0,.34)
	player.desktop_camera.position=Vector3(0,1.75,-.42)
	player.fling_power=5.0
	player._release_velocity=Vector3(2,4,0)
	box(Vector3(0,.7,-1),Vector3(3,1.4,2))
	if blocked: box(Vector3(0,2.9,0),Vector3(3,.2,3))
	await physics_frame
	await physics_frame
func run():
	for dominant in ["left","right"]:
		for hand_left in [true,false]:
			for two_hands in [false,true]:
				await reset_case()
				player.dominant_hand=dominant
				var hand:Node3D=player.left_hand if hand_left else player.right_hand
				var other:Node3D=player.right_hand if hand_left else player.left_hand
				player._grabs[hand]=Vector3(0,1.4,0)
				if two_hands:
					player._grabs[other]=Vector3(0,1.4,0)
					player._update_grab(other,false,true)
					check(not player.mantling and player._grabs.size()==1,"first of two releases stays hanging %s %s"%[dominant,hand_left])
				player._update_grab(hand,false,true)
				check(player.mantling and player.velocity==Vector3.ZERO,"last intentional release overrides high fling %s %s %s"%[dominant,hand_left,two_hands])
				for i in range(160):
					if not player.mantling: break
					player._step_mantle(1.0/90)
				check(not player.mantling and player.global_position.y>1.4 and player.global_position.z<-.25 and not player._body_shape.disabled,"actual mantle lands standing %s %s %s"%[dominant,hand_left,two_hands])
	await reset_case()
	player._grabs[player.left_hand]=Vector3(0,1.4,0)
	player._update_grab(player.left_hand,false,false)
	check(not player.mantling and player.velocity==Vector3.ZERO,"tracking/reservation cancellation cannot mantle or launch")
	await reset_case(true)
	player._grabs[player.left_hand]=Vector3(0,1.4,0)
	var expected:Vector3=player._release_velocity.limit_length(7)*5*1.25
	player._update_grab(player.left_hand,false,true)
	check(not player.mantling and player.velocity.is_equal_approx(expected),"invalid mantle retains configured release fling")
	await reset_case()
	player._grabs[player.right_hand]=Vector3(0,1.4,0)
	player._update_grab(player.right_hand,false,true)
	box(Vector3(0,2.05,.34),Vector3(1,.1,1))
	await physics_frame
	for i in range(100):
		if not player.mantling: break
		player._step_mantle(1.0/90)
	check(not player.mantling and player.global_position.y<.4 and not player._body_shape.disabled,"dynamic blocker aborts production mantle safely")
	await reset_case()
	player._grabs[player.right_hand]=Vector3(0,1.4,0)
	player._update_grab(player.right_hand,false,true)
	check(player.mantling,"head-only blocker test begins with valid route")
	player.desktop_camera.position=Vector3(.65,1.75,0)
	box(Vector3(.65,2.1,.34),Vector3(.2,.2,.2))
	await physics_frame
	check(not player.test_move(player.global_transform,Vector3.UP*.5),"new head-only obstacle leaves body sweep clear")
	for i in range(100):
		if not player.mantling: break
		player._step_mantle(1.0/90)
	check(not player.mantling and player.global_position.y<.3 and not player._body_shape.disabled,"live head offset plus head-only blocker aborts assistance")
	scene.queue_free()
	await process_frame
	print("RELEASE_MANTLE_PLAYER_RESULT passes=",passes," failures=",failures," headset_verified=false")
	quit(0 if failures==0 else 1)
