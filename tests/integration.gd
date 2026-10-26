extends SceneTree

var failures: Array[String] = []
var passed := 0
var shot_count := 0
var damage_events := 0
var death_events := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS ", description)
	else:
		failures.append(description)
		printerr("FAIL ", description)

func run() -> void:
	if "--concealment-integration-only" in OS.get_cmdline_user_args():
		await test_concealment_integration()
		print("QA_RESULT passes=", passed, " failures=", failures.size(), " synthetic=true headset_tested=false")
		quit(0 if failures.is_empty() else 1)
		return
	if "--head-collision-only" in OS.get_cmdline_user_args():
		await test_head_collision()
		print("QA_RESULT passes=", passed, " failures=", failures.size(), " synthetic=true headset_tested=false")
		quit(0 if failures.is_empty() else 1)
		return
	await test_weapon()
	await test_enemy()
	await test_enemy_obstacles()
	await test_warden()
	await test_player()
	await test_head_collision()
	await test_menu()
	await test_tracking_absence()
	await test_controller_interactions()
	await test_campaign()
	print("QA_RESULT passes=", passed, " failures=", failures.size(), " synthetic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)

func test_weapon() -> void:
	var script = load("res://scripts/weapon.gd")
	check(script != null and script.can_instantiate(), "weapon script compiles")
	if script == null or not script.can_instantiate():
		return
	var weapon = script.new()
	root.add_child(weapon)
	weapon._build_model()
	weapon.set_process(false)
	weapon.shot.connect(func(_o: Vector3, direction: Vector3, damage: float):
		shot_count += 1
		check(is_equal_approx(direction.length(), 1.0), "shot direction normalized")
		check(damage > 0, "shot damage positive"))
	check(weapon.ammo == 24 and weapon.reload_state == "ready", "weapon initial ready magazine")
	weapon.fire()
	check(weapon.ammo == 23 and shot_count == 1, "fire consumes one round and emits one shot")
	weapon.fire()
	check(weapon.ammo == 23 and shot_count == 1, "cooldown prevents duplicate fire")
	weapon.insert_magazine()
	weapon.rack_bolt()
	weapon.grab_magazine()
	check(weapon.ammo == 23 and weapon.reload_state == "ready", "out of order reload calls cannot mint ammo")
	weapon.eject_magazine()
	check(weapon.ammo == 0 and weapon.reload_state == "needs_mag", "partial magazine ejection discards remaining rounds")
	weapon.cooldown = 0
	weapon.fire()
	weapon.rack_bolt()
	weapon.insert_magazine()
	check(shot_count == 1 and weapon.reload_state == "needs_mag", "ejected weapon cannot fire or skip acquisition")
	weapon.grab_magazine()
	check(weapon.reload_state == "held_mag", "acquisition enters held magazine stage")
	weapon.rack_bolt()
	check(weapon.reload_state == "held_mag" and weapon.ammo == 0, "cannot rack unseated magazine")
	weapon.insert_magazine()
	check(weapon.reload_state == "needs_rack" and weapon.ammo == 0, "seated magazine requires rack")
	weapon.cooldown = 0
	weapon.fire()
	check(shot_count == 1, "unracked weapon cannot fire")
	weapon.rack_bolt()
	check(weapon.reload_state == "ready" and weapon.ammo == 24, "rack restores full magazine")
	for i in range(24):
		weapon.cooldown = 0
		weapon.fire()
	check(weapon.ammo == 0 and shot_count == 25, "24 round magazine emits exactly 24 shots")
	weapon.cooldown = 0
	weapon.fire()
	check(weapon.ammo == 0 and shot_count == 25, "empty magazine cannot shoot or underflow")
	for i in range(2):
		weapon.desktop_reload_step()
	check(weapon.reload_state == "ready" and weapon.ammo == 24, "empty rifle auto-ejects then desktop insert and charge complete reload")
	weapon.free()

func test_enemy() -> void:
	var script = load("res://scripts/enemy.gd")
	check(script != null and script.can_instantiate(), "enemy script compiles")
	if script == null or not script.can_instantiate():
		return
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(0, 0, -10)
	var enemy = script.new()
	enemy.setup(target, 0)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.hit_player.connect(func(_amount): damage_events += 1)
	enemy.defeated.connect(func(_unit): death_events += 1)
	await physics_frame
	await physics_frame
	var aim := target.global_position + Vector3.UP * 1.35
	check(enemy._clear_line(aim), "enemy sees unobstructed target")
	enemy.locked_aim = aim
	enemy._fire(aim)
	check(damage_events == 1, "enemy hits stationary target at telegraphed aim")
	enemy._fire(aim + Vector3.RIGHT)
	check(damage_events == 1, "moving one metre dodges locked enemy shot")
	var cover := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 1)
	collider.shape = shape
	cover.add_child(collider)
	root.add_child(cover)
	cover.position = Vector3(0, 1.5, -5)
	await physics_frame
	await physics_frame
	check(not enemy._clear_line(aim), "solid cover blocks enemy line of sight")
	enemy._fire(aim)
	check(damage_events == 1, "enemy cannot damage through cover")
	enemy.take_damage(-5)
	check(enemy.health == 85, "negative damage cannot heal enemy")
	enemy.take_damage(34)
	check(enemy.health == 51 and death_events == 0, "nonlethal hit reduces actual enemy health")
	enemy.take_damage(100)
	enemy.take_damage(100)
	check(death_events == 1, "lethal damage emits exactly one defeat")
	check(enemy.collision_layer == 0 and not enemy.is_in_group("enemies"), "dead enemy leaves combat collision and enemy group")
	cover.free()
	enemy.free()
	target.free()

