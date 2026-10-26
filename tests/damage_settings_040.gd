extends "res://tests/integration.gd"
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		printerr("Isolated QA profile required")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	stop_audio(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.building_input.set_physics_process(false)
	game.field_menu.set_open(false)
	game.paused = false
	game.dead = false
	game.complete = false
	game.player.input_enabled = true
	var menu = game.field_menu
	var saved: Dictionary = menu.get_settings().duplicate(true)
	menu.apply_settings({"difficulty":0.5,"enemy_damage_multiplier":1.0,"player_damage_multiplier":1.0})
	game._save_settings(menu.get_settings())
	check(menu.enemy_damage_multiplier == 1.0 and menu.player_damage_multiplier == 1.0,"independent damage defaults are1")
	menu.settings_page = "game"
	menu.set_numeric_setting(3,2.0)
	menu.set_numeric_setting(4,1.5)
	game._save_settings(menu.get_settings())
	check(menu.enemy_damage_multiplier == 2.0 and menu.player_damage_multiplier == 1.5,"distinct gameplay rows set independent damage sliders")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	check(disk.enemy_damage_multiplier == 2.0 and disk.player_damage_multiplier == 1.5,"Main persists both separate damage values")
	menu.apply_settings({"enemy_damage_multiplier":1.0,"player_damage_multiplier":1.0})
	menu.apply_settings(disk)
	check(menu.enemy_damage_multiplier == 2.0 and menu.player_damage_multiplier == 1.5,"menu reload restores independent damage controls")
	var enemy = game.enemies[0]
	for item in game.enemies:
		item.set_physics_process(false)
	check(enemy.damage_multiplier == 2.0,"Main propagates enemy slider to live enemy")
	var original_hp: float = enemy.healthmax
	enemy.position = Vector3(1000,0,1008)
	enemy.locked_aim = Vector3(1000,1.4,1000)
	enemy.variant = 0
	for scenario in [[0.5,1.0,12.0],[1.0,1.0,36.0],[1.0,2.0,72.0]]:
		menu.apply_settings({"difficulty":scenario[0],"enemy_damage_multiplier":scenario[1],"player_damage_multiplier":3.0})
		game._save_settings(menu.get_settings())
		game.health = 100.0
		game.shield = 100.0
		await physics_frame
		enemy._fire(enemy.locked_aim)
		check(is_equal_approx(100.0-game.shield,scenario[2]),"actual enemy shot damage%s ignores player slider" % scenario[2])
		check(enemy.healthmax == original_hp,"damage settings preserve enemy maximum HP")
	menu.apply_settings({"difficulty":1.0,"enemy_damage_multiplier":4.0,"player_damage_multiplier":2.0})
	game._save_settings(menu.get_settings())
	var builder = game.field_builder
	builder.reset_builds()
	builder.piece_index = 0
	builder._set_piece()
	builder._placement = Transform3D(Basis.IDENTITY,Vector3(1100,1.1,1100))
	builder.preview_valid = true
	builder._commit()
	var piece = builder.pieces[0]
	var hp: float = piece.max_health
	await physics_frame
	await physics_frame
	game._on_shot(Vector3(1100,1.1,1102),Vector3.FORWARD,10.0)
	check(is_equal_approx(piece.health,hp-20.0),"player single shot multiplied exactly once independent of enemy slider")
	var rays: Array[Vector3] = [Vector3.FORWARD,Vector3.FORWARD]
	game._on_pellet_shot(Vector3(1100,1.1,1102),rays,5.0)
	check(is_equal_approx(piece.health,hp-40.0),"two pellets each scale once before grouped cover damage")
	check(piece.max_health == hp and enemy.healthmax == original_hp,"independent sliders never inflate target HP")
	game.paused = true
	game._on_shot(Vector3(1100,1.1,1102),Vector3.FORWARD,10.0)
	game._on_pellet_shot(Vector3(1100,1.1,1102),rays,5.0)
	check(is_equal_approx(piece.health,hp-40.0),"paused Main blocks single and pellet damage callbacks")
	game.health = 100.0
	game.shield = 100.0
	enemy._fire(enemy.locked_aim)
	check(game.shield == 100.0 and game.health == 100.0,"paused Main rejects incoming enemy hit signal")
	game.paused = false
	menu.settings_page = "game"
	menu.set_numeric_setting(3,-10.0)
	menu.set_numeric_setting(4,50.0)
	check(is_equal_approx(menu.enemy_damage_multiplier,.25) and is_equal_approx(menu.player_damage_multiplier,4.0),"damage slider numerical bounds enforced")
	menu.apply_settings(saved)
	game._save_settings(saved)
	stop_audio(game)
	print("DAMAGE_SETTINGS_040_RESULT passes=",passed," failures=",failures.size()," headset_tested=false")
	await game._quit_game(0 if failures.is_empty() else 1,"test_complete")
