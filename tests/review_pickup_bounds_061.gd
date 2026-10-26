extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:Engine.max_fps=90;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);freeze(actor)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);freeze(rack)
	var scene_world=load("res://scripts/world.gd").new();root.add_child(scene_world);scene_world.build();freeze(scene_world)
	actor.global_position=scene_world.player_spawn
	var inv=load("res://scripts/weapon_inventory.gd").new();root.add_child(inv);inv.setup(actor,rack);inv.set_process(false)
	for frame in 4:await physics_frame
	check(rack.is_catalog_active(29) and inv.pickups.has(29),"knife29 is present in actual review and pickup proof")
	for index in rack.ACTIVE_WEAPON_INDICES:
		var prop:Node3D=inv.pickups.values().filter(func(p):return int(p.get_meta("catalog_index",-1))==index)[0];var bounds:AABB=inv._world_mesh_bounds(prop)
		var fits:bool=bounds.position.x>-6.5 and bounds.end.x<6.5 and bounds.position.z>=3.0 and bounds.end.z<13.0 and is_equal_approx(bounds.position.y,.80)
		check(fits,"C14 unchanged full-mesh deck/hover criterion index%d min%s max%s"%[index,bounds.position,bounds.end])
	actor.xr_enabled=true;actor.tracking_available=true;actor.xr_camera.position.y=2.0
	var trackers:Array[XRControllerTracker]=[]
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="review_reach061_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers.append(t)
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();freeze(rack);actor.left_hand_reserved=false
		var hand:XRController3D=actor.get_support_hand()
		for index in inv.pickups:
			var point:Vector3=inv._pickup_center(index);var reachable:=false
			for angle in [0.0,.45,-.45,.90,-.90]:
				var direction:=Vector3.BACK.rotated(Vector3.UP,angle)
				var foot:=Vector3(point.x,.05,point.z)+direction*.9
				if foot.x<=-6.5 or foot.x>=6.5 or foot.z<3.0 or foot.z>=13.0:continue
				var floor_ray:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*2,foot-Vector3.UP,1,[actor.get_rid()])
				var support:Dictionary=scene_world.get_world_3d().direct_space_state.intersect_ray(floor_ray)
				if support.is_empty() or not is_equal_approx(support.position.y,.05):continue
				actor.global_position=foot
				var hand_point:=point+direction*.6
				var aim:=Basis.looking_at(point-hand_point,Vector3.UP)
				hand.global_transform=Transform3D(aim*Basis(Vector3.RIGHT,PI/2),hand_point)
				if inv.get_aimed_pickup(hand)==index:reachable=true;break
			check(reachable,side+" index%d has a real deck standing position and eligible offhand pickup ray"%index)
	for tracker in trackers:XRServer.remove_tracker(tracker)
	inv.free();rack.shutdown();rack.free();actor.free();scene_world.free();await process_frame
	print("REVIEW_PICKUP_BOUNDS_061 checks=",checks," failures=",failures," actual_world=true knife29_included=true synthetic_tracking=true headset_tested=false")
	quit(failures)
