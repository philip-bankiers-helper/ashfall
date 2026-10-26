extends "res://tests/integration.gd"
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2); return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	stop_audio(game)
	var menu = game.field_menu
	var actor = game.player
	menu.apply_settings({})
	check(is_equal_approx(actor.glide_steering_gain,.875) and is_equal_approx(actor.sprint_fast_gain,1.75),"empty settings use new defaults without migration halving")
	menu.apply_settings({})
	check(is_equal_approx(actor.glide_steering_gain,.875),"repeated empty defaults never halve again")
	menu.apply_settings({"glide_steering_gain":1.75,"sprint_fast_gain":1.5,"movement_settings_version":3})
	check(is_equal_approx(actor.glide_steering_gain,.875) and is_equal_approx(actor.sprint_fast_gain,1.75),"actual legacy039 saved defaults migrate once")
	var migrated: Dictionary = menu.get_settings()
	check(migrated.controls_tuning_revision==1,"save marks migrated controls revision")
	game._save_settings(migrated)
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	for i in range(3): menu.apply_settings(persisted)
	check(is_equal_approx(actor.glide_steering_gain,.875) and is_equal_approx(actor.sprint_fast_gain,1.75),"actual JSON reload migration is idempotent")
	menu.apply_settings({"glide_steering_gain":2.2,"sprint_fast_gain":2.1})
	check(is_equal_approx(actor.glide_steering_gain,1.1) and is_equal_approx(actor.sprint_fast_gain,2.1),"legacy custom steering halves and custom fast gain preserved")
	var custom: Dictionary = menu.get_settings()
	menu.apply_settings(custom)
	check(is_equal_approx(actor.glide_steering_gain,1.1) and is_equal_approx(actor.sprint_fast_gain,2.1),"custom migrated tuning retains values on subsequent apply")
	menu.apply_settings({"controls_tuning_revision":1,"glide_steering_gain":1.75,"sprint_fast_gain":1.5})
	check(is_equal_approx(actor.glide_steering_gain,1.75) and is_equal_approx(actor.sprint_fast_gain,1.5),"revision1 explicit user tuning is never rewritten")
	menu.reset_movement_settings()
	check(is_equal_approx(actor.glide_steering_gain,.875) and is_equal_approx(actor.sprint_fast_gain,1.75) and is_equal_approx(actor.sprint_slow_gain,1.25),"menu Reset Defaults restores latest requested three tunings")
	menu.settings_page="movement"
	check(menu._labels()[0].contains("HEAD HEADING"),"menu labels default head orientation")
	menu._adjust_setting(0,1)
	check(actor.forward_reference=="hand" and menu._labels()[0].contains("LEFT CONTROLLER HEADING"),"actual menu choice selects physical left controller heading")
	game._save_settings(menu.get_settings())
	persisted=JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	menu.apply_settings({})
	menu.apply_settings(persisted)
	check(actor.forward_reference=="hand","actual settings JSON persists controller orientation choice")
	var tracker := XRControllerTracker.new()
	tracker.type=XRServer.TRACKER_CONTROLLER
	tracker.name="qa040settingsleft"
	XRServer.add_tracker(tracker)
	actor.left_hand.tracker=tracker.name
	actor.left_hand.pose="grip"
	tracker.set_pose("grip",Transform3D(Basis(Vector3.UP,PI/2),Vector3(.2,1.3,-.3)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	actor.xr_enabled=true
	actor._hand_input_ready[actor.left_hand]=true
	await process_frame
	check(actor.get_movement_forward().is_equal_approx(Vector3.LEFT),"saved controller menu choice drives production horizontal yaw")
	menu._adjust_setting(0,1)
	check(actor.forward_reference=="head" and actor.get_movement_forward().is_equal_approx(Vector3.FORWARD),"menu switches live heading back to head")
	actor.xr_enabled=false
	XRServer.remove_tracker(tracker)
	stop_audio(game)
	print("LOCOMOTION_SETTINGS_040_RESULT passes=",passed," failures=",failures.size()," headset_tested=false")
	await game._quit_game(0 if failures.is_empty() else 1,"test_complete")
