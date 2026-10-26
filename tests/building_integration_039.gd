extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; printerr("FAIL ", label)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.building_input.set_physics_process(false)
	var adapter = game.building_input
	var rack = game.weapon
	var actor = game.player
	game.field_menu.set_open(false)
	game.paused = false
	actor.input_enabled = true
	rack.set_holstered(true)
	check(game.field_builder != null and rack.construction_provider == game.field_builder, "actual Main wires builder and rack")
	check(adapter.eligible(), "holstered neutral gameplay eligible")
	actor.tracking_available = false
	check(not adapter.eligible(), "tracking loss blocks")
	actor.tracking_available = true
	for flag in ["paused", "dead", "complete"]:
		game.set(flag, true)
		check(not adapter.eligible(), "blocks " + flag)
		game.set(flag, false)
	game.field_menu.set_open(true)
	check(not adapter.eligible(), "menu blocks before paused update")
	game.field_menu.set_open(false)
	actor.input_enabled = true
	rack.set_holstered(false)
	check(not adapter.eligible(), "drawn weapon blocks")
	rack.set_holstered(true)
	rack.is_selecting = true
	check(not adapter.eligible(), "wheel blocks")
	rack.is_selecting = false
	for flag in ["climbing", "mantling", "head_obstructed"]:
		actor.set(flag, true)
		check(not adapter.eligible(), "blocks " + flag)
		actor.set(flag, false)
	for hand in [actor.left_hand, actor.right_hand]:
		actor._grabs[hand] = hand.global_position
		check(not adapter.eligible(), "actual hand climb blocks")
		actor._grabs.clear()
	var active = rack.weapons[rack.selected]
	for stage in ["held_mag", "needs_rack"]:
		active.reload_state = stage
		check(not adapter.eligible(), "blocks reload " + stage)
	active.reload_state = "ready"
	active._rack_grabbed = true
	check(not adapter.eligible(), "held rack blocks")
	active._rack_grabbed = false
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = true
	adapter._unhandled_input(event)
	check(not rack.is_holstered, "desktop B draws")
	adapter._unhandled_input(event)
	check(rack.is_holstered, "desktop B holsters")
	check(adapter.sample().cancel, "desktop transition cancels until physics sample")
	var targets: Array = game._construction_protected_targets()
	check(targets.size() >= game.objective_nodes.size(), "all locked and future station positions protected")
	# Synthetic tracked controllers exercise the actual adapter/rack, without HMD/GPU.
	actor.set_physics_process(false)
	rack.set_process(false)
	actor.xr_enabled = true
	actor.tracking_available = true
	actor.position = Vector3(1000, 0, 1000)
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 0.2, 30)
	collision.shape = shape
	ground.add_child(collision)
	game.add_child(ground)
	ground.position = Vector3(1000, -0.1, 1000)
	var trackers: Array[XRControllerTracker] = []
	for hand in [actor.left_hand, actor.right_hand]:
		var tracker := XRControllerTracker.new()
		tracker.type = XRServer.TRACKER_CONTROLLER
		tracker.name = "/user/build039/" + str(trackers.size())
		XRServer.add_tracker(tracker)
		hand.tracker = tracker.name
		hand.pose = "grip"
		var desired := Transform3D(Basis(Vector3.RIGHT, -0.35) * Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.3, 1.4, 0))
		tracker.set_pose("grip", desired, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trackers.append(tracker)
	await process_frame
	await physics_frame
	for dominant in ["right", "left"]:
		actor.dominant_hand = dominant
		rack._refresh_hands()
		rack.set_holstered(true)
		for hand in [actor.left_hand, actor.right_hand]: actor._hand_input_ready[hand] = true
		actor.input_enabled = true
		var primary: XRControllerTracker = trackers[1 if dominant == "right" else 0]
		var secondary: XRControllerTracker = trackers[0 if dominant == "right" else 1]
		game.field_builder.reset_builds()
		game.field_builder.piece_index = 0
		game.field_builder._set_piece()
		await physics_frame
		adapter._desktop_cancel = false
		primary.set_input("trigger", 0.0)
		secondary.set_input("trigger", 1.0)
		game.field_builder.tick_input(adapter.sample())
		check(not game.field_builder.is_active(), dominant + " ignores support trigger")
		secondary.set_input("trigger", 0.0)
		primary.set_input("trigger", 1.0)
		game.field_builder.tick_input(adapter.sample())
		check(game.field_builder.is_active(), dominant + " dominant trigger opens preview")
		check(game.field_builder.pieces.size() == 1, dominant + " opening press immediately places valid collider")
		primary.set_input("trigger", 0.0)
		game.field_builder.tick_input(adapter.sample())
		primary.set_input("trigger", 1.0)
		game.field_builder.tick_input(adapter.sample())
		check(game.field_builder.pieces.size() == 1, dominant + " release fresh press same slot cannot duplicate collider")
		var selected: int = rack.selected
		rack._switch_previous = false
		primary.set_input("by_button", true)
		rack._process(1.0/90.0)
		game.field_builder.tick_input(adapter.sample())
		check(rack.selected == selected and rack.is_holstered, dominant + " B/Y does not switch while building")
		check(game.field_builder.piece_index == 1, dominant + " B/Y cycles shape")
		primary.set_input("by_button", false)
		primary.set_input("ax_button", true)
		game.field_builder.tick_input(adapter.sample())
		check(not game.field_builder.is_active(), dominant + " A/X cancels preview")
		primary.set_input("ax_button", false)
		game.field_builder.tick_input(adapter.sample())
		check(not game.field_builder.is_active(), dominant + " held trigger after cancel requires neutral")
		primary.set_input("trigger", 0.0)
		await physics_frame
	for tracker in trackers: XRServer.remove_tracker(tracker)
	actor.xr_enabled = false

	game.field_builder.charges = 0
	game._begin_chapter()
	check(game.field_builder.charges == game.field_builder.initial_charges, "chapter reset restores construction budget")
	check(not game.field_builder.is_active(), "chapter reset hides construction")
	print("BUILDING_INTEGRATION_039 ", passed, " passed ", failed, " failed")
	game._quitting = true
	game.weapon.shutdown()
	game._stop_audio_tree(game)
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failed == 0 else 1)

