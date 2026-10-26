extends "res://tests/integration.gd"
##055 carry: only obsolete hardcoded047 telemetry version is updated.
##All30 other behavior checks and cleanup remain identical.

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2)
		return
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.weapon.set_process(false)
	for gun in game.weapon.weapons: gun.set_process(false)
	stop_audio(game)
	await physics_frame
	check(game.health == 100 and game.shield == 100, "new campaign starts with visible health and shield")
	var enemy = game.enemies[0]
	enemy.hit_player.emit(30.0)
	check(game.health == 100 and game.shield == 70, "actual enemy hit consumes shield before health")
	check(game.combat_hud.hit_source.is_equal_approx(enemy.get_weapon_muzzle_transform().origin), "actual attacker muzzle reaches directional HUD")
	enemy.hit_player.emit(90.0)
	check(game.shield == 0 and game.health == 80, "shield overflow reduces health by remaining damage")
	game._apply_damage_layers(-10)
	check(game.health == 80 and game.shield == 0, "negative damage cannot refill meters")
	game._apply_damage_layers(NAN)
	check(game.health == 80, "nonfinite damage ignored")
	game._apply_damage_layers(500)
	check(game.health == 0 and game.shield == 0, "overkill clamps both meters")
	game.health = 100
	game.shield = 100
	game.field_menu.settings_page = "game"
	var original_health: float = enemy.health
	game.field_menu.set_numeric_setting(0, 1.0)
	game._save_settings(game.field_menu.get_settings())
	check(enemy.difficulty == 1.0 and enemy._pressure_scale() > 2.0 and enemy.health == original_health, "actual menu-to-main setting reaches live enemy pressure without HP inflation")
	check(game.telemetry.snapshot().build_identity.version == "0.5.5", "actual startup telemetry identifies the current055 build")
	game.field_menu.apply_settings({})
	check(is_equal_approx(game.player.effective_walk_speed(), 6.5), "fresh walking1x is6.5m/s")
	check(is_equal_approx(game.player.glide_speed_mps, 13.0), "fresh flying target is2x configured6.5m/s walk")
	check(game.player.turning_style == "smooth" and game.player.smooth_turn_speed == 360, "fresh turning remains smooth360")
	check(not game.field_menu.vignette_enabled, "fresh vignette remains off")
	game.field_menu.settings_page = "flight"
	game.field_menu.set_numeric_setting(0, 15.0)
	game.field_menu.set_numeric_setting(1, 1.4)
	game.field_menu.set_numeric_setting(2, 1.8)
	game.field_menu.set_numeric_setting(3, 1.9)
	game.field_menu.set_numeric_setting(4, 8.0)
	game.field_menu.set_numeric_setting(5, 5.0)
	var saved: Dictionary = game.field_menu.get_settings()
	check(saved.movement_settings_version == 3 and saved.glide_speed_mps == 13 and game.field_menu.numeric_setting(0).is_empty(), "glide derives2x walk and obsolete independent slider removed")
	game.field_menu.apply_settings(saved)
	check(is_equal_approx(game.player.sprint_slow_gain, 1.4) and is_equal_approx(game.player.sprint_fast_gain, 1.8), "both sprint tiers roundtrip")
	check(game.player.sprint_stamina_seconds == 8 and game.player.sprint_recovery_seconds == 5 and is_equal_approx(game.player.glide_steering_gain,1.9), "stamina and direct steering gain roundtrip")
	game.field_menu.apply_settings({"movement_settings_version":2,"walk_speed_multiplier":1.0})
	check(game.player.walk_speed_multiplier == 1.0 and game.player.effective_walk_speed() == 6.5, "v2 displayed1x intentionally adopts new6.5 baseline")
	game.field_menu.reset_movement_settings()
	check(game.player.glide_speed_mps == 13 and game.player.effective_walk_speed() == 6.5, "Reset Defaults restores6.5walk and derived13glide")
	game.field_menu.settings_page = "movement"
	for walk_scale in [.5,1.0,1.75]:
		game.field_menu.set_numeric_setting(5,walk_scale)
		game._save_settings(game.field_menu.get_settings())
		var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
		game.field_menu.apply_settings(persisted)
		check(is_equal_approx(game.player.effective_walk_speed(),6.5*walk_scale) and is_equal_approx(game.player.glide_speed_mps,13.0*walk_scale), "actual walking slider/save/reload immediately derives glide2x atscale=" + str(walk_scale))
	game.field_menu.reset_movement_settings()
	check(game.player.turning_style == "smooth" and not game.field_menu.vignette_enabled, "Reset Defaults preserves smooth/no-vignette acceptance")
	game.enemies.clear()
	var target: Dictionary = game._station_grip_targets()[0]
	var expected: Vector3 = game.objective_nodes[0].to_global(Vector3(0,.65,.37))
	check(target.position.is_equal_approx(expected), "grip target raised40cm with station screen")
	var screen_found := false
	for child in game.objective_nodes[0].get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(.65,.4,.03)):
			screen_found = is_equal_approx(child.position.y, .65)
	check(screen_found, "visible blue panel and interaction target share raised height")
	game._open_backpack()
	check(game.field_menu.is_open and game.field_menu.settings_page == "loadout", "wheel backpack opens actual loadout panel")
	check(game.field_menu._labels().size() == 4 and game.field_menu._labels()[0].contains("CX4"), "loadout lists three carried weapons plus return row")
	var owned: Array = game.weapon_inventory.owned_indices()
	for i in range(owned.size()):
		check(game.field_menu._labels()[i].contains(game.weapon.get_weapon_label(owned[i])), "loadout row maps actual carried weapon%d" % owned[i])
	game.weapon.weapons[2].ammo = 1
	game._select_loadout_weapon(1)
	check(not game.field_menu.is_open and game.weapon.selected == 2 and game.weapon.ammo == 1, "backpack selection maps owned slot without ammunition refill")
	check(game.weapon.weapons[2]._requires_trigger_release, "backpack equip retains fresh-trigger firing gate")
	stop_audio(game)
	await create_timer(0.1).timeout
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	print("CONTROLS_036_INTEGRATION_RESULT passes=", passed, " failures=", failures.size(), " headset_tested=false")
	quit(0 if failures.is_empty() else 1)






