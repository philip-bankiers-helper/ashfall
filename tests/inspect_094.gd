extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var actor:Node3D=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack:Node3D=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var matador:Node3D=rack.weapons[12].guns[0];var body:MeshInstance3D=matador.model.find_child("Body",true,false)
	print("MATADOR_BOUNDS ",body.mesh.get_aabb()," global ",body.global_transform," muzzle ",matador.get_shot_transform())
	var points:Array=[]
	for v in body.mesh.get_faces():
		if v.z<body.mesh.get_aabb().position.z+.01:points.append(v)
	if points.size()>24:points.resize(24)
	print("MATADOR_FRONT ",points)
	var magnum:Node3D=rack.weapons[7];var receiver:MeshInstance3D=magnum.model.find_child("DownloadedMagnumBody081",true,false)
	for i in receiver.mesh.get_surface_count():
		var mat:Material=receiver.mesh.surface_get_material(i)
		print("MAGNUM_MATERIAL ",i," ",mat)
		if mat is StandardMaterial3D:print("MAGNUM_PBR ",mat.albedo_color," ",mat.albedo_texture," metallic=",mat.metallic," roughness=",mat.roughness)
	var props:PackedStringArray=[]
	for prop in Label3D.new().get_property_list():props.append(prop.name)
	print("LABEL_FLAGS ",props)
	rack.queue_free();actor.queue_free();await process_frame;await process_frame;quit()
