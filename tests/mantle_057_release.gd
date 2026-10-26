extends SceneTree
## Real Godot collision/release-path coverage; does not establish headset acceptance.
class FramePlayer extends "res://scripts/player.gd":
	func update_tracking()->bool:return tracking_available
const DT:=1.0/90.0
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func box(size:Vector3,at:Vector3,yaw:float=0.0)->StaticBody3D:
	var value:=StaticBody3D.new();value.position=at;value.rotation.y=yaw;value.collision_layer=1
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;value.add_child(collision);root.add_child(value)
	return value
func actor(at:Vector3,eye:float=1.65)->FramePlayer:
	var value:=FramePlayer.new();root.add_child(value);value.setup(false);value.xr_enabled=true;value.tracking_available=true;value.xr_camera.position.y=eye
	value.set_process(false);value.set_physics_process(false);value.position=at;value._sync_head_shape()
	return value
func finish_release(p,anchor:Vector3)->bool:
	var started:bool=p.try_start_release_mantle(anchor)
	for i in 20:p._step_mantle(DT)
	return started and p.is_supported() and not p.mantling
func static_case(yaw:float,side:float,outside:float,margin:float,eye:float=1.65)->void:
	var basis:=Basis(Vector3.UP,yaw)
	var ledge:=box(Vector3(4,1.2,4),basis*Vector3(0,.6,-3),yaw)
	var p:=actor(basis*Vector3(0,1.2+margin-eye,-1+outside),eye)
	var anchor:=basis*Vector3(side,1.12,-1.01)
	await physics_frame
	var before:=p.global_position
	var wanted:=outside<=.09 and margin>=0.0 and margin<=.06
	var result:=finish_release(p,anchor)
	print("RELEASE_054 yaw=",yaw," anchor_side=",side," outside=",outside," margin=",margin," eye=",eye," result=",result," position=",p.position)
	check(result==wanted,"offset-anchor release yaw=%s side=%s outside=%s margin=%s eye=%s"%[yaw,side,outside,margin,eye])
	if result:
		check(p.is_supported() and absf(p.position.y-1.2)<.015,"recovery finishes on physical top")
		check(Vector2(p.position.x-before.x,p.position.z-before.z).length()<=.1151,"recovery stays within115mm total horizontal motion")
		check(absf(p.xr_camera.global_position.y-(1.2+eye))<.015,"standing uses actual tracked eye height")
	else:check(p.global_position.distance_to(before)<.001,"refused release leaves origin unchanged")
	p.free();ledge.free();await physics_frame
func tracker_for(hand:XRController3D,pose:Transform3D)->XRControllerTracker:
	var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="mantle054_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
	tracker.set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);hand.transform=pose
	return tracker
func tracked_case(dominant:String,last_left:bool,two_hands:bool,tracking_loss:bool=false)->void:
	var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
	var p:=actor(Vector3(0,1.201-1.65,-.96));p.dominant_hand=dominant
	var trackers:Array[XRControllerTracker]=[]
	for index in range(2):
		var hand:XRController3D=p.left_hand if index==0 else p.right_hand
		var point:=Vector3(-.28 if index==0 else .28,1.12,-1.01)
		trackers.append(tracker_for(hand,Transform3D(Basis.IDENTITY,point-p.position)))
	await physics_frame;p.update_hand_input_rearm(.1)
	var last:=0 if last_left else 1
	trackers[last].set_input("grip",1.0)
	if two_hands:trackers[1-last].set_input("grip",1.0)
	p._physics_process(DT)
	check(p._grabs.size()==(2 if two_hands else 1),"actual tracked inputs acquire ledge hands=%s dominant=%s"%[p._grabs.size(),dominant])
	if two_hands:
		trackers[1-last].set_input("grip",0.0);await physics_frame;p._physics_process(DT)
		check(p._grabs.size()==1 and not p.is_supported(),"first of two releases remains anchored")
	if tracking_loss:trackers[last].invalidate_pose("grip")
	else:trackers[last].set_input("grip",0.0)
	await physics_frame;p._physics_process(DT)
	if not tracking_loss:
		for i in 20:p._physics_process(DT)
	if tracking_loss:
		check(not p.is_supported() and p.position.y<0,"tracking cancellation cannot complete release assist")
	else:
		check(p.is_supported() and absf(p.position.y-1.2)<.02 and not p.climbing,"actual final tracked release completes offset-anchor lip dominant=%s left=%s two=%s"%[dominant,last_left,two_hands])
	for tracker in trackers:XRServer.remove_tracker(tracker)
	p.free();ledge.free();await physics_frame
func blocked_case(yaw:float)->void:
	var basis:=Basis(Vector3.UP,yaw)
	var ledge:=box(Vector3(4,1.2,4),basis*Vector3(0,.6,-3),yaw)
	var ceiling:=box(Vector3(4,.1,3),basis*Vector3(0,1.55,-1.5),yaw)
	var p:=actor(basis*Vector3(0,1.201-1.65,-.96));await physics_frame
	var before:=p.position
	check(not finish_release(p,basis*Vector3(.28,1.12,-1.01)),"offset-anchor recovery refuses low ceiling yaw=%s"%yaw)
	check(p.position.distance_to(before)<.001,"blocked recovery has no partial origin changes")
	p.free();ceiling.free();ledge.free();await physics_frame