func test_player() -> void:
	var script = load("res://scripts/player.gd")
	check(script != null and script.can_instantiate(), "player script compiles")
	if script == null or not script.can_instantiate():
		return
	var floor_body := make_box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	var wall := make_box(Vector3(8, 8, 0.5), Vector3(0, 4, -1))
	var player = script.new()
	root.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	player.position = Vector3(0, 0.1, 0)
	await physics_frame
	await physics_frame
	for i in range(30):
		player.velocity = Vector3(0, -4, -4)
		player.move_and_slide()
		await physics_frame
	check(player.position.y > -0.02, "capsule cannot fall through floor")
	check(player.position.z > -0.51, "capsule cannot walk through wall")
	check(not player.find_grab_surface(Vector3(0, 1.5, -0.7)).is_empty(), "reachable wall supports physical grab query")
	check(player.find_grab_surface(Vector3(0, 1.5, 2)).is_empty(), "distant air cannot be grabbed")
	player.left_hand.global_position = Vector3(0,1.5,-0.7)
	player.right_hand.global_position = Vector3(0.2,1.5,-0.7)
	player._update_grab(player.left_hand,true)
	player._update_grab(player.right_hand,true)
	check(player._grabs.size() == 2, "both hands independently grip reachable wall")
	player._release_velocity = Vector3(0,10,0)
	player._update_grab(player.left_hand,false)
	check(player._grabs.size() == 1, "releasing one hand preserves opposite grip")
	player._update_grab(player.right_hand,false)
	check(player._grabs.is_empty() and is_equal_approx(player.velocity.length(),8.75), "last hand release applies default125percent gain to bounded7m/s gesture")
	var before_y: float = player.position.y
	for i in range(8):
		player.apply_climb_motion(Vector3(0, 0.1, -0.1), 1.0 / 90.0)
		await physics_frame
	check(player.position.y > before_y + 0.3, "climb pull raises real capsule")
	check(player.position.z > -0.51, "climb sweep prevents pulling through wall")
	player.reset_motion()
	player.position = Vector3(0, 6, 4)
	player._desktop_glide = true
	player.velocity = Vector3(0, -3, 0)
	for i in range(12):
		player._physics_process(1.0 / 90.0)
		await physics_frame
	check(player.gliding and player.movement_mode == "glide", "airborne glide input enters glide state")
	check(player.velocity.y > -3 and player.velocity.y < 0, "glide slows descent without upward flight")
	check(player.velocity.z < -1, "glide gains forward travel")
	player.reset_motion()
	check(not player.gliding and not player.climbing and player.velocity == Vector3.ZERO, "reset clears climb glide and launch momentum")
	player.position = Vector3(0,10,4)
	player.velocity = Vector3(6,4,0)
	for i in range(45):
		player._physics_process(1.0/90.0)
		await physics_frame
	check(player.velocity.x > 5.5 and player.position.x > 2.5, "released launch retains useful horizontal momentum for half second")
	player.velocity = Vector3(6,4,0)
	player._desktop_glide = true
	player._physics_process(1.0/90.0)
	check(player.gliding and player.velocity.y > 0, "rising launch transitions into glide without instant downward snap")
	player.reset_motion()
	var pivot: Vector3 = player.get_view_camera().global_position
	player.snap_turn(PI / 6)
	check(player.get_view_camera().global_position.distance_to(pivot) < 0.001, "snap turn retains camera pivot")
	wall.free()
	player.reset_motion()
	player.position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	var ledge := make_box(Vector3(4, 0.4, 1), Vector3(0, 0.2, -0.9))
	var ceiling := make_box(Vector3(4, 0.2, 4), Vector3(0, 1.8, 0))
	await physics_frame
	await physics_frame
	player._grabs[player.left_hand] = player.left_hand.global_position
	check(not player.try_start_mantle(), "overhead obstacle rejects mantle before motion")
	ceiling.free()
	await physics_frame
	await physics_frame
	check(player.try_start_mantle(), "clear low ledge begins mantle")
	for i in range(70):
		if player.mantling:
			player._step_mantle(1.0 / 90.0)
		await physics_frame
	check(not player.mantling and player.position.y > 0.4 and player.position.z < -0.6, "mantle finishes above ledge through swept motion")
	ledge.free()
	player.free()
	floor_body.free()

