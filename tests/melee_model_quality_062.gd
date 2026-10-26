extends SceneTree
const Assets=preload("res://scripts/blade_assets.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func vertex_key(v:Vector3)->String:return "%d,%d,%d"%[roundi(v.x*1000000),roundi(v.y*1000000),roundi(v.z*1000000)]
func triangle_vertices(mesh:ArrayMesh)->PackedVector3Array:
	var result:=PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():result.append_array(vertices)
		else:
			for index in indices:result.append(vertices[index])
	return result
func closed_mesh(blade:MeshInstance3D,edge:MeshInstance3D)->Dictionary:
	var edges:Dictionary={};var degenerate:=0;var volume:=0.0;var triangles:=0
	for part in [blade,edge]:
		var vertices:PackedVector3Array=triangle_vertices(part.mesh)
		for i in range(0,vertices.size(),3):
			var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
			triangles+=1
			if (b-a).cross(c-a).length_squared()<1e-18:degenerate+=1
			volume+=a.dot(b.cross(c))/6.0
			for pair in [[a,b],[b,c],[c,a]]:
				var first:=vertex_key(pair[0]);var second:=vertex_key(pair[1])
				var key:=first+"/"+second if first<second else second+"/"+first
				edges[key]=int(edges.get(key,0))+1
	var bad_edges:=0
	for count in edges.values():
		if count!=2:bad_edges+=1
	return {"triangles":triangles,"unpaired_edges":bad_edges,"degenerate_triangles":degenerate,"signed_volume":volume}
func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var metrics:Array=[]
	for kind in ["katana","excalibur","cyberblade","knife"]:
		var model:=Node3D.new();root.add_child(model);var built:Dictionary=Assets.build(model,kind)
		var pommel:MeshInstance3D=model.get_node("Pommel");var bottom:Vector3=pommel.position-Vector3.UP*pommel.mesh.size.y*.5
		check(absf(built.tip.position.distance_to(bottom)-(.38 if kind=="knife" else 1.4101590361445784))<.000001,kind+" corrected total span preserved")
		if kind!="knife":
			check(absf(Assets.GRIP.distance_to(bottom)-0.23502650602409636)<.000001,kind+" primary fist is exactly8in from outer pommel end")
			model.global_transform=Transform3D(Basis.from_euler(Vector3(.3,.6,.2)),Vector3(2,1,-3))
			check(absf(model.to_global(Assets.GRIP).distance_to(model.to_global(bottom))-0.23502650602409636)<.000001,kind+" pommel datum survives actual rotated world pose")
			check(model.get_node("GripCore").mesh.size==Vector3(.032,.285,.037),kind+" controller-sized hilt retained")
			var core:MeshInstance3D=model.get_node("GripCore");var center:Vector3=Assets.GRIP-core.position
			check(core.get_aabb().has_point(center-Vector3.UP*.05) and core.get_aabb().has_point(center+Vector3.UP*.05),kind+" actual handle contains primary fist")
		else:check(model.get_node("GripCore").mesh.size==Vector3(.033,.130,.036),"authored knife38cm/130mm grip preserved")
		var blade:MeshInstance3D=model.get_node("AuthoredBlade");var bevel:MeshInstance3D=model.get_node("ContinuousEdgeBevels")
		var topology:=closed_mesh(blade,bevel)
		check(topology.unpaired_edges==0,kind+" actual bevel/flat/heel/tip surfaces form closed manifold")
		check(topology.degenerate_triangles==0,kind+" no degenerate blade triangles")
		check(topology.signed_volume<-.000001,kind+" consistent outward Godot clockwise winding and physical volume")
		var tip_min:=INF;var tip_max:=-INF
		# get_faces() uses Godot's cached TriangleMesh quantization; inspect stored
		# render vertices for a submillimetre edge instead of its snapped cache.
		var stored_vertices:PackedVector3Array=blade.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in stored_vertices:
			if absf(vertex.y-built.tip.position.y)<.000001:tip_min=minf(tip_min,vertex.z);tip_max=maxf(tip_max,vertex.z)
		check(absf((tip_max-tip_min)-.00030)<.000002,kind+" actual stored tip thickness tapers to 0.30 mm")
		if kind!="knife":
			var collar:MeshInstance3D=model.get_node("HiltCollar")
			var core:MeshInstance3D=model.get_node("GripCore")
			check(absf(collar.position.y-collar.mesh.height*.5-(core.position.y+core.mesh.size.y*.5))<.000001,kind+" metal collar touches actual handle end without a gap")
		else:
			var core:MeshInstance3D=model.get_node("GripCore")
			for side in [-1,1]:
				var rivet:MeshInstance3D=model.get_node("KnifeGripFastener%d"%side)
				var rear:float=rivet.position.z-rivet.mesh.height*.5
				check(rear<core.position.z+core.mesh.size.z*.5,"knife fastener is seated into handle face rather than floating")
		var inlay_count:=0;var meshes:=0;var face_count:=0
		for child in model.get_children():
			if not child is MeshInstance3D:continue
			meshes+=1;face_count+=floori(child.mesh.get_faces().size()/3.0)
			check(child.layers==Assets.LIVE_LAYER,kind+" authored mesh uses existing live-weapon layer")
			if "Inlay" in child.name or child.name.begins_with("EnergyInset"):
				inlay_count+=1
				check(child.mesh is ArrayMesh,kind+" face detail follows curved blade as a thin mesh")
		if kind=="katana":check(inlay_count==0,"Katana polished bevel is continuous, no floating spine boxes")
		if kind=="excalibur":check(inlay_count==2,"Excalibur pair of original surface-following fullers")
		if kind=="cyberblade":check(inlay_count==8,"Cyberblade spine and seven energy insets follow real faces")
		metrics.append({"kind":kind,"mesh_instances":meshes,"triangles":face_count,"blade_topology":topology,"grip_to_pommel_m":Assets.GRIP.distance_to(bottom)})
		model.free()
	print("MELEE_MODEL_QUALITY_062_METRICS ",JSON.stringify(metrics))
	print("MELEE_MODEL_QUALITY_062 checks=",checks," failures=",failures," actual_meshes=true cpu_only=true native_rendered=false headset_tested=false")
	quit(failures)
