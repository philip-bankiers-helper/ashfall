extends SceneTree
const Detail=preload("res://scripts/heavy_model_finish.gd")
var checks:=0
var failures:=0
var actor
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func all_meshes(node:Node)->Array[MeshInstance3D]:
	var meshes:Array[MeshInstance3D]=[]
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh!=null:meshes.append(child)
		meshes.append_array(all_meshes(child))
	return meshes
func triangles(mesh:Mesh)->Array[Vector3]:
	var result:Array[Vector3]=[]
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for point in vertices:result.append(point)
		else:
			for index in indices:result.append(vertices[index])
	return result
func intersects(mesh:Mesh,from:Vector3,to:Vector3)->bool:
	var points:=triangles(mesh)
	for i in range(0,points.size(),3):
		# Geometry3D's fixed epsilon is too coarse for millimetre cut faces.
		# Uniform unit conversion preserves the same segment/triangle intersection.
		if Geometry3D.segment_intersects_triangle(from*1000,to*1000,points[i]*1000,points[i+1]*1000,points[i+2]*1000)!=null:return true
	return false
func signed_volume(mesh:Mesh)->float:
	var volume:=0.0;var points:=triangles(mesh)
	for i in range(0,points.size(),3):volume+=points[i].dot(points[i+1].cross(points[i+2]))/6.0
	return volume
func detail_corridor_clear(gun,from:Vector3,to:Vector3)->bool:
	for node in gun.find_children("*","Node3D",true,false):
		if not node.get_meta("original_heavy_model_detail",false):continue
		for mesh in all_meshes(node):
			if intersects(mesh.mesh,mesh.to_local(from),mesh.to_local(to)):return false
	return true
func mechanism_snapshot(gun)->Dictionary:
	var result:={"shot":gun.get_shot_transform(),"foregrip":gun.FOREGRIP_POINT,"flash":gun.muzzle_flash.transform,"ammo_label":gun.ammo_label.transform,"reload_state":gun.reload_state,"ammo":gun.ammo,"capacity":gun.magazine_size,"fire_interval":gun.fire_interval,"damage":gun.damage}
	if gun.has_method("get_box_seat"):
		for key in ["cover","belt_box","belt","charging_handle","cover_grip","box_grip","belt_feed_grip","feed_socket"]:result[key]=gun.get(key).transform
		result["box"]=gun.get_box_seat();result["handle"]=gun.get_handle_point()
	elif gun.has_method("get_chamber_insert_point"):
		result["hinge"]=gun.hinge.transform;result["insert"]=gun.get_chamber_insert_point();result["offer"]=gun.get_shell_offer_point();result["close"]=gun.get_close_grip_point()
		for i in 2:result["chamber"+str(i)]=gun.chamber_markers[i].transform
	else:
		result["bolt"]=gun.bolt.transform;result["pack"]=gun.shell_pack.transform
	return result
