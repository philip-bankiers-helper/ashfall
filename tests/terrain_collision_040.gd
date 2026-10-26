extends SceneTree
const World = preload("res://scripts/world.gd")
const Ballistic = preload("res://scripts/ballistic_query.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ",label)
func bodies(node: Node, result: Array[RID]):
	if node is CollisionObject3D: result.append(node.get_rid())
	for child in node.get_children(): bodies(child,result)
func rendered_faces(node: Node3D, result: PackedVector3Array) -> PackedVector3Array:
	if node is MeshInstance3D and node.mesh != null:
		for vertex in node.mesh.get_faces(): result.append(node.global_transform * vertex)
	for child in node.get_children():
		if child is Node3D: result = rendered_faces(child,result)
	return result
func on_surface(point: Vector3, faces: PackedVector3Array, xf: Transform3D) -> bool:
	for i in range(0,faces.size(),3):
		var a := xf*faces[i]
		var b := xf*faces[i+1]
		var c := xf*faces[i+2]
		var n := (b-a).cross(c-a).normalized()
		if absf(n.dot(point-a))>.006: continue
		var projected := point-n*n.dot(point-a)
		if n.dot((b-a).cross(projected-a))>=-.00001 and n.dot((c-b).cross(projected-b))>=-.00001 and n.dot((a-c).cross(projected-c))>=-.00001: return true
	return false
func run():
	var world := World.new()
	root.add_child(world)
	world.build()
	await physics_frame
	await physics_frame
	var surfaces := get_nodes_in_group("terrain_surface")
	check(surfaces.size() == 31, "all24massifs and7scanned rockfaces have collision")
	var all_rids: Array[RID] = []
	bodies(world,all_rids)
	var space := root.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	var count_samples := 0
	var count_support := 0
	var actor = preload("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_physics_process(false)
	var movement_regions := 0
	for body in surfaces:
		var rendered := rendered_faces(body.get_parent(),PackedVector3Array())
		var moved := false
		check(body.collision_layer == 9 and body.is_in_group("climbable") and not body.is_in_group("ballistic_proxy_ignore"), "visibleterrain shares support/head/bullet surface: " + str(body.get_parent().name))
		var exclusions: Array[RID] = all_rids.duplicate()
		exclusions.erase(body.get_rid())
		var local_samples := 0
		for child in body.get_children():
			if not child is CollisionShape3D: continue
			check(child.shape is ConcavePolygonShape3D and child.shape.backface_collision, "exact triangleBVH retains recesses and two-sided solidity")
			var faces: PackedVector3Array = child.shape.get_faces()
			var xf: Transform3D = child.global_transform
			for index in [int(faces.size()/12.0)*3, int(faces.size()/6.0)*3, int(faces.size()/4.0)*3]:
				index = mini(index, faces.size()-3)
				var a := xf * faces[index]
				var b := xf * faces[index+1]
				var c := xf * faces[index+2]
				var normal := (b-a).cross(c-a).normalized()
				if normal.length_squared() < 0.9: continue
				var point := (a+b+c)/3.0
				pass
				var from := point + normal * 0.4
				var to := point - normal * 0.4
				var query := PhysicsRayQueryParameters3D.create(from,to,1,exclusions)
				var hit := space.intersect_ray(query)
				pass
				check(not hit.is_empty() and on_surface(hit.position, faces, xf), "head/worldray matches visibletriangle within6mm")
				check(not hit.is_empty() and on_surface(hit.position,rendered,Transform3D.IDENTITY), "collision independently matches actual renderedmesh within6mm")
				var bullet := Ballistic.create(self,from,to,exclusions)
				var bhit := space.intersect_ray(bullet)
				check(not bhit.is_empty() and on_surface(bhit.position, faces, xf), "ballistic ray hits same renderedterrain")
				var sweep := PhysicsShapeQueryParameters3D.new()
				sweep.shape = sphere
				sweep.transform = Transform3D(Basis.IDENTITY,from)
				sweep.motion = to-from
				sweep.collision_mask = 1
				sweep.exclude = exclusions
				var motion := space.cast_motion(sweep)
				check(motion[0]<0.9 or not space.intersect_shape(sweep).is_empty(), "12cm head sweep cannot pass through visibleterrain")
				if absf(normal.y)>0.45:
					var foot := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point-Vector3.UP*.25,5,exclusions))
					check(not foot.is_empty() and foot.position.distance_to(point)<.006, "actual footmask1|4 supports renderedterrain")
					count_support += 1
					if not moved and normal.y>.75 and str(body.get_parent().name).begins_with("Mountain_"):
						var actual_top := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*200,point-Vector3.UP*200,5,[actor.get_rid()]))
						if not actual_top.is_empty() and actual_top.normal.y>=.75:
							actor.position = actual_top.position+Vector3.UP*.1
							actor.velocity = Vector3.ZERO
							var supported: bool = actor._resolve_support(.3,true)
							check(supported and actor.is_supported(), "actual player support resolver stands on massif")
							if supported: movement_regions += 1
							moved = true
				count_samples += 1
				local_samples += 1
		check(local_samples>0,"perimeter region sampled")
	check(count_samples>=90 and count_support>=20,"broad perimeter coverage includes traversable slopes")
	check(movement_regions>=12,"actual player support sampled on at least12 surrounding massifs")
	actor.queue_free()
	world.queue_free()
	await process_frame
	print("TERRAIN_COLLISION_040 checks=",checks," failures=",failures," samples=",count_samples," support_samples=",count_support," headset_tested=false")
	quit(failures)






