## 054 successor: only the explicit-release local side-rim refusal is superseded.
extends SceneTree
class FramePlayer extends "res://scripts/player.gd":
	func update_tracking()->bool:return tracking_available
const DT:=1.0/90.0
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func box(size:Vector3,at:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();body.position=at;body.collision_layer=1
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision);root.add_child(body);return body
func actor(at:Vector3)->FramePlayer:
	var value:=FramePlayer.new();root.add_child(value);value.setup(false);value.xr_enabled=true;value.tracking_available=true;value.xr_camera.position.y=1.65
	value.set_process(false);value.set_physics_process(false);value.position=at;return value
func release_case(height:float,margin:float)->void:
	var ledge:=box(Vector3(4,height,4),Vector3(0,height*.5,-3))
	var p:=actor(Vector3(0,height+margin-1.65,-1.4));await physics_frame
	var before:=p.get_view_camera().global_position
	var supported:=p.try_start_release_mantle(Vector3(0,height-.08,-1))
	print("MARGIN_REPRO height=",height," margin=",margin," before_head=",before," result=",supported," feet=",p.position)
	if margin>0:
		check(supported and p.is_supported() and absf(p.position.y-height)<.015,"camera center +%s over %sm ledge stands without radius clearance"%[margin,height])
		check(absf(p.xr_camera.global_position.y-(height+1.65))<.015,"release restores measured standing height margin=%s"%margin)
	else:check(not supported and not p.is_supported(),"camera center below ledge rejected margin=%s"%margin)
	p.free();ledge.free();await physics_frame
func tracked_case(margin:float)->void:
	var height:=1.2
	var ledge:=box(Vector3(4,height,4),Vector3(0,height*.5,-3))
	var p:=actor(Vector3(0,height+margin-1.65,-.6))
	var trackers:Array[XRControllerTracker]=[]
	for hand in [p.left_hand,p.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="margin045_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers.append(t)
	await physics_frame;p.update_hand_input_rearm(.1)
	var pose:=Transform3D(Basis.IDENTITY,Vector3(0,height-p.position.y-.08,-.42))
	trackers[0].set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);p.left_hand.transform=pose;trackers[0].set_input("grip",1.0)
	p._physics_process(DT)
	check(p._grabs.has(p.left_hand),"real tracked grip acquires physical ledge margin=%s"%margin)
	for i in range(8):
		pose.origin.z+=.10;trackers[0].set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);p.left_hand.transform=pose
		await physics_frame;p._physics_process(DT)
	check(p.position.z< -1.2 and not p.is_supported(),"actual tracked pull crosses ledge with torso below at center+%s"%margin)
	trackers[0].set_input("grip",0.0);await physics_frame;p._physics_process(DT)
	check(p.is_supported() and absf(p.position.y-height)<.02 and not p.climbing,"actual tracked final release stands at center+%s"%margin)
	for t in trackers:XRServer.remove_tracker(t)
	p.free();ledge.free();await physics_frame
