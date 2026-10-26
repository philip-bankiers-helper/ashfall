extends SceneTree
## Headless input-boundary test. These two adapters select the VR code paths
## without starting OpenXR. All hand validation/input/weapon logic is inherited.
class SyntheticPlayer extends "res://scripts/player.gd":
	func update_tracking() -> bool:
		return tracking_available

class SyntheticWeapon extends "res://scripts/weapon.gd":
	func _vr_active() -> bool:
		return true

var failures := 0
var passes := 0
var shots := 0
var actor: SyntheticPlayer
var weapon: SyntheticWeapon
var left: XRControllerTracker
var right: XRControllerTracker

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		printerr("FAIL ", label)

func tracker(name_value: String, hand: XRController3D) -> XRControllerTracker:
	var value := XRControllerTracker.new()
	value.type = XRServer.TRACKER_CONTROLLER
	value.name = name_value
	XRServer.add_tracker(value)
	hand.tracker = value.name
	hand.pose = "grip"
	value.set_pose("grip", hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	return value

func tick() -> void:
	actor._physics_process(1.0 / 90.0)
	weapon._process(1.0 / 90.0)

func neutral_ticks() -> void:
	for i in range(8): tick()

func restore(value: XRControllerTracker, hand: XRController3D) -> void:
	XRServer.add_tracker(value)
	hand.pose = "grip"
	value.set_pose("grip", hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame

func run() -> void:
	print("SCOPE synthetic controller lifecycle; HMD focus and renderer deliberately bypassed; headset_tested=false")
	actor = SyntheticPlayer.new()
	root.add_child(actor)
	actor.setup(true)
	actor.tracking_available = true
	actor.set_physics_process(false)
	actor.set_process(false)
	left = tracker("qa_loss_left", actor.left_hand)
	right = tracker("qa_loss_right", actor.right_hand)
	await process_frame
	weapon = SyntheticWeapon.new()
	root.add_child(weapon)
	weapon.setup(actor)
	weapon.set_process(false)
	weapon.shot.connect(func(_origin, _direction, _damage): shots += 1)
	neutral_ticks()
	check(actor.is_hand_tracked(actor.left_hand) and actor.is_hand_tracked(actor.right_hand), "both real XRController nodes accept synthetic poses")
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(0,-0.025,-0.36))
	left.set_input("grip", 1.0)
	tick()
	check(weapon.supported, "support acquired through production process")
	XRServer.remove_tracker(left)
	await process_frame
	tick()
	check(not actor.is_hand_tracked(actor.left_hand), "removed offhand tracker invalidates hand")
	check(not weapon.supported and not actor.left_hand_reserved, "offhand loss releases support and reservation")
	check(actor.is_hand_input_ready(actor.right_hand), "offhand loss preserves opposite hand readiness")
	await restore(left, actor.left_hand)
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(0,-0.025,-0.36))
	tick()
	check(not weapon.supported and not actor.is_hand_input_ready(actor.left_hand), "recovered held grip cannot reacquire support or player gestures")
	left.set_input("grip", 0.0)
	neutral_ticks()
	left.set_input("grip", 1.0)
	tick()
	check(weapon.supported and actor.is_hand_input_ready(actor.left_hand), "neutral then fresh grip restores fore-end support")
	left.set_input("grip", 0.0)
	tick()
	right.set_input("by_button", true)
	tick()
	check(weapon.reload_state == "ready", "old B binding no longer ejects rifle magazine")
	right.set_input("by_button", false)
	right.set_input("primary", Vector2(0,-1))
	tick()
	check(weapon.reload_state == "needs_mag", "right stick downward gesture ejects magazine")
	right.set_input("primary", Vector2.ZERO)
	tick()
	actor.left_hand.global_position = actor.get_view_camera().global_position + Vector3(-0.23,-0.62,0.02)
	left.set_input("grip", 1.0)
	tick()
	check(weapon.reload_state == "needs_mag", "obsolete hip pocket is not an ammunition source")
	left.set_input("grip", 0.0)
	tick()
	actor.left_hand.global_position = weapon.get_offered_magazine_transform().origin
	left.set_input("grip", 1.0)
	tick()
	check(weapon.reload_state == "held_mag", "fresh weapon-local gesture begins reload")
	actor.left_hand.global_position += weapon.global_basis.y * 0.02
	tick()
	check(weapon.reload_state == "held_mag", "small hand jitter cannot seat offered magazine")
	XRServer.remove_tracker(left)
	await process_frame
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(0,-0.18,-0.15))
	tick()
	check(weapon.reload_state == "held_mag" and not weapon.loose_magazine.visible, "offhand loss hides held magazine and prevents stale insertion")
	await restore(left, actor.left_hand)
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(0,-0.18,-0.15))
	tick()
	check(weapon.reload_state == "held_mag", "reacquired held grip cannot insert magazine")
	left.set_input("grip", 0.0)
	neutral_ticks()
	check(weapon.reload_state == "needs_mag", "release after reacquisition safely drops magazine")
	actor.left_hand.global_position = weapon.get_offered_magazine_transform().origin
	left.set_input("grip", 1.0)
	tick()
	check(weapon.reload_state == "held_mag", "fresh grip after tracking recovery reacquires magazine")
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(0,-0.18,-0.15))
	tick()
	left.set_input("grip", 0.0)
	tick()
	actor.left_hand.global_position = weapon.reload_world_point(Vector3(-0.05,0.064,-0.10))
	left.set_input("grip", 1.0)
	tick()
	actor.left_hand.global_position += weapon.global_basis.z * 0.04
	tick()
	check(weapon.reload_state == "needs_rack" and weapon.bolt.position.z > -0.08, "partial charging pull moves bolt without completing reload")
	XRServer.remove_tracker(left)
	await process_frame
	tick()
	check(not weapon._rack_grabbed and is_equal_approx(weapon.bolt.position.z, -0.10), "offhand loss releases charging latch and returns bolt")
	await restore(left, actor.left_hand)
	weapon.reset_weapon()
	left.set_input("grip", 0.0)
	right.set_input("trigger", 0.0)
	neutral_ticks()
	right.set_input("trigger", 1.0)
	tick()
	check(shots == 1, "valid right trigger produces actual shot signal")
	XRServer.remove_tracker(right)
	await process_frame
	weapon.cooldown = 0.0
	tick()
	check(shots == 1 and not weapon.model.visible, "right tracker loss hides weapon and blocks held fire")
	await restore(right, actor.right_hand)
	weapon.cooldown = 0.0
	tick()
	check(shots == 1 and weapon.model.visible, "right hand returns but held trigger remains gated")
	right.set_input("trigger", 0.0)
	neutral_ticks()
	right.set_input("trigger", 1.0)
	tick()
	check(shots == 2, "release then fresh trigger restores fire")
	actor.head_obstructed = true
	right.set_input("trigger", 0.0)
	weapon._process(0.2)
	var ammo_before_obstruction: int = weapon.ammo
	right.set_input("trigger", 1.0)
	weapon._process(0.2)
	check(weapon.ammo == ammo_before_obstruction and shots == 2 and actor.input_enabled, "head obstruction blocks fresh trigger without disabling retreat input")
	actor.head_obstructed = false
	right.set_input("trigger", 0.0)
	left.set_input("grip", 1.0)
	actor._grabs[actor.left_hand] = actor.left_hand.global_position
	actor._release_velocity = Vector3(4,5,0)
	XRServer.remove_tracker(left)
	await process_frame
	actor.update_hand_input_rearm(1.0 / 90.0)
	check(actor._grabs.is_empty() and actor.velocity == Vector3.ZERO and actor._release_velocity == Vector3.ZERO, "tracking loss detaches seeded climb without launch impulse")
	await restore(left, actor.left_hand)
	left.set_input("grip", 0.0)
	left.set_input("primary", Vector2(0,1))
	left.set_input("ax_button", true)
	left.set_input("by_button", true)
	neutral_ticks()
	check(not actor.is_hand_input_ready(actor.left_hand) and absf(actor.velocity.x) < 0.01 and absf(actor.velocity.z) < 0.01, "held stick and face buttons across recovery cannot rearm or move")
	left.set_input("primary", Vector2.ZERO)
	left.set_input("ax_button", false)
	left.set_input("by_button", false)
	neutral_ticks()
	check(actor.is_hand_input_ready(actor.left_hand), "neutral interval rearms recovered locomotion hand")
	actor._grabs[actor.left_hand] = actor.left_hand.global_position
	actor._release_velocity = Vector3(4,5,0)
	actor._update_grab(actor.left_hand, false)
	check(actor.velocity.is_equal_approx(Vector3(5,6.25,0)), "intentional grip release still preserves ordinary launch impulse")
	actor.reset_motion()
	var menu = load("res://scripts/menu.gd").new()
	root.add_child(menu)
	menu.setup(actor)
	menu.set_process(false)
	XRServer.remove_tracker(left)
	await process_frame
	tick()
	menu._process(1.0 / 90.0)
	left.set_input("menu_button", true)
	await restore(left, actor.left_hand)
	neutral_ticks()
	menu._process(1.0 / 90.0)
	check(not menu.is_open, "held menu button across tracking loss cannot open menu")
	left.set_input("menu_button", false)
	neutral_ticks()
	menu._process(1.0 / 90.0)
	left.set_input("menu_button", true)
	tick()
	menu._process(1.0 / 90.0)
	check(menu.is_open and not actor.input_enabled, "fresh menu press after neutral recovery opens menu")
	menu.set_open(false)
	check(not actor.is_hand_input_ready(actor.left_hand) and not actor.is_hand_input_ready(actor.right_hand), "closing menu disarms both hands until neutral")
	menu.free()
	XRServer.remove_tracker(left)
	XRServer.remove_tracker(right)
	weapon._sound.stop()
	await create_timer(0.2).timeout
	weapon.free()
	actor.free()
	await test_objective_loss()
	print("CONTROLLER_LOSS_RESULT passes=", passes, " failures=", failures, " synthetic=true headset_tested=false")
	quit(0 if failures == 0 else 1)

