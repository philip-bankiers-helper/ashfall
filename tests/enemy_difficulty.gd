extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
class Target extends CharacterBody3D:
	var exposure_provider: Node
var checks := 0
var failures := 0
var target: Target
var hits := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func make_enemy(value: float, pos: Vector3 = Vector3(0, 0, 15)) -> AshEnemy:
	var enemy := Enemy.new()
	enemy.setup(target, 0)
	enemy.position = pos
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_guard_heading(target.position - pos)
	enemy.set_difficulty(value)
	return enemy

func scenario(value: float) -> Dictionary:
	seed(9842)
	var enemy := make_enemy(value)
	enemy.hit_player.connect(func(_amount: float): hits += 1)
	hits = 0
	var detected := -1.0
	var attacks := 0
	var old_state := enemy.state
	for frame in range(2700):
		enemy._physics_process(1.0 / 90.0)
		if enemy._has_sight and detected < 0.0: detected = float(frame) / 90.0
		if enemy.state == Enemy.State.RECOVER and old_state != enemy.state: attacks += 1
		old_state = enemy.state
		await physics_frame
	var result := {"difficulty": value, "detect_seconds": detected, "attacks_30s": attacks, "hits_30s": hits, "health": enemy.healthmax}
	enemy.queue_free()
	await process_frame
	return result

func run() -> void:
	target = Target.new()
	root.add_child(target)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	await physics_frame
	var easy := await scenario(0.0)
	var hard := await scenario(1.0)
	print("DIFFICULTY_SCENARIO easy=", easy, " hard=", hard)
	check(hard.detect_seconds < easy.detect_seconds, "hard guard acquires same exposed target sooner")
	check(hard.attacks_30s > easy.attacks_30s, "hard guard delivers more telegraphed attacks in thirty seconds")
	check(hard.hits_30s > easy.hits_30s, "hard guard is more accurate against stationary exposed player")
	check(hard.health == easy.health, "difficulty does not inflate enemy health")
	var guard := make_enemy(1.0)
	check(is_equal_approx(guard._reaction_duration(), 0.74), "hard telegraph still reserves 0.42 second locked dodge window")
	guard.set_difficulty(-5.0)
	check(guard.difficulty == 0.0, "difficulty lower bound clamped")
	guard.set_difficulty(INF)
	check(guard.difficulty == 0.5, "nonfinite difficulty safely defaults")
	guard.set_difficulty(1.0)
	var ally := make_enemy(1.0, Vector3(4, 0, 14))
	guard._update_detection(Vector3(0, 1.35, 0), 15.0, 2.0)
	check(guard._has_sight and ally._has_last_known and not ally._has_sight and ally.detection_level == 0.0, "squad relay supplies observed position without granting sight")
	check(ally._last_seen_aim == guard._last_seen_aim and ally.state == Enemy.State.PURSUE, "nearby squad investigates reported observation")
	ally.position = Vector3(2, 0, 2)
	ally._lost_time = 2.0
	var route := ally._investigate_direction()
	target.position = Vector3(50, 25, 50)
	check(ally._investigate_direction().is_equal_approx(route), "search flank is independent of hidden player movement and elevation")
	check(absf(route.x) > 0.1 and is_zero_approx(route.y), "ground search uses lateral route with no unsupported vertical teleport")
	guard.set_difficulty(0.0)
	var short_search := guard._search_duration()
	guard.set_difficulty(1.0)
	check(guard._search_duration() > short_search, "hard search persists longer before returning to patrol")
	var cover := StaticBody3D.new()
	var cover_collision := CollisionShape3D.new()
	var cover_shape := BoxShape3D.new()
	cover_shape.size = Vector3(60, 30, 1)
	cover_collision.shape = cover_shape
	cover.add_child(cover_collision)
	cover.position = Vector3(0, 10, 7)
	root.add_child(cover)
	target.position = Vector3.ZERO
	await physics_frame
	guard.alert_memory = 6.0
	for i in range(20): guard._update_detection(Vector3(0, 1.35, 0), 15.0, 0.1)
	check(not guard._has_sight, "hard difficulty with active memory still cannot see through cover")
	guard.locked_aim = Vector3(0, 1.35, 0)
	var before_hits := hits
	guard.hit_player.connect(func(_amount: float): hits += 1)
	guard._fire(guard.locked_aim)
	check(hits == before_hits, "hard difficulty attack remains blocked by physical cover")
	print("DIFFICULTY_TESTS checks=", checks, " failures=", failures)
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)
