extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
const World = preload("res://scripts/world.gd")
class Target extends CharacterBody3D:
	var exposure_provider: Node
var target: Target
var checks := 0
var failures := 0
var hits := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func solid(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = pos
	root.add_child(body)
	return body
func guard(value: float, pos: Vector3, kind: int = 0) -> AshEnemy:
	var unit := Enemy.new()
	unit.setup(target, kind)
	unit.position = pos
	root.add_child(unit)
	unit.set_physics_process(false)
	unit.set_difficulty(value)
	unit.set_guard_heading(target.position - pos)
	return unit

func dodge_run(value: float) -> Dictionary:
	seed(1271)
	target.position = Vector3.ZERO
	var unit := guard(value, Vector3(0, 0, 15))
	unit.hit_player.connect(func(_amount: float): hits += 1)
	hits = 0
	var attacks := 0
	var moves := 0
	var dodging := false
	var direction := 1.0
	for frame in range(2700):
		var previous := unit.state
		# React 120ms after the visible aim stops tracking; move at ordinary walking speed.
		if unit.state == Enemy.State.WINDUP and unit.state_time >= unit._reaction_duration() - 0.30:
			if not dodging:
				dodging = true
				moves += 1
				direction = -1.0 if target.position.x > 0.0 else 1.0
				if absf(target.position.x - unit.locked_aim.x) > 0.01:
					direction = signf(target.position.x - unit.locked_aim.x)
			target.position.x += direction * 3.0 / 90.0
		unit._physics_process(1.0 / 90.0)
		if unit.state == Enemy.State.RECOVER and previous != unit.state:
			attacks += 1
			dodging = false
		await physics_frame
	var result := {"difficulty": value, "attacks": attacks, "dodge_responses": moves, "hits": hits}
	unit.queue_free()
	await process_frame
	return result

func detection_run(value: float) -> float:
	var unit := guard(value, Vector3(0, 0, 20))
	var duration := 10.0
	for frame in range(900):
		unit._physics_process(1.0 / 90.0)
		if unit._has_sight:
			duration = float(frame + 1) / 90.0
			break
		await physics_frame
	unit.queue_free()
	await process_frame
	return duration

func run() -> void:
	target = Target.new()
	root.add_child(target)
	solid(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await physics_frame
	var easy := await dodge_run(0.0)
	var hard := await dodge_run(1.0)
	print("DODGE_SCENARIOS easy=", easy, " hard=", hard)
	check(easy.attacks >= 4 and easy.hits == 0, "easy locked telegraphs are evaded by reactive walking")
	check(hard.attacks >= 8 and hard.hits == 0, "hard locked telegraphs are evaded with 120ms reaction and 3m/s strafe")
	target.position = Vector3.ZERO
	var environment := World.new()
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation.x = -PI / 2.0
	sun.light_energy = 1.15
	environment.add_child(sun)
	environment.sun_light = sun
	target.exposure_provider = environment
	var sunny_easy := await detection_run(0.0)
	var sunny_hard := await detection_run(1.0)
	var roof := solid(Vector3(0, 3, 0), Vector3(6, 0.2, 6))
	await physics_frame
	var shadow_easy := await detection_run(0.0)
	var shadow_hard := await detection_run(1.0)
	print("TACTICAL_DETECTION sunny_easy=", sunny_easy, " sunny_hard=", sunny_hard, " shadow_easy=", shadow_easy, " shadow_hard=", shadow_hard)
	check(shadow_easy > sunny_easy * 2.0 and shadow_hard > sunny_hard * 2.0, "real roof shadow delays acquisition at both difficulty extremes")
	check(shadow_hard < shadow_easy and shadow_hard > sunny_easy, "hard shadow still affords more concealment than easy sunlight")
	roof.queue_free()
	target.exposure_provider = null
	await process_frame
	var left := guard(1.0, Vector3(-1.0, 0, 12))
	var right := guard(1.0, Vector3(1.0, 0, 12))
	for unit in [left, right]:
		unit._update_detection(Vector3(0, 1.35, 0), 12.0, 2.0)
		unit.state = Enemy.State.PURSUE
		unit.attack_cooldown = 100.0
	var left_start := left.position
	var right_start := right.position
	for frame in range(180):
		left._physics_process(1.0 / 90.0)
		right._physics_process(1.0 / 90.0)
		await physics_frame
	print("SQUAD_ROUTES left=", left.position - left_start, " right=", right.position - right_start)
	check((left.position.x - left_start.x) * (right.position.x - right_start.x) < 0.0, "squad members take distinct opposing observed-target flanks")
	var wall := solid(Vector3(0, 10, 5), Vector3(80, 20, 1))
	for unit in [left, right]:
		unit.locked_aim = Vector3(0, 1.35, 0)
		unit._change_state(Enemy.State.WINDUP)
	await physics_frame
	var snapshots := [left._last_seen_aim, right._last_seen_aim]
	var cover_hits := 0
	left.hit_player.connect(func(_amount: float): hits += 1)
	hits = 0
	var bounded := true
	var covered_attacks := 0
	for frame in range(360):
		if frame == 100: target.position = Vector3(20, 10, -10)
		var previous := left.state
		left._physics_process(1.0 / 90.0)
		right._physics_process(1.0 / 90.0)
		if previous == Enemy.State.WINDUP and left.state == Enemy.State.RECOVER: covered_attacks += 1
		bounded = bounded and absf(left.position.y) < 0.5 and absf(right.position.y) < 0.5
		await physics_frame
	cover_hits = hits
	check(left._last_seen_aim == snapshots[0] and right._last_seen_aim == snapshots[1], "coordinated search never receives hidden lateral or vertical truth")
	check(covered_attacks == 1 and not left._has_sight and not right._has_sight and cover_hits == 0, "hard guard fires at stationary locked target but physical cover prevents damage")
	check(bounded, "ground flanking remains floor bounded when hidden target changes height")
	left.queue_free()
	right.queue_free()
	wall.queue_free()
	await process_frame
	print("TACTICS_TESTS checks=", checks, " failures=", failures)
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	var gate_exit := 0 if failures == 0 else 1
	print("TACTICS_EXIT_CODE=", gate_exit)
	quit(gate_exit)