func run()->void:
	for height in [1.0,1.2,1.65]:
		for margin in [.005,.02,.06,.14,-.005]:await release_case(height,margin)
	for margin in [.005,.02,.06]:await tracked_case(margin)
	# Lateral head radius must still stop tall walls and diagonal corner approaches.
	var wall:=box(Vector3(4,4,.1),Vector3(0,2,-1))
	for direction in [Vector3.FORWARD,Vector3(-.4,0,-1).normalized()]:
		var p:=actor(Vector3(0,0,-.4));await physics_frame
		for i in range(8):p.apply_climb_motion(direction*.15,DT);await physics_frame
		check(p.xr_camera.global_position.z>-.84,"tall wall retains lateral12cm head boundary direction=%s"%direction)
		check(p.position.y<.01,"tall wall cannot add phantom vertical boost")
		p.free();await physics_frame
	wall.free();await physics_frame
	var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
	var ceiling:=box(Vector3(4,.12,4),Vector3(0,2.0,-3))
	var blocked:=actor(Vector3(0,1.2+.005-1.65,-1.4));await physics_frame
	check(not blocked.try_start_release_mantle(Vector3(0,1.1,-1)),"ceiling blocks standing sweep despite marginal support")
	check(blocked.xr_camera.global_position.y<=1.825,"ceiling preserves upper12cm head clearance")
	blocked.free();ceiling.free();ledge.free();await physics_frame
	ledge=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
	var outside:=actor(Vector3(2.06,1.2+.005-1.65,-1.4));await physics_frame
	var before_outside:Vector3=outside.position
	check(outside.try_start_release_mantle(Vector3(2,1.1,-1)) and outside.is_supported() and absf(outside.position.y-1.2)<.015 and outside.position.x<2.0 and Vector2(outside.position.x-before_outside.x,outside.position.z-before_outside.z).length()<=.1151,"054 explicit release finishes local side-rim overlap within115mm on real top")
	outside.free()
	# A corner whose top is above goggles remains a wall, even diagonally.
	for margin in [-.005,-.02]:
		var corner:=actor(Vector3(2.28,1.2+margin-1.65,-.72));await physics_frame
		var initial_y:=corner.position.y
		for i in range(5):corner.apply_climb_motion(Vector3(-1,0,-1).normalized()*.12,DT);await physics_frame
		check(corner.position.x>2.04 or corner.position.z>-.96,"diagonal above-goggle ledge corner blocks crossing margin=%s"%margin)
		check(corner.position.y<=initial_y+.003,"corner cannot boost goggles over ledge margin=%s"%margin)
		corner.free();await physics_frame
	ledge.free();await physics_frame
	# Actual authored checkpoint and scanned crate/rock physics, not equivalent boxes.
	var campaign=load("res://scripts/world.gd").new();root.add_child(campaign);campaign.build();await physics_frame
	var space:PhysicsDirectSpaceState3D=root.get_world_3d().direct_space_state
	var platform_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(3.5,4,-11),Vector3(3.5,-2,-11),1))
	check(not platform_hit.is_empty() and absf(platform_hit.position.y-1.0)<.03,"actual first checkpoint fixture resolves authored1m top")
	if not platform_hit.is_empty():
		for margin in [.005,.02,.06]:
			var p:=actor(platform_hit.position+Vector3.UP*(margin-1.65));await physics_frame
			check(p.try_start_release_mantle(platform_hit.position) and absf(p.position.y-platform_hit.position.y)<.015,"actual first checkpoint release margin=%s"%margin)
			p.free();await physics_frame
	var tested_props:=0
	for model in campaign.get_children():
		if not (str(model.name).begins_with("CC0_old_military_crate") or str(model.name).begins_with("CC0_rock_07")):continue
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(model.global_position+Vector3.UP*4,model.global_position-Vector3.UP*2,1))
		if hit.is_empty() or hit.normal.y<.85:continue
		var hit_parent:Node=hit.collider.get_parent()
		if hit_parent!=model:continue
		for margin in [.005,.02,.06]:
			var p:=actor(hit.position+Vector3.UP*(margin-1.65));await physics_frame
			var resolved:=p.try_start_release_mantle(hit.position)
			print("ACTUAL_MARGIN prop=",model.name," normal=",hit.normal," top=",hit.position," margin=",margin," resolved=",resolved," feet=",p.position)
			check(resolved and absf(p.position.y-hit.position.y)<.015,"actual %s release margin=%s"%[model.name,margin])
			p.free();await physics_frame
		if hit.normal.y<.999:
			var roof:=box(Vector3(2,.10,2),hit.position+Vector3.UP*.5)
			var p:=actor(hit.position+Vector3.UP*(.005-1.65));await physics_frame
			check(not p.try_start_release_mantle(hit.position),"sloped scanned rock recovery cannot bypass ceiling")
			check(p.xr_camera.global_position.y<=hit.position.y+.45-.118,"sloped recovery retains upper head ceiling clearance")
			p.free();roof.free();await physics_frame
		tested_props+=1
		if tested_props>=4:break
	check(tested_props>=2,"actual scanned crate/rock marginal supports covered")
	campaign.free();await physics_frame
	# Real production physics uses only horizontal separation and the new15% reduction.
	var flyer:=actor(Vector3(0,5,0));var trackers:Array[XRControllerTracker]=[]
	for hand in [flyer.left_hand,flyer.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="glide045_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers.append(t)
	await physics_frame;flyer.update_hand_input_rearm(.1)
	check(is_equal_approx(flyer.GLIDE_HORIZONTAL_SPREAD,0.95890625),"glide spread reduced exactly15percent then5percent")
	for span in [0.9588,0.9590]:
		flyer.position=Vector3(0,5,0);flyer.reset_motion();flyer.left_hand.position=Vector3(0,.2,-.3);flyer.right_hand.position=Vector3(span,2.0,-.3);await physics_frame;flyer._physics_process(DT)
		check(flyer.gliding==(span>0.95890625),"new horizontal-only spread boundary span=%s"%span)
		if flyer.gliding:check(absf(Vector2(flyer.velocity.x,flyer.velocity.z).length()-flyer.effective_walk_speed()*2)<.01,"glide still immediate2xwalk in same physics frame")
	for t in trackers:XRServer.remove_tracker(t)
	flyer.free();await physics_frame
	print("MANTLE_054_MARGIN_CARRY_045 checks=",checks," failures=",failures," real_physics=true synthetic=true headset_tested=false")
	quit(failures)


