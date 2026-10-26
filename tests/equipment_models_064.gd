extends "res://tests/equipment_models_062.gd"
## CPU actual-mesh checks. No renderer/native window, XR or controller input.

func ray_depth(prop:Node3D,origin:Vector3)->float:
	var nearest:=INF
	for part in prop.find_children("*","MeshInstance3D",true,false):
		if not part.is_visible_in_tree():continue
		var transform:Transform3D=prop.global_transform.affine_inverse()*part.global_transform
		var faces:PackedVector3Array=part.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var hit:Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,transform*faces[i],transform*faces[i+1],transform*faces[i+2])
			if hit is Vector3:nearest=minf(nearest,origin.distance_to(hit))
	return nearest

func triangle_count(prop:Node3D)->int:
	var count:=0
	for part in prop.find_children("*","MeshInstance3D",true,false):count+=part.mesh.get_faces().size()/3
	return count

func check_batch_coverage(scene:Node3D)->void:
	# Instrument this same factory in memory with baking disabled. Every triangle
	# authored by the real generators must survive production material batching.
	# No instrumented file is saved or used for gameplay/render acceptance.
	# Release PCKs contain compiled GDScript, so FileAccess cannot retrieve the
	# source there. This external QA snapshot is byte-bound to the production
	# factory by the source/package manifest. The baked side remains the REAL
	# Models factory loaded from source or the exported production PCK.
	var text:=FileAccess.get_file_as_string("res://tests/fixtures/field_item_models_source064.txt")
	var expected:="43B783AAB144117D69359D26FC15AD66847A6FAB1803B03ABAD59CDF7073607D"
	check(text.sha256_text().to_upper()==expected,"unbatched source snapshot matches bound production factory hash")
	var production_script:GDScript=load("res://scripts/field_item_models.gd")
	var available:String=production_script.source_code
	check(available.is_empty() or available==text,"available production source matches snapshot; compiled PCK may omit source text")
	if text.sha256_text().to_upper()!=expected:return
	var start:=text.find("static func _bake_static(");var finish:=text.find("static func _collect_meshes(")
	var raw:=GDScript.new();raw.source_code=text.substr(0,start)+"static func _bake_static(_container:Node3D)->void:\n\tpass\n\n"+text.substr(finish)
	var compiled:=raw.reload()==OK
	check(compiled,"unbatched geometry instrumentation compiles")
	if not compiled:return
	for kind in ["soda","shaker","banana","backpack","ammo0","ammo1","ammo2"]:
		var authored:Node3D;var baked:Node3D
		if kind.begins_with("ammo"):
			authored=Node3D.new();baked=Node3D.new();raw.ammo_supply(authored,kind.right(1).to_int());Models.ammo_supply(baked,kind.right(1).to_int())
		else:
			authored=raw.consumable(kind,Supplies.TITLES);baked=Supplies.make_prop(kind)
		scene.add_child(authored);scene.add_child(baked)
		if kind.begins_with("ammo"):
			var body:MeshInstance3D=authored.get_node("SupplyBody");var seam:MeshInstance3D=authored.get_node("LidSeam");var lid:MeshInstance3D=authored.get_node("Lid")
			var body_top:float=body.position.y+body.mesh.get_aabb().end.y;var seam_bottom:float=seam.position.y+seam.mesh.get_aabb().position.y
			var seam_top:float=seam.position.y+seam.mesh.get_aabb().end.y;var lid_bottom:float=lid.position.y+lid.mesh.get_aabb().position.y
			check(body_top<=seam_bottom+.0001 and seam_top<lid_bottom,kind+" body/seam/lid have no coincident vertical shell volume")
		var original:=triangle_count(authored);var final:=triangle_count(baked)
		check(original==final,"%s all authored triangles survive indexed material batching (%d/%d)"%[kind,final,original])
		var used:=true
		for part in baked.find_children("*","MeshInstance3D",true,false):
			for surface in range(part.mesh.get_surface_count()):
				var data:Array=part.mesh.surface_get_arrays(surface);var present:Dictionary={}
				if not data[Mesh.ARRAY_INDEX] is PackedInt32Array:used=false;continue
				for index in data[Mesh.ARRAY_INDEX]:present[index]=true
				used=used and present.size()==data[Mesh.ARRAY_VERTEX].size()
		check(used,kind+" every final vertex is referenced by an explicit triangle index")
		authored.free();baked.free()

