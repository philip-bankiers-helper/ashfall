extends SceneTree
## Explicit XR-off native-only audit. Captures real Mobile/Vulkan mono pixels.
var actor:Node3D
var rack:Node3D
var output:=""
var rows:Array[Dictionary]=[]
var mk18_only:=false
func _initialize()->void:
	root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(2560,1600)
	output=OS.get_environment("ASHFALL_OPTICS_OUTPUT");mk18_only="--mk18-only" in OS.get_cmdline_user_args();call_deferred("run")
func stop_audio(node:Node)->void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop();node.stream=null
	for child in node.get_children():stop_audio(child)
func mesh_box(size:Vector3,at:Vector3,color:Color)->void:
	var part:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;part.mesh=box;part.position=at
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;part.material_override=material;root.add_child(part)
func capture(label:String)->void:
	for frame in 10:await process_frame
	await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image();var path:=output+"/"+label+".png"
	var code:=pixels.save_png(path)
	rows.append({"label":label,"path":path,"save_error":code,"size":str(pixels.get_size()),"camera":str(actor.get_view_camera().global_transform)})
func run()->void:
	if DisplayServer.get_name()=="headless":print("OPTICS_NATIVE_PARSE_OK no_graphics=true");quit();return
	if output.is_empty() or XRServer.primary_interface!=null:push_error("Requires isolated output and XR disabled");quit(1);return
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var camera:Camera3D=actor.get_view_camera();camera.current=true;camera.fov=80;camera.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,2,0))
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.08,.10,.14);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.8;camera.environment=environment
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-40,0);sun.light_energy=1.4;root.add_child(sun)
	mesh_box(Vector3(50,.024,.03),Vector3(0,2.45,-20),Color.CYAN)
	mesh_box(Vector3(50,.024,.03),Vector3(0,1.55,-20),Color.CYAN)
	mesh_box(Vector3(.024,10,.03),Vector3(2,2,-20),Color(.8,.7,.2))
	var marker:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.4;sphere.height=.8;sphere.radial_segments=64;sphere.rings=32;marker.mesh=sphere;marker.position=Vector3(0,2,-20)
	var magenta:=StandardMaterial3D.new();magenta.albedo_color=Color.MAGENTA;magenta.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;marker.material_override=magenta;root.add_child(marker)
	rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false);gun.hide()
	var awp:Node3D=rack.weapons[5];awp.show();camera.cull_mask=1|(1<<19)
	awp.global_transform=Transform3D(Basis(Vector3.RIGHT,deg_to_rad(awp.SIGHT_DROP_DEGREES)),Vector3.ZERO);awp.global_position+=camera.global_position-awp.get_shot_transform().origin
	for power in [1.0,4.0,8.0]:
		if mk18_only:break
		for roll in [0.0,30.0,60.0]:
			camera.global_basis=Basis(Vector3.FORWARD,deg_to_rad(roll))
			awp.optic.active=power>1;awp.optic.lens.visible=power>1
			if power>1:
				awp.optic.zoom_magnification=power;awp.optic._commit_displayed_frame();awp.optic.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;awp.optic.right_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			await capture("awp-power%s-roll%s"%[power,roll])
	awp.shutdown();awp.hide();marker.hide()
	camera.global_basis=Basis.IDENTITY;camera.cull_mask=1|(1<<18)|(1<<19)
	for index in ([3] if mk18_only else [0,9,21,3]):
		var gun:Node3D=rack.weapons[index];gun.show();gun._process(0)
		var sight_height:float=gun.get_meta("reflex_sight").position.y if gun.has_meta("reflex_sight") else .135
		gun.global_transform=Transform3D(Basis.IDENTITY,camera.global_position+Vector3(.0,-sight_height,-.48));gun.publish_displayed_aim(gun.get_shot_transform())
		if gun.has_meta("reflex_sight"):gun.get_meta("reflex_sight").update_aim()
		await capture("sight-"+str(index));gun.hide()
	var file:=FileAccess.open(output+"/native-optics.json",FileAccess.WRITE);file.store_string(JSON.stringify({"actual_native_mono":true,"actual_xr":false,"frames":rows},"\t"));file.close()
	rack.shutdown();stop_audio(rack);stop_audio(actor);rack.free();actor.free()
	print("OPTICS_NATIVE_061 captures=",rows.size()," actual_xr=false");quit()
