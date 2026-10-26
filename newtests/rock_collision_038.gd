extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:=preload("res://scripts/world.gd").new()
	root.add_child(world)
	world._model_prop("rock_07",Vector3(-31,0,-4),15,-.52,true)
	await physics_frame
	var model:Node3D=world.get_child(0)
	var space:=world.get_world_3d().direct_space_state
	var proxies:=get_nodes_in_group("ballistic_proxy_ignore")
	var surfaces:=get_nodes_in_group("ballistic_surface")
	var layers_ok:bool=proxies.size()==1 and surfaces.size()==1 and proxies[0].collision_layer==1 and surfaces[0].collision_layer==8 and surfaces[0].collision_mask==0
	var ballistic_at:=Vector3(-31.4,4,-2.2)
	var proxy_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(ballistic_at,ballistic_at-Vector3.UP*5,1))
	var visible_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(ballistic_at,ballistic_at-Vector3.UP*5,8))
	var separation_ok:bool=not proxy_hit.is_empty() and not visible_hit.is_empty() and visible_hit.collider.is_in_group("ballistic_surface") and proxy_hit.collider.is_in_group("ballistic_proxy_ignore") and absf(visible_hit.position.y-.7083)<.01
	print("DUAL_COLLISION layers=",layers_ok," visible_surface=",separation_ok," proxy=",proxy_hit," visible=",visible_hit)
	var hit_count:=0
	var low_count:=0
	var mismatch:=0
	for x in range(-30,31):
		for z in range(-30,31):
			var at:=Vector3(-31+x*.1,4,-4+z*.1)
			var high:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*5,1))
			if high.is_empty(): continue
			hit_count+=1
			if high.position.y<1.023: low_count+=1
			var low:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,high.position.y+1.45,at.z),at-Vector3.UP*5,1))
			if low.is_empty() or absf(low.position.y-high.position.y)>.002: mismatch+=1; print("MISMATCH at=",at," high=",high.position," low=",low)
	print("ROCK_CLOSED_HULL_GRID hits=",hit_count," low_chest_samples=",low_count," high_vs_head_ray_mismatches=",mismatch)
	for at in [Vector3(-31.4,4,-2.2),Vector3(-31.31288,4,-2.37383)]:
		print("FORMER_HOLE ",at," ",space.intersect_ray(PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*5,1)))
	world.free(); await physics_frame
	quit(0 if mismatch==0 and hit_count>100 and low_count>10 and layers_ok and separation_ok else 1)



