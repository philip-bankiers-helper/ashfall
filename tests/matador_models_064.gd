extends SceneTree
class DesktopActor extends Node3D:
	var right_hand:XRController3D
	var left_hand:XRController3D
	var dominant_hand:="right"
	var view:Camera3D
	var _grabs:Dictionary={}
	func get_weapon_hand()->XRController3D:return null
	func get_support_hand()->XRController3D:return null
	func get_view_camera()->Camera3D:return view
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func hash_bytes(data:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(data);return context.finish().hex_encode()
func material_record(material:Material)->Dictionary:
	if material==null:return {}
	var out:={"class":material.get_class()}
	for key in ["albedo_color","metallic","roughness","shading_mode","cull_mode","transparency","emission_enabled","emission","emission_energy_multiplier","uv1_triplanar","uv1_scale","texture_filter","normal_enabled","vertex_color_use_as_albedo","diffuse_mode","specular_mode"]:out[key]=var_to_str(material.get(key))
	for key in ["albedo_texture","roughness_texture","normal_texture","metallic_texture"]:
		var texture:Texture2D=material.get(key)
		out[key]=hash_bytes(texture.get_image().get_data()) if texture!=null else "none"
	return out
func mesh_records(node:Node,path:String="")->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	for i in node.get_child_count():
		var child:Node=node.get_child(i);var child_path:=path+"/"+str(i)
		if child is MeshInstance3D and child.mesh!=null:
			var record:={"tree_path":child_path,"transform":var_to_str(child.transform),"visible":child.visible,"shadow":child.cast_shadow,"material":material_record(child.material_override),"surfaces":[]}
			for surface in child.mesh.get_surface_count():record.surfaces.append({"arrays":hash_bytes(var_to_bytes(child.mesh.surface_get_arrays(surface))),"material":material_record(child.mesh.surface_get_material(surface)),"primitive":child.mesh.surface_get_primitive_type(surface) if child.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES})
			out.append(record)
		out.append_array(mesh_records(child,child_path))
	return out
func protected_snapshot(pair)->Array[Dictionary]:
	var rows:Array[Dictionary]=[]
	for gun in pair.guns:
		var row:Dictionary={"shot":var_to_str(gun.get_shot_transform()),"capacity":gun.magazine_size,"ammo":gun.ammo,"damage":gun.damage,"fire_interval":gun.fire_interval,"shotgun_mode":gun.shotgun_mode,"spin_seconds":gun.SPIN_SECONDS,"reload_state":gun.reload_state}
		for key in ["model","spin_root","reload_arrow","magazine","bolt","firing_carrier","guide","muzzle_flash","insertion_arrow","charging_arrow","hip_source","loose_magazine","ammo_label"]:
			var part:Node3D=gun.get(key);row[key]=var_to_str(part.transform)
		rows.append(row)
	return rows
func snapshots_match(current:Array,baseline:Array)->bool:
	if current.size()!=baseline.size():return false
	for i in current.size():
		if current[i].size()!=baseline[i].size():return false
		for key in current[i]:
			if not baseline[i].has(key):return false
			var value=current[i][key];var prior=baseline[i][key]
			if key=="fire_interval" and bool(current[i].get("shotgun_mode",false)):prior=float(prior)/1.2 #086 explicit rate change; other golden fields exact
			if (value is int or value is float) and (prior is int or prior is float):
				# JSON decimal serialization rounds the one-star1/13 Uzi interval.
				if absf(float(value)-float(prior))>1e-12:return false
			elif value!=prior:return false
	return true
func make_actor()->DesktopActor:
	var actor:=DesktopActor.new();root.add_child(actor);actor.view=Camera3D.new();actor.add_child(actor.view);return actor
func make_pair(actor:Node3D,matador:bool):
	#084: this historical golden geometry suite verifies retained authored fallback.
	var quality:Variant=ProjectSettings.get_setting("ashfall/lightweight_models",null);ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var pair=load("res://scripts/dual_matadors.gd" if matador else "res://scripts/dual_pistols.gd").new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
	load("res://scripts/arsenal_data.gd").apply(pair,12 if matador else 11);ProjectSettings.set_setting("ashfall/lightweight_models",quality);return pair
func all_meshes(node:Node,visible_only:bool=false)->Array[MeshInstance3D]:
	var out:Array[MeshInstance3D]=[]
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh!=null and (not visible_only or child.is_visible_in_tree()):out.append(child)
		out.append_array(all_meshes(child,visible_only))
	return out
func triangles(mesh:Mesh)->Array[Vector3]:
	var out:Array[Vector3]=[]
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for vertex in vertices:out.append(vertex)
		else:
			for index in indices:out.append(vertices[index])
	return out
func ray_hits(gun,from:Vector3,to:Vector3)->bool:
	for mesh in all_meshes(gun.model,true):
		var a:Vector3=mesh.to_local(gun.model.to_global(from))*1000;var b:Vector3=mesh.to_local(gun.model.to_global(to))*1000;var points:=triangles(mesh.mesh)
		for i in range(0,points.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,points[i]*1000,points[i+1]*1000,points[i+2]*1000)!=null:return true
	return false
func geometry_record(root_node:Node3D,gun)->Dictionary:
	var finite:=true;var indexed:=true;var clockwise:=true;var negative_volume:=true;var count:=0;var min_point:=Vector3(INF,INF,INF);var max_point:=-Vector3(INF,INF,INF)
	for mesh in all_meshes(root_node):
		var volume:=0.0
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			indexed=indexed and not indices.is_empty();count+=indices.size()/3
			for vertex in vertices:
				finite=finite and vertex.is_finite();var point:Vector3=gun.model.to_local(mesh.to_global(vertex));min_point=min_point.min(point);max_point=max_point.max(point)
			for normal in normals:finite=finite and normal.is_finite() and absf(normal.length()-1)<.01
			for i in range(0,indices.size(),3):
				var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
				var cross:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]);finite=finite and cross.length()>1e-12
				clockwise=clockwise and cross.dot(normals[a]+normals[b]+normals[c])< -1e-13
				volume+=vertices[a].dot(vertices[b].cross(vertices[c]))/6.0
		negative_volume=negative_volume and volume< -1e-15
	return {"finite":finite,"indexed":indexed,"clockwise":clockwise,"negative_volume":negative_volume,"triangles":count,"meshes":all_meshes(root_node).size(),"min":min_point,"max":max_point}
