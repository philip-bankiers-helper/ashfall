extends SceneTree
## CPU geometry/ownership/production-state checks, never native visual parity.
var checks := 0
var failures: Array[String] = []
var actor
var guns: Array = []
var reports: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",text)
	if not ok: failures.append(text)
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false); node.set_process_unhandled_input(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): freeze(child)
func added_meshes(gun) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for mesh in gun.find_children("*","MeshInstance3D",true,false):
		var parent: Node = mesh.get_parent(); var added := false
		while parent != gun and parent != null:
			added = added or parent.get_meta("original_long_gun_detail_064",false)
			parent = parent.get_parent()
		if added and mesh.mesh != null: result.append(mesh)
	return result
func mesh_hit(mesh: MeshInstance3D, from: Vector3, to: Vector3) -> bool:
	var a := mesh.to_local(from); var b := mesh.to_local(to)
	var faces := mesh.mesh.get_faces()
	for n in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(a,b,faces[n],faces[n+1],faces[n+2]) != null: return true
	return false
func clear_line(meshes: Array, from: Vector3, to: Vector3) -> bool:
	for mesh in meshes:
		if mesh.is_visible_in_tree() and mesh_hit(mesh,from,to): return false
	return true
func mesh_orientation(mesh: Mesh) -> Dictionary:
	var volume := 0.0; var normals_wrong := 0; var triangles := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for offset in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
			var a: int = indices[offset] if not indices.is_empty() else offset
			var b: int = indices[offset+1] if not indices.is_empty() else offset+1
			var c: int = indices[offset+2] if not indices.is_empty() else offset+2
			var cross := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			volume += vertices[a].dot(vertices[b].cross(vertices[c]))/6.0
			if normals.size() == vertices.size() and cross.length_squared() > 1e-18:
				if (normals[a]+normals[b]+normals[c]).dot(-cross.normalized()) <= 0.0: normals_wrong += 1
			triangles += 1
	return {"signed_volume":volume,"normals_disagreeing_with_godot_front":normals_wrong,"triangles":triangles}
func owns(gun, parent: Node, name_text: String) -> Node3D:
	var node := parent.find_child(name_text,true,false) as Node3D
	check(node != null and gun.is_ancestor_of(node),name_text+" owned by actual moving "+str(parent.name))
	return node
func geometry(gun, label: String) -> void:
	var meshes := added_meshes(gun)
	check(not meshes.is_empty(),label+" has actual added mesh geometry")
	var triangles := 0; var finite := true; var positive_area := true
	var inward: Array[String] = []; var bad_normals := 0; var orientation: Array = []
	for mesh in meshes:
		var faces := mesh.mesh.get_faces(); triangles += faces.size()/3
		for v in faces: finite = finite and v.is_finite()
		for n in range(0,faces.size(),3): positive_area = positive_area and (faces[n+1]-faces[n]).cross(faces[n+2]-faces[n]).length_squared()>.000000000000000001
		var winding := mesh_orientation(mesh.mesh)
		winding["node"] = str(mesh.get_path()); orientation.append(winding)
		if winding.signed_volume >= 0: inward.append(str(mesh.get_path()))
		bad_normals += winding.normals_disagreeing_with_godot_front
	check(finite,label+" added geometry has finite vertices")
	check(positive_area,label+" added geometry has nondegenerate triangles")
	check(inward.is_empty(),label+" added closed meshes use negative outward Godot volume; inward="+str(inward))
	check(bad_normals==0,label+" all added normals agree with clockwise Godot fronts; wrong="+str(bad_normals))
	check(meshes.size()<45,label+" added manufacture bounded below45 mesh instances")
	check(gun.find_children("*","CollisionObject3D",true,false).is_empty(),label+" adds no collision objects")
	var ray: Transform3D = gun.get_shot_transform()
	check(clear_line(meshes,ray.origin,ray.origin-ray.basis.z*.25),label+" new art keeps existing forward muzzle ray clear")
	reports.append({"weapon":label,"added_mesh_instances":meshes.size(),"triangles":triangles,"orientation":orientation,"shot_transform":str(ray),"actual_reload_zones":str(gun.get_reload_zones()),"claim":"CPU geometry only; no native/render/physical parity evidence"})