func canonical(snapshot:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key in snapshot:result[key]=var_to_str(snapshot[key])
	return result
func run()->void:
	# Historical authored geometry/target snapshots; imported moving assemblies have separate tracker tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/heavy_models_062.json"))
	#086 Explicit8cm bin/feed refit applied to the historical oracle; all other fields remain exact.
	for key in ["belt_box","belt_feed_grip","feed_socket"]:
		var at:Transform3D=str_to_var(baseline.belt_lmg.ready[key]);at.origin.z+=.08;baseline.belt_lmg.ready[key]=var_to_str(at)
	var box:Vector3=str_to_var(baseline.belt_lmg.ready.box);box.z+=.08;baseline.belt_lmg.ready.box=var_to_str(box)
	for stage in ["box_removed","holding_box","needs_feed"]:
		var point:Vector3=str_to_var(baseline.belt_lmg[stage].grab);point.z+=.08;baseline.belt_lmg[stage].grab=var_to_str(point)
	for name in ["belt_lmg","dt11","auto_shotgun"]:
		var gun=load("res://scripts/"+name+".gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		check(canonical(mechanism_snapshot(gun))==baseline[name].ready,name+" ready-state targets, parent transforms, bore and timing identical to captured062")
		var group_name:String={"belt_lmg":"M60OriginalDetail063","dt11":"DT11OriginalDetail063","auto_shotgun":"M1014OriginalDetail063"}[name]
		var detail:Node3D=gun.model.find_child(group_name,true,false)
		check(detail!=null and detail.get_meta("original_heavy_model_detail",false),name+" original manufactured detail present in actual model")
		check(detail.get_child_count()<=4,name+" main static detail batched into at most four finish draws")
		check(gun.find_children("*","CollisionObject3D",true,false).is_empty(),name+" model refinement adds no collision or hitbox")
		check(detail_corridor_clear(gun,gun.sight_rear.global_position,gun.sight_front.global_position),name+" added triangle geometry leaves existing sight corridor clear")
		var shot:Transform3D=gun.get_shot_transform()
		check(detail_corridor_clear(gun,shot.origin,shot.origin-shot.basis.z*.05),name+" added muzzle hardware leaves unchanged firing origin and forward ray open")
		var count:=0;var valid:=true
		for mesh in all_meshes(detail):
			for surface in mesh.mesh.get_surface_count():
				var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				count+=vertices.size()
				for point in vertices:valid=valid and point.is_finite()
				for normal in normals:valid=valid and normal.is_finite() and normal.length()>.9
			valid=valid and mesh.material_override is StandardMaterial3D and not mesh.material_override.emission_enabled
		check(valid and count<16000,name+" finite bounded geometry and opaque non-emissive finish")
		if name=="belt_lmg":
			check(gun.cover.get_node("FeedCoverSkin063").get_parent()==gun.cover and gun.belt_box.has_node("AmmoBoxSkin063") and gun.offered_box.has_node("AmmoBoxSkin063") and gun.held_box.has_node("AmmoBoxSkin063"),"M60 feed cover and all three box presentations carry coherent attached hardware")
			for state in ["box_removed","holding_box","needs_feed","box_seated","needs_charge"]:
				gun.reload_state=state;gun._update_reload_visuals()
				check(canonical({"grab":gun.get_reload_grab_point(),"cover":gun.cover.transform,"belt":gun.belt.transform,"handle":gun.charging_handle.transform})==baseline[name][state],"M60 moving stage coordinates preserved "+state)
		elif name=="dt11":
			var fore:Node3D=gun.hinge.get_node("ContouredForeEnd063")
			check(fore.position.is_equal_approx(gun.fore_end_marker.position) and gun.hinge.has_node("BarrelBreechDetail063"),"DT11 sculpted fore-end and extractor follow the actual hinge and existing grab marker")
			check(signed_volume(all_meshes(fore)[0].mesh)<0,"DT11 sculpted shell has outward winding and closed negative conventional volume")
			for angle in [0.0,-.72]:
				gun.hinge.rotation.x=angle
				check(canonical({"insert":gun.get_chamber_insert_point(),"close":gun.get_close_grip_point()})==baseline[name][str(angle)],"DT11 open/closed chamber and close contacts preserved "+str(angle))
		else:
			check(gun.bolt.has_node("ChargingKnobSkin063") and gun.shell_pack.has_node("ShellPackManufacture063"),"M1014 handle hardware and six-shell manufacture follow existing moving parents")
			check(gun.model.get_node("ContouredForeEnd063").position==gun.FOREGRIP_POINT,"M1014 sculpted handguard stays centered on accepted support target")
		gun.shutdown();gun.free()
	# Geometry probes test actual holes, closed wall thickness and normal winding,
	# not a count of painted rectangles or a renderer screenshot substitute.
	var holder:=Node3D.new();root.add_child(holder);var material:=StandardMaterial3D.new()
	var tube:=Detail.tube(holder,"probe",Vector3.ZERO,.39,.032,.0285,material,true)
	check(not intersects(tube.mesh,Vector3(0,0,-.3),Vector3(0,0,.3)),"perforated shroud has open axial bore")
	var hole_angle:=TAU*1.5/24.0;var solid_angle:=TAU*.5/24.0;var z:float=-.39*.5+.39*1.5/20.0
	check(not intersects(tube.mesh,Vector3.ZERO+Vector3(0,0,z),Vector3(cos(hole_angle)*.05,sin(hole_angle)*.05,z)),"cooling aperture is actual through geometry")
	check(intersects(tube.mesh,Vector3(0,0,z),Vector3(cos(solid_angle)*.05,sin(solid_angle)*.05,z)),"neighboring shroud web has solid physical-looking wall")
	check(signed_volume(tube.mesh)<0,"perforated wall has negative conventional outward volume")
	holder.free();actor.free();await process_frame;OS.delay_msec(180);await process_frame
	print("HEAVY_MODELS_064 checks=",checks," failures=",failures," cpu_only=true rendered=false physical_parity=false")
	quit(failures)
