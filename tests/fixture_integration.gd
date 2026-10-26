extends SceneTree
var passes := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	if ok: passes += 1; print("PASS ", label)
	else: failures += 1; printerr("FAIL ", label)
func quiet(node: Node):
	node.set_process(false)
	node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): quiet(child)
func shoot(main, fixture):
	main._on_shot(fixture.global_position + Vector3(0,-1,0), Vector3.UP, 30)
func run():
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/fixture-test-appdata"):
		printerr("Isolated fixture APPDATA required"); quit(2); return
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	main.new_campaign()
	quiet(main)
	await physics_frame
	await physics_frame
	var fixture = main.world.destructible_fixtures[0]
	var point = Vector3(0,3,-18)
	var baseline = main.world.get_light_exposure(point)
	shoot(main, fixture)
	check(fixture.broken and fixture.light.light_energy == 0, "production shot ray disables fixture")
	check(main.toast == "LIGHT DISABLED", "production shot feedback reports LIGHT DISABLED")
	check(main.world.get_light_exposure(point) < baseline-0.1, "production hit lowers actual exposure")
	for enemy in main.enemies: enemy.queue_free()
	main.enemies.clear()
	main.player.global_position = main.world.objective_positions[0]
	main._activate_objective()
	quiet(main)
	check(main.chapter == 1 and fixture.broken, "actual objective advance preserves broken fixture")
	check(main.load_checkpoint(), "production checkpoint load succeeds")
	quiet(main)
	check(not fixture.broken and is_equal_approx(main.world.get_light_exposure(point),baseline), "checkpoint restores intact fixture and calibrated exposure")
	shoot(main, fixture)
	main.dead = true
	main._respawn()
	quiet(main)
	check(not fixture.broken and fixture.light.light_energy > 0, "production respawn restores fixture")
	shoot(main, fixture)
	main.new_campaign()
	quiet(main)
	check(not fixture.broken and main.chapter == 0, "production new campaign restores fixture")
	await create_timer(0.15).timeout
	main.queue_free()
	await create_timer(0.15).timeout
	print("FIXTURE_INTEGRATION_RESULT passes=",passes," failures=",failures," synthetic=true headset_tested=false")
	quit(0 if failures == 0 else 1)
