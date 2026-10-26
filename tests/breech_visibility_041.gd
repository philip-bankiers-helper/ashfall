extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var gun=load("res://scripts/shotgun.gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
	for i in range(2):
		var expected:=Vector3(-.027 if i==0 else .027,.020,-.113)
		check(gun.to_local(gun.chamber_markers[i].global_position).distance_to(expected)<.0001,"closed chamber remains exactly aligned with original barrel %d"%i)
	gun.eject_magazine();gun.grab_magazine();gun.insert_magazine();gun._process(.2)
	check(gun.hinge.rotation.x<-.71,"barrels physically open")
	var targets:Array[Vector3]=[]
	for marker in gun.chamber_markers:targets.append(marker.global_position)
	var bodies:Array[StaticBody3D]=[]
	for mesh in gun.model.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null or mesh in gun.chamber_live or mesh in gun.chamber_spent:continue
		var body:=StaticBody3D.new();body.collision_layer=16;body.collision_mask=0;body.set_meta("mesh_name",str(mesh.name))
		var collision:=CollisionShape3D.new();collision.shape=mesh.mesh.create_trimesh_shape();body.add_child(collision);root.add_child(body);body.global_transform=mesh.global_transform;bodies.append(body)
	await physics_frame
	for eye in [Vector3(0,.50,.35),Vector3(-.12,.55,.40),Vector3(.12,.55,.40)]:
		for i in range(2):
			var from:Vector3=gun.to_global(eye)
			var query:=PhysicsRayQueryParameters3D.create(from,targets[i],16)
			query.hit_back_faces=true
			var hit:Dictionary=gun.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():print("OCCLUDER ",hit.collider.get_meta("mesh_name")," at ",gun.to_local(hit.position)," target ",gun.to_local(targets[i]))
			check(hit.is_empty(),"actual visible mesh ray from plausible above/rear eye "+str(eye)+" reaches chamber "+str(i))
	for body in bodies:body.free()
	gun.shutdown();await create_timer(.2).timeout;gun.free();actor.free();await process_frame
	print("BREECH_VISIBILITY_041 checks=",checks," failures=",failures)
	quit(failures)

