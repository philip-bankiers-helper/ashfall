extends "res://tests/integration.gd"

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		printerr("Isolated APPDATA required")
		quit(2)
		return
	var had_settings := FileAccess.file_exists("user://settings.json")
	var previous_settings := FileAccess.get_file_as_string("user://settings.json") if had_settings else ""
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	main.new_campaign()
	stop_audio(main)
	main.field_menu.set_open(true)
	main._process(0.01)
	main.field_menu._choose(5)
	main.field_menu._sliders[0].value = 83
	check(main.enemies.all(func(e): return is_equal_approx(e.difficulty, 0.83)), "actual difficulty slider updates every current enemy through main signal")
	check(main.enemies.all(func(e): return not e.is_physics_processing()), "difficulty adjustment while paused does not resume enemy AI")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	check(saved is Dictionary and is_equal_approx(float(saved.get("difficulty", -1)), 0.83), "actual menu signal persists difficulty to isolated settings file")
	var health_before: float = main.enemies[0].health
	main.field_menu._sliders[0].value = 0
	check(main.enemies.all(func(e): return e.difficulty == 0), "easy endpoint reaches all current enemies")
	check(main.enemies[0].health == health_before, "difficulty change preserves current enemy health")
	main.field_menu._sliders[0].value = 100
	main._respawn()
	check(main.enemies.all(func(e): return e.difficulty == 1), "checkpoint respawn inherits selected hard endpoint")
	check(main.enemies.all(func(e): return not e.is_physics_processing()), "respawn keeps new difficulty-configured encounter paused")
	main.chapter = 3
	main._begin_chapter()
	stop_audio(main)
	check(main.enemies.size() == 6 and main.enemies.all(func(e): return e.difficulty == 1), "extraction encounter inherits difficulty on every unit")
	var boss = main.enemies.back()
	check(boss.variant == 3 and boss.health == 350, "hard difficulty preserves authored Warden health and variant")
	main.new_campaign()
	stop_audio(main)
	check(main.enemies.all(func(e): return e.difficulty == 1), "new campaign preserves user difficulty preference")
	main.field_menu.apply_settings(saved)
	main.new_campaign()
	stop_audio(main)
	check(main.enemies.all(func(e): return is_equal_approx(e.difficulty, 0.83)), "saved setting applied before spawn restores encounter difficulty")
	main.field_menu.set_open(false)
	main._process(0.01)
	for enemy in main.enemies: enemy.set_physics_process(false)
	main.enemies[0].take_damage(10000)
	check(get_nodes_in_group("ragdolls").size() == 1, "actual campaign enemy death creates one physical wreck")
	var corpse = get_nodes_in_group("ragdolls")[0]
	check(corpse.bodies.size() > 1 and corpse.bodies.all(func(body): return body is RigidBody3D and body.collision_layer == 0 and body.collision_mask == 1), "campaign corpse uses multiple world-colliding bodies without blocking actors")
	await physics_frame
	main.field_menu.set_open(true)
	main._process(0.01)
	var positions: Array[Vector3] = []
	for body in corpse.bodies: positions.append(body.global_position)
	var age_before: float = corpse.age
	for i in range(8): await physics_frame
	var unmoved := true
	for i in range(corpse.bodies.size()): unmoved = unmoved and corpse.bodies[i].global_position.is_equal_approx(positions[i])
	check(corpse._paused and unmoved and corpse.age == age_before, "actual menu pause freezes corpse transforms and lifetime")
	main.field_menu.set_open(false)
	main._process(0.01)
	for enemy in main.enemies: enemy.set_physics_process(false)
	for i in range(8): await physics_frame
	check(not corpse._paused and corpse.age > age_before and corpse.bodies.all(func(body): return not body.freeze), "menu resume restores physical corpse simulation")
	main._respawn()
	stop_audio(main)
	check(get_nodes_in_group("ragdolls").is_empty(), "checkpoint respawn clears previous wrecks")
	main.enemies[0].take_damage(10000)
	main.new_campaign()
	stop_audio(main)
	check(get_nodes_in_group("ragdolls").is_empty(), "new campaign clears previous wrecks")
	main.enemies[0].take_damage(10000)
	main.load_checkpoint()
	stop_audio(main)
	check(get_nodes_in_group("ragdolls").is_empty(), "checkpoint load clears previous wrecks")
	stop_audio(main)
	await create_timer(0.2).timeout
	main.free()
	await process_frame
	if had_settings:
		var settings_file := FileAccess.open("user://settings.json", FileAccess.WRITE)
		settings_file.store_string(previous_settings)
		settings_file.close()
	else:
		DirAccess.remove_absolute("user://settings.json")
	print("CAMPAIGN_DIFFICULTY_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)
