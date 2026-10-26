extends SceneTree
# Headless: --path AshfallVR --script res://tests/enemy_perception.gd
const Enemy = preload("res://scripts/enemy.gd")
const Bank = preload("res://scripts/audio_bank.gd")
class Target extends CharacterBody3D:
	var exposure_provider: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var target := Target.new()
	root.add_child(target)
	var enemy := Enemy.new()
	enemy.setup(target, 0)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_guard_heading(Vector3.FORWARD)
	target.position = Vector3(0, 0, 15)
	await physics_frame
	for i in range(100): enemy._update_detection(target.position + Vector3.UP * 1.35, 15.0, 0.1)
	check(not enemy._has_sight and enemy.detection_level == 0.0, "bright target behind guard is not visually acquired")
	enemy.set_guard_heading(Vector3.BACK)
	for i in range(20): enemy._update_detection(target.position + Vector3.UP * 1.35, 15.0, 0.1)
	check(enemy._has_sight, "authored guard heading acquires same unobstructed target")
	enemy.set_guard_heading(Vector3.FORWARD)
	check(enemy._within_fov(Vector3(8, 1.4, -10), 13.0), "ground forward cone includes 39 degree target")
	check(not enemy._within_fov(Vector3(20, 1.4, -5), 21.0), "ground cone excludes 76 degree target")
	check(not enemy._within_fov(Vector3(0, 30, -10), 30.0), "vertical cone excludes high overhead target")
	enemy.alert_memory = 0.0
	enemy.detection_level = 0.0
	target.position = Vector3(0, 0, 3)
	for i in range(4): enemy._update_detection(target.position + Vector3.UP * 1.35, 3.0, 0.1)
	check(enemy._has_sight, "close rear proximity detects with physical LOS within 0.4 seconds")
	enemy.state = Enemy.State.PATROL
	enemy._phase = 0.0
	enemy.age = 3.0
	enemy._update_orientation(2.0)
	var scan := enemy._visual.rotation.y
	target.position = Vector3(-100, 100, 100)
	enemy._update_orientation(2.0)
	check(is_equal_approx(scan, enemy._visual.rotation.y) and enemy._turret.rotation.x == 0.0, "patrol scan and pitch ignore undiscovered player position")
	target.position = Vector3(0, 0, -15)
	enemy.set_guard_heading(Vector3.FORWARD)
	enemy.alert_memory = 6.0
	enemy._update_detection(target.position + Vector3.UP * 1.35, 15.0, 0.1)
	var observed := enemy._last_seen_aim
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 1)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0, 10, -5)
	root.add_child(wall)
	target.position = Vector3(8, 12, -15)
	await physics_frame
	enemy._update_detection(target.position + Vector3.UP * 1.35, 23.0, 0.1)
	check(not enemy._has_sight and enemy._last_seen_aim == observed, "cover preserves last observed position instead of hidden target")
	enemy.state = Enemy.State.PURSUE
	enemy._update_orientation(2.0)
	check(absf(enemy._visual.rotation.y) < 0.01 and absf(enemy._turret.rotation.x) < 0.01, "covered target cannot steer guard yaw or pitch")
	enemy.locked_aim = observed
	enemy._change_state(Enemy.State.WINDUP)
	enemy._sight_timer = 100.0
	enemy._physics_process(0.1)
	check(enemy.locked_aim == observed, "early windup cannot track target through cover")
	enemy.notify_gunshot(target.position)
	enemy._update_detection(target.position + Vector3.UP * 1.35, 23.0, 0.1)
	check(not enemy._has_sight, "auditory FOV exception never bypasses cover")
	check(enemy._within_fov(target.position, 23.0), "recent localized gunshot permits turning toward cue")
	check(not enemy._within_fov(Vector3(0, 0, 20), 20.0), "cue does not grant unrelated rear vision")
	var boss := Enemy.new()
	boss.setup(target, 3)
	boss.position = Vector3(30, 3, 0)
	root.add_child(boss)
	boss.set_physics_process(false)
	boss._has_last_known = true
	boss._last_seen_aim = Vector3(30, 1.35, -15)
	boss._last_seen = Vector3(30, 0, -15)
	boss._has_sight = false
	boss._sight_timer = 100.0
	boss.state = Enemy.State.WINDUP
	boss.locked_aim = boss._last_seen_aim
	var initial := boss.position
	boss._physics_process(0.01)
	var vertical_velocity := boss.velocity.y
	boss.position = initial
	boss.age = 0.0
	target.position.y = 100.0
	boss._physics_process(0.01)
	check(is_equal_approx(vertical_velocity, boss.velocity.y), "hidden player altitude cannot control WARDEN hover")
	check(enemy._voice.bus == "SFX" and enemy._voice.max_polyphony <= 2 and enemy._impact_voice.max_polyphony <= 2, "enemy voices use SFX bus with bounded polyphony")
	check(enemy._sound("fire") == Bank.sample("enemy_fire", 0), "fire uses shared authored audio bank")
	check(enemy._sound("charge") == Bank.sample("enemy_charge", 0) and enemy._sound("death") == Bank.sample("enemy_break", 0), "charge and destruction use distinct shared audio cues")
	check(enemy._sound("fire", 1) != enemy._sound("fire", 0), "fire variations are cached distinct samples")
	print("PERCEPTION_TESTS checks=", checks, " failures=", failures)
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	Bank._cache.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)
