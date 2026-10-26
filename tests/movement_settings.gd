extends SceneTree

class SyntheticPlayer extends "res://scripts/player.gd":
	func update_tracking() -> bool:
		return tracking_available

var passed := 0
var failures := 0
var actor: SyntheticPlayer
var left: XRControllerTracker
var right: XRControllerTracker

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
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

func neutral() -> void:
	left.set_input("primary", Vector2.ZERO)
	right.set_input("primary", Vector2.ZERO)
	for i in range(8): actor.update_hand_input_rearm(1.0 / 90.0)

func reset_turn() -> void:
	actor.rotation = Vector3.ZERO
	actor.reset_motion()
	actor.apply_turn_input(0, 0.01)

func run() -> void:
	print("SCOPE production movement methods with synthetic controller poses; HMD session availability adapter; headset_tested=false")
	actor = SyntheticPlayer.new()
	root.add_child(actor)
	actor.setup(true)
	actor.tracking_available = true
	actor.set_process(false)
	actor.set_physics_process(false)
	left = tracker("qa_movement_left", actor.left_hand)
	right = tracker("qa_movement_right", actor.right_hand)
	await process_frame
	neutral()
	actor.xr_camera.rotation = Vector3.ZERO
	actor.left_hand.rotation.y = PI / 2
	actor.forward_reference = "head"
	check(actor.get_movement_forward().is_equal_approx(Vector3.FORWARD), "head reference follows camera heading")
	actor.forward_reference = "hand"
	check(actor.get_movement_forward().is_equal_approx(Vector3.LEFT), "hand reference follows ready offhand heading")
	left.invalidate_pose("grip")
	actor.update_hand_input_rearm(0.01)
	check(actor.get_movement_forward().is_equal_approx(Vector3.FORWARD), "lost offhand reference falls back to camera without stale direction")
	left.set_pose("grip", actor.left_hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	neutral()
	actor.forward_reference = "head"

	for power in [0.0, 0.5, 1.0, 2.0, 5.0]:
		actor.fling_power = power
		actor._grabs[actor.left_hand] = actor.left_hand.global_position
		actor._release_velocity = Vector3(0, 10, 0)
		actor._update_grab(actor.left_hand, false)
		check(is_equal_approx(actor.velocity.length(), 7.0 * power * 1.25), "deliberate final release respects fling power %.1f" % power)
		actor._grabs[actor.left_hand] = actor.left_hand.global_position
		actor._release_velocity = Vector3(0, 10, 0)
		actor._update_grab(actor.left_hand, false, false)
		check(actor.velocity == Vector3.ZERO, "tracking-loss release never flings at power %.1f" % power)
	actor.xr_enabled = false
	actor.forward_reference = "head"
	var glide_velocities: Array[Vector3] = []
	for power in [0.0, 5.0]:
		actor.reset_motion()
		actor.position = Vector3(0, 20, 0)
		actor.fling_power = power
		actor._desktop_glide = true
		actor.velocity = Vector3(0,-2,0)
		actor._physics_process(0.1)
		check(actor.gliding, "glide activates independently of fling power %.1f" % power)
		glide_velocities.append(actor.velocity)
	check(glide_velocities[0].is_equal_approx(glide_velocities[1]), "fling power does not change glide velocity")
	actor.xr_enabled = true
	actor.fling_power = 1.0

	reset_turn()
	actor.turning_style = "snap"
	actor.snap_degrees = 30
	var camera_before := actor.get_view_camera().global_position
	actor.apply_turn_input(1,0.01)
	check(is_equal_approx(actor.rotation.y, -PI/6), "snap produces configured angle")
	check(actor.get_view_camera().global_position.distance_to(camera_before) < 0.001, "turn preserves tracked camera pivot")
	actor.apply_turn_input(1,1.0)
	check(is_equal_approx(actor.rotation.y, -PI/6), "held snap stick does not repeat")
	actor.apply_turn_input(0,0.01)
	actor.apply_turn_input(1,0.01)
	check(is_equal_approx(actor.rotation.y, -PI/3), "neutral then fresh snap turns again")
	reset_turn()
	actor.turning_style = "auto_snap"
	actor.apply_turn_input(1,0.01)
	actor.apply_turn_input(1,0.15)
	check(is_equal_approx(actor.rotation.y,-PI/6), "auto snap respects repeat delay")
	actor.apply_turn_input(1,0.16)
	check(is_equal_approx(actor.rotation.y,-PI/3), "auto snap repeats after configured cadence")

	reset_turn()
	actor.turning_style = "smooth"
	actor.smooth_turn_speed = 90
	actor.smooth_ease_in = false
	actor.smooth_analog = true
	actor.apply_turn_input(0.65,1.0)
	check(is_equal_approx(actor.rotation.y,-PI/4), "analog smooth input scales angular speed")
	reset_turn()
	actor.smooth_analog = false
	actor.apply_turn_input(0.65,1.0)
	check(is_equal_approx(actor.rotation.y,-PI/2), "nonanalog smooth input uses full configured speed")
	reset_turn()
	actor.smooth_ease_in = true
	actor.apply_turn_input(1,0.03)
	check(is_equal_approx(actor._smooth_turn_rate,-22.5), "ease in ramps from rest instead of instant full speed")
	for i in range(3): actor.apply_turn_input(1,0.03)
	check(is_equal_approx(actor._smooth_turn_rate,-90), "ease in reaches configured speed")
	var yaw := actor.rotation.y
	actor.apply_turn_input(0,0.01)
	check(actor._smooth_turn_rate == 0 and is_equal_approx(actor.rotation.y,yaw), "neutral stops smooth turn immediately without drift")
	actor.apply_turn_input(1,0.03)
	actor.require_neutral_input()
	check(actor._smooth_turn_rate == 0 and not actor.is_hand_input_ready(actor.right_hand), "menu rearm clears smooth rate and hand readiness")
	right.set_input("primary", Vector2(1,0))
	yaw = actor.rotation.y
	actor._physics_process(0.03)
	check(is_equal_approx(actor.rotation.y,yaw), "held turn after menu rearm cannot rotate player")
	neutral()
	right.set_input("primary", Vector2(1,0))
	actor._physics_process(0.03)
	check(not is_equal_approx(actor.rotation.y,yaw), "fresh turn after neutral recovery resumes rotation")
	right.invalidate_pose("grip")
	yaw = actor.rotation.y
	actor._physics_process(0.03)
	check(actor._smooth_turn_rate == 0 and is_equal_approx(actor.rotation.y,yaw), "controller loss cancels smooth rate and turn")
	XRServer.remove_tracker(left)
	XRServer.remove_tracker(right)
	actor.free()
	await process_frame
	print("MOVEMENT_SETTINGS_RESULT passes=",passed," failures=",failures," synthetic=true headset_tested=false")
	quit(0 if failures == 0 else 1)
