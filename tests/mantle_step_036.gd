extends SceneTree

const Player = preload("res://scripts/player.gd")
class SyntheticSprintPlayer extends "res://scripts/player.gd":
	func is_hand_input_ready(hand: XRController3D) -> bool:
		return bool(_hand_input_ready.get(hand, false))

class SyntheticFramePlayer extends "res://scripts/player.gd":
	func update_tracking() -> bool:
		return tracking_available
	func update_hand_input_rearm(_delta: float) -> void:
		pass
	func is_hand_input_ready(hand: XRController3D) -> bool:
		return bool(_hand_input_ready.get(hand, false))
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		printerr("FAIL ", label)

func box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = at
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	root.add_child(body)
	return body

func player(at: Vector3, use_xr: bool = false) -> CharacterBody3D:
	var body := Player.new()
	root.add_child(body)
	body.setup(use_xr)
	body.set_physics_process(false)
	body.global_position = at
	return body

func settle(body: CharacterBody3D) -> void:
	for i in range(4):
		await physics_frame
		body.velocity = Vector3(0, -1, 0)
		body.move_and_slide()

func run() -> void:
	var floor := box(Vector3(8, .5, 8), Vector3(0, -.25, 0))
	var bump := box(Vector3(2, .22, 2), Vector3(0, .11, -2))
	var actor := player(Vector3(0, .01, 0))
	await settle(actor)
	check(actor.is_on_floor(), "ground fixture supports actual player capsule")
	check(is_equal_approx(actor.effective_walk_speed(), 6.5), "normal walk is 6.5 m/s")
	check(is_equal_approx(actor.GLIDE_SPEED, 12.0), "initial glide is 12 m/s")
	check(actor.turning_style == "smooth", "initial turning is smooth")
	for i in range(35):
		actor.apply_locomotion_motion(Vector3.FORWARD, Vector3.FORWARD, false, false, 1.0 / 60.0)
		await physics_frame
	print("WALK_END ", actor.position)
	check(actor.position.z < -1.4 and actor.position.y > .17, "walk crosses 22 cm discontinuity")
	actor.free()
	bump.free()
	await physics_frame
	var ledge := box(Vector3(2, 1.1, 2), Vector3(0, .55, -1.5))
	actor = player(Vector3(0, .01, 0))
	await settle(actor)
	var head: Vector3 = actor.get_view_camera().global_position
	var anchor := Vector3(0, .95, -.55)
	var route: Dictionary = preload("res://scripts/release_mantle.gd").plan(actor, actor._body_shape, head, anchor, Vector3.FORWARD)
	check(not route.is_empty(), "release planner accepts supported top below tracked head")
	var planner = preload("res://scripts/release_mantle.gd")
	check(planner.plan(actor, actor._body_shape, Vector3(.3, 1.39, 0), anchor, Vector3.FORWARD).is_empty(), "top within 30.48 cm of offset HMD rejects mantle")
	check(not planner.plan(actor, actor._body_shape, Vector3(.3, 1.5, 0), anchor, Vector3.FORWARD).is_empty(), "offset HMD with adequate head clearance can mantle")
	var overhead := box(Vector3(2, .15, 2), Vector3(0, 2.1, -1.5))
	await physics_frame
	check(planner.plan(actor, actor._body_shape, head, anchor, Vector3.FORWARD).is_empty(), "occupied standing destination rejects mantle")
	overhead.free()
	await physics_frame
	if not route.is_empty():
		actor.dominant_hand = "left"
		actor._grabs[actor.right_hand] = anchor
		actor._grabs[actor.left_hand] = anchor
		actor._update_grab(actor.right_hand, false)
		check(not actor.mantling, "first of two hands releasing retains climb")
		actor.fling_power = 5.0
		actor._release_velocity = Vector3(0, 20, 0)
		actor._update_grab(actor.left_hand, false)
		check(actor.mantling, "final intentional release starts mantle")
		check(actor.velocity == Vector3.ZERO, "mantle wins over high fling velocity")
		var mantle_frames := 0
		for i in range(160):
			if actor.mantling:
				actor._step_mantle(1.0 / 60.0)
				mantle_frames += 1
			await physics_frame
		check(not actor.mantling and actor.position.y > 1.0 and actor.position.z < -.7, "release route stands atop ledge")
		print("MANTLE_FRAMES ", mantle_frames)
		check(mantle_frames <= 9, "validated release route completes within 0.15 seconds")
	actor.free()
	actor = player(Vector3(0, .01, 0))
	await settle(actor)
	actor.dominant_hand = "right"
	actor._grabs[actor.left_hand] = anchor
	actor._update_grab(actor.left_hand, false)
	check(actor.mantling, "single offhand release mantles with right dominance")
	actor.free()
	actor = player(Vector3(0, .01, 0), true)
	actor.tracking_available = true
	actor.xr_camera.position = Vector3(.3, 1.5, 0)
	await settle(actor)
	actor._grabs[actor.right_hand] = anchor
	actor._update_grab(actor.right_hand, false)
	check(actor.mantling, "offset tracked camera drives actual final-release mantle path")
	actor.free()
	ledge.free()
	await physics_frame
	var tall := box(Vector3(2, 1.5, 2), Vector3(0, .75, -1.5))
	actor = player(Vector3(0, .01, 0))
	await settle(actor)
	check(planner.plan(actor, actor._body_shape, actor.get_view_camera().global_position, Vector3(0, 1.2, -.55), Vector3.FORWARD).is_empty(), "tall top above HMD release threshold is not mantled")
	check(not planner.plan(actor, actor._body_shape, Vector3(.2, 2.0, 0), Vector3(0, 1.35, -.55), Vector3.FORWARD).is_empty(), "1.5 m ledge accepts release when HMD is 0.5 m above top")
	actor._grabs[actor.right_hand] = Vector3(0, 1.2, -.55)
	actor._release_velocity = Vector3(0, 20, 0)
	actor._update_grab(actor.right_hand, false, false)
	check(not actor.mantling and actor.velocity == Vector3.ZERO, "tracking-loss release neither mantles nor flings")
	actor.free()
	tall.free()
	await physics_frame
	ledge = box(Vector3(2, 1.1, 2), Vector3(0, .55, -1.5))
	actor = SyntheticFramePlayer.new()
	root.add_child(actor)
	actor.setup(true)
	actor.set_physics_process(false)
	actor.tracking_available = true
	actor.xr_camera.position = Vector3(0, 1.65, 0)
	actor.global_position = Vector3(0, .01, 0)
	await settle(actor)
	var frame_left := XRControllerTracker.new()
	frame_left.type = XRServer.TRACKER_CONTROLLER
	frame_left.name = "qa_036_frame_left"
	XRServer.add_tracker(frame_left)
	actor.left_hand.tracker = frame_left.name
	actor.left_hand.position = Vector3(-.28, 1.1, -.45)
	frame_left.set_pose("grip", actor.left_hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	var frame_right := XRControllerTracker.new()
	frame_right.type = XRServer.TRACKER_CONTROLLER
	frame_right.name = "qa_036_frame_right"
	XRServer.add_tracker(frame_right)
	actor.right_hand.tracker = frame_right.name
	frame_right.set_pose("grip", actor.right_hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	actor._hand_input_ready[actor.left_hand] = true
	actor._hand_input_ready[actor.right_hand] = true
	frame_left.set_input("primary", Vector2(0, 1))
	frame_left.set_input("grip", .9)
	await physics_frame
	actor._physics_process(1.0 / 60.0)
	check(actor._grabs.has(actor.left_hand), "actual physics tick acquires ledge grip")
	var before_release: Vector3 = actor.global_position
	var yaw_before: float = actor.rotation.y
	frame_left.set_input("grip", 0.0)
	frame_right.set_input("primary", Vector2(1, 0))
	actor._physics_process(1.0 / 60.0)
	check(actor.mantling and actor.velocity == Vector3.ZERO, "actual release tick starts mantle without walk or gravity velocity")
	check(actor.global_position.distance_to(before_release) < .001 and is_equal_approx(actor.rotation.y, yaw_before), "release tick cannot run movement or turn after planning")
	XRServer.remove_tracker(frame_left)
	XRServer.remove_tracker(frame_right)
	actor.free()
	ledge.free()
	actor = SyntheticSprintPlayer.new()
	root.add_child(actor)
	actor.setup(true)
	actor.set_physics_process(false)
	actor.global_position = Vector3(0, .01, 0)
	await settle(actor)
	actor.tracking_available = true
	var tracker := XRControllerTracker.new()
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.name = "qa_036_left"
	XRServer.add_tracker(tracker)
	actor.left_hand.tracker = tracker.name
	tracker.set_pose("grip", actor.left_hand.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await physics_frame
	actor._hand_input_ready[actor.left_hand] = true
	tracker.set_input("primary", Vector2(0, 1))
	tracker.set_input("primary_click", true)
	check(actor.sprint_requested(.01) and actor._sprint_mode == 1, "first physical left click starts slow sprint")
	tracker.set_input("primary_click", false)
	actor.sprint_requested(.08)
	tracker.set_input("primary_click", true)
	check(actor.sprint_requested(.01) and actor._sprint_mode == 2, "second click inside window starts fast sprint")
	tracker.set_input("primary_click", false)
	actor.sprint_requested(actor.sprint_stamina_seconds)
	check(actor._sprint_mode == 0 and not actor.sprint_requested(.01), "stamina timeout returns to walk")
	actor.require_neutral_input()
	check(actor._sprint_mode == 0, "menu or tracking reset clears sprint toggle")
	actor._hand_input_ready[actor.left_hand] = true
	actor.sprint_binding = "left_grip"
	actor._sprint_stamina = actor.sprint_stamina_seconds
	tracker.set_input("grip", 0.0)
	actor.sprint_requested(.01)
	tracker.set_input("grip", .9)
	check(actor.sprint_requested(.01) and actor._sprint_mode == 1, "first left grip press toggles slow sprint away from a surface")
	tracker.set_input("grip", 0.0)
	check(actor.sprint_requested(.08) and actor._sprint_mode == 1, "left grip release keeps slow sprint toggled")
	tracker.set_input("grip", .9)
	check(actor.sprint_requested(.01) and actor._sprint_mode == 2, "second left grip press inside window toggles fast sprint")
	var grip_surface := box(Vector3(1, 1, 1), actor.left_hand.global_position + Vector3(-.65, 0, 0))
	await physics_frame
	check(not actor.sprint_requested(.01), "nearby climb surface takes priority over grip sprint")
	grip_surface.free()
	await physics_frame
	check(not actor.sprint_requested(.01), "held grip leaving surface cannot become a new sprint press")
	tracker.set_input("grip", 0.0)
	actor.sprint_requested(.4)
	tracker.set_input("grip", .9)
	check(actor.sprint_requested(.01) and actor._sprint_mode == 1, "fresh grip after surface release toggles sprint again")
	var left_glove: Node3D = actor.left_hand.get_node("ArticulatedGlove")
	var right_glove: Node3D = actor.right_hand.get_node("ArticulatedGlove")
	var pitch := Basis(Vector3.RIGHT, -PI / 2.0)
	check(left_glove.basis.is_equal_approx(pitch * Basis(Vector3.FORWARD, PI / 2.0)) and right_glove.basis.is_equal_approx(pitch * Basis(Vector3.FORWARD, -PI / 2.0)), "left and right visual gloves roll oppositely after local X correction")
	var left_thumb: Node3D = left_glove.get_node("Thumb")
	var right_thumb: Node3D = right_glove.get_node("Thumb")
	var left_thumb_in_pitched_hand := pitch.inverse() * left_glove.basis * left_thumb.position
	var right_thumb_in_pitched_hand := pitch.inverse() * right_glove.basis * right_thumb.position
	check(left_thumb_in_pitched_hand.y < -.03 and right_thumb_in_pitched_hand.y < -.03, "both thumb pads rotate below their respective palms")
	XRServer.remove_tracker(tracker)
	actor.free()
	floor.free()
	await physics_frame
	print("MANTLE_STEP_036 passes=", passed, " failures=", failed, " headset_tested=false")
	quit(0 if failed == 0 else 1)
