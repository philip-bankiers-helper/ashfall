extends SceneTree
const World = preload("res://scripts/world.gd")
const Routes = preload("res://scripts/guard_routes.gd")
const Enemy = preload("res://scripts/enemy.gd")
class Target extends CharacterBody3D:
	var exposure_provider: Node
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _initialize(): call_deferred("run")
func run():
	var world := World.new()
	root.add_child(world)
	world.build()
	var routes := Routes.new()
	root.add_child(routes)
	var target := Target.new()
	target.position = Vector3(-18, 8, -43)
	target.exposure_provider = world
	root.add_child(target)
	await physics_frame
	var timings: Array[float] = []
	var valid := 0
	var batch_start := Time.get_ticks_usec()
	for i in range(8):
		var from := Vector3(-29, 0, -26.5 - i * 0.05)
		var before := Time.get_ticks_usec()
		var path := routes.route(from, target.position)
		timings.append(float(Time.get_ticks_usec() - before))
		if not path.is_empty(): valid += 1
	var batch := Time.get_ticks_usec() - batch_start
	var mean := 0.0
	for timing in timings: mean += timing / timings.size()
	print("ROUTE_CPU direct eight_batch_us=", batch, " mean_us=", mean, " max_us=", timings.max(), " valid=", valid, " samples=", timings)
	check(valid == 8, "all representative cross-floor requests resolve")
	routes.set_physics_process(false)
	routes.invalidate_static_cache()
	var requests: Array = []
	var owners: Array[Node3D] = []
	batch_start = Time.get_ticks_usec()
	for i in range(8):
		var owner := Node3D.new()
		root.add_child(owner)
		owners.append(owner)
		var origin := Vector3(-29, 0, -26.5 - i * 0.05) if i % 2 == 0 else Vector3(-18 + i * 0.05, 8, -43)
		var destination := target.position if i % 2 == 0 else Vector3(15, 16, -69)
		requests.append(routes.request_route(owner, origin, destination, 2.2, 1.0))
	print("ROUTE_CPU queued_enqueue_eight_us=", Time.get_ticks_usec() - batch_start)
	requests[0].direction(Vector3(-29, 0, -26.5), 3.0)
	check(requests[0].pending and requests[0].elapsed == 0.0, "waiting request consumes no investigation budget")
	var queued_timings: Array[float] = []
	var bounded := true
	for i in range(8):
		var completed_before := routes.completed_queries
		routes._physics_process(1.0 / 90.0)
		bounded = bounded and routes.completed_queries - completed_before <= 1
		queued_timings.append(float(routes.last_query_usec))
		await physics_frame
	mean = 0.0
	for timing in queued_timings: mean += timing / queued_timings.size()
	print("ROUTE_CPU queued eight_frames mean_us=", mean, " max_us=", queued_timings.max(), " samples=", queued_timings)
	check(bounded and routes._pending.is_empty(), "eight requests drain over eight frames with at most one query per frame")
	valid = 0
	for request in requests:
		if not request.pending and not request.aborted and not request.points.is_empty(): valid += 1
	check(valid == 8, "budgeted requests preserve valid route results")
	var obsolete = routes.request_route(owners[0], Vector3(-29, 0, -26.5), target.position, 2.2, 1.0)
	var replacement = routes.request_route(owners[0], Vector3(-29, 0, -26.5), target.position, 2.2, 1.0)
	check(obsolete.aborted and routes._pending.size() == 1, "new observation replaces obsolete queued request")
	owners[0].queue_free()
	await process_frame
	var completed_before := routes.completed_queries
	routes._physics_process(1.0 / 90.0)
	check(routes.completed_queries == completed_before and routes._pending.is_empty(), "removed guard never spends route query budget")
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	collider.shape = box
	blocker.add_child(collider)
	blocker.position = target.position + Vector3.UP
	root.add_child(blocker)
	await physics_frame
	await physics_frame
	check(routes.route(Vector3(-29, 0, -26.5), target.position).is_empty(), "cached corridor does not reuse blocked endpoint attachment")
	blocker.queue_free()
	await process_frame
	await physics_frame
	check(not routes.route(Vector3(-29, 0, -26.5), target.position).is_empty(), "endpoint becomes usable again after physical blocker removed")
	var guards: Array[AshEnemy] = []
	for i in range(8):
		var unit := Enemy.new()
		unit.setup(target, i % 3)
		unit.position = Vector3(-20 + i * 0.6, 8.2, -40)
		root.add_child(unit)
		unit.set_physics_process(false)
		unit.set_guard_heading(target.position - unit.position)
		guards.append(unit)
	await physics_frame
	var perception: Array[float] = []
	for frame in range(120):
		var before := Time.get_ticks_usec()
		for unit in guards:
			var aim := target.position + Vector3.UP * 1.35
			unit._update_detection(aim, unit.position.distance_to(aim), 0.17)
		perception.append(float(Time.get_ticks_usec() - before))
		await physics_frame
	mean = 0.0
	for timing in perception: mean += timing / perception.size()
	print("PERCEPTION_CPU eight_guard_batch mean_us=", mean, " max_us=", perception.max(), " samples=120 actual_world_lighting=true")
	print("ROUTE_COST_TESTS checks=", checks, " failures=", failures, " CPU_only_not_GPU_or_headset=true")
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)
