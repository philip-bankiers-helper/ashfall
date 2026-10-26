extends SceneTree
class FramePlayer extends "res://scripts/player.gd":
	func update_tracking() -> bool: return tracking_available
	func update_hand_input_rearm(_delta: float) -> void: pass
	func is_hand_input_ready(hand: XRController3D) -> bool:
		return bool(_hand_input_ready.get(hand, false))
class SprintBlocker extends Node:
	var blocked := false
	func blocks_sprint() -> bool: return blocked
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value: passed += 1; print("PASS ", label)
	else: failed += 1; printerr("FAIL ", label)
func box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var mesh := BoxShape3D.new()
	mesh.size = size
	shape.shape = mesh
	body.add_child(shape)
	root.add_child(body)
	return body
func actor(at: Vector3, xr := false) -> FramePlayer:
	var body := FramePlayer.new()
	root.add_child(body)
	body.setup(xr)
	body.set_physics_process(false)
	body.position = at
	if xr: body.xr_camera.position.y = 1.65; body.tracking_available = true
	return body
func run() -> void:
	var floor := box(Vector3(40,.5,40), Vector3(0,-.25,0))
	await physics_frame
	for height in [.22,.8,.99,1.4,1.5]:
		for angle in [-.35,0.0,.35]:
			var ledge := box(Vector3(3,height,3),Vector3(0,height*.5,-3))
			var p := actor(Vector3(0,0,0))
			await physics_frame
			var direction := Vector3.FORWARD.rotated(Vector3.UP,angle)
			for i in range(28):
				p.apply_locomotion_motion(direction,direction,false,false,1.0/90.0)
				await physics_frame
			check(p.position.y > height-.03 and p.position.z < -1.7,"walk auto-support height=%s angle=%s actual=%s" % [height,angle,p.position])
			p.free(); ledge.free(); await physics_frame
	# Latest headset-height correction: both ledges exceed the old chest gate.
	for sample in [Vector2(1.65,1.5),Vector2(1.4,1.26)]:
		var ledge:=box(Vector3(4,sample.y,4),Vector3(0,sample.y*.5,-3))
		var p:=actor(Vector3(0,0,-.7),true)
		p.xr_camera.position.y=sample.x
		await physics_frame
		check(sample.y>sample.x*.75 and p.get_view_camera().global_position.y-p.HEAD_RADIUS>sample.y,"regression fixture headset clears ledge while old chest gate fails eye=%s ledge=%s"%[sample.x,sample.y])
		p._grabs[p.left_hand]=p.left_hand.global_position
		p.climbing=true
		for i in range(7):
			p.apply_climb_motion(Vector3.FORWARD*.15,1.0/90.0)
			await physics_frame
		check(p.position.z < -1.3 and absf(p.position.y)<.02,"head moves over ledge with torso remaining below surface")
		p._update_grab(p.left_hand,false)
		check(p.is_supported() and absf(p.position.y-sample.y)<.02 and absf(p.get_view_camera().global_position.y-(sample.y+sample.x))<.02,"headset-clear final grip release restores full standing eyeheight")
		p.free()
		p=actor(Vector3(0,0,-1.5),true)
		p.xr_camera.position.y=sample.x
		await physics_frame
		p.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/90.0)
		check(p.is_supported() and absf(p.position.y-sample.y)<.02,"same generic support fixes head-over-ledge idle torso-below case")
		p.free();ledge.free();await physics_frame
	var too_high:=box(Vector3(4,1.7,4),Vector3(0,.85,-3))
	var blocked_player:=actor(Vector3(0,0,-.7),true)
	await physics_frame
	for i in range(25):
		blocked_player.apply_locomotion_motion(Vector3.FORWARD,Vector3.FORWARD,false,false,1.0/90.0)
		await physics_frame
	check(blocked_player.position.z>-.9 and blocked_player.position.y<.03,"ledge intersecting goggles remains blocked by head envelope")
	blocked_player.free();too_high.free();await physics_frame
	for height in [.65,1.05,1.4]:
		for angle in [-.4,0.0,.4]:
			var ledge := box(Vector3(4,height,4),Vector3(0,height*.5,-3))
			var p := actor(Vector3(0,0,-.7))
			await physics_frame
			p._grabs[p.left_hand] = p.left_hand.global_position
			p.climbing = true
			for i in range(7):
				p.apply_climb_motion(Vector3.FORWARD.rotated(Vector3.UP,angle)*.15,1.0/90.0)
				await physics_frame
			check(p.position.z < -1.3 and absf(p.position.y) < .02,"torso crosses ledge during grip h=%s angle=%s" % [height,angle])
			p._update_grab(p.left_hand,false)
			check(p.position.y > height-.02 and p.is_supported() and not p.mantling,"last grip release stands on support h=%s angle=%s actual=%s" % [height,angle,p.position])
			p.free(); ledge.free(); await physics_frame
	# Physical XR controller samples acquire and release through the real loop.
	for height in [.7,1.3]:
		var xr_ledge := box(Vector3(4,height,4),Vector3(0,height*.5,-3))
		var xr_p := actor(Vector3(0,0,-.7),true)
		var hand_tracker := XRControllerTracker.new()
		hand_tracker.type=XRServer.TRACKER_CONTROLLER
		hand_tracker.name="qa038climb"
		XRServer.add_tracker(hand_tracker)
		xr_p.left_hand.tracker=hand_tracker.name
		xr_p._hand_input_ready[xr_p.left_hand]=true
		var pose:=Transform3D(Basis.IDENTITY,Vector3(0,height-.1,-.25))
		hand_tracker.set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		xr_p.left_hand.transform=pose
		hand_tracker.set_input("grip",.9)
		await physics_frame
		xr_p._physics_process(1.0/90.0)
		print("GRIP ",height," hand=",xr_p.left_hand.global_position," grip=",xr_p.left_hand.get_float("grip")," surface=",xr_p.find_grab_surface(xr_p.left_hand.global_position))
		check(xr_p.climbing_left,"real XR grip acquires ledge h=%s" % height)
		for i in range(5):
			pose.origin.z += .17
			hand_tracker.set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
			xr_p.left_hand.transform=pose
			await physics_frame
			xr_p._physics_process(1.0/90.0)
		print("PULL ",height," hand=",xr_p.left_hand.global_position," grabs=",xr_p._grabs," vel=",xr_p.velocity)
		check(xr_p.position.z < -1.2 and xr_p.position.y < .05,"real XR pull moves torso inside ledge h=%s" % height)
		hand_tracker.set_input("grip",0.0)
		await physics_frame
		xr_p._physics_process(1.0/90.0)
		check(xr_p.position.y > height-.02 and not xr_p.climbing and not xr_p.mantling,"real XR release stands naturally h=%s actual=%s" % [height,xr_p.position])
		XRServer.remove_tracker(hand_tracker)
		xr_p.free(); xr_ledge.free(); await physics_frame
	# Already-spread tracked hands: edge crossing and a 40 cm gap.
	var start_platform := box(Vector3(4,1,2),Vector3(0,.5,0))
	var end_platform := box(Vector3(4,1,2),Vector3(0,.5,-2.4))
	var flyer:=actor(Vector3(0,1,-.8),true)
	var flight_trackers:Array[XRControllerTracker]=[]
	for index in range(2):
		var hand: XRController3D=flyer.left_hand if index==0 else flyer.right_hand
		var flight_tracker:=XRControllerTracker.new()
		flight_tracker.type=XRServer.TRACKER_CONTROLLER
		flight_tracker.name="qa038fly"+str(index)
		XRServer.add_tracker(flight_tracker)
		hand.tracker=flight_tracker.name
		hand.position=Vector3(-.6 if index==0 else .6,1.2,-.3)
		flight_tracker.set_pose("grip",hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		flyer._hand_input_ready[hand]=true
		flight_trackers.append(flight_tracker)
	flight_trackers[0].set_input("primary",Vector2(0,1))
	await physics_frame
	var first_air_checked:=false
	for i in range(10):
		flyer._physics_process(1.0/90.0)
		if not flyer.is_supported() and not first_air_checked:
			first_air_checked=true
			check(flyer.gliding and flyer.movement_mode=="glide" and is_equal_approx(flyer.velocity.y,-1.6),"already-spread XR hands glide on exact first unsupported edge frame")
		await physics_frame
	check(first_air_checked and flyer.position.z < -1.45 and flyer.position.y>.9,"tracked arms-out flight traverses40cmgap without delayedfall actual=%s" % flyer.position)
	flight_trackers[0].set_input("primary",Vector2.ZERO)
	for spread in [0.958875,0.95890625,0.95900625]:
		flyer.position=Vector3(0,5,0)
		flyer.reset_motion()
		flyer.left_hand.position=Vector3(0,1.2,-.3)
		flyer.right_hand.position=Vector3(spread,1.2,-.3)
		await physics_frame
		flyer._physics_process(1.0/90.0)
		check(flyer.gliding == (spread>0.95890625),"horizontal glide threshold boundary spread=%s actual=%s"%[spread,flyer.gliding])
	for heights in [Vector2(.2,2.4),Vector2(2.5,.1),Vector2(.5,1.8)]:
		flyer.position=Vector3(0,5,0)
		flyer.reset_motion()
		flyer.left_hand.position=Vector3(-.2,heights.x,-.3)
		flyer.right_hand.position=Vector3(.2,heights.y,-.3)
		await physics_frame
		flyer._physics_process(1.0/90.0)
		check(not flyer.gliding,"asymmetric vertical climbing pose never substitutes for horizontal spread heights=%s"%heights)
	for multiplier in [.5,1.0,1.5]:
		flyer.position=Vector3(0,5,0)
		flyer.reset_motion()
		flyer.walk_speed_multiplier=multiplier
		flyer.left_hand.position=Vector3(-.6,1.8,-.3)
		flyer.right_hand.position=Vector3(.6,.6,-.3)
		await physics_frame
		var before:=flyer.position
		flyer._physics_process(1.0/90.0)
		var speed:=flyer.effective_walk_speed()*2.0
		check(absf(Vector2(flyer.velocity.x,flyer.velocity.z).length()-speed)<.01 and is_equal_approx(flyer.velocity.y,-1.6),"glide immediately2xwalking multiplier=%s actual=%s" % [multiplier,flyer.velocity])
		var expected_heading:=Vector3(.65*.875,0,-1).normalized()
		check(absf(flyer.velocity.x-speed*expected_heading.x)<.01 and absf(flyer.velocity.z-speed*expected_heading.z)<.01,"old hand-height mapping0.875xstrength applied without smoothing")
		check(absf((flyer.position-before).x-speed*expected_heading.x/90.0)<.005,"actual sameframe tilted trajectory matches directvelocity")
		flyer.left_hand.position.y=.6
		flyer.right_hand.position.y=1.8
		await physics_frame
		var before_reverse:=flyer.position
		flyer._physics_process(1.0/90.0)
		print("GLIDE_REVERSE multiplier=",multiplier," actual_velocity=",flyer.velocity," actual_displacement=",flyer.position-before_reverse)
		check(flyer.velocity.x<-speed*.49 and flyer.velocity.z<-speed*.86 and absf((flyer.position-before_reverse).x+speed*expected_heading.x/90.0)<.005,"abrupt oppositehandtilt reverses actualvelocity AND trajectory ononeframe")
		check(is_zero_approx(flyer.xr_camera.rotation.z),"flightheading never rolls camera")
	flyer.position=Vector3(0,5,0)
	flyer.rotation.y=PI/2.0
	flyer.reset_motion()
	flyer.walk_speed_multiplier=1.0
	flyer.left_hand.position=Vector3(-.6,1.8,-.3)
	flyer.right_hand.position=Vector3(.6,.6,-.3)
	await physics_frame
	flyer._physics_process(1.0/90.0)
	var yaw_expected:=Vector3(-1,0,-.65*.875).normalized()*13.0
	check(Vector2(flyer.velocity.x-yaw_expected.x,flyer.velocity.z-yaw_expected.z).length()<.01,"actual flight maps preserved bank sign through90degree locomotionyaw")
	flyer.left_hand.position.x=.6
	flyer.right_hand.position.x=-.6
	await physics_frame
	flyer._physics_process(1.0/90.0)
	check(Vector2(flyer.velocity.x-yaw_expected.x,flyer.velocity.z-yaw_expected.z).length()<.01,"crossedhandpositions do notreverse preservedheightmapping")
	flyer.left_hand.position=Vector3(-.02,1.2,-.3)
	flyer.right_hand.position=Vector3(.02,1.2,-.3)
	await physics_frame
	flyer._physics_process(1.0/90.0)
	check(not flyer.gliding and flyer.velocity.is_finite(),"closehands stop glideintent without undefinedheading")
	start_platform.free(); end_platform.free(); await physics_frame
	var release_ledge:=box(Vector3(4,1.3,4),Vector3(0,.65,-3))
	flyer.position=Vector3(0,1,-.7)
	flyer.rotation=Vector3.ZERO
	flyer.reset_motion()
	flyer.left_hand.position=Vector3(0,.2,-.25)
	flyer.right_hand.position=Vector3(1.2,.2,-.25)
	flight_trackers[0].set_input("grip",.9)
	await physics_frame
	flyer._physics_process(1.0/90.0)
	check(flyer.climbing_left,"actual XR acquirebeforearmsoutclimbrelease")
	flight_trackers[0].set_input("grip",0.0)
	await physics_frame
	flyer._physics_process(1.0/90.0)
	check(flyer.gliding and not flyer.climbing and absf(Vector2(flyer.velocity.x,flyer.velocity.z).length()-13.0)<.01,"actual XR finalgriprelease withspreadhands glidesfullspeedonsameframe")
	release_ledge.free()
	for flight_tracker in flight_trackers: XRServer.remove_tracker(flight_tracker)
	flyer.free(); await physics_frame
	var wall := box(Vector3(4,4,.2),Vector3(0,2,-1))
	var p := actor(Vector3.ZERO)
	await physics_frame
	for i in range(30):
		p.apply_climb_motion(Vector3(0,0,-.2),1.0/90.0); await physics_frame
	check(p.get_view_camera().global_position.z > -.79,"head envelope cannot pass vertical wall")
	p.free(); wall.free(); await physics_frame
	var ledge := box(Vector3(4,1.0,4),Vector3(0,.5,-3))
	var ceiling := box(Vector3(4,.2,4),Vector3(0,2.3,-3))
	p = actor(Vector3(0,0,-2))
	await physics_frame
	p._grabs[p.left_hand] = p.left_hand.global_position
	p._update_grab(p.left_hand,false)
	check(p.get_view_camera().global_position.y < 2.09 and p.position.y < .5,"ceiling limits release elevation without head penetration")
	p.free(); ceiling.free(); ledge.free(); await physics_frame
	p=actor(Vector3(0,3,0))
	await physics_frame
	for i in range(120):
		p.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/90.0); await physics_frame
	check(absf(p.position.y)<.02 and p.is_supported(),"fall lands at standing height without floor penetration")
	p.free(); await physics_frame
	p=actor(Vector3.ZERO,true)
	var tracker := XRControllerTracker.new()
	tracker.type=XRServer.TRACKER_CONTROLLER
	tracker.name="qa038left"
	XRServer.add_tracker(tracker)
	p.left_hand.tracker=tracker.name
	tracker.set_pose("grip",p.left_hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	p._hand_input_ready[p.left_hand]=true
	tracker.set_input("primary",Vector2(0,1))
	await physics_frame
	# Run full player physics (XR polling -> sprint -> actual displacement).
	tracker.set_input("primary_click",true)
	p._physics_process(1.0/90.0)
	print("SPRINT1 ",p._sprint_mode," vel=",p.velocity," supported=",p.is_supported()," head=",p.xr_camera.position," stick=",p.left_hand.get_vector2("primary")," click=",p.left_hand.is_button_pressed("primary_click"))
	check(p._sprint_mode==1 and p.velocity.length()>8.0,"first XR click moves at slow sprint speed")
	tracker.set_input("primary_click",false)
	for i in range(40): p._physics_process(1.0/90.0); await physics_frame
	var blocker:=SprintBlocker.new()
	root.add_child(blocker)
	p.sprint_conflict_provider=blocker
	blocker.blocked=true
	p._physics_process(1.0/90.0)
	check(p._sprint_mode==1 and p.velocity.length()>8.0,"stick-click sprint continues through normal weapon support")
	blocker.blocked=false
	p._physics_process(1.0/90.0)
	check(p._sprint_mode==1 and p.velocity.length()>8.0,"speed resumes after temporary weapon arbitration")
	var stamina_before: float=p._sprint_stamina
	tracker.set_input("primary_click",true)
	p._physics_process(1.0/90.0)
	print("SPRINT2 ",p._sprint_mode," vel=",p.velocity," supported=",p.is_supported())
	check(p._sprint_mode==2 and p.velocity.length()>9.6,"second XR click after .44s enters fast sprint")
	tracker.set_input("primary_click",false)
	p._physics_process(1.0/90.0)
	check(p._sprint_stamina<stamina_before,"real moving XR sprint consumes HUD stamina source")
	tracker.set_input("primary_click",true)
	p._physics_process(1.0/90.0)
	check(p._sprint_mode==0 and p.velocity.length()<6.6,"third XR click returns to walk")
	for hand in [p.left_hand,p.right_hand]:
		var glove: Node3D=hand.get_node("ArticulatedGlove")
		var thumb: Node3D=glove.get_node("GripSurface/Thumb")
		var pitch:=Basis(Vector3.RIGHT,-PI/2.0)
		var palm:Node3D=glove.get_node("GripSurface/PalmSurface")
		# 045 moved the skin beside the grip and shortened the thumb-root spread.
		# Measure actual thumb relative to actual palm, not the old rig origin.
		var relative:Vector3=pitch.inverse()*hand.global_basis.inverse()*(thumb.global_position-palm.global_position)
		var toward_grip:bool=relative.x>0 if hand==p.left_hand else relative.x<0
		check(relative.y>.02 and relative.y<.04 and toward_grip,"actual mirrored thumb root above palm and opposed toward grip: "+hand.name)
	blocker.free()
	XRServer.remove_tracker(tracker)
	p.free(); await physics_frame
	# Room-scale tracking must not put the virtual head through a thin wall.
	wall=box(Vector3(4,4,.1),Vector3(0,2,-.7))
	p=actor(Vector3.ZERO,true)
	await physics_frame
	p._sync_body_to_head()
	p.xr_camera.position.z=-1.4
	p._sync_body_to_head()
	check(p.xr_camera.global_position.z>-.54,"tracked room-scale movement swept against thin wall")
	p.free(); wall.free(); await physics_frame
	p=actor(Vector3(0,2,0))
	p.velocity.y=-90.0
	await physics_frame
	for i in range(11):
		p.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/90.0); await physics_frame
	check(p.position.y>=-.01 and p.is_supported(),"fast fall foot-plane crossing lands above floor")
	p.free(); floor.free(); await physics_frame
	var campaign:=preload("res://scripts/world.gd").new()
	root.add_child(campaign)
	campaign.build()
	await physics_frame
	for approach in [Vector3(3.5,0,-9),Vector3(-3.5,0,-9),Vector3(7,0,-11)]:
		var runner:=actor(approach)
		var direction:=Vector3.LEFT if approach.x>6 else Vector3.FORWARD
		await physics_frame
		for i in range(26):
			runner.apply_locomotion_motion(direction,direction,false,false,1.0/90.0)
			await physics_frame
		check(runner.position.y>.98 and runner.position.y<1.03 and runner.is_supported(),"actual first checkpoint platform walk withoutstairs from=%s actual=%s eye=1.65 goggles-clear-rise=1.53" % [approach,runner.position])
		runner.free(); await physics_frame
	for model in campaign.get_children():
		if not (str(model.name).begins_with("CC0_old_military_crate") or str(model.name).begins_with("CC0_rock_07")): continue
		for body in model.get_children():
			if not body is StaticBody3D: continue
			for collision in body.get_children():
				if not collision is CollisionShape3D or not collision.shape is BoxShape3D: continue
				var size:Vector3=collision.shape.size * collision.global_basis.get_scale()
				var top:float=collision.global_position.y+size.y*.5
				print("ACTUAL_PROP ",model.name," center=",collision.global_position," size=",size," top=",top)
				if top<.05: continue
				for axis in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD]:
					var extent:float=(size.x*.5 if absf(axis.x)>.5 else size.z*.5)
					var start:Vector3=collision.global_position+axis*(extent+.55)
					start.y=0.0
					var ground_query:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*(top+1.0),start-Vector3.UP*2.0,1)
					var ground_hit:=root.get_world_3d().direct_space_state.intersect_ray(ground_query)
					if ground_hit.is_empty(): continue
					start.y=ground_hit.position.y
					if top-start.y>1.023 or top-start.y<.05: continue
					var runner:=actor(start)
					await physics_frame
					for i in range(ceili((extent+.8)/6.5*90.0)):
						runner.apply_locomotion_motion(-axis,-axis,false,false,1.0/90.0)
						await physics_frame
					check(absf(runner.position.y-top)<.04 and runner.is_supported(),"actual small prop walk %s axis=%s top=%s end=%s" % [model.name,axis,top,runner.position])
					runner.free(); await physics_frame
	# Actual procedural crates are1.2m high, under measured mid-chest1.2375m.
	for approach in [Vector3(7,0,8.5),Vector3(8.5,0,7),Vector3(7,0,5.5)]:
		var crate_runner:=actor(approach)
		var crate_direction:Vector3=(Vector3(7,0,7)-approach).normalized()
		await physics_frame
		for i in range(20):
			crate_runner.apply_locomotion_motion(crate_direction,crate_direction,false,false,1.0/90.0)
			await physics_frame
		check(absf(crate_runner.position.y-1.2)<.03 and crate_runner.is_supported(),"actual staging1.2m crate under1.2375m midchest walks from="+str(approach)+" end="+str(crate_runner.position))
		crate_runner.free();await physics_frame
	var rock_routes:=0
	for model in campaign.get_children():
		if not str(model.name).begins_with("CC0_rock_07"): continue
		var space:=root.get_world_3d().direct_space_state
		for sx in range(-30,31):
			if rock_routes>=3: break
			for sz in range(-30,31):
				if rock_routes>=3: break
				var at:Vector3=model.global_position+Vector3(sx*.1,4,sz*.1)
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*4.1,1))
				if hit.is_empty() or not model.is_ancestor_of(hit.collider) or hit.position.y<.15 or hit.position.y>1.023 or hit.normal.y<.5: continue
				var normal_out:=Vector3(hit.normal.x,0,hit.normal.z).normalized()
				if normal_out.length()<.5: continue
				print("ROCK_SAMPLE ",hit.position," normal=",hit.normal)
				for angle in [-.25,0.0,.25]:
					var outward:=normal_out.rotated(Vector3.UP,angle)
					var start:Vector3=hit.position+outward*.6
					var ground:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3.UP*2,start-Vector3.UP*2,1))
					if ground.is_empty(): continue
					start.y=ground.position.y
					var runner:=actor(start)
					await physics_frame
					for i in range(11):
						runner.apply_locomotion_motion(-outward,-outward,false,false,1.0/90.0)
						await physics_frame
					var support:=runner._support_hit()
					print("ROCK_END_SUPPORT ",support," HIGH=",space.intersect_ray(PhysicsRayQueryParameters3D.create(runner.position+Vector3.UP*4,runner.position-Vector3.UP*2,1)))
					check(not support.is_empty() and model.is_ancestor_of(support.collider) and runner.is_supported() and runner.position.y>.1,"actual uneven rock lowedge walk angle=%s start=%s end=%s sampletop=%s" % [angle,start,runner.position,hit.position.y])
					rock_routes+=1
					runner.free(); await physics_frame
	check(rock_routes>=3,"actual rock lowregion traversed from3approachangles")
	campaign.free(); await physics_frame
	print("HEAD_COLLISION_038 passes=",passed," failures=",failed," physical_headset_tested=false")
	quit(0 if failed==0 else 1)




