func test_head_collision() -> void:
	var player = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	player.set_process(false)
	var camera_before: Transform3D = player.xr_camera.global_transform
	check(not player.is_head_position_obstructed(Vector3(0.25,1.5,0)), "clear head lean remains unobstructed")
	check(not player.is_head_position_obstructed(Vector3(0,0.65,0)), "clear crouch remains unobstructed")
	var wall := make_box(Vector3(4,3,0.1), Vector3(0,1.5,-0.5))
	await physics_frame
	await physics_frame
	check(player.is_head_position_obstructed(Vector3(0,1.5,-0.5)), "head sphere overlapping wall is obstructed")
	check(player.is_head_position_obstructed(Vector3(0,1.5,-0.8)), "head beyond thin wall is caught by body-head segment")
	check(not player.update_head_obstruction(), "desktop wrapper never triggers headset obstruction")
	check(player.xr_camera.global_transform.is_equal_approx(camera_before), "head collision queries do not alter tracked camera transform")
	wall.free()
	var low_wall := make_box(Vector3(4,0.5,0.1), Vector3(0,0.25,-0.5))
	await physics_frame
	await physics_frame
	check(not player.is_head_position_obstructed(Vector3(0,1.5,-0.8)), "looking above low cover does not trigger head obstruction")
	low_wall.free()
	var menu = load("res://scripts/menu.gd").new()
	root.add_child(menu)
	menu.setup(player)
	menu.set_process(false)
	player.xr_enabled = true
	player.head_obstructed = true
	menu.vignette_enabled = false
	menu._process(0.12)
	check(menu._vignette.visible and is_equal_approx(float(menu._vignette_material.get_shader_parameter("obstruction")), 1.0), "head obstruction fades opaque with comfort vignette disabled")
	player.head_obstructed = false
	menu._process(0.2)
	check(not menu._vignette.visible and is_zero_approx(float(menu._vignette_material.get_shader_parameter("obstruction"))), "clearing obstruction fades overlay out")
	menu.free()
	player.free()

