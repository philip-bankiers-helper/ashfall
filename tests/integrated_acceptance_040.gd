extends "res://tests/integration.gd"
## Cross-feature production Main smoke. No GPU, OpenXR session or headset claim.
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
	game.field_menu.set_open(false)
	game.paused = false
	game.dead = false
	game.complete = false
	game.player.input_enabled = true
	var identity: Dictionary = game.telemetry.snapshot().build_identity
	check(identity.get("version") == "0.4.7", "actual Main telemetry identifies integrated0.4.7")
	check(game.body_visual != null and game.body_visual.actor == game.player, "actual Main wires visible body to production player")
	check(game.body_visual.find_children("*","CollisionObject3D",true,false).is_empty(), "integrated visible body adds no collision objects")
	game.field_menu.settings_page = "root"
	game.field_menu._refresh()
	check(game.field_menu._spatial_title.text.contains("0.4.7"), "actual spatial menu matches integrated version")
	check(game.weapon.weapons.size() == 12, "actual Main rack owns twelve gameplay types")
	var prior_toast: String = game.toast
	game.weapon.feedback.emit("INSERT MAGAZINE")
	check(game.toast == prior_toast, "weapon reload feedback cannot inject HUD instructions")
	game.xr_enabled = true
	game._on_tracking_changed(true)
	game.xr_enabled = false
	check(game.toast == prior_toast, "tracking restoration produces no HUD status text")
	check(game.ammo_pickups != null and game.ammo_pickups.boxes.size() == 3, "actual Main wires three family supply boxes")
	for i in range(game.weapon.weapons.size()):
		if game.weapon_inventory.has_weapon(i):
			game.weapon.select_weapon(i)
			check(game.weapon.selected == i and game.weapon.weapons[i].visible, "owned slot%d selects real visible weapon" % i)
		else:
			check(not game.weapon.select_weapon(i), "unowned slot%d cannot bypass finite inventory" % i)
		check(game.weapon.weapons[i].has_method("get_shot_transform"), "slot%d uses physical shot transform" % i)
	var pistol_ammo: int = game.weapon.weapons[2].ammo
	game._open_backpack()
	check(game.field_menu._labels().size() == 4 and game.field_menu._labels()[1].contains("MERIDIAN"), "actual loadout exposes three carried slots plus back")
	game._select_loadout_weapon(1)
	check(game.weapon.selected == 2 and not game.field_menu.is_open and game.weapon.ammo == pistol_ammo, "actual Main loadout equips pistol without ammo grant")
	game.player.input_enabled = true
	var menu = game.field_menu
	var saved: Dictionary = menu.get_settings().duplicate(true)
	menu.settings_page = "game"
	menu.set_numeric_setting(2, 1.35)
	menu.set_numeric_setting(0, .85)
	var changed: Dictionary = menu.get_settings()
	game._save_settings(changed)
	check(is_equal_approx(game.combat_hud.hud_size,1.35), "Main settings path changes live HUD geometry scale")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	check(is_equal_approx(float(disk.hud_size),1.35) and is_equal_approx(float(disk.difficulty),.85), "actual isolated save persists HUD and difficulty")
	menu.apply_settings(disk)
	check(is_equal_approx(menu.hud_size,1.35), "actual menu reload restores HUD size")
	for enemy in game.enemies:
		if is_instance_valid(enemy): check(is_equal_approx(enemy.difficulty,.85), "Main settings propagate to live enemy")
	var hud = game.combat_hud
	check(hud.get_parent() == game.player.get_view_camera(), "actual HUD attached to selected production camera")
	check(hud.find_children("*","Label3D",true,false).is_empty(), "meter group has no text")
	check(hud.sprint_fill.position.y > hud.shield_fill.position.y and hud.shield_fill.position.y > hud.health_fill.position.y, "live meter order sprint shield health")
	game.health = 100.0
	game.shield = 100.0
	game.enemies[0].hit_player.emit(30.0)
	hud.refresh(0)
	check(is_equal_approx(game.shield,70) and is_equal_approx(hud.shield_fill.scale.x,.7*1.35), "real enemy signal updates shield HUD after scale change")
	check(game.impact_marks.marks.size() == 64, "actual Main allocates bounded environmental impact pool")
	check(game.weapon.construction_provider == game.field_builder and game.building_input.builder == game.field_builder, "actual rack and adapter share integrated builder")
	var builder = game.field_builder
	builder.reset_builds()
	check(builder.charges == 6 and builder.max_charges == 12, "campaign construction starts6 with bounded12 supply")
	check(builder.award_supply("audit-kill",2) == 2 and builder.award_supply("audit-kill",2) == 0, "campaign reward deduplicates kill identity")
	builder.piece_index = 0
	builder._set_piece()
	builder._placement = Transform3D(Basis.IDENTITY,Vector3(1000,1.1,1000))
	builder.preview_valid = true
	builder._commit()
	var piece = builder.pieces[-1]
	var budget: int = builder.charges
	await physics_frame
	var impact_before: int = game.impact_marks.accepted
	game._on_shot(Vector3(1000,1.1,1002),Vector3.FORWARD,20)
	check(piece.health < piece.max_health and not piece.broken, "actual Main rifle ray damages constructed cover")
	var cover_mark: int = posmod(game.impact_marks.cursor-1,64)
	check(game.impact_marks.accepted > impact_before and game.impact_marks.marks[cover_mark].visible, "nonlethal constructed-cover hit creates visible environmental mark")
	var rays: Array[Vector3] = [Vector3.FORWARD,Vector3.FORWARD]
	var hp: float = piece.health
	game._on_pellet_shot(Vector3(1000,1.1,1002),rays,10)
	check(piece.health < hp, "actual Main pellet grouping damages constructed cover")
	game._on_shot(Vector3(1000,1.1,1002),Vector3.FORWARD,1000)
	check(piece.broken and piece.collision_layer == 0 and builder.pieces.is_empty(), "cover destruction immediately removes collision and live-cap entry")
	check(builder.charges == budget, "destroying own cover does not refund resource")
	game.impact_marks._process(.02)
	check(not game.impact_marks.marks[cover_mark].visible, "destroyed cover leaves no floating hit mark")
	await physics_frame
	var ground_enemy
	for enemy in game.enemies:
		if enemy.variant in [0,2]: ground_enemy = enemy; break
	check(ground_enemy != null and ground_enemy._detail_visual != null, "actual campaign ground enemy owns detailed mesh rig")
	if ground_enemy != null:
		var supply_before: int = builder.charges
		var kills_before: int = game.total_kills
		ground_enemy.take_damage(10000)
		check(builder.charges == mini(builder.max_charges,supply_before+2) and game.total_kills == kills_before+1, "actual enemy death awards two construction supply")
		var supply_after: int = builder.charges
		game._enemy_defeated(ground_enemy)
		check(builder.charges == supply_after and game.total_kills == kills_before+1, "repeated defeat callback cannot duplicate supply or kill")
		var corpses: Array[Node] = get_nodes_in_group("ragdolls")
		check(not corpses.is_empty() and not corpses[-1].bodies.is_empty(), "actual detailed enemy death spawns rigid-body ragdoll")
		if not corpses.is_empty():
			corpses[-1].set_paused(true)
			var frozen := true
			for body in corpses[-1].bodies: frozen = frozen and body.freeze
			check(frozen, "ragdoll pause freezes all real physics bodies")
	game._begin_chapter()
	await process_frame
	await physics_frame
	check(builder.pieces.is_empty() and builder.charges == 6, "actual chapter lifecycle clears/refills building")
	check(get_nodes_in_group("ragdolls").is_empty(), "actual chapter lifecycle clears ragdolls")
	menu.apply_settings(saved)
	game._save_settings(saved)
	stop_audio(game)
	print("INTEGRATED_ACCEPTANCE_040_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	await game._quit_game(0 if failures.is_empty() else 1,"test_complete")


