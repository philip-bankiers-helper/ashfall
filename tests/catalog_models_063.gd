extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func corridor_clear(node:Node3D,from:Vector3,to:Vector3)->bool:
	for child in node.get_children():
		if child is MeshInstance3D:
			var start:Vector3=child.to_local(from);var finish:Vector3=child.to_local(to)
			for surface in child.mesh.get_surface_count():
				var triangles:PackedVector3Array=child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var indices:PackedInt32Array=child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
				for i in range(0,indices.size(),3):
					if Geometry3D.segment_intersects_triangle(start,finish,triangles[indices[i]],triangles[indices[i+1]],triangles[indices[i+2]])!=null:return false
	return true
func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for index in [0,17,18,19,20,21,23,24,25]:
		var gun:Node3D=rack.weapons[index];var chassis:Node3D=gun.model.find_child("AuthoredCatalogChassis",true,false)
		check(chassis!=null,"actual rack has original refined chassis "+str(index))
		check(chassis.get_child_count()<=6,"static detail is batched to at most six finish draws "+str(index))
		check(corridor_clear(chassis,gun.sight_rear.global_position,gun.sight_front.global_position),"production sight line remains open through actual mesh triangles "+str(index))
		var vertices:=0
		for mesh in chassis.get_children():
			var bounds:AABB=mesh.mesh.get_aabb()
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()<1.6,"chassis has finite hand-sized bounds "+str(index))
			vertices+=mesh.mesh.surface_get_array_len(0)
		check(vertices<6000,"bounded original detail mesh budget "+str(index))
		var before:Transform3D=gun.get_shot_transform();var rounds:int=gun.ammo
		gun.eject_magazine();check(gun.reload_state=="needs_mag" and gun.ammo==0,"unchanged production eject state owns rounds "+str(index))
		check(gun.get_shot_transform().is_equal_approx(before),"eject does not alter sight or bore calibration "+str(index))
		check(gun.loose_magazine.mesh==gun.magazine.mesh and gun.hip_source.get_child(0).mesh==gun.magazine.mesh,"live, ejected and offered magazine share actual shape "+str(index))
		gun.grab_magazine();gun.insert_magazine();gun.rack_bolt()
		check(gun.reload_state=="ready" and gun.ammo==rounds,"original magazine/charge sequence remains usable "+str(index))
		check(gun.sight_front!=null and gun.sight_rear!=null,"physical front/rear aiming hooks survive model pass "+str(index))
		gun.reset_weapon()
	rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("CATALOG_MODELS_063 checks=",checks," failures=",failures," cpu_only=true native_rendered=false physical_parity=false")
	quit(failures)