func test_enemy_obstacles() -> void:
	var script = load("res://scripts/enemy.gd")
	var enemy = script.new()
	var target := Node3D.new()
	root.add_child(target)
	enemy.setup(target, 0)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	var floor_body := make_box(Vector3(8,1,4), Vector3(0,-0.5,1))
	enemy.position = Vector3(0,0.1,-0.6)
	await physics_frame
	await physics_frame
	for i in range(8):
		enemy.velocity = Vector3.DOWN * 4
		enemy.move_and_slide()
		await physics_frame
	check(enemy.is_on_floor(), "enemy settles on test platform")
	check(enemy._safe_direction(Vector3.FORWARD) == Vector3.ZERO, "enemy rejects unguarded ledge over 0.65m")
	var wall := make_box(Vector3(4,3,0.3),Vector3(0,1.5,0.3))
	await physics_frame
	await physics_frame
	var safe: Vector3 = enemy._safe_direction(Vector3.BACK)
	check(absf(safe.x) > 0.5, "enemy chooses tangent around full-height wall")
	wall.free()
	floor_body.free()

	floor_body = make_box(Vector3(8,1,8),Vector3(0,-0.5,0))
	var step := make_box(Vector3(4,0.25,2),Vector3(0,0.125,-1.6))
	enemy.position = Vector3(0,0.06,0)
	await physics_frame
	await physics_frame
	for i in range(100):
		enemy.velocity = Vector3(0,-1,-2.2)
		enemy._try_step(1.0/90.0)
		enemy.move_and_slide()
		await physics_frame
	print("ENEMY_STEP_END ", enemy.position)
	# Enemy capsule bottom is body origin + .055m, so a .25m top yields body y=.195.
	check(enemy.position.z < -1.1 and enemy.position.y > 0.18, "enemy traverses 0.25m step with capsule")
	for key in ["charge","fire","hit","death"]:
		var sound = enemy._sound(key)
		check(sound is AudioStreamWAV and sound.data.size() > 0, "enemy spatial %s sound generates" % key)
	enemy.free()
	target.free()
	step.free()
	floor_body.free()

func test_warden() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var enemy = load("res://scripts/enemy.gd").new()
	enemy.setup(target, 3)
	enemy.position = Vector3(10,0,0)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	damage_events = 0
	enemy.hit_player.connect(func(_amount): damage_events += 1)
	check(enemy.health == 350 and enemy.boss_phase == 1, "Warden initializes with boss health and first phase")
	enemy._impact_point = Vector3.ZERO
	await physics_frame
	await physics_frame
	enemy._resolve_warden_impact(Vector3.UP*1.35)
	check(damage_events == 1, "Warden marked ground impact damages stationary target")
	target.position = Vector3(3,0,0)
	enemy._resolve_warden_impact(target.position + Vector3.UP*1.35)
	check(damage_events == 1, "leaving two metre marker evades Warden blast")
	target.position = Vector3(0,3,0)
	enemy._resolve_warden_impact(target.position + Vector3.UP*1.35)
	check(damage_events == 1, "vertical movement evades Warden ground blast")
	target.position = Vector3(1,0,0)
	var cover := make_box(Vector3(0.1,3,2),Vector3(0.5,1,0))
	await physics_frame
	await physics_frame
	enemy._resolve_warden_impact(target.position + Vector3.UP*1.35)
	check(damage_events == 1, "solid cover blocks Warden area damage")
	enemy._change_state(enemy.State.RECOVER)
	enemy.take_damage(176)
	check(enemy.boss_phase == 2 and enemy.health == 174, "Warden enters second phase below half health")
	stop_audio(enemy)
	enemy.free()
	target.free()
	cover.free()
func make_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	body.position = position
	return body

