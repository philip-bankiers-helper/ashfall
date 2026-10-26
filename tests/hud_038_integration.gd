extends "res://tests/integration.gd"

class FramePlayer extends "res://scripts/player.gd":
	func update_tracking() -> bool: return tracking_available
	func update_hand_input_rearm(_delta: float) -> void: pass
	func is_hand_input_ready(hand: XRController3D) -> bool: return bool(_hand_input_ready.get(hand, false))

# This is a synthetic XR routing check, not a live OpenXR session or pixels test.
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2)
		return
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.weapon.set_process(false)
	for gun in game.weapon.weapons: gun.set_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	stop_audio(game)
	await physics_frame
	var hud = game.combat_hud
	check(hud.get_parent() == game.player.desktop_camera, "actual Main initially routes HUD to desktop camera in XR-off test")
	# Exercise the production helper with the real player's XR camera. We cannot
	# initialize OpenXR in headless mode; report this injection explicitly.
	hud.queue_free()
	await process_frame
	game.player.xr_enabled = true
	game.xr_enabled = true
	game.player.desktop_camera.current = false
	game.player.xr_camera.current = true
	game.combat_hud = load("res://scripts/combat_hud.gd").new()
	game.add_child(game.combat_hud)
	game.combat_hud.setup(game.player, game)
	hud = game.combat_hud
	var camera: Camera3D = game.player.xr_camera
	check(hud.get_parent() == camera and camera.current and game.player.get_view_camera() == camera, "production HUD setup follows actual XR camera selection")
	check(hud.find_children("*", "Label3D", true, false).is_empty() and hud.find_children("*", "Label", true, false).is_empty(), "HUD has zero text nodes")
	check(hud.sprint_fill.position.y > hud.shield_fill.position.y and hud.shield_fill.position.y > hud.health_fill.position.y, "visible bar geometry ordered sprint shield health")
	check(hud.sprint_fill.position.y - hud.health_fill.position.y < .03, "three meters occupy under3cm vertical space at80cm")
	var sizes_ok := true
	var projection_ok := true
	var viewport_size: Vector2 = root.get_visible_rect().size
	for meter in [hud.sprint_fill, hud.shield_fill, hud.health_fill]:
		var mesh: QuadMesh = meter.mesh
		sizes_ok = sizes_ok and mesh.size.y <= .0061 and absf(meter.position.x) < .0001
		# Default projection fallback only: an XR runtime supplies per-eye frusta.
		for corner in [Vector3(-mesh.size.x/2, -mesh.size.y/2, 0), Vector3(mesh.size.x/2, mesh.size.y/2, 0)]:
			var point: Vector3 = meter.to_global(corner)
			var screen := camera.unproject_position(point)
			projection_ok = projection_ok and not camera.is_position_behind(point) and screen.x >= 0 and screen.y >= 0 and screen.x <= viewport_size.x and screen.y <= viewport_size.y
	check(sizes_ok, "all bars thin and centered at full capacity")
	check(projection_ok, "all meter corners inside synthetic XR camera default viewport projection; not per-eye verification")
	var old_relative: Vector3 = camera.to_local(hud.health_fill.global_position)
	camera.position += Vector3(.3,.2,-.4)
	camera.rotation = Vector3(.1,.8,.05)
	check(camera.to_local(hud.health_fill.global_position).is_equal_approx(old_relative), "meters follow actual camera position and yaw without world drift")
	game.health = 100
	game.shield = 100
	var enemy = game.enemies[0]
	enemy.hit_player.emit(30.0)
	hud.refresh(0)
	check(game.shield == 70 and is_equal_approx(hud.shield_fill.scale.x,.7) and hud.health_fill.scale.x == 1.0, "actual enemy signal visibly shrinks shield bar first")
	enemy.hit_player.emit(90.0)
	hud.refresh(0)
	check(game.health == 80 and hud.shield_fill.scale.x < .001 and is_equal_approx(hud.health_fill.scale.x,.8), "actual overflow hit shrinks health geometry")
	check(hud.hit_arrow.visible and hud.hit_source.is_equal_approx(enemy.get_weapon_muzzle_transform().origin), "actual animated attacker muzzle drives damage indicator")
	game.radio_time = 0
	game._caption_pending = false
	game.toast_time = 0
	game._update_compact_hud(.02, "30 / 90", "GRIP SCREEN", "EXPOSED", "ALERT", "R RELOAD")
	check(game.hud.text.is_empty() and game.vr_label.text.is_empty(), "actual main update removes old persistent status text")
	check(not game.training_label.visible and not game._hud_controls.visible, "old training/control labels remain hidden")
	check(game.vr_cue.position.y > hud.sprint_fill.position.y and absf(game.vr_cue.position.x) < .001 and game.vr_cue.font_size <= 20, "transient message anchor stays centered above bars at compact font")
	check(game.vr_cue.text.split("\n").size() <= 2 and game.vr_cue.text.length() <= 85, "actual action update produces at most two compact lines")
	game.paused = true
	hud.refresh(.02)
	check(not hud.visible and not hud.hit_arrow.visible, "pause hides entire XR meter group and damage cue")
	game.paused = false
	hud.refresh(.02)
	check(hud.visible, "unpause restores actual meter group")
	# Connect the same production HUD to an actual physics-driven player. Only
	# tracking availability is supplied synthetically; sprint/motion are real.
	var runner := FramePlayer.new()
	root.add_child(runner)
	runner.setup(true)
	runner.set_physics_process(false)
	runner.position = Vector3(1000,0,0)
	runner.xr_camera.position.y = 1.65
	runner.tracking_available = true
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30,.5,30)
	floor_shape.shape = shape
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(1000,-.25,0)
	root.add_child(floor_body)
	var tracker := XRControllerTracker.new()
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.name = "hud038left"
	XRServer.add_tracker(tracker)
	runner.left_hand.tracker = tracker.name
	tracker.set_pose("grip",runner.left_hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	runner._hand_input_ready[runner.left_hand] = true
	tracker.set_input("primary",Vector2(0,1))
	var run_hud = load("res://scripts/combat_hud.gd").new()
	game.add_child(run_hud)
	run_hud.setup(runner,game)
	await physics_frame
	runner._physics_process(1.0/60.0)
	tracker.set_input("primary_click",true)
	runner._physics_process(1.0/60.0)
	tracker.set_input("primary_click",false)
	for i in range(35):
		runner._physics_process(1.0/60.0)
		await physics_frame
	run_hud.refresh(0)
	check(runner._sprint_mode == 1 and runner.velocity.length() > 8 and run_hud.sprint_fill.scale.x < .95, "physical XR click plus actual movement drains visible stamina bar")
	# Preserve intent across ordinary two-hand weapon support, formerly a cancel.
	runner.sprint_conflict_provider = game.weapon
	game.weapon.weapons[game.weapon.selected].supported = true
	runner._physics_process(1.0/60.0)
	run_hud.refresh(0)
	check(runner._sprint_mode == 1 and runner.velocity.length() > 8, "actual rack support state no longer destroys first sprint toggle")
	var first_fraction: float = run_hud.sprint_fill.scale.x
	tracker.set_input("primary_click",true)
	runner._physics_process(1.0/60.0)
	run_hud.refresh(0)
	check(runner._sprint_mode == 2 and runner.velocity.length() > 9.6 and run_hud.sprint_fill.scale.x < first_fraction, "later second click increases actual speed while visible stamina continues draining")
	game.field_menu.settings_page = "game"
	game.field_menu.set_numeric_setting(2,1.5)
	game._save_settings(game.field_menu.get_settings())
	hud.refresh(0)
	check(is_equal_approx(hud.hud_size,1.5) and is_equal_approx(hud.health_fill.scale.x,.8*1.5), "actual menu numeric slider save changes live meter geometry")
	hud.set_hud_size(99)
	check(is_equal_approx(hud.hud_size,1.75), "HUD renderer clamps oversized scale")
	hud.set_hud_size(-5)
	check(is_equal_approx(hud.hud_size,.65), "HUD renderer clamps undersized scale")
	hud.set_hud_size(NAN)
	check(is_equal_approx(hud.hud_size,1.0), "HUD renderer rejects nonfinite scale")
	XRServer.remove_tracker(tracker)
	runner.queue_free()
	floor_body.queue_free()
	stop_audio(game)
	await create_timer(.1).timeout
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.1).timeout
	var reloaded = load("res://scripts/main.gd").new()
	root.add_child(reloaded)
	reloaded.set_process(false)
	reloaded.player.set_physics_process(false)
	stop_audio(reloaded)
	check(is_equal_approx(reloaded.field_menu.hud_size,1.5) and is_equal_approx(reloaded.combat_hud.hud_size,1.5), "new actual Main loads saved menu size and applies meter geometry at startup")
	stop_audio(reloaded)
	await create_timer(.1).timeout
	reloaded.queue_free()
	await process_frame
	await process_frame
	await create_timer(.1).timeout
	print("HUD_038_INTEGRATION_RESULT passes=", passed, " failures=", failures.size(), " synthetic_xr_camera=true live_openxr=false pixels_verified=false headset_tested=false")
	quit(0 if failures.is_empty() else 1)





