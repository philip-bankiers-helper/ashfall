extends SceneTree
# Run headless with --xr-mode off --fixed-fps 90 --path AshfallVR
# --script res://tests/enemy_navigation.gd --log-file <absolute-output-log>
const Enemy = preload("res://scripts/enemy.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var target := Node3D.new()
	target.position = Vector3(0, 0, -25)
	root.add_child(target)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 8, 0.5)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0, 3, -2)
	root.add_child(wall)
	var scout := Enemy.new()
	scout.setup(target, 1)
	root.add_child(scout)
	scout._phase = 0.8
	scout.attack_cooldown = 999
	scout._last_seen = target.position
	scout._change_state(scout.State.PURSUE)
	var penetrated := false
	var max_flank := 0.0
	for frame in range(600):
		await physics_frame
		max_flank = maxf(max_flank, absf(scout.position.x))
		if absf(scout.position.x) < 1.5 and scout.position.z < -1.75 and scout.position.z > -2.25 and scout.position.y < 7:
			penetrated = true
	print("FLYER_ROUTE position=", scout.position, " maximum_flank=", max_flank)
	check(max_flank > 1.9, "scout chooses flank around three-metre wall")
	check(scout.position.z < -4.0, "scout proceeds beyond wall")
	check(not penetrated, "scout never crosses solid wall volume")
	check(scout.position.y > 0.5, "flying route works without ground support")
	scout.queue_free()
	wall.queue_free()
	await process_frame
	var patrol := Enemy.new()
	patrol.setup(target, 0)
	root.add_child(patrol)
	patrol.set_physics_process(false)
	target.position = Vector3(0, 0, -80)
	patrol._lost_time = 12.0
	patrol._last_seen = Vector3.ZERO
	var original_cooldown: float = patrol.attack_cooldown
	patrol.take_damage(1)
	check(patrol._last_seen == target.position and patrol._lost_time == 0, "valid hit refreshes last-known target and alert age")
	check(patrol.attack_cooldown == original_cooldown and patrol.health == 84, "regular damage and attack cooldown unchanged")
	patrol._physics_process(1.0 / 90.0)
	check(patrol.state == patrol.State.PURSUE, "hit alert survives following tick outside visual range")
	patrol._lost_time = 12.0
	patrol.take_damage(0)
	check(patrol._lost_time == 12.0, "zero-damage call does not create alert")
	var ledge := StaticBody3D.new()
	var ledge_collision := CollisionShape3D.new()
	var ledge_box := BoxShape3D.new()
	ledge_box.size = Vector3(4, 0.5, 4)
	ledge_collision.shape = ledge_box
	ledge.add_child(ledge_collision)
	ledge.position.y = -0.25
	root.add_child(ledge)
	patrol.position = Vector3(0, 0.1, -1.7)
	patrol.velocity = Vector3.ZERO
	patrol._change_state(patrol.State.PATROL)
	await physics_frame
	for i in range(30):
		patrol._physics_process(1.0 / 90.0)
		await physics_frame
	check(patrol.is_on_floor() and patrol._safe_direction(Vector3.FORWARD).is_zero_approx(), "raised uphill probe still rejects unsupported catwalk drop")
	check(patrol._safe_direction(Vector3.BACK).length() > 0.9, "ledge safety still permits supported retreat")
	print("NAVIGATION_TESTS checks=", checks, " failures=", failures)
	for voice in root.find_children("*", "AudioStreamPlayer3D", true, false):
		voice.stop()
		voice.stream = null
	for child in root.get_children():
		child.queue_free()
	await process_frame
	Enemy._sound_bank.clear()
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)