func run()->void:
	var scene:=Node3D.new();root.add_child(scene)
	check_batch_coverage(scene)
	for kind in ["soda","shaker","banana","backpack"]:
		var prop:Node3D=Supplies.make_prop(kind);scene.add_child(prop)
		var evidence:=inspect(prop,kind)
		check(prop.transform==Transform3D.IDENTITY,kind+" authored origin/scale unchanged")
		check(prop.get_node("ItemTitle").position.y==.25 and prop.get_node("ItemTitle").text==Supplies.TITLES.get(kind,"BACKPACK +1 POUCH"),kind+" title contract unchanged")
		check(evidence.bounds.size.x<.34 and evidence.bounds.size.y<.40 and evidence.bounds.size.z<.26,kind+" within existing interaction envelope")
		if kind in ["soda","shaker","banana"]:
			check(prop.has_node("Cap") and prop.get_node("Cap").get_parent()==prop,kind+" independent direct-child Cap remains")
		if kind=="soda":
			var closed:Array[float]=[]
			for x in [-.004,0.0,.004]:closed.append(ray_depth(prop,Vector3(x,.09,.010)))
			prop.get_node("Cap").hide()
			for index in range(3):
				var depth:=ray_depth(prop,Vector3((index-1)*.004,.09,.010))
				check(is_finite(depth) and depth-closed[index]>.015 and absf(depth-.048)<.003,"soda aperture ray%d reaches actual cavity floor after Cap.hide, no opaque full lid"%index)
			for x in [-.018,.018]:
				var lid_depth:=ray_depth(prop,Vector3(x,.09,.010))
				check(absf(lid_depth-.0254)<.0003,"soda permanent silver lid has real indexed triangles beside aperture at x=%.3f"%x)
			check(prop.get_meta("visual_parts").has("PermanentEndPlate") and prop.get_meta("visual_parts").has("PermanentPullTab"),"soda fixed lid and pull ring remain in body batch")
			check(prop.get_node("Cap").get_meta("visual_parts")==["RemovableOpeningSeal"],"soda closure seal alone belongs to removable Cap")
		elif kind=="shaker":
			var closed:=ray_depth(prop,Vector3(0,.15,0))
			prop.get_node("Cap").hide()
			var opened:=ray_depth(prop,Vector3(0,.15,0))
			check(is_finite(opened) and opened-closed>.025 and absf(opened-.071)<.003,"shaker Cap.hide exposes actual cavity floor rather than opaque mouth disc or missing mesh")
		elif kind=="backpack":
			var parts:Array=prop.get_meta("visual_parts")
			check(parts.has("WebbingRow5") and parts.has("LowerPocketWebbing0") and not parts.has("FieldPatch"),"backpack reference webbing replaces unsupported lower patch")
		prop.queue_free()
	for family in range(3):
		var prop:=Node3D.new();scene.add_child(prop);Models.ammo_supply(prop,family)
		inspect(prop,"ammo%d"%family)
		check(prop.transform==Transform3D.IDENTITY,"ammo%d supply origin/scale unchanged"%family)
		prop.queue_free()
	# A wrapped label has millimetre surface clearance across its full arc instead
	# of penetrating the near cylinder and floating at its outer edge.
	var sample:=Node3D.new();scene.add_child(sample)
	Models._wrapped_panel(sample,"DiagnosticWrap",Vector2(.03745,.03745),Vector2(-.04,.04),Vector2(.32,.88),Models.material(Color.WHITE))
	var points:PackedVector3Array=sample.get_child(0).mesh.get_faces();var conforming:=true;var maximum_error:=0.0
	for point in points:
		maximum_error=maxf(maximum_error,absf(Vector2(point.x,point.z).length()-.03745))
		# ArrayMesh storage quantization is about0.06mm in this fixture; allow0.1mm,
		# still far below the previous flat panel's millimetre-scale intersection.
		conforming=conforming and absf(Vector2(point.x,point.z).length()-.03745)<.00010
	print("WRAP_MESH_METRICS vertices=",points.size()," maximum_radial_error_m=",maximum_error)
	check(conforming and points.size()>12,"actual wrapped label vertices conform to cylindrical surface")
	var file:=FileAccess.open("user://equipment-064-metrics.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(measurements,"\t"));file.close()
	scene.queue_free();await process_frame;await process_frame
	print("EQUIPMENT_MODELS_064_RESULT passes=",passed," failures=",failures," headless=true xr=false native_pixels=false")
	quit(0 if failures==0 else 1)
