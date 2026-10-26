extends SceneTree
const Body = preload("res://scripts/player_body.gd")
const Player = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(value: bool,label: String):
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ",label)
func counts(node: Node) -> Vector3i:
	var result := Vector3i(1 if node is MeshInstance3D else 0,1 if node is CollisionObject3D else 0,1 if str(node.name).contains("Glove") or str(node.name).contains("Hand") else 0)
	for child in node.get_children(): result += counts(child)
	return result
func run():
	var player := Player.new()
	root.add_child(player)
	player.setup(true)
	player.set_physics_process(false)
	player.tracking_available = true
	player.input_enabled = true
	player.xr_camera.position.y = 1.65
	player.left_hand.position = Vector3(-.3,1.1,-.4)
	player.right_hand.position = Vector3(.3,1.1,-.4)
	var body := Body.new()
	root.add_child(body)
	body.setup(player)
	body.set_process(false)
	check(counts(body)==Vector3i(13,0,0),"13bounded render meshes no colliders or duplicatehands")
	for height in [.55,.85,1.2,1.65,2.2]:
		player.xr_camera.position.y = height
		for rotation_value in [Vector3.ZERO,Vector3(-1.35,.8,.15),Vector3(.7,-1.2,-.2)]:
			player.xr_camera.rotation = rotation_value
			body.update_pose(.016)
			check(is_equal_approx(body.eye_height,height),"tracked crouch height retained")
			check(absf(body.pieces.Jacket.global_basis.y.normalized().dot(Vector3.UP)-1)<.0001,"headpitch never tilts torso")
			check(body.pieces.Jacket.global_position.y<player.xr_camera.global_position.y-.15,"torso remains below cameraeye")
			var finite := true
			var eye_clear := true
			for mesh in body.pieces.values():
				finite = finite and mesh.global_transform.is_finite()
				if mesh.visible: eye_clear = eye_clear and not mesh.mesh.get_aabb().has_point(mesh.to_local(player.xr_camera.global_position))
			check(finite,"crouch/yaw/lean pose finite")
			check(eye_clear,"cameraeye outside all visiblesuit meshbounds")
	player.xr_camera.position.y = 1.65
	player.xr_camera.rotation = Vector3.ZERO
	for side in [-1.0,1.0]:
		player.left_hand.position = Vector3(side*.5,1.9,-.25)
		player.right_hand.position = Vector3(-side*.35,.8,-.6)
		var left_glove = player.left_hand.get_node("ArticulatedGlove")
		left_glove.position += Vector3(.035,.025,-.07)
		body.update_pose(.016)
		check(body.wrists[0].distance_to(left_glove.to_global(Vector3(0,0,.08)))<.00001,"left arm reaches actual offsetrenderedglove")
		check(body.wrists[1].distance_to(player.right_hand.get_node("ArticulatedGlove").to_global(Vector3(0,0,.08)))<.00001,"right arm reaches renderedglove after mirroredhandposes")
		check(body.elbows[0].distance_to(body.shoulders[0])>.1 and body.elbows[1].distance_to(body.shoulders[1])>.1,"two bone arms have plausible elbowlength")
	player.left_hand.global_position = player.xr_camera.global_position
	body.update_pose(.016)
	check(not body.pieces.LForearm.visible,"sleeve atvisor hides before enteringeye")
	var original_hand := player.left_hand.transform
	var original_collider_count := counts(player).y
	player.velocity = Vector3(5,0,2)
	body.update_pose(.1)
	var moving := body.phase
	check(moving>0,"velocity drives bounded gait")
	check(player.left_hand.transform==original_hand and counts(player).y==original_collider_count,"renderbody never changestracking orphysics")
	player.input_enabled = false
	var before: Transform3D = body.pieces.Jacket.global_transform
	player.xr_camera.position.x = .3
	body.update_pose(.1)
	check(body.pieces.Jacket.global_transform==before and body.phase==moving,"menu pause retainsbodypose andgait")
	player.input_enabled = true
	player.tracking_available = false
	body.update_pose(.1)
	check(not body.visible,"trackingloss hides stale body")
	player.tracking_available = true
	body.reset_pose()
	check(body.visible and body.phase==0,"reset/reacquisition restoresbody andclearsgait")
	player.velocity = Vector3.ZERO
	body.update_pose(.3)
	check(body.phase==0,"stationary bodydoesnot walkinplace")
	body.setup(player)
	check(counts(body)==Vector3i(13,0,0),"repeat setup neverduplicatesgeometry")
	body.queue_free();player.queue_free()
	await process_frame
	print("PLAYER_BODY_040 checks=",checks," failures=",failures," headset_tested=false")
	quit(failures)

