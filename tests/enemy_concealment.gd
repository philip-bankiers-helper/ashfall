extends SceneTree
# Real physics geometry and AshWorld lighting provider; no rendered/GPU session.
const Enemy = preload("res://scripts/enemy.gd")
const World = preload("res://scripts/world.gd")
class TestTarget extends CharacterBody3D:
	var exposure_provider: Node
var checks := 0
var failures := 0
var target: TestTarget
var enemy
var environment

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func solid(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	root.add_child(body)
	return body

func reset_detection(speed: float = 0.0) -> void:
	enemy.detection_level = 0.0
	enemy.alert_memory = 0.0
	enemy._has_sensed_aim = false
	enemy._has_sight = false
	target.velocity = Vector3(speed, 0, 0)

func acquire_seconds(speed: float = 0.0) -> float:
	reset_detection(speed)
	var aim := target.position + Vector3.UP * 1.35
	for step in range(200):
		enemy._update_detection(aim, (enemy.position + Vector3.UP * 1.4).distance_to(aim), 0.1)
		if enemy._has_sight: return (step + 1) * 0.1
	return 20.0

func run() -> void:
	environment = World.new()
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation.x = -PI / 2.0
	sun.light_energy = 1.15
	environment.add_child(sun)
	environment.sun_light = sun
	target = TestTarget.new()
	target.exposure_provider = environment
	root.add_child(target)
	enemy = Enemy.new()
	enemy.setup(target, 0)
	enemy.position = Vector3(0, 0, 20)
	root.add_child(enemy)
	enemy.set_guard_heading(target.position - enemy.position)
	enemy.set_physics_process(false)
	await physics_frame
	var aim := Vector3(0, 1.35, 0)
	var sunlight: float = environment.get_light_exposure(aim)
	var sun_time := acquire_seconds()
	var roof := solid(Vector3(0, 3, 0), Vector3(6, 0.2, 6))
	await physics_frame
	var shadow: float = environment.get_light_exposure(aim)
	var shadow_time := acquire_seconds()
	check(is_equal_approx(sunlight, 0.84) and is_equal_approx(shadow, 0.12), "actual sun ray distinguishes roof shadow from sunlight")
	check(enemy._clear_line(aim), "roof leaves identical enemy-to-head sightline unobstructed")
	check(shadow_time > sun_time * 2.5, "stationary shadow detection substantially slower than sunlight")
	var moving_time := acquire_seconds(4.5)
	check(moving_time < shadow_time * 0.7, "motion increases detection in same shadow")
	check(shadow_time < 10.0, "shadow does not grant invisibility")
	enemy.position.z = 3.0
	var close_time := acquire_seconds()
	check(close_time <= 0.5, "close enemy notices concealed player within half second")
	enemy.position.z = 20.0
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(2, 1.35, 0)
	lamp.omni_range = 6.0
	lamp.light_energy = 2.0
	environment.add_child(lamp)
	environment.authored_lights.append(lamp)
	var lit: float = environment.get_light_exposure(aim)
	var lit_time := acquire_seconds()
	var lamp_blocker := solid(Vector3(1, 1.35, 0), Vector3(0.1, 2, 0.6))
	await physics_frame
	var occluded: float = environment.get_light_exposure(aim)
	var occluded_time := acquire_seconds()
	check(lit > shadow + 0.2 and is_equal_approx(occluded, shadow), "occluded local lamp contributes no exposure")
	check(occluded_time > lit_time and enemy._clear_line(aim), "lamp occlusion reduces detection with enemy LOS still clear")
	var cover := solid(Vector3(0, 2, 10), Vector3(6, 4, 0.4))
	await physics_frame
	reset_detection(4.5)
	for step in range(100): enemy._update_detection(aim, 20.0, 0.1)
	check(not enemy._has_sight and enemy.detection_level == 0.0, "full cover prevents visual detection even in motion")
	enemy.notify_gunshot(target.position)
	enemy._update_detection(aim, 20.0, 0.1)
	check(enemy.state == enemy.State.PURSUE and not enemy._has_sight, "gunshot causes investigation without seeing through cover")
	for step in range(65): enemy._update_detection(aim, 20.0, 0.1)
	check(enemy.alert_memory == 0.0 and enemy.detection_level == 0.0, "alert memory and detection decay while target hidden")
	cover.queue_free()
	await process_frame
	reset_detection()
	enemy.take_damage(1.0)
	enemy._update_detection(aim, 20.0, 0.1)
	check(enemy._has_sight and enemy.alert_memory == 6.0, "hit alerts enemy in shadow when physical sightline is clear")
	print("CONCEALMENT_TIMES sun=", sun_time, " shadow=", shadow_time, " moving_shadow=", moving_time, " close_shadow=", close_time, " lamp=", lit_time, " occluded_lamp=", occluded_time)
	print("CONCEALMENT_TESTS checks=", checks, " failures=", failures)
	for voice in root.find_children("*", "AudioStreamPlayer3D", true, false):
		voice.stop()
		voice.stream = null
	for child in root.get_children(): child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)
