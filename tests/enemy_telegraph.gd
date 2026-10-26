extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func run():
	var target := Node3D.new()
	root.add_child(target)
	var unit := Enemy.new()
	unit.setup(target)
	root.add_child(unit)
	unit.set_physics_process(false)
	var source := Vector3(12, 17.4, -65)
	var aim := Vector3(15, 17.3, -69)
	for i in range(500):
		unit._draw_beam(source, aim + Vector3(sin(float(i)), 0, 0))
	unit._draw_beam(source, aim)
	var basis: Basis = unit._beam.global_basis
	var a: Vector3 = unit._beam.global_transform * Vector3(0, -0.5, 0)
	var b: Vector3 = unit._beam.global_transform * Vector3(0, 0.5, 0)
	print("TELEGRAPH_GEOMETRY basis_lengths=", Vector3(basis.x.length(), basis.y.length(), basis.z.length()), " actual_endpoints=", a, ",", b, " expected=", source, ",", aim)
	check(absf(basis.x.length() - 1.0) < 0.001 and absf(basis.z.length() - 1.0) < 0.001, "repeated beam transform never accumulates radial scale")
	check(a.distance_to(source) < 0.001 and is_equal_approx(b.distance_to(aim), 0.85), "beam stops short of head without moving emitter")
	check(is_equal_approx(unit._beam.mesh.top_radius, 0.004) and not unit._beam.mesh.cap_top, "thin open cylinder cannot display an oversized end cap")
	var both_eyes_clear := true
	for eye_offset in [-0.032, 0.032]:
		var eye := aim + Vector3(eye_offset, 0, 0)
		for i in range(101):
			var centerline := a.lerp(b, float(i) / 100.0)
			both_eyes_clear = both_eyes_clear and centerline.distance_to(eye) > 0.8
	check(both_eyes_clear, "physical 64mm eye separation leaves over 80cm head clearance")
	unit.locked_aim = aim
	unit._draw_beam(source, aim)
	check(unit.locked_aim == aim, "visual head exclusion never changes locked attack aim")
	check(unit._beam.material_override.shader.code.contains("length(VERTEX)") and unit._beam.material_override.shader.code.contains("discard"), "each eye rejects near-camera beam fragments")
	unit._draw_beam(Vector3.ZERO, Vector3(0.5, 0, 0))
	check(not unit._beam.visible, "close range retains emitter warning without face-crossing beam")
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(0, 1.4, -3)
	root.add_child(blocker)
	await physics_frame
	await physics_frame
	unit._draw_beam(Vector3(0, 1.4, 0), Vector3(0, 1.4, -10))
	b = unit._beam.global_transform * Vector3(0, 0.5, 0)
	check(b.z > -2.91 and b.z < -2.8, "warning beam terminates at actual cover surface")
	print("TELEGRAPH_TESTS checks=", checks, " failures=", failures)
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)
