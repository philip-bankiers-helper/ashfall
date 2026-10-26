extends SceneTree
var passes := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passes += 1; print("PASS ", label)
	else: failures += 1; printerr("FAIL ", label)

func stop_nodes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): stop_nodes(child)

func capture(name_value: String) -> void:
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../reports/" + name_value + ".png")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		printerr("Isolated APPDATA required"); quit(2); return
	root.size = Vector2i(1280, 800)
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	stop_nodes(main)
	main.encounter_active = true
	main.toast_time = 0
	main.radio_text = main.RADIO[0]
	main.radio_time = 17.0
	main._update_compact_hud(0.1, "11 / 24", "RELAY 15 m", "EXPOSED TO LIGHT", "UNDETECTED", "")
	check(main.vr_label.text.split("\n").size() == 2 and main.vr_cue.text.split("\n").size() <= 2, "status and cue bounded to two lines each")
	var original: String = main.radio_text
	var rebuilt: String = " ".join(main._caption_pages).replace("\n", " ")
	check(rebuilt == original, "radio pagination preserves every word")
	var clock_before: float = main._caption_clock
	main._update_compact_hud(1.0, "11 / 24", "PRESS RIGHT A / F TO ACTIVATE", "EXPOSED", "UNDETECTED", "")
	check(main.vr_cue.text.contains("ACTIVATE") and main._caption_clock == clock_before, "near interaction takes priority and pauses caption progress")
	main.weapon.weapons[0].reload_state = "needs_rack"
	main._update_compact_hud(1.0, "0 / 24", "RELAY 15 m", "EXPOSED", "UNDETECTED", "Grip the charging handle and pull back.")
	check(main.vr_cue.text.contains("charging handle") and main._caption_clock == clock_before, "reload takes priority without discarding pending radio")
	main.weapon.weapons[0].reload_state = "ready"
	main.radio_time = 0.0
	var seen: Dictionary = {}
	for i in range(40):
		main._update_compact_hud(1.0, "11 / 24", "RELAY 15 m", "EXPOSED", "UNDETECTED", "")
		if not main.radio_label.text.is_empty(): seen[main.radio_label.text] = true
	check(seen.size() == main._caption_pages.size() and not main._caption_pending, "interrupted subtitles finish all pages even after voice timer expires")
	main._update_compact_hud(0.0, "11 / 24", "RELAY 15 m", "EXPOSED", "UNDETECTED", "")
	check(not main._hud_bottom.visible and not main._hud_controls.visible, "empty desktop bottom panel and combat controls hidden")
	main.chapter = 3
	var saved_position: Vector3 = main.player.global_position
	main.player.global_position = main.world.objective_positions[3] + Vector3(123, 0, 0)
	var longest: String = main._compact_status("24 / 24", "PARTLY LIT", "SUSPICIOUS")
	check(longest.split("\n")[1].length() <= 38 and longest.contains("EXTRACT 123m | PART LIT / SUSPICIOUS"), "long extraction status remains concise without smaller type")
	main.chapter = 0
	main.player.global_position = saved_position
	main.encounter_active = false
	check(main._compact_status("24 / 24", "PARTLY LIT", "SUSPICIOUS").ends_with("STAGING | ADVANCE WHEN READY"), "staging uses concise production status")
	main.encounter_active = true
	if "--capture" in OS.get_cmdline_user_args():
		main.radio_time = 17.0
		main.weapon.weapons[0]._process(0.016)
		main._process(0.0)
		check(main.hud.text == main.vr_label.text and main.hud.text.contains("24 / 24"), "real process populates shared desktop and VR status from actual ammo")
		await capture("hud-fullgame-desktop")
		main.ui_layer.visible = false
		main.vr_label.visible = true
		main.vr_cue.visible = true
		main.weapon.weapons[0]._process(0.016)
		await capture("hud-fullgame-radio")
		main.player.global_position = main.world.objective_positions[0] + Vector3(0, 0.0, 2.7)
		main.player.get_view_camera().look_at(main.world.objective_positions[0] + Vector3(0, 1.3, 0))
		main.weapon.weapons[0]._process(0.016)
		main._process(0.0)
		main.vr_label.visible = true
		main.vr_cue.visible = true
		await capture("hud-fullgame-near-objective")
		main.chapter = 3
		main.player.global_position = main.world.objective_positions[3] + Vector3(123, 0, 0)
		main.player.get_view_camera().look_at(main.world.objective_positions[3] + Vector3(0, 2, 0))
		main._light_exposure = 0.45
		main._enemy_awareness = 0.4
		main._awareness_timer = 999.0
		main._process(0.0)
		main.vr_label.visible = true
		main.vr_cue.visible = true
		main.weapon.weapons[0]._process(0.016)
		await capture("hud-fullgame-long-status")
		main.chapter = 0
		main.player.global_position = saved_position
		main.player.get_view_camera().rotation = Vector3.ZERO
		main.encounter_active = false
		main._process(0.0)
		main.ui_layer.visible = true
		main.vr_label.visible = false
		main.vr_cue.visible = false
		main.weapon.weapons[0]._process(0.016)
		await capture("hud-fullgame-staging")
	main._stop_audio_tree(main)
	await create_timer(0.2).timeout
	main.free()
	await process_frame
	print("HUD_READABILITY_RESULT passes=", passes, " failures=", failures, " synthetic_view=true headset_tested=false")
	quit(0 if failures == 0 else 1)
