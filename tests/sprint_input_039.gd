extends SceneTree
## Production player physics and controller APIs, real Main/world; only the HMD
## focus/presence boundary is synthetic. No direct writes to sprint tier/stamina.
class SyntheticPlayer extends "res://scripts/player.gd":
	func update_tracking() -> bool:
		if not tracking_available:
			reset_motion()
			require_neutral_input()
		return tracking_available

const DT := 1.0 / 90.0
var actor: SyntheticPlayer
var left: XRControllerTracker
var right: XRControllerTracker
var passed := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failures += 1; printerr("FAIL ", label)
func disable(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): disable(child)
func tracker(id: String, hand: XRController3D) -> XRControllerTracker:
	var value := XRControllerTracker.new()
	value.type = XRServer.TRACKER_CONTROLLER
	value.name = id
	XRServer.add_tracker(value)
	hand.tracker = value.name
	hand.pose = "grip"
	value.set_pose("grip", hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	return value
func tick(count: int = 1) -> void:
	for i in count: actor._physics_process(DT)
func speed(expected: float, label: String) -> void:
	var start := actor.global_position
	tick(30)
	var actual := Vector2(actor.velocity.x, actor.velocity.z).length()
	var displacement := Vector2(actor.global_position.x-start.x, actor.global_position.z-start.z).length() / (30*DT)
	print("MEASURE ", label, " velocity=", actual, " displacement_mps=", displacement, " stamina=", actor._sprint_stamina, " supported=", actor.is_supported())
	check(absf(actual-expected)<.015 and absf(displacement-expected)<.015, label)
func neutral() -> void:
	left.set_input("primary", Vector2.ZERO)
	left.set_input("primary_click", false)
	right.set_input("primary_click", false)
	tick(12)
func press() -> void:
	left.set_input("primary_click", true)
	tick()
func release_click(delay: int = 2) -> void:
	left.set_input("primary_click", false)
	tick(delay)
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2); return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	disable(game)
	actor = SyntheticPlayer.new()
	game.add_child(actor)
	actor.setup(true)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.xr_camera.position.y = 1.65
	actor.position = Vector3(1000,0,1000)
	actor.tracking_available = true
	game.player = actor
	game.field_menu.player = actor
	left = tracker("qa_sprint_left", actor.left_hand)
	right = tracker("qa_sprint_right", actor.right_hand)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000,.2,2000)
	collision.shape = shape
	floor_body.add_child(collision)
	game.add_child(floor_body)
	floor_body.position = Vector3(1000,-.1,1000)
	await physics_frame
	await process_frame
	print("SCOPE actual Main world + production player physics, synthetic XR trackers and HMD focus; headset_tested=false")
	neutral()
	actor.left_hand.rotation.y=PI/2.0
	actor.xr_camera.rotation.y=0
	actor.forward_reference="head"
	check(actor.get_movement_forward().is_equal_approx(Vector3.FORWARD),"head mode follows headset yaw")
	actor.forward_reference="hand"
	check(actor.get_movement_forward().is_equal_approx(Vector3.LEFT),"hand mode follows physical left controller yaw")
	var hand_forward:=actor.get_movement_forward()
	actor.left_hand.position+=Vector3(3,2,-4)
	check(actor.get_movement_forward().is_equal_approx(hand_forward),"controller position cannot change orientation-derived heading")
	actor.left_hand.rotation.x=.7
	check(actor.get_movement_forward().is_equal_approx(Vector3.LEFT),"controller pitch projects onto horizontal plane")
	actor.forward_reference="head"
	actor.left_hand.transform=Transform3D.IDENTITY
	for dominant in ["right", "left"]:
		actor.dominant_hand = dominant
		actor.reset_motion()
		actor.require_neutral_input()
		neutral()
		check(actor.is_hand_input_ready(actor.left_hand) and actor.is_hand_input_ready(actor.right_hand), dominant+" both physical hands neutral armed")
		left.set_input("primary", Vector2(0,1))
		speed(6.5, dominant+" baseline walk")
		right.set_input("primary_click", true)
		tick(4)
		check(actor._sprint_mode == 0, dominant+" physical right click does not sprint")
		right.set_input("primary_click", false)
		press()
		speed(8.125, dominant+" physical left first press slow sprint")
		tick(8)
		check(actor._sprint_mode == 1, dominant+" held first press never repeats")
		var before: float = actor._sprint_stamina
		release_click(2)
		press()
		speed(11.375, dominant+" short release second press fast sprint")
		check(actor._sprint_stamina < before, dominant+" actual moving sprint consumes stamina")
		# Stop while the fast-tier click remains held; movement alone cannot resume.
		left.set_input("primary",Vector2.ZERO)
		tick()
		check(actor._sprint_mode==0 and not actor.sprinting,dominant+" neutral movement cancels fast tier immediately")
		left.set_input("primary",Vector2(0,1))
		speed(6.5,dominant+" movement resume with held click stays walking")
		release_click()
		press()
		check(actor._sprint_mode==1,dominant+" fresh press after stop starts slow tier")
		left.set_input("primary",Vector2.ZERO)
		tick()
		check(actor._sprint_mode==0,dominant+" neutral movement cancels slow tier immediately")
		left.set_input("primary",Vector2(0,1))
		speed(6.5,dominant+" slow-tier movement resume needs fresh click")
		release_click()
		press()
		release_click()
		press()
		release_click()
		press()
		speed(6.5, dominant+" third press returns to walk")
		release_click()
		press()
		check(actor._sprint_mode == 1, dominant+" rapid sequence first edge enters slow")
		release_click(2)
		press()
		check(actor._sprint_mode == 2, dominant+" rapid double click 33ms between edges enters fast")
		speed(11.375, dominant+" rapid double click actual fast displacement")
		release_click()
		press()
		speed(6.5, dominant+" rapid sequence third edge returns walk")
		release_click()
		press()
		release_click(40)
		press()
		speed(11.375, dominant+" second press after 444ms still fast sprint")
		# Run to real stamina exhaustion; held input cannot restart it.
		var exhaustion_frames := 0
		while actor._sprint_mode != 0 and exhaustion_frames < 600:
			tick()
			exhaustion_frames += 1
		check(actor._sprint_mode == 0 and not actor.sprinting, dominant+" sustained sprint exhausts and stops")
		check(is_zero_approx(actor._sprint_stamina),dominant+" exhaustion reaches zero stamina")
		release_click()
		press()
		check(actor._sprint_mode == 0,dominant+" fresh click below quarter stamina cannot restart")
		speed(6.5, dominant+" exhausted held click stays walking")
		neutral()
		var recovery_start: float = actor._sprint_stamina
		tick(360)
		check(actor._sprint_stamina > recovery_start and is_equal_approx(actor._sprint_stamina,actor.sprint_stamina_seconds), dominant+" idle stamina fully recovers")
		left.set_input("primary",Vector2(0,1))
		press()
		check(actor._sprint_mode == 1, dominant+" recovered fresh click restarts slow")
		# Match production tracking loss reset; held restore must wait for neutral.
		actor.tracking_available = false
		tick()
		check(actor._sprint_mode == 0 and actor.velocity == Vector3.ZERO, dominant+" tracking loss stops motion and clears sprint")
		actor.tracking_available = true
		tick(20)
		check(not actor.is_hand_input_ready(actor.left_hand) and actor._sprint_mode == 0, dominant+" held input after tracking recovery cannot rearm")
		neutral()
		left.set_input("primary",Vector2(0,1))
		press()
		speed(8.125,dominant+" neutral recovery then fresh click works")
		# Actual Main-owned menu invokes the real pause and resume transitions.
		game.field_menu.set_open(true)
		tick(12)
		check(actor.velocity == Vector3.ZERO and actor._sprint_mode == 0,dominant+" pause stops motion")
		game.field_menu.set_open(false)
		tick(20)
		check(not actor.is_hand_input_ready(actor.left_hand),dominant+" held input cannot restart after pause")
		neutral()
		left.set_input("primary",Vector2(0,1))
		press()
		speed(8.125,dominant+" pause neutral rearm then fresh click works")
	XRServer.remove_tracker(left)
	XRServer.remove_tracker(right)
	game.queue_free()
	await process_frame
	await create_timer(.1).timeout
	print("SPRINT_INPUT_039_RESULT passes=",passed," failures=",failures," headset_tested=false")
	quit(0 if failures == 0 else 1)

