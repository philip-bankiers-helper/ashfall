extends SceneTree
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passes+=1;print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)
func run():
	var player=load("res://scripts/player.gd").new()
	root.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	check(is_equal_approx(player.glide_speed_mps,12.0),"new flight target defaults to 12m/s")
	for dominant in ["left","right"]:
		player.dominant_hand=dominant
		for angle in [0.0,PI*.5]:
			player.rotation.y=angle
			player.reset_motion()
			var forward:Vector3=-player.global_basis.z
			var right:Vector3=player.global_basis.x
			var heading:Vector3=player.update_glide_heading(forward,player.to_global(Vector3(-.6,1.6,0)),player.to_global(Vector3(.6,1.2,0)),true,1.0)
			check(heading.dot(right)>.3 and is_zero_approx(heading.y),"lower right arm banks right without lift %s %s"%[dominant,angle])
			player.reset_motion()
			heading=player.update_glide_heading(forward,player.to_global(Vector3(-.6,1.2,0)),player.to_global(Vector3(.6,1.6,0)),true,1.0)
			check(heading.dot(right)<-.3,"lower left arm banks left %s %s"%[dominant,angle])
			player.reset_motion()
			heading=player.update_glide_heading(forward,player.to_global(Vector3(-.6,1.5,0)),player.to_global(Vector3(.6,1.47,0)),true,1.0)
			check(heading.is_equal_approx(forward),"arm noise deadzone remains straight %s %s"%[dominant,angle])
			var first:Vector3=player.update_glide_heading(forward,player.to_global(Vector3(-.6,1.6,0)),player.to_global(Vector3(.6,1.2,0)),true,1.0/90)
			check(first.dot(right)>0 and first.dot(right)<.1,"bank onset filtered %s %s"%[dominant,angle])
			heading=player.update_glide_heading(forward,Vector3.ZERO,Vector3.ZERO,false,1.0/90)
			check(heading.is_equal_approx(forward) and player._glide_bank==0,"tracking loss immediately clears bank %s %s"%[dominant,angle])
	player.queue_free()
	await process_frame
	print("GLIDE_BANK_RESULT passes=",passes," failures=",failures," headset_verified=false")
	quit(0 if failures==0 else 1)
