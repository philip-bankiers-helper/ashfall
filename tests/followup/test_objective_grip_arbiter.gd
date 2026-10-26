extends SceneTree
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passes+=1;print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)
func samples(left:Node3D,right:Node3D,grip:float,ready:bool=true,blocked:bool=false)->Array:
	return [{"hand":left,"position":left.global_position,"grip":grip,"ready":ready,"blocked":blocked},{"hand":right,"position":right.global_position,"grip":grip,"ready":ready,"blocked":blocked}]
func run():
	var scene:=Node3D.new()
	root.add_child(scene)
	var left:=Node3D.new()
	var right:=Node3D.new()
	scene.add_child(left)
	scene.add_child(right)
	left.position=Vector3(-.15,1,0)
	right.position=Vector3(.25,1,0)
	var arbiter=load("res://scripts/objective_grip_arbiter.gd").new()
	var space:=scene.get_world_3d().direct_space_state
	var targets:Array=[{"id":"relay","position":Vector3(0,1,0)}]
	check(arbiter.step(samples(left,right,1),targets,space,[]).is_empty(),"initial held grip never activates")
	arbiter.step(samples(left,right,0),targets,space,[])
	var event:Dictionary=arbiter.step(samples(left,right,1),targets,space,[])
	check(event.get("hand")==left and event.get("id")=="relay","simultaneous grips select closest target hand once")
	check(arbiter.is_reserved(left) and arbiter.is_reserved(right),"both consumed eligible presses block other gestures")
	targets[0].id="next_relay"
	check(arbiter.step(samples(left,right,1),targets,space,[]).is_empty(),"held grip cannot activate next objective")
	arbiter.reset(true)
	check(arbiter.is_reserved(left) and arbiter.step(samples(left,right,1),targets,space,[]).is_empty(),"chapter reset preserves consumption until release")
	arbiter.step(samples(left,right,0),targets,space,[])
	check(not arbiter.is_reserved(left) and not arbiter.is_reserved(right),"release clears hand reservations")
	arbiter.step(samples(left,right,1,false),targets,space,[])
	check(arbiter.step(samples(left,right,1,true),targets,space,[]).is_empty(),"tracking recovery while held cannot activate")
	arbiter.step(samples(left,right,0),targets,space,[])
	check(not arbiter.step(samples(left,right,1),targets,space,[]).is_empty(),"neutral rearms a fresh interaction")
	arbiter.reset()
	arbiter.step(samples(left,right,0),targets,space,[])
	check(arbiter.step(samples(left,right,1,true,true),targets,space,[]).is_empty(),"existing climbing grips cannot also activate")
	left.position.x=-.5
	right.position.x=.5
	arbiter.step(samples(left,right,0),targets,space,[])
	check(arbiter.step(samples(left,right,1),targets,space,[]).is_empty(),"out of reach target cannot activate")
	left.position.x=-.15
	right.position.x=-.25
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.02,2,2)
	collision.shape=box
	wall.add_child(collision)
	scene.add_child(wall)
	wall.position=Vector3(-.075,1,0)
	await physics_frame
	await physics_frame
	arbiter.step(samples(left,right,0),targets,space,[])
	check(arbiter.step(samples(left,right,1),targets,space,[]).is_empty(),"wall blocks nearby target interaction")
	wall.queue_free()
	await physics_frame
	var player=load("res://scripts/player.gd").new()
	scene.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	player._objective_grip_arbiter=arbiter
	arbiter.step(samples(player.left_hand,player.right_hand,0),[],space,[])
	var hand_target:Array=[{"id":"relay","position":player.left_hand.global_position}]
	arbiter.step(samples(player.left_hand,player.right_hand,1),hand_target,space,[])
	player._update_grab(player.left_hand,true)
	check(player.is_hand_grip_reserved(player.left_hand) and not player._grabs.has(player.left_hand),"production climb cannot consume objective grip")
	player.reset_motion()
	check(player.is_hand_grip_reserved(player.left_hand),"production reset retains consumed grip")
	scene.queue_free()
	await process_frame
	print("OBJECTIVE_GRIP_RESULT passes=",passes," failures=",failures)
	quit(0 if failures==0 else 1)
