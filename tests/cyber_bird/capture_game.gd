extends SceneTree
var game: Node3D
var city: Node3D
var output: String
func _initialize(): call_deferred("run")
func freeze(node: Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func capture(title: String):
	for frame in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+title+".png")
	print("CAPTURE ",title)
func frame_city(eye: Vector3, target: Vector3):
	var camera: Camera3D=game.player.get_view_camera()
	camera.global_position=city.global_position+eye
	camera.look_at(city.global_position+target)
	city.update_lighting(camera.global_position)
func run():
	output=OS.get_cmdline_user_args()[0]
	game=load("res://scripts/main.gd").new();root.add_child(game)
	freeze(game)
	game.front_menu.activate(4)
	await capture("08-MAP-SELECTOR")
	game.front_menu.activate(13)
	await capture("09-CYBER-BIRD-READY")
	game.front_menu.activate(0)
	city=game.active_sandbox_map
	for frame in 6:await physics_frame
	freeze(game)
	game.weapon.hide()
	frame_city(Vector3(-9,1.7088,370),Vector3(-9,2.0,351))
	await capture("10-READY-ENTRY")
	# Native scene and actual inventory drop. No mock models or added presentation lighting.
	game.combat_hud.hide();game.ui_layer.hide();game.vr_label.hide();game.vr_cue.hide()
	frame_city(Vector3(-13,1.7088,374),Vector3(-12,.8,368))
	await capture("11-REAL-LOOT-AT-TERMINAL")
	var b: Dictionary=city.buildings.filter(func(v):return v.id==36)[0]
	frame_city(b.center+Vector3(2.5,1.7088,float(b.depth)*.5-2),b.center+Vector3(-6,1.5,float(b.depth)*.25-4))
	await capture("12-PLAYABLE-INTERIOR")
	for spec in [[28,"13-MARKET-INTERIOR"],[35,"14-FOUNDRY-INTERIOR"],[3,"15-HERON-INTERIOR"]]:
		var room: Dictionary=city.buildings.filter(func(v: Dictionary):return v.id==spec[0])[0]
		frame_city(room.center+Vector3(2.5,1.7088,float(room.depth)*.5-2),room.center+Vector3(-6,1.5,float(room.depth)*.25-4))
		await capture(spec[1])
	frame_city(Vector3(42,35,74),Vector3(0,18,0))
	await capture("16-AVIARY-OVERLOOK")
	# Warm caches/shaders first, then report desktop frame timings at fixed native views.
	var rows:Array=[]
	for view in [["street",Vector3(0,1.7088,71),Vector3(0,21,0)],["roof",Vector3(30,42,60),Vector3(-50,28,0)],["overview",Vector3(180,110,220),Vector3(-10,10,-10)]]:
		frame_city(view[1],view[2])
		for warm in 35:await process_frame
		var samples:Array[float]=[]
		var draws:Array[int]=[]
		for frame in 150:
			var start:=Time.get_ticks_usec();await process_frame
			samples.append(float(Time.get_ticks_usec()-start)/1000)
			draws.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		samples.sort();draws.sort()
		rows.append({"view":view[0],"desktop_frame_ms_p50":samples[75],"desktop_frame_ms_p95":samples[142],"draw_calls_p50":draws[75],"triangles":RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)})
	var f:=FileAccess.open(output+"/NATIVE-DESKTOP-PERFORMANCE.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"xr_mode":"off","renderer":"Vulkan Mobile","resolution":"1600x1000","scene_processing":"frozen for repeatable render measurements","stereo_or_headset_performance":false,"samples":rows},"\t"));f.close()
	print("NATIVE_PERFORMANCE ",JSON.stringify(rows))
	quit()