func test_concealment_integration() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		check(false, "concealment integration requires isolated save directory")
		return
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	main.new_campaign()
	stop_audio(main)
	check(main.player.exposure_provider == main.world, "campaign wires player to actual world exposure provider")
	var nearby = main.enemies[0]
	var distant = main.enemies[1]
	distant.position = Vector3(500,1,0)
	var defeated = main.enemies[2]
	defeated.take_damage(10000)
	var dead_memory: float = defeated.alert_memory
	var cam: Camera3D = main.player.get_view_camera()
	cam.look_at(cam.global_position + Vector3.UP, Vector3.FORWARD)
	main.weapon._process(0.01)
	main.weapon.fire()
	check(main.weapon.ammo == 23 and nearby.alert_memory > 0 and nearby.state == nearby.State.PURSUE, "actual weapon miss alerts nearby enemy through main shot signal")
	check(distant.alert_memory == 0 and distant.state == distant.State.PATROL, "gunshot does not alert enemy beyond hearing range")
	defeated.notify_gunshot(cam.global_position)
	check(defeated.state == defeated.State.DEAD and defeated.alert_memory == dead_memory, "still-existing defeated enemy ignores gunshot stimulus")
	# The shared teardown helper disabled automatic callbacks and stopped audio;
	# restart stems so pausing live playback is actually exercised.
	for stem in main.music._players: stem.play()
	main.field_menu.set_open(true)
	main._process(0.1)
	nearby.alert_memory = 0
	main.weapon.cooldown = 0
	main.weapon.fire()
	check(nearby.alert_memory == 0 and main.weapon.ammo == 23, "paused weapon cannot consume ammo or alert enemies")
	main.music._process(0.4)
	check(main.music._paused and main.music._players.all(func(p): return p.stream_paused), "campaign pause fades and suspends all music stems")
	main.field_menu.set_open(false)
	main._process(0.1)
	main.music._process(0.4)
	check(not main.music._paused and main.music._players.all(func(p): return not p.stream_paused), "campaign resume resumes music stems")
	nearby.detection_level = 0.8
	main.encounter_active = true
	main._awareness_timer = 0
	main._process(0.2)
	check(is_equal_approx(main.music._intensity, 0.8), "actual enemy awareness drives campaign music intensity")
	main.chapter = 3
	main._awareness_timer = 0
	main._process(0.2)
	check(main.music._extraction, "extraction chapter selects extraction music layer")
	main.new_campaign()
	stop_audio(main)
	main._awareness_timer = 0
	main._process(0.2)
	check(main.enemies.all(func(e): return e.alert_memory == 0 and e.detection_level == 0), "new campaign replaces alerted enemies with clean awareness")
	check(main.music._intensity == 0 and not main.music._extraction, "new campaign resets music threat and extraction state")
	stop_audio(main)
	await create_timer(0.2).timeout
	main.free()

func test_campaign() -> void:
	var safe_save: bool = OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata")
	check(safe_save, "campaign tests use isolated save directory")
	if not safe_save:
		printerr("Set process APPDATA to reports/QA/test-appdata before campaign tests. Actual user saves must not be overwritten.")
		return
	var script = load("res://scripts/main.gd")
	check(script != null and script.can_instantiate(), "main campaign script compiles")
	if script == null or not script.can_instantiate():
		return
	var main = script.new()
	root.add_child(main)
	main.set_process(false)
	main.player.set_physics_process(false)
	main.weapon.set_process(false)
	main.new_campaign()
	check(main.chapter == 0 and not main.complete and main.enemies.size() == 4, "new campaign starts four enemy first encounter")
	var children_before: int = main.get_child_count()
	for i in range(1000):
		main._tracer(Vector3.ZERO, Vector3(1,2,3))
		main._impact(Vector3(1,2,3), Vector3.UP)
	check(main.get_child_count() == children_before and main._tracers.size() == 16 and main._impacts.size() == 16, "1000 shot effects retain bounded 16 plus 16 node pools")
	main.field_menu.set_open(true)
	main._process(0.2)
	var all_expired := true
	for effect in main._tracers + main._impacts:
		all_expired = all_expired and not effect.visible
	check(all_expired, "pooled shot effects expire while gameplay paused")
	var paused_health: float = main.health
	main._damage_player(50)
	check(main.paused and main.health == paused_health, "open field menu prevents combat damage")
	check(not main.enemies[0].is_physics_processing(), "pause suspends enemy AI")
	main.chapter = 1
	main._respawn()
	check(not main.enemies[0].is_physics_processing(), "checkpoint respawn while menu open keeps new enemy AI paused")
	main.chapter = 0
	main._begin_chapter()
	main.field_menu._choose(1)
	main.field_menu.set_numeric_setting(2,45)
	main.field_menu.set_open(false)
	var settings_file = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	check(settings_file is Dictionary and settings_file.get("snap_degrees") == main.player.snap_degrees, "menu changes persist to settings file")
	main.field_menu.set_open(false)
	main._process(1.0 / 90.0)
	check(not main.paused, "closing field menu resumes campaign")
	main.player.global_position = main.world.objective_positions[0]
	main._activate_objective()
	check(main.chapter == 0, "live enemies lock objective")
	for chapter_index in range(4):
		check(main.enemies.size() == [4,6,8,6][chapter_index], "chapter %d has expected encounter size" % chapter_index)
		for enemy in main.enemies.duplicate():
			enemy.set_physics_process(false)
			enemy.take_damage(10000)
		check(main.enemies.is_empty(), "chapter %d clear removes defeated enemies" % chapter_index)
		main.player.global_position = main.world.objective_positions[chapter_index] + Vector3(0, 0, 10)
		main._activate_objective()
		check(main.chapter == chapter_index, "remote activation rejected chapter %d" % chapter_index)
		main.player.global_position = main.world.objective_positions[chapter_index]
		main._activate_objective()
		check(main.chapter == chapter_index + 1, "nearby cleared objective advances chapter %d" % chapter_index)
	check(main.complete and main.total_kills == 24, "all four encounters finish campaign with 24 kills")
	check(FileAccess.file_exists("user://campaign.json"), "campaign save written to isolated user directory")
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://campaign.json"))
	check(saved is Dictionary and saved.get("chapter") == 4 and saved.get("kills") == 24, "completed chapter and kills persisted")
	main.chapter = 0
	main.total_kills = 0
	main._load_progress()
	check(main.chapter == 4 and main.total_kills == 24, "save reload restores progression")
	main.new_campaign()
	check(main.chapter == 0 and not main.complete and main.health == 100 and main.total_kills == 0, "new campaign resets completed state")
	main._damage_player(200)
	check(main.dead and main.health == 0, "lethal damage enters death state")
	main._respawn()
	check(not main.dead and main.health == 100 and main.enemies.size() == 4, "respawn restores checkpoint encounter")
	for enemy in main.enemies:
		enemy.set_physics_process(false)
	await create_timer(2.6).timeout
	stop_audio(main)
	await create_timer(0.1).timeout
	main.free()
	await process_frame