func optic_corridor(gun, label: String) -> void:
	var meshes := added_meshes(gun)
	if label == "AWP":
		for x in [-.012,0.0,.012]:
			for y in [-.012,0.0,.012]: check(clear_line(meshes,gun.to_global(Vector3(x,.151+y,.25)),gun.to_global(Vector3(x,.151+y,-.40))),"AWP new art clears central optical aperture sample"+str(Vector2(x,y)))
	elif label == "SPR":
		for x in [-.044,0.0,.044]:
			for y in [-.026,0.0,.026]: check(clear_line(meshes,gun.to_global(Vector3(x,.151+y,.25)),gun.to_global(Vector3(x,.151+y,-.40))),"SPR new hood clears80-percent rectangular aperture sample"+str(Vector2(x,y)))
	else:
		var rear: Vector3 = gun.sight_rear.global_position
		var front: Vector3 = gun.sight_front.global_position
		for offset in [Vector3.ZERO,Vector3(.003,0,0),Vector3(-.003,0,0)]: check(clear_line(meshes,rear+Vector3.BACK*.15+offset,front+Vector3.FORWARD*.10+offset),"P90 new art clears existing raised sight corridor"+str(offset))
func p90_profile(frame: MeshInstance3D) -> void:
	var envelope := frame.mesh.get_aabb()
	check(envelope.position.is_equal_approx(Vector3(-.043,-.130,-.095)) and envelope.size.is_equal_approx(Vector3(.086,.210,.300)),"P90 corrected frame preserves exact original XYZ envelope")
	check(frame.get_meta("thumb_aperture_center")==Vector3(0,-.060,.095),"P90 original thumb-aperture center retained")
	var faces := frame.mesh.get_faces();var old_vertices_preserved := true
	# get_faces() may weld/quantize the CPU TriangleMesh cache; compare the
	# committed vertex buffer itself for aperture-coordinate preservation.
	var vertices:PackedVector3Array=frame.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in 32:
		var angle := TAU*i/32.0
		var expected := Vector3(.043,-.060+sin(angle)*.031,.095+cos(angle)*.044)
		var found := false
		for v in vertices:
			if v.distance_to(expected)<.000001:found=true;break
		old_vertices_preserved=old_vertices_preserved and found
	check(old_vertices_preserved,"P90 original32 aperture polygon corners remain on actual mesh")
	var edges_preserved:=true
	for v in vertices:
		var p:=Vector2(v.z,v.y);var normalized:=(p-Vector2(.095,-.060))/Vector2(.044,.031)
		if normalized.length_squared()>1.01:continue
		var distance:=INF
		for i in 32:
			var a:=Vector2(.095+cos(TAU*i/32.0)*.044,-.060+sin(TAU*i/32.0)*.031)
			var b:=Vector2(.095+cos(TAU*(i+1)/32.0)*.044,-.060+sin(TAU*(i+1)/32.0)*.031)
			distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
		edges_preserved=edges_preserved and distance<.000001
	check(edges_preserved,"P90 additional aperture vertices stay collinear on original boundary edges")
	# Transverse rays measure the actual side silhouette, not a metadata label.
	# The earlier ellipse fails both longitudinal shoulder and heel-cut tests.
	for yz in [Vector2(.055,-.075),Vector2(.055,-.025),Vector2(.055,.025),Vector2(.055,.10),Vector2(.055,.17),Vector2(-.070,.195)]:
		check(mesh_hit(frame,frame.to_global(Vector3(-.10,yz.x,yz.y)),frame.to_global(Vector3(.10,yz.x,yz.y))),"P90 elongated stock occupies longitudinal shoulder/butt "+str(yz))
	for yz in [Vector2(-.075,-.055),Vector2(-.10,-.045),Vector2(.079,.19),Vector2(-.125,.18)]:
		check(not mesh_hit(frame,frame.to_global(Vector3(-.10,yz.x,yz.y)),frame.to_global(Vector3(.10,yz.x,yz.y))),"P90 clipped stock corners remain empty "+str(yz))
	for yz in [Vector2(-.060,.095),Vector2(-.040,.095),Vector2(-.080,.095),Vector2(-.060,.065),Vector2(-.060,.125)]:
		check(not mesh_hit(frame,frame.to_global(Vector3(-.10,yz.x,yz.y)),frame.to_global(Vector3(.10,yz.x,yz.y))),"P90 original through-hole remains open "+str(yz))
	var side_triangles:Array=[]
	for n in range(0,faces.size(),3):
		if is_equal_approx(faces[n].x,.043) and is_equal_approx(faces[n+1].x,.043) and is_equal_approx(faces[n+2].x,.043):
			side_triangles.append([[faces[n].z,faces[n].y],[faces[n+1].z,faces[n+1].y],[faces[n+2].z,faces[n+2].y]])
	reports.append({"weapon":"P90 corrected stock profile","actual_envelope_position":str(envelope.position),"actual_envelope_size":str(envelope.size),"actual_mesh_side_triangles_zy":side_triangles,"claim":"Authored chamfered silhouette, CPU mesh/ray evidence only; cropped film does not establish hidden dimensions"})
