extends SceneTree
const World = preload("res://scripts/world.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Routes = preload("res://scripts/guard_routes.gd")
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func run():
	seed(90210)
	var world := World.new()
	root.add_child(world)
	world.build()
	var routes := Routes.new()
	root.add_child(routes)
	var target := Node3D.new()
	root.add_child(target)
	await physics_frame
	await physics_frame
	var goal := Vector3(15, 16, -69)
	for start in [Vector3(21, 16.2, -76), Vector3(19.5, 16.2, -74), Vector3(9.5, 16.2, -76)]:
		var unit := Enemy.new()
		unit.setup(target, 2)
		unit.position = start
		root.add_child(unit)
		unit.set_physics_process(false)
		unit.set_navigation_provider(routes)
		unit.notify_gunshot(goal)
		target.position = Vector3(1000, 500, 1000)
		var reached := false
		var minimum_y: float = start.y
		var maximum_step := 0.0
		var elapsed := 0.0
		for frame in range(2700):
			var previous: Vector3 = unit.position
			unit._physics_process(1.0 / 90.0)
			elapsed += 1.0 / 90.0
			minimum_y = minf(minimum_y, unit.position.y)
			maximum_step = maxf(maximum_step, previous.distance_to(unit.position))
			if unit._route_follow != null and unit._route_follow.finished:
				reached = true
				break
			if unit.state == Enemy.State.PATROL: break
			await physics_frame
		print("ROOF_TRAVERSAL start=", start, " reached=", reached, " final=", unit.position, " seconds=", elapsed, " min_y=", minimum_y, " max_step=", maximum_step)
		check(reached and unit.position.distance_to(goal) < 0.6, "armored guard physically walks around equipment house to remembered point")
		check(minimum_y > 15.8 and maximum_step < 0.41, "roof route never drops a floor or teleports")
		check(unit._last_seen == goal and not unit._has_sight, "hidden target cannot redirect roof investigation")
		unit.queue_free()
		await process_frame
	print("ROOF_ROUTE_TESTS checks=", checks, " failures=", failures)
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)

