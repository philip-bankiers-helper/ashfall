extends SceneTree
const World=preload("res://scripts/world.gd")
const Extension=preload("res://scripts/campaign_extension.gd")
var scene:Node3D
func _initialize():call_deferred("run")
func run():
	scene=Node3D.new();root.add_child(scene)
	var world=World.new();scene.add_child(world);world.build()
	var ext=Extension.new();ext.build(world)
	for p in ext.jammer_positions:
		var unit=load("res://scripts/interference_unit.gd").new();unit.position=p;scene.add_child(unit)
	var gate=load("res://scripts/spillway_gate.gd").new();gate.position=ext.gate_position;scene.add_child(gate);gate.activate()
	var actor=CharacterBody3D.new();actor.floor_snap_length=.5;actor.floor_max_angle=deg_to_rad(48);actor.collision_layer=2;actor.collision_mask=5
	var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7;shape.shape=capsule;shape.position.y=.88;actor.add_child(shape);scene.add_child(actor)
	await physics_frame;await physics_frame
	var results:Dictionary={}
	var spawn_ok:=true
	for group in ext.mission_spawns:
		for p in group:
			var heavy=CapsuleShape3D.new();heavy.radius=.55;heavy.height=1.65
			var query=PhysicsShapeQueryParameters3D.new();query.shape=heavy;query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.88);query.collision_mask=5
			var overlaps=scene.get_world_3d().direct_space_state.intersect_shape(query)
			if not overlaps.is_empty():spawn_ok=false;print("SPAWN_OVERLAP ",p)
	results["spawn_clearance"]={"pass":spawn_ok,"count":8}
	for name in ["crown_entry","spillway_entry","spillway_stairs","return"]:
		var points:PackedVector3Array=ext.route_waypoints[name]
		actor.position=points[0]+Vector3.UP*.05;actor.velocity=Vector3.ZERO
		var index:=1;var frames:=0;var min_y:float=actor.position.y
		while index<points.size() and frames<12000:
			await physics_frame
			var diff:Vector3=points[index]-actor.position
			if Vector2(diff.x,diff.z).length()<.32 and absf(diff.y)<.65:index+=1;continue
			var direction:=Vector3(diff.x,0,diff.z).normalized()
			actor.velocity.x=direction.x*4.2;actor.velocity.z=direction.z*4.2;actor.velocity.y-=18.0/60.0
			actor.move_and_slide();frames+=1;min_y=minf(min_y,actor.position.y)
		results[name]={"pass":index==points.size(),"index":index,"points":points.size(),"final":str(actor.position),"minimum_y":min_y,"simulated_seconds":frames/60.0}
		print("EXTENSION_ROUTE ",name," ",results[name])
	var f=FileAccess.open("res://../reports/extension-geometry.json",FileAccess.WRITE);f.store_string(JSON.stringify(results,"\t"));f.close()
	var ok:bool=results.values().all(func(v):return v["pass"])
	scene.queue_free();await process_frame;quit(0 if ok else 1)