func panel_and_anchor_cases()->void:
	# Constructed floors use layer4, which normal walking support already sees.
	var floor_panel:=box(Vector3(2.53,.11,2.53),Vector3(0,1.145,-2.265));floor_panel.collision_layer=4
	var p:=actor(Vector3(0,1.201-1.65,-.96));await physics_frame
	check(finish_release(p,Vector3(.28,1.12,-1.01)) and p.is_supported(),"player-built layer4 floor receives the same grazing support as walking")
	p.free();floor_panel.free();await physics_frame
	var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
	p=actor(Vector3(0,1.201-1.65,-.96));await physics_frame
	check(finish_release(p,Vector3(0,1.12,-.96)) and p.is_supported(),"hand directly below goggles needs no horizontal anchor bearing")
	p.free();await physics_frame
	for anchor in [Vector3(3,1.12,-1.01),Vector3(INF,1.12,-1.01)]:
		p=actor(Vector3(0,1.201-1.65,-.96));await physics_frame
		var before:=p.position
		check(not finish_release(p,anchor) and p.position.distance_to(before)<.001,"remote/nonfinite anchor cannot manufacture support")
		p.free();await physics_frame
	ledge.free();await physics_frame
func slope_case()->void:
	# A walkable authored slope is not restricted to the old near-flat .98 normal.
	for pitch in [-.30,.30]:
		var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3));ledge.rotation.x=pitch
		var rim:=ledge.transform*Vector3(0,.6,2)
		var p:=actor(rim+Vector3(0,.001-1.65,.04));await physics_frame
		var before:=p.position
		if pitch<0:
			var first_hit:=p._support_hit()
			check(not first_hit.is_empty() and first_hit.normal.y<cos(p.floor_max_angle),"center ray really hits unwalkable side below adjacent walkable top")
		var result:=finish_release(p,rim+Vector3(.28,-.08,-.01))
		print("SLOPE_054 pitch=",pitch," rim=",rim," result=",result," position=",p.position)
		if pitch<0:
			check(result and p.is_supported(),"clear walkable non-grid sloped lip receives collision-swept recovery")
			if result:
				var support:=p._support_hit()
				check(not support.is_empty() and absf(p.position.y-support.position.y)<.015,"slope finish agrees with actual support height")
		else:
			check(not result and p.position.distance_to(before)<.001,"uphill top intersecting goggles cannot gain an unsafe lip bypass")
		p.free();ledge.free();await physics_frame
func corner_case(yaw:float)->void:
	var basis:=Basis(Vector3.UP,yaw)
	var ledge:=box(Vector3(4,1.2,4),basis*Vector3(0,.6,-3),yaw)
	var p:=actor(basis*Vector3(2.04,1.201-1.65,-.96));await physics_frame
	var before:=p.position
	check(finish_release(p,basis*Vector3(1.98,1.12,-1.01)) and p.is_supported(),"rotated two-edge corner completes on actual top yaw=%s"%yaw)
	check(Vector2(p.position.x-before.x,p.position.z-before.z).length()<=.1151,"diagonal corner keeps total horizontal bound")
	p.free();ledge.free();await physics_frame
func lower_floor_case()->void:
	var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
	var ground:=box(Vector3(20,.1,20),Vector3(0,-.05,-1))
	var p:=actor(Vector3(0,1.201-1.65,-.96));await physics_frame
	var initial:=p._support_hit()
	check(not initial.is_empty() and absf(initial.position.y)<.001,"outside center ray really sees lower walkable floor")
	var result:=finish_release(p,Vector3(.28,1.12,-1.01))
	print("LOWER_FLOOR_054 result=",result," feet=",p.position," head=",p.xr_camera.global_position)
	check(result and p.is_supported() and absf(p.position.y-1.2)<.015,"local grazing top takes precedence over lower floor behind center ray")
	p.free();ground.free();ledge.free();await physics_frame
func partial_support_case()->void:
	# The center already sees the top, so this bypasses local-route preflight
	# and exercises rollback after the normal solver moves upward into a roof.
	var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
	var ceiling:=box(Vector3(4,.1,4),Vector3(0,2.05,-3))
	var p:=actor(Vector3(0,1.205-1.65,-1.4));await physics_frame
	var before:=p.position
	var old_head:=p.xr_camera.global_position
	var raw_result:=p._resolve_support(p.head_support_rise())
	check(not raw_result and p.position.y>before.y+.1,"fixture proves raw support solver advances partially before ceiling refusal")
	p.position=before;p._sync_head_shape()
	p._last_head=old_head;p.velocity=Vector3(1,2,3)
	check(not finish_release(p,Vector3(.28,1.12,-1.01)) and p.position.distance_to(before)<.001,"direct support ceiling refusal rolls back actual partial upward solver motion")
	check(p.velocity==Vector3(1,2,3) and p._last_head==old_head and not p.is_supported(),"failed standing sweep restores velocity and cached head/support")
	p.free();ceiling.free();ledge.free();await physics_frame
func run()->void:
	for yaw in [0.0,.37]:
		for side in [-.28,.28]:
			for outside in [.04,.09]:await static_case(yaw,side,outside,.001)
		for margin in [-.006,0.0,.06,.07]:await static_case(yaw,.28,.04,margin)
		await static_case(yaw,.28,.16,.001)
		await blocked_case(yaw)
		await corner_case(yaw)
	for eye in [.85,1.35,1.95]:await static_case(.61,.28,.04,.001,eye)
	await panel_and_anchor_cases()
	await slope_case()
	await lower_floor_case()
	await partial_support_case()
	for dominant in ["left","right"]:
		for last_left in [true,false]:
			for two_hands in [false,true]:await tracked_case(dominant,last_left,two_hands)
	await tracked_case("right",true,false,true)
	print("MANTLE_057_RELEASE checks=",checks," failures=",failures," real_physics=true synthetic_tracking=true exact_screenshot_pose=false headset_verified=false")
	quit(1 if failures else 0)
