extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var path:="res://assets/materials/build_panel_user.png"
	var piece=load("res://scripts/construction_piece.gd").new();root.add_child(piece)
	var material:=StandardMaterial3D.new();piece.apply_panel_material(material)
	check(material.albedo_texture!=null and material.albedo_texture.get_width()==768 and material.albedo_texture.get_height()==768,"actual panel material uses user crop at768square")
	check(material.texture_repeat and material.uv1_scale==Vector3(3,2,1),"full tile repeated on each BoxMesh face")
	var image:Image=material.albedo_texture.get_image();image.convert(Image.FORMAT_RGB8)
	image.clear_mipmaps()
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
	check(digest.finish().hex_encode()=="8a35e7d2645cecb95a3ecc9fb89d0d31aa6032f9fd5d4b6fb68e448b2c26c883","exact decoded crop pixels match original source RGB independent of imported encoding")
	for x0 in [0,576]:
		for y0 in [0,576]:
			var green:=0
			for x in range(x0,x0+192):
				for y in range(y0,y0+192):
					var c:=image.get_pixel(x,y)
					if c.g>.65 and c.g>c.r*1.3 and c.g>c.b*1.3:green+=1
			check(green>100,"crop retains supplied green corner light strip "+str(Vector2i(x0,y0)))
	var builder=load("res://scripts/field_builder.gd").new();root.add_child(builder)
	for kind in ["wall","floor"]:
		var mesh:Mesh=builder._geometry(kind).mesh;var arrays:=mesh.surface_get_arrays(0)
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var axis:=2 if kind=="wall" else 1
		for direction in [-1,1]:
			var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF);var count:=0
			for i in normals.size():
				if normals[i][axis]*direction>.9:
					var p:=uv[i]*Vector2(material.uv1_scale.x,material.uv1_scale.y);low=low.min(p);high=high.max(p);count+=1
			check(count>=4 and (high-low).distance_to(Vector2.ONE)<.00001,kind+" actual face UVs show complete texture on side "+str(direction))
	var repeat:=StandardMaterial3D.new();piece.apply_panel_material(repeat)
	check(repeat.albedo_texture==material.albedo_texture,"repeated panels share cached texture resource")
	var visual:=MeshInstance3D.new();visual.mesh=builder._geometry("wall").mesh;visual.material_override=material;piece.add_child(visual);piece.configure(180,visual);piece.hit(20);piece._process(.01)
	check(piece.health==160 and material.albedo_texture==repeat.albedo_texture and material.emission_enabled,"damage feedback and health keep supplied surface bound")
	builder.free();piece.free();await process_frame
	print("BUILD_TEXTURE_076 checks=",checks," failures=",failures," actual_material=true actual_uv=true xr_off=true native_rendered=false");quit(failures)
