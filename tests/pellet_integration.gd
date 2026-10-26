extends "res://tests/integration.gd"

class CountingMain extends "res://scripts/main.gd":
	var feedback_calls := 0
	var suppress_stress_audio := false
	func _play_sound(kind):
		if not suppress_stress_audio: super._play_sound(kind)
	func _feedback(message: String, duration: float = 2.4):
		feedback_calls += 1
		super._feedback(message, duration)

class Target extends StaticBody3D:
	var calls := 0
	var damage := 0.0
	var notifications := 0
	func take_damage(value: float):
		calls += 1
		damage += value
	func notify_gunshot(_origin: Vector3):
		notifications += 1
	func reset():
		calls = 0
		damage = 0
		notifications = 0

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2)
		return
	var main := CountingMain.new()
	root.add_child(main)
	main.new_campaign()
	stop_audio(main)
	main.enemies.clear()
	main.encounter_active = true
	var origin := Vector3(1000,10,1000)
	var target := Target.new()
	target.collision_layer = 4
	target.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,0.5)
	shape.shape = box
	target.add_child(shape)
	main.add_child(target)
	main.enemies = [target]
	target.global_position = origin + Vector3(0,0,-5)
	await physics_frame
	var rays: Array[Vector3] = []
	for i in range(8): rays.append(Vector3.FORWARD)
	main.feedback_calls = 0
	main._on_pellet_shot(origin,rays,10)
	check(target.calls == 1 and is_equal_approx(target.damage,80), "eight close pellets aggregate into one80damage call")
	check(target.notifications == 1, "eight pellets notify enemy only once per discharge")
	check(main.feedback_calls == 0, "eight pellets produce no redundant hit HUD text")
	main.encounter_active = false
	main.feedback_calls = 0
	main._on_pellet_shot(origin,rays,10)
	check(main.feedback_calls == 0, "first encounter-opening discharge produces no redundant hit HUD text")
	target.reset()
	var many := rays.duplicate()
	for i in range(40): many.append(Vector3.FORWARD)
	main._on_pellet_shot(origin,many,10)
	check(target.calls == 1 and is_equal_approx(target.damage,80), "oversized direction array is capped at eight rays")
	for distance in [8.25,16.75,25.25,39.75,40.3]:
		target.global_position = origin + Vector3(0,0,-distance)
		await physics_frame
		target.reset()
		main._on_pellet_shot(origin,rays,10)
		var expected := 0.0 if distance > 40.25 else 80 * lerpf(1,0.25,clampf((distance-0.25-8)/17,0,1))
		check(is_equal_approx(target.damage,expected), "physical hit distance %.2f respects falloff and40m limit" % (distance-0.25))
	target.global_position = origin + Vector3(0,0,-5)
	await physics_frame
	target.reset()
	main._on_pellet_shot(origin,[Vector3.ZERO,Vector3(NAN,0,0),Vector3(INF,0,0),Vector3.RIGHT],10)
	check(target.calls == 0, "zero nonfinite and wrong-axis rays cannot damage forward target")
	main._on_pellet_shot(Vector3(NAN,0,0),rays,10)
	main._on_pellet_shot(origin,rays,NAN)
	main._on_pellet_shot(origin,rays,-10)
	check(target.calls == 0, "invalid origin or damage rejected")
	main._on_pellet_shot(origin,[Vector3(0,0,-100)],10)
	check(target.calls == 1 and is_equal_approx(target.damage,10), "finite nonunit directions are normalized")
	var cover := make_box(Vector3(3,3,0.3),origin + Vector3(0,0,-2))
	await physics_frame
	target.reset()
	main._on_pellet_shot(origin,rays,10)
	check(target.calls == 0, "actual world cover intercepts pellet rays")
	cover.free()
	await physics_frame
	for state in ["paused","dead","complete"]:
		target.reset()
		main.set(state,true)
		main._on_pellet_shot(origin,rays,10)
		check(target.calls == 0 and target.notifications == 0, state + " blocks damage and gunshot notification")
		main.set(state,false)
	main.xr_enabled = true
	main.player.get_view_camera().global_position = origin + Vector3(-2,0,0)
	cover = make_box(Vector3(0.3,3,3),origin + Vector3(-1,0,0))
	await physics_frame
	target.reset()
	main._on_pellet_shot(origin,rays,10)
	check(target.calls == 0 and main.toast == "MUZZLE BLOCKED", "XR head-to-muzzle cover blocks every pellet")
	main.xr_enabled = false
	cover.free()
	await physics_frame
	var count_before := main.get_child_count()
	# Allocation stress isolates effect pools; real audio lifecycle is paced below.
	var actual_ambience = main.ambience
	main.ambience = null
	main.suppress_stress_audio = true
	for i in range(1000): main._on_pellet_shot(origin,rays,1)
	check(main.get_child_count() == count_before and main._tracers.size() == 16 and main._impacts.size() == 16, "1000 pellet discharges retain fixed effect pools and child count")
	main.ambience = actual_ambience
	main.suppress_stress_audio = false
	for i in range(100):
		main._on_pellet_shot(origin,rays,1)
		await create_timer(0.3).timeout
	check(main.get_child_count() == count_before, "100 real-time paced discharges with production audio retain bounded nodes")
	main.enemies.clear()
	target.free()
	var boss = load("res://scripts/enemy.gd").new()
	boss.setup(main.player,3)
	main.add_child(boss)
	boss.global_position = origin + Vector3(0,-1,-5)
	boss.set_physics_process(false)
	await physics_frame
	await physics_frame
	boss._change_state(boss.State.PATROL)
	main._on_pellet_shot(origin,rays,10)
	print("PELLET_BOSS closed_health=",boss.health," paused=",main.paused," dead=",main.dead," complete=",main.complete)
	check(is_equal_approx(boss.health,330), "grouped pellets honor real Warden closed-core armor")
	boss._change_state(boss.State.RECOVER)
	main._on_pellet_shot(origin,rays,10)
	check(is_equal_approx(boss.health,250), "grouped pellets deal full damage during real exposed-core recovery")
	stop_audio(main)
	main._stop_audio_tree(main)
	await create_timer(0.2).timeout
	main.free()
	await process_frame
	print("PELLET_INTEGRATION_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)