func run()->void:
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/matador_base064.json"));var actor:=make_actor()
	var uzis=make_pair(actor,false);var matadors=make_pair(actor,true)
	var frozen063:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uzi_frozen063.json"))
	check(hash_bytes(var_to_bytes(mesh_records(uzis)))==frozen063.uzi_fingerprint,"all Uzi canonical meshes, arrays, materials, textures, visibility and transforms match authoritative frozen063 PCK")
	check(snapshots_match(protected_snapshot(uzis),baseline.uzi_protected),"both actual Uzi profile mechanism snapshots unchanged")
	check(snapshots_match(protected_snapshot(matadors),baseline.matador_protected),"both actual Matador bore, marker, spin, reload, ammo and timing snapshots unchanged")
	check(uzis.guns[0].magazine_size==20 and uzis.guns[1].magazine_size==20 and not uzis.shotgun_mode,"active one-star Uzi remains20 per independent automatic hand")
	check(matadors.guns[0].magazine_size==8 and matadors.guns[1].magazine_size==8 and matadors.shotgun_mode,"active Matador remains8 per independent semiautomatic hand")
	var metrics:Array[Dictionary]=[]
	for hand in 2:
		var gun=matadors.guns[hand];var detail:Node3D=gun.spin_root.get_node("MatadorManufacture064");var label:="Matador hand"+str(hand)+" "
		check(detail.get_parent()==gun.spin_root and detail.get_meta("original_matador_detail064",false),label+" all new manufacture follows existing full-turn spin parent")
		var data:=geometry_record(detail,gun)
		check(data.indexed and data.triangles==int(detail.get_meta("generated_indexed_triangles")),label+" actual indexed batches contain every indexed source triangle without append loss")
		check(data.finite and data.clockwise and data.negative_volume,label+" finite nondegenerate clockwise geometry, outward unit normals and negative conventional closed volume")
		check(data.triangles>=1200 and data.triangles<=6000 and data.meshes<=4,label+" bounded actual geometry and at most four finish draws")
		check(data.min.x>=-.04001 and data.max.x<=.04001 and data.min.y>=-.13501 and data.max.y<=.07501 and data.min.z>=-.36001 and data.max.z<=.04751,label+" manufacture remains within existing Matador silhouette envelope")
		var opaque:=true
		for mesh in all_meshes(detail):opaque=opaque and mesh.material_override is StandardMaterial3D and not mesh.material_override.emission_enabled and mesh.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
		check(opaque,label+" original opaque restrained finishes")
		for x in [-.021,.021]:
			check(not ray_hits(gun,Vector3(x,.045,-.40),Vector3(x,.045,-.31)),label+" actual barrel bore open x="+str(x))
			check(ray_hits(gun,Vector3(x+.015,.045,-.40),Vector3(x+.015,.045,-.33)),label+" adjacent crown annulus is actual solid material x="+str(x))
		check(not ray_hits(gun,Vector3(-.06,-.052,-.075),Vector3(.06,-.052,-.075)),label+" actual trigger region is open negative space")
		check(ray_hits(gun,Vector3(-.06,-.077,-.055),Vector3(.06,-.077,-.055)),label+" adjacent trigger-guard bar remains solid")
		check(not ray_hits(gun,Vector3(0,.045,-.37),Vector3(0,.045,-.43)),label+" existing central firing origin/forward ray stays clear")
		check(gun.find_children("*","CollisionObject3D",true,false).is_empty(),label+" no colliders or hitboxes added")
		var mesh:MeshInstance3D=all_meshes(detail)[0];var vertex:Vector3=triangles(mesh.mesh)[0];var before:Vector3=mesh.to_global(vertex);var pivot:Vector3=gun.spin_root.global_position
		gun.spin_root.rotation.x=.5
		check(mesh.to_global(vertex).is_equal_approx(pivot+Basis(Vector3.RIGHT,.5)*(before-pivot)),label+" actual new mesh vertices move with existing cosmetic spin")
		gun.spin_root.basis=Basis.IDENTITY
		metrics.append({"hand":hand,"new_triangles":data.triangles,"new_draws":data.meshes,"min":var_to_str(data.min),"max":var_to_str(data.max)})
	# Direct desktop APIs exercise existing mode gates without controller objects,
	# trigger setters, physical inputs or an XR runtime.
	var u=uzis.guns[0];u.fire();u.cooldown=0;u.fire()
	check(u.ammo==18 and uzis.guns[1].ammo==20,"Uzi direct fire remains automatic and other hand ammunition independent")
	var m=matadors.guns[0];m.fire();m.cooldown=0;m.fire()
	check(m.ammo==7 and matadors.guns[1].ammo==8,"Matador direct fire preserves semiautomatic rearm gate and other hand ammunition")
	var other_spin:float=matadors.guns[1].spin_elapsed;m.reload_flick()
	check(m.ammo==8 and m.spin_elapsed==0 and matadors.guns[1].spin_elapsed==other_spin,"one Matador occupied-hand reload keeps existing capacity/spin and other hand independent")
	uzis.shutdown();matadors.shutdown();uzis.free();matadors.free();actor.free();await process_frame;OS.delay_msec(180);await process_frame
	print("MATADOR_MODELS064_METRICS ",JSON.stringify(metrics))
	print("MATADOR_MODELS_064 checks=",checks," failures=",failures," cpu_only=true controller_actions=false rendered=false physical_parity=false")
	quit(failures)
