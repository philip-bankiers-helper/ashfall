extends "res://tests/controller_loss.gd"
## Reuses only synthetic tracker helpers and assertion reporting.
func run() -> void:
	actor = SyntheticPlayer.new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_physics_process(false)
	actor.set_process(false)
	weapon = SyntheticWeapon.new()
	root.add_child(weapon)
	weapon.setup(actor)
	weapon.set_process(false)
	var training = load("res://scripts/training.gd").new()
	root.add_child(training)
	training.setup(actor, weapon)
	training.set_process(false)
	check(training.get_hint().contains("WASD"), "desktop starts with movement hint")
	actor.position.x += 1.6
	training.observe_progress()
	check(training.get_progress().has("move"), "actual position change records movement")
	weapon.eject_magazine()
	check(training.get_hint(false).is_empty(), "production HUD policy suppresses reload instructions")
	check(training.get_hint().contains("insert magazine"), "ejected magazine prioritizes local insertion hint")
	weapon.grab_magazine()
	check(training.get_hint().contains("insert"), "held magazine prioritizes insertion hint")
	weapon.insert_magazine()
	check(training.get_hint().contains("rack"), "seated magazine prioritizes charging hint")
	weapon.rack_bolt()
	training.observe_progress()
	check(training.get_progress().has("reload"), "actual full reload records training progress")
	actor.input_enabled = false
	check(training.get_hint().is_empty(), "menu input lock suppresses hints")
	actor.input_enabled = true
	actor.head_obstructed = true
	check(training.get_hint().is_empty(), "head obstruction suppresses hints")
	actor.head_obstructed = false
	actor.xr_enabled = true
	actor.tracking_available = false
	check(training.get_hint().is_empty(), "missing tracking suppresses VR hints")
	actor.tracking_available = true
	left = tracker("qa_training_left", actor.left_hand)
	right = tracker("qa_training_right", actor.right_hand)
	await process_frame
	check(training.get_hint().is_empty(), "tracked but unarmed hands suppress VR hints")
	for i in range(8): actor.update_hand_input_rearm(1.0 / 90.0)
	training.reset()
	check(training.get_hint().contains("Left stick"), "neutral ready hands enable VR movement hint")
	check(training.get_progress().is_empty(), "training reset clears prior progress")
	weapon.eject_magazine()
	check(training.get_hint().contains("below weapon") and not training.get_hint().contains("hip"), "VR reload hint describes weapon-local acquisition instead of hip")
	weapon.reset_weapon()
	actor.climbing = true
	training.observe_progress()
	check(training.get_progress().has("climb"), "climb state records training progress")
	actor.gliding = true
	training.observe_progress()
	check(training.get_progress().has("glide"), "glide state records training progress")
	XRServer.remove_tracker(left)
	XRServer.remove_tracker(right)
	weapon.shutdown()
	await create_timer(0.15).timeout
	training.free()
	weapon.free()
	actor.free()
	print("TRAINING_RESULT passes=", passes, " failures=", failures, " synthetic=true headset_tested=false")
	quit(0 if failures == 0 else 1)