func run() -> void:
	# Historical authored geometry coverage; downloaded P90 has separate actual tracker/mesh tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	check(DisplayServer.get_name()=="headless","CPU headless execution")
	check(not root.use_xr,"XR viewport remains off")
	var box := mesh_orientation(BoxMesh.new());var cylinder := mesh_orientation(CylinderMesh.new())
	check(box.signed_volume<0 and box.normals_disagreeing_with_godot_front==0,"Godot BoxMesh calibrates negative outward volume and clockwise normals")
	check(cylinder.signed_volume<0 and cylinder.normals_disagreeing_with_godot_front==0,"Godot CylinderMesh calibrates negative outward volume and clockwise normals")
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);freeze(actor)
	var arsenal=load("res://scripts/arsenal_data.gd")
	for entry in [["precision_rifle.gd",5],["spr.gd",13],["top_feed_pdw.gd",10]]:
		var gun=load("res://scripts/"+entry[0]).new();root.add_child(gun);gun.setup(actor,false);arsenal.apply(gun,entry[1]);freeze(gun);guns.append(gun)
	await process_frame; await physics_frame
	for gun in guns: gun.global_transform=Transform3D.IDENTITY
	var awp=guns[0];var spr=guns[1];var pdw=guns[2]
	for pair in [[awp,"AWP"],[spr,"SPR"],[pdw,"P90"]]: geometry(pair[0],pair[1]);optic_corridor(pair[0],pair[1])
	check(awp.get_shot_transform().origin.is_equal_approx(Vector3(0,.047,-1.01)),"AWP shot origin unchanged")
	check(spr.get_shot_transform().origin.is_equal_approx(Vector3(0,.045,-.69)),"SPR shot origin unchanged")
	check(pdw.get_shot_transform().origin.is_equal_approx(Vector3(0,.045,-.46)),"P90 shot origin unchanged")
	check(is_equal_approx(rad_to_deg(awp.get_shot_transform().basis.z.angle_to(awp.model.global_basis.z)),2.5),"AWP accepted2.5degree calibration retained")
	check(awp.magazine_size==3 and awp.ammo==3 and awp.chambered,"AWP accepted3-round separate bolt setup retained")
	check(awp.optic._material.shader.code.contains("ALPHA=1.0") and awp.optic.lens.name=="AWPCentralScopeAndBlackout","AWP compositor/blackout shader remains actual original")
	check(spr.optic.WINDOW_SIZE.is_equal_approx(Vector2(.11,.065)),"SPR broad rectangular magnifying window unchanged")
	var moving=owns(awp,awp.bolt_handle,"AWPMovingBoltManufacture064")
	var before: Vector3=moving.global_position;awp._set_bolt_visual(Vector3.BACK*awp.BOLT_TRAVEL)
	check((moving.global_position-before).is_equal_approx(Vector3.BACK*.115),"AWP manufacture travels with actual115mm bolt root")
	awp._set_bolt_visual(Vector3.ZERO)
	owns(awp,awp.magazine,"AWPSeatedMagazine064");owns(awp,awp.loose_magazine,"AWPHeldMagazine064");owns(awp,awp.hip_source,"AWPOfferedMagazine064")
	owns(spr,spr.bolt,"SPRMovingChargingHandle064");owns(spr,spr.firing_carrier,"SPRMovingCarrierDetail064");owns(spr,spr.magazine,"SPRSeatedMagazine064")
	owns(pdw,pdw.bolt,"P90MovingChargeGrip064");owns(pdw,pdw.magazine,"P90SeatedTopMagazine064");owns(pdw,pdw.loose_magazine,"P90HeldTopMagazine064");owns(pdw,pdw.hip_source,"P90OfferedTopMagazine064")
	var frame=pdw.model.find_child("ThroughApertureBullpupFrame",true,false)
	check(frame!=null and frame.get_meta("real_through_aperture",false),"P90 thumb opening is actual mesh aperture")
	if frame!=null:p90_profile(frame)
	var all_visible:Array=[]
	for mesh in pdw.model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh!=null:all_visible.append(mesh)
	check(clear_line(all_visible,pdw.to_global(Vector3(-.10,-.060,.095)),pdw.to_global(Vector3(.10,-.060,.095))),"P90 thumb aperture passes through complete visible gun geometry")
	check(pdw.magazine.position.is_equal_approx(pdw.TOP_SEAT) and pdw._top_rest.is_equal_approx(pdw.TOP_SEAT),"P90 top seat/root unchanged")
	for side in ["right","left"]:
		actor.dominant_hand=side;pdw.refresh_hands();pdw.reload_state="needs_mag"
		var zone:Dictionary=pdw.get_reload_zones()[0]
		check(zone.position.is_equal_approx(pdw.TOP_OFFER+Vector3(0,.0508,.0508)) and is_equal_approx(zone.radius,.25),side+" P90 enlarged magazine grab zone unchanged")
		check(pdw.get_charge_point().is_equal_approx(Vector3(.05 if side=="left" else -.05,.064,-.10)),side+" P90 charging target unchanged")
	actor.dominant_hand="right"
	for gun in guns:gun.refresh_hands();gun.reset_weapon()
	awp.eject_magazine();check(awp.reload_state=="needs_bolt","AWP reload still begins separate BACK stage")
	awp.desktop_reload_step();awp._process(0)
	check(awp.reload_state=="needs_mag" and awp.insertion_arrow.visible and not awp.magazine.visible,"AWP original insertion arrow/root visibility follows ejection")
	awp.grab_magazine();awp._process(0);check(awp.loose_magazine.visible,"AWP actual detailed held magazine follows original held state")
	awp.insert_magazine();check(awp.reload_state=="needs_bolt" and not awp.chambered,"AWP inserted magazine still needs separate BACK cycle")
	awp.desktop_reload_step();check(awp.reload_state=="ready" and awp.chambered and awp.ammo==3,"AWP production state returns ready3 only after bolt")
	spr.eject_magazine();spr.grab_magazine();spr.insert_magazine();check(spr.reload_state=="needs_rack","SPR original UP magazine still requires BACK handle")
	spr.rack_bolt();check(spr.reload_state=="ready","SPR original charging transition retained")
	pdw.eject_magazine();pdw.grab_magazine();pdw.insert_magazine();check(pdw.reload_state=="needs_rack","P90 insertion still requires separate BACK charge")
	pdw.rack_bolt();check(pdw.reload_state=="ready","P90 original charging transition retained")
	for gun in guns:gun.shutdown();freeze(gun);gun.free()
	actor.free()
	var output:=OS.get_environment("ASHFALL_LONG_GUN_REPORT")
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"cpu_headless":true,"actual_xr":false,"native_render":false,"checks":checks,"failures":failures,"geometry":reports},"\t"))
	print("LONG_GUN_MODELS_064 checks=",checks," failures=",failures.size()," cpu_only=true native=false")
	quit(0 if failures.is_empty() else 1)