func test_menu() -> void:
	var player = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	var menu = load("res://scripts/menu.gd").new()
	root.add_child(menu)
	menu.setup(player)
	menu.set_process(false)
	player.velocity = Vector3.ONE
	menu.set_open(true)
	check(menu.is_open and not player.input_enabled and player.velocity == Vector3.ZERO, "menu suspends movement and clears velocity")
	menu._choose(1)
	menu.set_numeric_setting(2,45)
	check(player.snap_degrees == 45, "menu switches snap turn to 45 degrees")
	menu._choose(6)
	menu._choose(2)
	check(is_equal_approx(player.move_speed,2.6), "comfort menu reduces movement speed")
	menu._choose(6)
	menu._choose(7)
	menu._choose(3)
	menu._choose(3)
	check(not menu.vignette_enabled, "vignette can be disabled")
	var settings: Dictionary = menu.get_settings()
	menu.apply_settings({})
	menu.apply_settings(settings)
	check(player.snap_degrees == 45 and menu.comfort_speed and not menu.vignette_enabled, "menu settings round trip")
	menu.set_open(false)
	check(not menu.is_open and player.input_enabled, "closing menu resumes input")
	menu.free()
	player.free()

func test_tracking_absence() -> void:
	var player = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.setup(true)
	player.set_physics_process(false)
	player.input_enabled = true
	player.velocity = Vector3.ONE
	player.gliding = true
	player.update_tracking()
	check(not player.tracking_available and not player.input_enabled, "missing OpenXR tracking gates locomotion")
	check(player.velocity == Vector3.ZERO and not player.gliding, "tracking absence clears stale motion")
	player.input_enabled = false
	player.xr_enabled = false
	player.update_tracking()
	check(player.tracking_available and not player.input_enabled, "desktop tracking recovery preserves menu input lock")
	player.input_enabled = true
	check(player.input_enabled, "desktop input can resume after tracking reset")
	player.free()

