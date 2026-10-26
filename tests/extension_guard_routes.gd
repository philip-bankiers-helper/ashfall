extends SceneTree
const World = preload("res://scripts/world.gd")
const Extension = preload("res://scripts/campaign_extension.gd")
const Routes = preload("res://scripts/guard_routes.gd")
const Enemy = preload("res://scripts/enemy.gd")
var checks := 0
var failures := 0
var routes
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func diagnose(from: Vector3, to: Vector3):
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var side := flat.normalized().cross(Vector3.UP) * 0.58
	var offsets := [Vector3.ZERO, side, -side] if from.y > 15.0 and to.y > 15.0 else [Vector3.ZERO]
	var count := maxi(2, int(ceil(from.distance_to(to) / 0.45)))
	for i in range(count + 1):
		var point := from.lerp(to, float(i) / count)
		var hit: Dictionary = routes._ray(point + Vector3.UP * 0.65, point - Vector3.UP * 0.7)
		if hit.is_empty() or hit.normal.y < 0.25 or absf(hit.position.y - point.y) > 0.6:
			print("EDGE_SUPPORT_FAIL point=", point, " hit=", hit)
			return
		if i > 0:
			var previous := from.lerp(to, float(i - 1) / count)
			for height in [0.7, 1.4]:
				for offset in offsets:
					hit = routes._ray(previous + offset + Vector3.UP * height, point + offset + Vector3.UP * height)
					if not hit.is_empty():
						print("EDGE_CHEST_FAIL point=", point + offset + Vector3.UP * height, " hit=", hit)
						return
func traverse(start: Vector3, goal: Vector3, kind: int) -> void:
	var target := Node3D.new()
	root.add_child(target)
	var unit := Enemy.new()
	unit.setup(target, kind)
	unit.position = start + Vector3.UP * 0.12
	root.add_child(unit)
	unit.set_physics_process(false)
	unit.set_difficulty(1.0)
	unit.set_navigation_provider(routes)
	unit.notify_gunshot(goal)
	target.position = Vector3(1000, 500, 1000)
	var elapsed := 0.0
	var reached := false
	var arrival := 0.0
	var max_step := 0.0
	var min_y: float = start.y
	for frame in range(7200):
		var before := unit.position
		unit._physics_process(1.0 / 90.0)
		elapsed += 1.0 / 90.0
		max_step = maxf(max_step, before.distance_to(unit.position))
		min_y = minf(min_y, unit.position.y)
		if unit._route_follow != null and unit._route_follow.finished and not reached:
			reached = true
			arrival = elapsed
		if unit.state == Enemy.State.PATROL: break
		await physics_frame
	print("EXTENSION_GUARD start=", start, " goal=", goal, " kind=", kind, " reached=", reached, " arrival=", arrival, " elapsed=", elapsed, " final=", unit.position, " min_y=", min_y, " max_step=", max_step, " route_abort=", unit._route_follow.abort_reason if unit._route_follow != null else "no_route")
	check(reached, "guard physically traverses registered extension corridor")
	check(max_step < 0.41 and min_y > minf(start.y, goal.y) - 0.3, "extension pursuit has bounded movement with no floor loss")
	check(unit._last_seen == goal and not unit._has_sight, "hidden player relocation does not update extension route destination")
	check(unit.state == Enemy.State.PATROL and reached and elapsed - arrival < 12.0, "extension lost-contact search expires after arrival")
	unit.queue_free()
	target.queue_free()
	await process_frame
func run():
	seed(90210)
	var world := World.new()
	root.add_child(world)
	world.build()
	var extension := Extension.new()
	extension.build(world)
	routes = Routes.new()
	root.add_child(routes)
	for corridor in extension.guard_corridors:
		check(routes.register_corridor(corridor), "authored extension corridor registers within bounds")
	await physics_frame
	await physics_frame
	for corridor_index in range(extension.guard_corridors.size()):
		var corridor: PackedVector3Array = extension.guard_corridors[corridor_index]
		for index in range(corridor.size() - 1):
			if not routes.walkable_segment(corridor[index], corridor[index + 1]):
				print("EXTENSION_BLOCKED_EDGE corridor=", corridor_index, " index=", index, " from=", corridor[index], " to=", corridor[index + 1])
				diagnose(corridor[index], corridor[index + 1])
	await traverse(Vector3(15,16,-69), Vector3(29,24.6,-88), 2)
	await traverse(Vector3(47,24.6,-88), Vector3(47,22,-78), 2)
	await traverse(Vector3(47,22,-78), Vector3(52,6,-46), 0)
	await traverse(Vector3(47,22,-78), Vector3(52,6,-46), 2)
	await traverse(Vector3(52,6,-46), Vector3(47,22,-78), 0)
	await traverse(Vector3(47,6,-44), Vector3(47,0,-26), 2)
	print("EXTENSION_GUARD_TESTS checks=", checks, " failures=", failures)
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)
