extends SceneTree
const World=preload("res://scripts/world.gd")
const Extension=preload("res://scripts/campaign_extension.gd")
const Player=preload("res://scripts/player.gd")
func _initialize():call_deferred("run")
func run():
	var scene=Node3D.new();root.add_child(scene)
	var world=World.new();scene.add_child(world);world.build()
	var ext=Extension.new();ext.build(world)
	var player=Player.new();scene.add_child(player);player.setup(false);player.set_physics_process(false)
	await physics_frame;await physics_frame
	player.position=Vector3(47,24.6,-83.5);player.get_view_camera().rotation.y=PI
	player._desktop_glide=true
	var glide_frames:=0
	for frame in range(600):
		await physics_frame
		player._physics_process(1.0/60)
		if player.gliding:glide_frames+=1
		if player.is_on_floor() and frame>2:break
	var glide={"pass":player.position.y>21.8 and player.position.z>-80 and player.position.z<-59,"final":str(player.position),"gliding_frames":glide_frames}
	player.reset_motion();player.position=Vector3(27,16.05,-79.3);player.get_view_camera().rotation=Vector3.ZERO
	var cam:Camera3D=player.get_view_camera()
	var climb_frames:=0
	for frame in range(900):
		await physics_frame
		if player.mantling:player._step_mantle(1.0/60)
		else:
			player._grabs[cam]=cam.global_position
			if not player.try_start_mantle():player.apply_climb_motion(Vector3.UP*2.2/60,1.0/60)
		climb_frames+=1
		if player.position.y>24.5 and not player.mantling:break
	var climb={"pass":player.position.y>24.5,"final":str(player.position),"frames":climb_frames,"synthetic_pull":true}
	var result={"glide":glide,"climb":climb,"headset_tested":false}
	print("EXTENSION_LOCOMOTION ",result)
	var f=FileAccess.open("res://../reports/extension-locomotion.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	scene.queue_free();await process_frame;quit(0 if glide["pass"] and climb["pass"] else 1)