func test_controller_interactions() -> void:
	var actor = load("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_physics_process(false)
	actor.set_process(false)
	var tracker := XRControllerTracker.new()
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.name = "qa_left"
	XRServer.add_tracker(tracker)
	actor.left_hand.tracker = tracker.name
	actor.left_hand.pose = "grip"
	tracker.set_pose("grip", actor.left_hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	var right_tracker := XRControllerTracker.new()
	right_tracker.type = XRServer.TRACKER_CONTROLLER
	right_tracker.name = "qa_right"
	XRServer.add_tracker(right_tracker)
	actor.right_hand.tracker = right_tracker.name
	actor.right_hand.pose = "grip"
	right_tracker.set_pose("grip", actor.right_hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	print("SYNTHETIC_TRACKER active=",actor.left_hand.get_is_active()," valid=",actor.is_hand_tracked(actor.left_hand)," pose=",tracker.get_pose("grip").has_tracking_data)
	for i in range(8): actor.update_hand_input_rearm(1.0 / 90.0)
	tracker.set_input("grip", 0.0)
	var weapon = load("res://scripts/weapon.gd").new()
	root.add_child(weapon)
	weapon.setup(actor)
	weapon.set_process(false)
	weapon.global_transform = actor.right_hand.global_transform
	tracker.set_input("grip", 1.0)
	check(actor.left_hand.get_float("grip") > 0.9, "synthetic tracker input reaches actual XRController")
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(0,-0.025,-0.36))
	weapon._update_support(0.1)
	check(weapon.supported and actor.left_hand_reserved, "fore-end contact plus grip establishes support")
	actor.left_hand.global_position += Vector3.LEFT
	weapon._update_support(0.1)
	check(not weapon.supported and not actor.left_hand_reserved, "support releases beyond retention distance")
	weapon.eject_magazine()
	tracker.set_input("grip", 0.0)
	weapon._poll_vr()
	actor.left_hand.global_position = Vector3(3,3,3)
	tracker.set_input("grip", 1.0)
	weapon._poll_vr()
	check(weapon.reload_state == "needs_mag", "gripping distant air cannot acquire magazine")
	tracker.set_input("grip", 0.0)
	weapon._poll_vr()
	actor.left_hand.global_position = weapon.get_offered_magazine_transform().origin
	tracker.set_input("grip", 1.0)
	weapon._poll_vr()
	check(weapon.reload_state == "held_mag", "weapon-local offered magazine plus grip acquires magazine")
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(0,-0.18,-0.15))
	weapon._poll_vr()
	check(weapon.reload_state == "needs_rack" and weapon.ammo == 0, "physical well contact seats magazine")
	tracker.set_input("grip", 0.0)
	weapon._poll_vr()
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(-0.05,0.064,-0.10))
	tracker.set_input("grip", 1.0)
	weapon._poll_vr()
	actor.left_hand.global_position += weapon.global_basis.z * 0.10
	weapon._poll_vr()
	check(weapon.reload_state == "ready" and weapon.ammo == 24, "physical charging-handle pull completes reload")
	weapon.eject_magazine()
	tracker.set_input("grip",0.0)
	weapon._poll_vr()
	actor.input_enabled = false
	actor.left_hand.global_position = weapon.get_offered_magazine_transform().origin
	tracker.set_input("grip",1.0)
	weapon._poll_vr()
	check(weapon.reload_state == "needs_mag", "menu input lock blocks synthetic reload gesture")
	actor.input_enabled = true
	weapon._poll_vr()
	check(weapon.reload_state == "needs_mag", "held grip cannot resume gesture immediately after menu")
	tracker.set_input("grip",0.0)
	for i in range(8): actor.update_hand_input_rearm(1.0 / 90.0)
	weapon._poll_vr()
	tracker.set_input("grip",1.0)
	weapon._poll_vr()
	check(weapon.reload_state == "held_mag", "fresh grip after resume can acquire magazine")
	weapon.reset_weapon()
	check(weapon.reload_state == "ready" and weapon.ammo == 24 and not actor.left_hand_reserved, "reset mid reload clears reservation and restores usable weapon")
	XRServer.remove_tracker(tracker)
	XRServer.remove_tracker(right_tracker)
	weapon.free()
	actor.free()

func stop_audio(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		stop_audio(child)

