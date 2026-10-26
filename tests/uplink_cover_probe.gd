extends SceneTree
const World = preload("res://scripts/world.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Routes = preload("res://scripts/guard_routes.gd")
var scene: Node3D
var results: Array = []
var approach := [Vector3(-18,9.6,-44),Vector3(-11.4,9.6,-43),Vector3(-11.4,9.6,-47),Vector3(6,9.6,-47),Vector3(6,13.6,-60.5),Vector3(2.5,13.6,-62.7),Vector3(2.5,17.6,-50),Vector3(8,17.6,-50),Vector3(8,17.6,-62),Vector3(15,17.6,-69)]
func _initialize(): call_deferred("run")
func ray(a:Vector3,b:Vector3)->Dictionary:
	return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func run():
	seed(90210)
	scene=Node3D.new();root.add_child(scene)
	var world=World.new();scene.add_child(world);world.build()
	var nav=Routes.new();scene.add_child(nav)
	var target=Node3D.new();scene.add_child(target)
	await physics_frame;await physics_frame
	for p in [Vector3(19.5,16.2,-76.5),Vector3(21,16.2,-76),Vector3(19.5,16.2,-74)]:
		var capsule=CapsuleShape3D.new();capsule.radius=.55;capsule.height=1.65
		var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.88);query.collision_mask=1
		var overlap=scene.get_world_3d().direct_space_state.intersect_shape(query)
		var exposed: Array=[]
		for segment in range(approach.size()-1):
			var visible:=0
			for step in range(11):
				var eye:Vector3=approach[segment].lerp(approach[segment+1],step/10.0)
				if ray(eye,p+Vector3.UP*1.1).is_empty():visible+=1
			exposed.append(visible)
		var climb_visible:=0
		for step in range(17):
			if ray(Vector3(15,1.6+step,-61.5),p+Vector3.UP*1.1).is_empty():climb_visible+=1
		var ground=ray(p+Vector3.UP,p-Vector3.UP*2)
		var row={"position":str(p),"capsule_overlaps":overlap.size(),"ground_y":ground.position.y if not ground.is_empty() else null,"approach_visible_samples_per_segment_of11":exposed,"front_climb_visible_of17":climb_visible}
		row["existing_route_to_roof_front"] = nav.route(p,Vector3(15,16,-69))
		row["proposed_east_segments_walkable"] = [nav.walkable_segment(p,Vector3(21,16,-71)),nav.walkable_segment(Vector3(21,16,-71),Vector3(15,16,-69))]
		var enemy=Enemy.new();enemy.position=p;enemy.setup(target,2);scene.add_child(enemy);enemy.set_navigation_provider(nav);enemy.set_guard_heading(Vector3(-18,9,-44)-p)
		target.position=Vector3(15,16,-69)
		enemy.notify_gunshot(target.position+Vector3.UP*1.6)
		var min_y:float=p.y;var distance:=0.0;var sight_frames:=0
		for frame in range(720):
			await physics_frame
			min_y=minf(min_y,enemy.position.y);distance=maxf(distance,enemy.position.distance_to(p))
			if enemy._has_sight:sight_frames+=1
		row["investigate12s"]={"final":str(enemy.position),"minimum_y":min_y,"max_displacement":distance,"sight_frames":sight_frames,"state":enemy.state}
		enemy.position=p;enemy.velocity=Vector3.ZERO
		enemy.set_physics_process(false)
		for child in enemy.get_children():
			if child is AudioStreamPlayer3D:child.stop();child.stream=null
		await physics_frame
		enemy.queue_free();await physics_frame
		enemy=Enemy.new();enemy.position=p;enemy.setup(target,2);scene.add_child(enemy);enemy.set_navigation_provider(nav);enemy.set_guard_heading(Vector3(-18,9,-44)-p)
		var first_exposure_frame:=-1;min_y=p.y
		for frame in range(1800):
			var t:=float(frame)/1800.0*(approach.size()-1)
			var index:=mini(int(t),approach.size()-2)
			var eye:Vector3=approach[index].lerp(approach[index+1],t-index)
			target.position=eye-Vector3.UP*1.35
			if frame%180==0:enemy.notify_gunshot(eye)
			await physics_frame
			min_y=minf(min_y,enemy.position.y)
			if first_exposure_frame<0 and ray(eye,enemy.position+Vector3.UP*1.1).is_empty():first_exposure_frame=frame
		row["moving_approach30s"]={"first_exposure_second":first_exposure_frame/60.0 if first_exposure_frame>=0 else -1,"final":str(enemy.position),"minimum_y":min_y}
		for child in enemy.get_children():
			if child is AudioStreamPlayer3D:child.stop();child.stream=null
		enemy.queue_free();await physics_frame
		results.append(row)
	var f=FileAccess.open("res://../reports/uplink-cover-probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"seed":90210,"world_sha256":FileAccess.get_sha256("res://scripts/world.gd"),"enemy_sha256":FileAccess.get_sha256("res://scripts/enemy.gd"),"approach_eye_positions":approach,"results":results},"\t"));f.close()
	print("UPLINK_COVER_PROBE_COMPLETE candidates=",results.size())
	scene.queue_free()
	await create_timer(.15).timeout;quit()
