extends SceneTree
const Routes = preload("res://scripts/guard_routes.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func run():
	var routes := Routes.new()
	root.add_child(routes)
	var initial := routes._graph.get_point_count()
	check(initial == 23, "classic graph starts unchanged at twenty-three anchors")
	routes._static_edges["fixture"] = true
	var branch := PackedVector3Array([Vector3(15, 16, -69), Vector3(25, 16, -69), Vector3(25, 20, -81)])
	check(routes.register_corridor(branch), "explicit finite branch registers")
	check(routes._graph.get_point_count() == initial + 2, "existing exact endpoint reused")
	check(routes._graph.are_points_connected(18, 23) and routes._graph.are_points_connected(23, 24), "only consecutive supplied links added")
	check(not routes._graph.are_points_connected(19, 23), "nearby classic anchor gains no automatic wall-crossing edge")
	check(routes._static_edges.is_empty(), "registration invalidates static clearance cache")
	check(routes.register_corridor(branch) and routes._graph.get_point_count() == initial + 2, "repeated registration reuses points without growth")
	check(routes.register_corridor(PackedVector3Array([Vector3(25.05, 20, -81), Vector3(27, 20, -85)])) and routes._graph.get_point_count() == initial + 3, "ten-centimetre endpoint tolerance joins exact authored seam")
	var count := routes._graph.get_point_count()
	for invalid in [PackedVector3Array(), PackedVector3Array([Vector3.ZERO]), PackedVector3Array([Vector3.ZERO, Vector3(INF, 0, 0)]), PackedVector3Array([Vector3.ZERO, Vector3(41, 0, 0)]), PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0, 0)])]:
		check(not routes.register_corridor(invalid) and routes._graph.get_point_count() == count, "invalid corridor rejected without partial graph mutation")
	var oversize := PackedVector3Array()
	for i in range(65): oversize.append(Vector3(i, 0, 0))
	check(not routes.register_corridor(oversize) and routes._graph.get_point_count() == count, "per-request point budget enforced")
	check(routes.register_corridor(PackedVector3Array([Vector3(100, 6, 100), Vector3(105, 6, 100)])), "explicit disconnected local corridor may register")
	check(routes._graph.get_point_path(18, routes._graph.get_point_count() - 1).is_empty(), "disconnected corridor never acquires an invented graph bridge")
	print("ROUTE_REGISTRATION_TESTS checks=", checks, " failures=", failures)
	routes.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
