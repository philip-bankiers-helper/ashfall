extends SceneTree
func _initialize():call_deferred("run")
func run():
	var scene=Node3D.new();root.add_child(scene)
	var world=load("res://scripts/world.gd").new();scene.add_child(world);world.build()
	var ext=load("res://scripts/campaign_extension.gd").new();ext.build(world)
	for p in ext.jammer_positions:
		var unit=load("res://scripts/interference_unit.gd").new();unit.position=p;scene.add_child(unit)
	var gate=load("res://scripts/spillway_gate.gd").new();gate.position=ext.gate_position;scene.add_child(gate)
	var camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=78
	var shots=[
		{"name":"crown-entry","eye":Vector3(26,26.3,-87),"at":Vector3(-8,25.8,-91)},
		{"name":"jammer","eye":Vector3(12,26.2,-87.5),"at":Vector3(16,25.8,-91)},
		{"name":"spillway-overview","eye":Vector3(72,34,-35),"at":Vector3(47,13,-64)},
		{"name":"spillway-lower-gate","eye":Vector3(47,7.6,-58),"at":Vector3(47,7.4,-48)}]
	for shot in shots:
		camera.position=shot.eye;camera.look_at(shot.at)
		for frame in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../reports/extension-"+shot.name+".png")
	print("EXTENSION_CAPTURE_COMPLETE views=",shots.size())
	scene.queue_free();await process_frame;quit()
