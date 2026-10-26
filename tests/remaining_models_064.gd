extends SceneTree
## Mesh/transform QA only. Desktop actor has no controller instances or inputs.
class DesktopActor extends Node3D:
	var right_hand:XRController3D
	var left_hand:XRController3D
	var dominant_hand:="right"
var checks:=0
var failures:=0
var metrics:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func snapshot(gun)->Dictionary:
	var out:Dictionary={}
	for key in ["model","magazine","loose_magazine","bolt","firing_carrier","guide","hip_source","insertion_arrow","charging_arrow","muzzle_flash","ammo_label","sight_front","sight_rear"]:
		var node:Node3D=gun.get(key);out[key]=var_to_str(node.transform)
	for key in ["ammo","magazine_size","damage","fire_interval","motion_damping","offhand_influence","grip_toggle","FOREGRIP_POINT","FOREGRIP_ACQUIRE","FOREGRIP_RELEASE","reload_state"]:out[key]=var_to_str(gun.get(key))
	out["shot"]=var_to_str(gun.get_shot_transform());out["insert"]=var_to_str(gun.get_magazine_insert_point());out["offer"]=var_to_str(gun.get_magazine_offer_point());out["offered_transform"]=var_to_str(gun.get_offered_magazine_transform())
	return out
func meshes(node:Node,visible_only:bool=false)->Array[MeshInstance3D]:
	var result:Array[MeshInstance3D]=[]
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh!=null and (not visible_only or child.is_visible_in_tree()):result.append(child)
		result.append_array(meshes(child,visible_only))
	return result
func triangles(mesh:Mesh)->Array[Vector3]:
	var out:Array[Vector3]=[]
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for point in vertices:out.append(point)
		else:
			for index in indices:out.append(vertices[index])
	return out
func correct_facing(mesh:Mesh)->bool:
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():indices.append(i)
		for i in range(0,indices.size(),3):
			var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
			var conventional:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]);var normal_sum:Vector3=normals[a]+normals[b]+normals[c]
			if conventional.dot(normal_sum)>=-1e-13:return false
	return true
func signed_volume(mesh:Mesh)->float:
	var volume:=0.0;var points:=triangles(mesh)
	for i in range(0,points.size(),3):volume+=points[i].dot(points[i+1].cross(points[i+2]))/6.0
	return volume
func blocked(gun,from:Vector3,to:Vector3,detail_only:bool=false)->bool:
	for mesh in meshes(gun,true):
		var added:=false;var ancestor:Node=mesh
		while ancestor!=gun and ancestor!=null:
			added=added or ancestor.get_meta("original_remaining_detail064",false);ancestor=ancestor.get_parent()
		if detail_only and not added:continue
		var a:Vector3=mesh.to_local(gun.model.to_global(from))*1000;var b:Vector3=mesh.to_local(gun.model.to_global(to))*1000;var points:=triangles(mesh.mesh)
		for i in range(0,points.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,points[i]*1000,points[i+1]*1000,points[i+2]*1000)!=null:return true
	return false
func added_meshes(gun)->Array[MeshInstance3D]:
	var out:Array[MeshInstance3D]=[]
	for mesh in meshes(gun):
		var ancestor:Node=mesh
		while ancestor!=gun and ancestor!=null:
			if ancestor.get_meta("original_remaining_detail064",false):out.append(mesh);break
			ancestor=ancestor.get_parent()
	return out
func stable_phase(source:Dictionary)->Dictionary:
	var out:=source.duplicate();var guide:Transform3D=str_to_var(out.guide)
	# Existing guide pulsing intentionally samples wall-clock time. Compare its
	# target origin, and prove the pulse function itself unchanged in source QA.
	out.guide=var_to_str(Transform3D(Basis.IDENTITY,guide.origin));return out
func requested076(base:Dictionary,name:String,phase:String)->Dictionary:
	var out:Dictionary=base[name][phase].duplicate()
	if name!="pistol":return out
	for key in ["magazine","insertion_arrow","offered_transform"]:
		var at:Transform3D=str_to_var(out[key]);at.origin.z+=.04;out[key]=var_to_str(at)
	for key in ["insert","offer"]:
		var point:Vector3=str_to_var(out[key]);point.z+=.04;out[key]=var_to_str(point)
	if phase not in ["ready","kick"]:
		var at:Transform3D=str_to_var(out.guide);at.origin.z+=.04;out.guide=var_to_str(at)
	return out
