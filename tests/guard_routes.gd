extends SceneTree
const World = preload("res://scripts/world.gd")
const Enemy = preload("res://scripts/enemy.gd")
var provider
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func traverse(start: Vector3, goal: Vector3, kind: int = 0) -> Dictionary:
	var target := Node3D.new()
	target.position = goal
	root.add_child(target)
	var unit := Enemy.new()
	unit.setup(target, kind)
	unit.position = start + Vector3.UP * 0.1
	root.add_child(unit)
	unit.set_physics_process(false)
	var follower = provider.begin_route(start, goal, 2.2, 1.0)
	var maximum_step := 0.0
	var elapsed := 0.0
	var max_height := start.y
	for frame in range(9000):
		var route_direction: Vector3 = follower.direction(unit.position, 1.0 / 90.0)
		if follower.finished or follower.aborted: break
		var before := unit.position
		unit._avoid_time = maxf(0, unit._avoid_time - 1.0 / 90.0)
		var direction: Vector3 = unit._safe_direction(route_direction, true)
		unit.velocity.x = move_toward(unit.velocity.x, direction.x * 2.2, 5.0 / 90.0)
		unit.velocity.z = move_toward(unit.velocity.z, direction.z * 2.2, 5.0 / 90.0)
		unit.velocity.y -= 18.0 / 90.0
		if unit.is_on_floor():
			unit.velocity.y = -0.1
			unit._try_step(1.0 / 90.0)
		unit.move_and_slide()
		elapsed += 1.0 / 90.0
		maximum_step = maxf(maximum_step, before.distance_to(unit.position))
		max_height = maxf(max_height, unit.position.y)
		await physics_frame
	var result := {"reached": follower.finished, "seconds": elapsed, "index": follower.index, "abort_reason": follower.abort_reason, "position": unit.position, "max_frame_step": maximum_step, "max_height": max_height}
	unit.queue_free()
	target.queue_free()
	await process_frame
	return result
func autonomous(start: Vector3, goal: Vector3) -> Dictionary:
	var target := Node3D.new()
	target.position = goal
	root.add_child(target)
	var unit := Enemy.new()
	unit.setup(target, 0)
	unit.position = start + Vector3.UP * 0.1
	root.add_child(unit)
	unit.set_physics_process(false)
	unit.set_difficulty(1.0)
	unit.set_navigation_provider(provider)
	unit.notify_gunshot(goal)
	target.position = Vector3(1000, 500, 1000) # No continuing visual/audio information.
	var reached := false
	var elapsed := 0.0
	var arrival_time := 0.0
	var maximum_step := 0.0
	for frame in range(9000):
		var before := unit.position
		unit._physics_process(1.0 / 90.0)
		elapsed += 1.0 / 90.0
		maximum_step = maxf(maximum_step, before.distance_to(unit.position))
		if unit._route_follow != null and unit._route_follow.finished and not reached:
			reached = true
			arrival_time = elapsed
		if unit.state == Enemy.State.PATROL: break
		await physics_frame
	var result := {"reached": reached, "arrival_seconds": arrival_time, "total_seconds": elapsed, "returned_patrol": unit.state == Enemy.State.PATROL, "remembered_goal": unit._last_seen == goal, "position": unit.position, "max_frame_step": maximum_step}
	unit.queue_free()
	target.queue_free()
	await process_frame
	return result
func run():
	var world := World.new()
	root.add_child(world)
	world.build()
	var script_path: String = "res://scripts/guard_routes.gd"
	provider = load(script_path).new()
	root.add_child(provider)
	await physics_frame
	for index in range(provider._anchors.size()):
		for adjacent in provider._graph.get_point_connections(index):
			if adjacent > index: print("EDGE ", index, "->", adjacent, " valid=", provider.walkable_segment(provider._anchors[index], provider._anchors[adjacent]))
	var path: PackedVector3Array = provider.route(Vector3(-29, 0, -26.5), Vector3(-18, 8, -43))
	print("ROUTE ground_roof=", path)
	check(not path.is_empty(), "ground-to-roof authored corridor connects")
	check(provider.route(Vector3(-29, 0, -26.5), Vector3(-18, 3, -43)).is_empty(), "interior unsupported off-floor destination rejected")
	var muzzle_route: PackedVector3Array = provider.route(Vector3(-29, 0, -26.5), Vector3(-18, 9.5, -43))
	check(not muzzle_route.is_empty() and absf(muzzle_route[-1].y - 8.0) < 0.1, "muzzle-height sound report resolves to nearby physical floor")
	check(provider.route(Vector3(-29, 0, -26.5), Vector3(-18, 13, -43)).is_empty(), "unsupported airborne report cannot snap across a storey")
	var stopped = provider.begin_route(Vector3(-29, 0, -26.5), Vector3(-18, 8, -43), 2.2, 1.0)
	for i in range(320): stopped.direction(Vector3(-29, 0, -26.5), 1.0 / 90.0)
	check(stopped.aborted and stopped.abort_reason == "blocked", "stalled route aborts after three seconds without progress")
	var bounded = provider.begin_route(Vector3(-29, 0, -26.5), Vector3(15, 16, -69), 1.4, 1.0)
	bounded.direction(Vector3(-29, 0, -26.5), 56.0)
	check(bounded.aborted and bounded.abort_reason == "time_budget", "lost target investigation cannot exceed fifty-five seconds")
	for pair in [[Vector3(-29, 0, -26.5), Vector3(-18, 8, -43)], [Vector3(-18, 8, -43), Vector3(15, 16, -69)], [Vector3(-18, 8, -43), Vector3(-29, 0, -26.5)]]:
		var result := await traverse(pair[0], pair[1])
		print("TRAVERSE ", pair, " ", result)
		check(result.reached, "collision-driven guard traverses authored route")
		check(result.max_frame_step < 0.41, "no traversal frame teleports beyond bounded step assist")
		var ai_result := await autonomous(pair[0], pair[1])
		print("AUTONOMOUS ", pair, " ", ai_result)
		check(ai_result.reached and ai_result.max_frame_step < 0.41, "production enemy AI physically follows remembered vertical route")
		check(ai_result.remembered_goal, "hidden target relocation cannot change route destination")
		check(ai_result.returned_patrol and ai_result.total_seconds - ai_result.arrival_seconds < 12.0, "arrived investigation expires into patrol after bounded local search")
	print("GUARD_ROUTE_TESTS checks=", checks, " failures=", failures)
	for child in root.get_children(): child.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)





