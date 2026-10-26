extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
var passes := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		printerr("FAIL ", label)

func run() -> void:
	print("SCOPE synthetic XRPose confidence and XRControllerTracker validation; no OpenXR session; headset_tested=false")
	var player := PlayerScript.new()
	player.set_process(false)
	player.set_physics_process(false)
	root.add_child(player)
	player.setup(false)
	var pose := XRPose.new()
	pose.has_tracking_data = true
	check(not player.is_pose_tracking_valid(null), "null head or hand pose rejected")
	for confidence in [0, -1, 3, 32, 114]:
		pose.set("tracking_confidence", confidence)
		check(not player.is_pose_tracking_valid(pose), "shared head and hand validator rejects confidence %d" % confidence)
	for confidence in [XRPose.XR_TRACKING_CONFIDENCE_LOW, XRPose.XR_TRACKING_CONFIDENCE_HIGH]:
		pose.set("tracking_confidence", confidence)
		check(player.is_pose_tracking_valid(pose), "shared validator accepts live confidence %d" % confidence)
	pose.has_tracking_data = false
	check(not player.is_pose_tracking_valid(pose), "valid confidence with stale pose rejected")
	var tracker := XRControllerTracker.new()
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.name = "qa_confidence_left"
	XRServer.add_tracker(tracker)
	player.left_hand.tracker = tracker.name
	player.left_hand.pose = "grip"
	tracker.set_pose("grip", Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	check(player.is_hand_tracked(player.left_hand), "actual controller node accepts valid tracker pose")
	var hand_pose := tracker.get_pose("grip")
	hand_pose.set("tracking_confidence", 32)
	check(not player.is_hand_tracked(player.left_hand), "actual controller validation rejects malformed confidence 32")
	hand_pose.set("tracking_confidence", XRPose.XR_TRACKING_CONFIDENCE_LOW)
	check(player.is_hand_tracked(player.left_hand), "valid low confidence recovers controller pose")
	player.xr_enabled = true
	check(not player.update_tracking() and not player.input_enabled, "headless process without focused XR session cannot enable input")
	XRServer.remove_tracker(tracker)
	player.free()
	print("CONFIDENCE_RESULT passes=", passes, " failures=", failures, " synthetic=true headset_tested=false")
	quit(0 if failures == 0 else 1)
