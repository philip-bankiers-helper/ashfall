extends SceneTree

var passes := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		printerr("FAIL ", label)

func stop_nodes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		stop_nodes(child)

func write_save(value: Variant) -> void:
	var file := FileAccess.open("user://campaign.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(value))

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		printerr("Isolated APPDATA required")
		quit(2)
		return
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	main.new_campaign()
	stop_nodes(main)
	write_save({"version": 1, "chapter": -10, "kills": -40, "play_time": -3})
	main._load_progress()
	check(main.chapter == 0 and main.total_kills == 0 and main.play_time == 0, "negative save values clamp safely")
	write_save({"version": 1, "chapter": 999, "kills": 24, "play_time": 34.5})
	main._load_progress()
	check(main.chapter == main.CHAPTERS.size(), "out-of-range chapter clamps to campaign end")
	write_save({"version": 99, "chapter": 1, "kills": 2})
	main._load_progress()
	check(main.chapter == main.CHAPTERS.size() and main.total_kills == 24, "unknown save version does not overwrite state")
	write_save([1,2,3])
	main._load_progress()
	check(main.chapter == main.CHAPTERS.size(), "non-object save safely ignored")
	for field in ["chapter", "kills", "play_time"]:
		for bad_value in [null, "not-a-number", {}, [], true]:
			var data := {"version": 1, "chapter": 1, "kills": 4, "play_time": 12.5}
			data[field] = bad_value
			write_save(data)
			check(not main._load_progress() and main.chapter == main.CHAPTERS.size() and main.total_kills == 24, "invalid %s type %d rejected without partial mutation" % [field, typeof(bad_value)])
	for chapter in range(1, main.CHAPTERS.size()):
		write_save({"version": 1, "chapter": chapter, "kills": 4, "play_time": 12.5})
		main._load_progress()
		check(main.chapter == chapter and main.player.global_position.is_equal_approx(main.world.objective_positions[chapter-1] + Vector3(0,1,3)), "checkpoint %d loads expected spawn" % chapter)
	main.new_campaign()
	stop_nodes(main)
	main._damage_player(200)
	check(main.dead, "lethal damage arms delayed checkpoint recovery")
	main.new_campaign()
	stop_nodes(main)
	var expected_position: Vector3 = main.world.player_spawn + Vector3(2,0,0)
	main.player.global_position = expected_position
	main.health = 73
	var expected_enemy = main.enemies[0]
	await create_timer(2.7).timeout
	check(main.health == 73 and main.player.global_position.is_equal_approx(expected_position), "new campaign cancels stale death timer health and position reset")
	check(is_instance_valid(expected_enemy) and main.enemies[0] == expected_enemy, "new campaign cancels stale death timer encounter replacement")
	main.player.velocity = Vector3(3,4,5)
	main.player.gliding = true
	main.weapon.eject_magazine()
	main._damage_player(200)
	write_save({"version": 1, "chapter": 0, "kills": 0, "play_time": 2.5})
	check(main.load_checkpoint(), "checkpoint can be loaded while death recovery is pending")
	stop_nodes(main)
	check(main.health == 100 and not main.dead and main.weapon.ammo == 24 and main.weapon.reload_state == "ready", "checkpoint restores health and rifle readiness")
	check(main.player.velocity == Vector3.ZERO and not main.player.gliding and main.player.global_position.is_equal_approx(main.world.player_spawn), "chapter zero checkpoint restores spawn and clears motion")
	main.health = 61
	main.player.global_position = expected_position
	expected_enemy = main.enemies[0]
	await create_timer(2.7).timeout
	check(main.health == 61 and main.player.global_position.is_equal_approx(expected_position) and is_instance_valid(expected_enemy) and main.enemies[0] == expected_enemy, "checkpoint load invalidates earlier death timer")
	write_save({"version": 1, "chapter": main.CHAPTERS.size(), "kills": 24, "play_time": 60})
	check(main.load_checkpoint() and main.complete and main.enemies.is_empty(), "completed checkpoint restores completion without respawning hostiles")
	check(is_instance_valid(main.world.rescue_craft), "completed checkpoint starts evacuation arrival")
	main.new_campaign()
	stop_nodes(main)
	await process_frame
	check(not is_instance_valid(main.world.rescue_craft), "new campaign clears completed evacuation craft")
	var backup := FileAccess.open("user://campaign.json.backup", FileAccess.WRITE)
	backup.store_string(JSON.stringify({"version":1,"chapter":1,"kills":4,"play_time":9.5}))
	backup.close()
	var broken := FileAccess.open("user://campaign.json", FileAccess.WRITE)
	broken.store_string("{broken checkpoint")
	broken.close()
	check(main.load_checkpoint() and main.chapter == 1 and main.total_kills == 4, "explicit checkpoint load recovers verified backup after corrupt primary")
	stop_nodes(main)
	write_save({"version":99,"chapter":2,"kills":10,"play_time":20})
	check(not main.load_checkpoint() and main.chapter == 1, "future primary schema blocks backup downgrade in main")
	write_save({"version":1,"chapter":0,"kills":0,"play_time":0})
	stop_nodes(main)
	await create_timer(0.2).timeout
	main.free()
	print("CAMPAIGN_RECOVERY_RESULT passes=", passes, " failures=", failures, " synthetic=true headset_tested=false")
	quit(0 if failures == 0 else 1)
