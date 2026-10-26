extends SceneTree
## Native comparison only. Do not run concurrently with other GPU validation.
## --path AshfallVR --script res://tests/enemy_telegraph_visual.gd -- --output=<absolute-dir>
const Enemy = preload("res://scripts/enemy.gd")
var output := ""
func _initialize(): call_deferred("run")
func run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty():
		push_error("Explicit workspace output directory required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.13, 0.19, 0.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.near = 0.045
	camera.fov = 80
	scene.add_child(camera)
	camera.current = true
	var target := Node3D.new()
	target.position = camera.position - Vector3.UP * 1.35
	scene.add_child(target)
	var units: Array[AshEnemy] = []
	var materials: Array[Material] = []
	var aims := [Vector3(-0.1, 1.58, 0.1), Vector3(0.08, 1.61, 0.1), Vector3(0, 1.5, 0.05)]
	for i in range(3):
		var unit := Enemy.new()
		unit.position = Vector3((i - 1) * 2.2, 0 if i != 1 else 2.0, -5 if i != 1 else -8)
		unit.setup(target, 3 if i == 1 else 0)
		scene.add_child(unit)
		unit.set_physics_process(false)
		unit.set_guard_heading(camera.position - unit.position)
		unit.locked_aim = aims[i]
		unit._change_state(Enemy.State.WINDUP)
		materials.append(unit._beam.material_override)
		units.append(unit)
	for phase in ["before", "after"]:
		for i in range(units.size()):
			var unit := units[i]
			var origin := unit.position + Vector3.UP * 1.4
			var mesh: CylinderMesh = unit._beam.mesh
			if phase == "before":
				mesh.top_radius = 0.009
				mesh.bottom_radius = 0.009
				mesh.cap_top = true
				mesh.cap_bottom = true
				mesh.radial_segments = 4
				unit._beam.material_override = unit._mat(Color(1, 0.14, 0.04), 0, 2)
				var delta: Vector3 = aims[i] - origin
				unit._beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())).scaled_local(Vector3(1, delta.length(), 1)), (origin + aims[i]) * 0.5)
				unit._beam.visible = true
			else:
				mesh.top_radius = 0.004
				mesh.bottom_radius = 0.004
				mesh.cap_top = false
				mesh.cap_bottom = false
				mesh.radial_segments = 6
				unit._beam.material_override = materials[i]
				unit._draw_beam(origin, aims[i])
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(output.path_join("telegraph-" + phase + ".png"))
		print("TELEGRAPH_CAPTURE phase=", phase, " error=", error)
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	quit()