func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var actor:=DesktopActor.new();root.add_child(actor)
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/remaining_models_base064.json"))
	# Uploaded UMP supersedes the old064 static finish; ump_asset_074 tests its meshes and real reload route.
	for name in ["burst_carbine","pistol"]:
		var gun=load("res://scripts/"+name+".gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false)
		check(snapshot(gun)==requested076(baseline,name,"ready"),name+" only authorized076 lower-assembly/reload target shift; other ready state preserved")
		check(gun.FOREGRIP_POINT==Vector3(0,-.025,-.36) and gun.FOREGRIP_ACQUIRE==.25 and gun.FOREGRIP_RELEASE==.45,name+" accepted shared support coordinates and distances unchanged")
		if name=="pistol":check(gun.PISTOL_SUPPORT_POINT==Vector3(0,-.065,-.095),"pistol cup support follows4cm lower-assembly shift")
		gun.recoil=.027;gun.recoil_pitch=.083;gun.recoil_yaw=-.017;gun._apply_recoil_visual()
		check(snapshot(gun)==requested076(baseline,name,"kick"),name+" visual recoil translation and rotation match baseline")
		gun.recoil=0;gun.recoil_pitch=0;gun.recoil_yaw=0;gun._apply_recoil_visual()
		for cycle in [.0,.025,.0475,.07125,.095]:
			gun._carrier_time=cycle;gun._process(0)
			check(stable_phase(snapshot(gun))==stable_phase(requested076(baseline,name,str(cycle))),name+" existing moving-node cycle phase preserved "+str(cycle))
		check(gun.find_children("*","CollisionObject3D",true,false).is_empty(),name+" no collision bodies/hitboxes added")
		var group_name:String={"compact_smg":"CompactManufacture064","burst_carbine":"BurstManufacture064","pistol":"PistolManufacture064"}[name]
		var group:Node3D=gun.model.get_node(group_name)
		check(group.get_meta("original_remaining_detail064",false) and group.get_child_count()<=6,name+" actual manufacture root present with bounded finish batches")
		var added:=added_meshes(gun);var count:=0;var valid:=true;var clockwise:=true;var negative_volume:=true
		for mesh in added:
			for surface in mesh.mesh.get_surface_count():
				var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				for point in vertices:valid=valid and point.is_finite()
				for normal in normals:valid=valid and normal.is_finite() and normal.length()>.9
			var points:=triangles(mesh.mesh);count+=points.size()/3
			for i in range(0,points.size(),3):valid=valid and (points[i+1]-points[i]).cross(points[i+2]-points[i]).length()>1e-12
			valid=valid and mesh.material_override is StandardMaterial3D and not mesh.material_override.emission_enabled and mesh.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
			clockwise=clockwise and correct_facing(mesh.mesh);negative_volume=negative_volume and signed_volume(mesh.mesh)<-1e-15
		check(valid,name+" finite nondegenerate triangles, unit normals and opaque nonemissive materials")
		check(clockwise and negative_volume,name+" every added mesh has Godot clockwise fronts, outward normals and negative conventional closed volume")
		check(count<=12000 and added.size()<=18,name+" added triangle and draw bounds")
		var visible_meshes:=meshes(gun.model,true)
		var visible_triangles:=0
		for mesh in visible_meshes:visible_triangles+=triangles(mesh.mesh).size()/3
		check(visible_meshes.size()<=64 and visible_triangles<=24000,name+" actual visible model stays within64 mesh draws and24000 triangles")
		var rear:Vector3=gun.model.to_local(gun.sight_rear.global_position);var front:Vector3=gun.model.to_local(gun.sight_front.global_position)
		check(not blocked(gun,rear,front,true),name+" added geometry leaves existing zeroed sight line open")
		var muzzle:Vector3=gun.model.to_local(gun.get_shot_transform().origin)
		check(not blocked(gun,muzzle,muzzle+Vector3.FORWARD*.05),name+" unchanged shot origin has open forward bore through actual visible model")
		var opening:Vector3={"compact_smg":Vector3(0,-.05,-.075),"burst_carbine":Vector3(0,-.05,-.077),"pistol":Vector3(0,-.048,-.215)}[name]
		check(not blocked(gun,opening-Vector3.RIGHT*.08,opening+Vector3.RIGHT*.08),name+" trigger guard retains actual open negative space")
		if name in ["compact_smg","burst_carbine"]:
			var p:Vector3=Vector3(0,.018,-.3375) if name=="compact_smg" else Vector3(0,.015,-.43925)
			check(not blocked(gun,p,p+Vector3.RIGHT*.08),name+" handguard side aperture is open through all actual visible geometry")
			p.z=-.315 if name=="compact_smg" else -.405
			check(blocked(gun,p,p+Vector3.RIGHT*.08),name+" adjacent handguard web has real material")
			check(gun.bolt.has_node("ChargingHandleManufacture064"),name+" charging texture moves under existing charging-handle parent")
		if name=="compact_smg":
			check(gun.magazine.has_node("MagazineManufacture064") and gun.loose_magazine.has_node("MagazineManufacture064") and gun.hip_source.has_node("MagazineManufacture064"),"compact seated/held/offered magazines carry matching attached hardware")
		elif name=="pistol":
			check(correct_facing(gun.bolt.mesh) and signed_volume(gun.bolt.mesh)<0,"pistol replacement slide shell also has clockwise fronts and outward normals")
			var detail:Node3D=gun.bolt.get_node("SlideManufacture064");var before:=detail.global_position;var frame_before:=group.global_transform
			gun.bolt.position.z+=.035
			check(detail.global_position.is_equal_approx(before+Vector3(0,0,.035)) and group.global_transform==frame_before,"pistol serrations/ejection skin follows exact existing slide travel while frame stays fixed")
			check(gun.magazine.has_node("MagazineManufacture064") and gun.loose_magazine.has_node("MagazineManufacture064") and gun.hip_source.has_node("MagazineManufacture064"),"pistol all magazine presentations retain their original moving parents")
		metrics.append({"weapon":name,"added_triangles":count,"replacement_triangles":triangles(gun.bolt.mesh).size()/3 if name=="pistol" else 0,"added_mesh_draws":added.size(),"visible_model_mesh_draws":visible_meshes.size(),"visible_model_triangles":visible_triangles})
		gun.shutdown();gun.free()
	actor.free();await process_frame;OS.delay_msec(180);await process_frame
	print("REMAINING_MODELS064_METRICS ",JSON.stringify(metrics))
	print("REMAINING_MODELS_064 checks=",checks," failures=",failures," cpu_only=true controller_actions=false rendered=false physical_parity=false")
	quit(failures)
