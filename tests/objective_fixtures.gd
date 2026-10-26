extends SceneTree
var passes := 0
var failures := 0
var disabled_count := 0
var opened_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passes += 1; print("PASS ", label)
	else: failures += 1; printerr("FAIL ", label)

func ray(world: Node3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask))

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var unit = load("res://scripts/interference_unit.gd").new()
	world.add_child(unit)
	unit.disabled.connect(func(): disabled_count += 1)
	var gate = load("res://scripts/spillway_gate.gd").new()
	gate.position.x = 10
	world.add_child(gate)
	gate.opened.connect(func(): opened_count += 1)
	await physics_frame
	await physics_frame
	check(ray(world, Vector3(0, 1.2, 3), Vector3(0, 1.2, -3), 4).get("collider") == unit, "weapon layer ray actually hits unit")
	unit.set_active(false)
	unit.take_damage(999)
	check(unit.health == 90 and disabled_count == 0, "inactive unit ignores damage")
	unit.set_active(true)
	unit.take_damage(NAN)
	unit.take_damage(-10)
	check(unit.health == 90, "malformed damage does not alter health")
	unit.take_damage(30)
	check(unit.health == 60 and not unit.is_disabled, "partial rifle damage retained")
	unit.take_damage(100)
	unit.take_damage(100)
	check(unit.health == 0 and unit.is_disabled and disabled_count == 1, "lethal damage disables once with clamped health")
	check(unit.get_hit_feedback() == "INTERFERENCE DISABLED", "shared weapon hit feedback reports objective result")
	unit.set_paused(true)
	unit._process(1)
	check(unit._effect_time == 0, "paused objective effect does not advance")
	unit.set_paused(false)
	unit._process(1)
	check(not unit.is_processing() and not unit._sparks[0].visible, "bounded effect finishes without persistent sparks")
	unit.reset()
	check(unit.health == 90 and not unit.is_disabled and unit._antenna.rotation == Vector3.ZERO, "unit reset restores health and antenna")
	unit.take_damage(90)
	check(disabled_count == 2, "reset objective can disable again")
	check(not ray(world, Vector3(10, 1.5, 3), Vector3(10, 1.5, -3), 1).is_empty(), "closed gate blocks actual physics ray")
	gate.activate()
	gate.activate()
	await physics_frame
	check(gate.is_open and opened_count == 1 and ray(world, Vector3(10, 1.5, 3), Vector3(10, 1.5, -3), 1).is_empty(), "activation opens collision immediately and emits once")
	check(not ray(world, Vector3(12.2, 1.5, 3), Vector3(12.2, 1.5, -3), 1).is_empty(), "open gate keeps stationary frame collision")
	gate.set_paused(true)
	var travel: float = gate._travel
	gate._process(1)
	check(gate._travel == travel and gate._barrier.collision_layer == 0, "pause freezes animation without restoring unsafe blocking collision")
	gate.set_paused(false)
	gate._process(1)
	check(is_equal_approx(gate._panel.position.y, 3.1) and not gate.is_processing(), "visual panel retracts fully with bounded animation")
	gate.reset()
	await physics_frame
	check(not gate.is_open and gate._panel.position == Vector3.ZERO and not ray(world, Vector3(10, 1.5, 3), Vector3(10, 1.5, -3), 1).is_empty(), "gate reset restores mesh and actual blocker")
	unit._sound.stop()
	unit._sound.stream = null
	await create_timer(0.2).timeout
	world.free()
	await process_frame
	print("OBJECTIVE_FIXTURES_RESULT passes=", passes, " failures=", failures, " headset_tested=false")
	quit(0 if failures == 0 else 1)
