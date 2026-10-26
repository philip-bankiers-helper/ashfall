extends SceneTree
var city: Node3D
var camera: Camera3D
var output: String
func _initialize() -> void: call_deferred("run")
func shot(title: String, eye: Vector3, target: Vector3, fov := 72.0) -> void:
	camera.position = eye
	camera.look_at(target)
	camera.fov = fov
	city.update_lighting(eye)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+title+".png")
	print("CAPTURE ",title)
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	city = load("res://scripts/cyber_bird.gd").new()
	root.add_child(city)
	city.build()
	root.world_3d.environment = city._environment
	root.use_occlusion_culling = true
	camera = Camera3D.new()
	camera.far = 1600
	camera.near = .08
	root.add_child(camera)
	camera.current = true
	print("CITY_STATS ",JSON.stringify(city.statistics)," buildings=",city.buildings.size()," windows=",city.windows.size())
	await shot("01-OVERVIEW",Vector3(280,180,320),Vector3(-20,12,-10),74)
	await shot("02-STREET-AVIARY",Vector3(0,1.7088,55),Vector3(0,21,0),78)
	await shot("03-MARKET-STREET",Vector3(10,1.7088,180),Vector3(65,10,115),80)
	var b: Dictionary = city.buildings.filter(func(v: Dictionary): return v.id==36)[0]
	await shot("04-INTERIOR",b.center+Vector3(-2,1.7088,0),b.center+Vector3(b.stair_x,2,1),82)
	await shot("05-ROOFTOP",b.center+Vector3(-8,b.floors*4.2+1.7088,9),Vector3(-110,26,-30),80)
	await shot("06-STAIR-LANDING",b.center+Vector3(b.stair_x-3.7,6.0,-5.05),b.center+Vector3(b.stair_x-1.3,6.4,3.0),86)
	await shot("07-TERMINAL-SPAWN",Vector3(-9,1.7088,370),Vector3(-9,2.2,351),80)
	quit(0)