func stop_nodes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		stop_nodes(child)

func test_objective_loss() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		check(false, "objective test requires isolated save directory")
		return
	var script = load("res://scripts/main.gd")
	if script == null or not script.can_instantiate():
		check(false, "campaign compiles for objective tracking test")
		return
	var main = script.new()
	root.add_child(main)
	main.new_campaign()
	stop_nodes(main)
	for enemy in main.enemies.duplicate():
		enemy.take_damage(10000)
	var point:Vector3=main._station_grip_targets()[0].position
	main.player.global_position = point+Vector3(0,-1,.65)
	main.player.right_hand.global_position=point+Vector3(0,0,.12)
	main.xr_enabled = true
	main.player.xr_enabled=true
	main.player.tracking_available=true
	var button_tracker := tracker("qa_objective_right", main.player.right_hand)
	await physics_frame
	for i in range(8): main.player.update_hand_input_rearm(1.0 / 90.0)
	main.player.update_objective_grips()
	button_tracker.set_input("grip", 1.0)
	button_tracker.invalidate_pose("grip")
	main.player.update_hand_input_rearm(1.0 / 90.0)
	check(main.player.right_hand.get_float("grip")>.65 and not main.player.is_hand_tracked(main.player.right_hand), "stale grip survives invalid pose in harness")
	await physics_frame
	main.player.update_objective_grips()
	check(main.chapter == 0, "invalid right pose with held grip cannot activate cleared nearby objective")
	button_tracker.set_pose("grip", main.player.right_hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in range(8): main.player.update_hand_input_rearm(1.0 / 90.0)
	await physics_frame
	main.player.update_objective_grips()
	check(main.chapter == 0, "restored pose with grip still held cannot activate objective")
	button_tracker.set_input("grip", 0.0)
	for i in range(8): main.player.update_hand_input_rearm(1.0 / 90.0)
	await physics_frame
	main.player.update_objective_grips()
	check(main.chapter == 0, "restored valid pose without grip preserves objective")
	button_tracker.set_input("grip", 1.0)
	await physics_frame
	main.player.update_objective_grips()
	check(main.chapter == 1, "valid right pose and fresh near-screen grip advances objective")
	XRServer.remove_tracker(button_tracker)
	stop_nodes(main)
	await create_timer(0.2).timeout
	main.free()
