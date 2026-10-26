extends SceneTree
class Rifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
class Shotgun extends "res://scripts/shotgun.gd":
	func _vr_active()->bool:return true
var actor
var trackers:Dictionary={}
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func hand(gun,point:Vector3,grip:float):
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip)
	gun._poll_vr()
func offset(radius:float,axis:String,outside:bool)->Vector3:
	if axis=="left":return Vector3(-(radius+(.045 if outside else .02)),0,0)
	if axis=="right":return Vector3(radius+(.045 if outside else .02),0,0)
	return Vector3(0,0,-(radius+(.05 if outside else .025)))
func run():
	print("SCOPE production reload polling using real synthetic XR controller grip; headset_tested=false")
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for h in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="reload038_"+str(h.get_instance_id());XRServer.add_tracker(t);h.tracker=t.name;h.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[h]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for kind in ["rifle","shotgun"]:
			var gun=Rifle.new() if kind=="rifle" else Shotgun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false)
			for axis in ["left","right","forward"]:
				for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
				actor.update_hand_input_rearm(.2);gun.reset_weapon();gun._poll_vr()
				gun.global_transform=gun.corrected_grip_transform(gun.right_hand.global_transform)
				# Opening is real dominant stick input, not a state mutation.
				trackers[gun.right_hand].set_input("primary",Vector2(0,-1));gun._poll_vr();trackers[gun.right_hand].set_input("primary",Vector2.ZERO);gun._poll_vr()
				if kind=="shotgun":gun._process(.2) # Production hinge animation reaches its real open pose.
				var offer:Vector3=gun.OFFER_POINT if kind=="rifle" else gun.get_shell_offer_point()
				var tag=side+" "+kind+" "+axis+" "
				hand(gun,offer+offset(.10,axis,true),0);hand(gun,offer+offset(.10,axis,true),1)
				check(gun.reload_state in ["needs_mag","open_empty"],tag+"outside fresh-ammo reach rejected")
				hand(gun,offer+offset(.10,axis,false),0);hand(gun,offer+offset(.10,axis,false),1)
				check(gun.reload_state in ["held_mag","holding_shells"],tag+"new-only fresh-ammo reach grabs")
				var insert:Vector3=gun.INSERT_POINT if kind=="rifle" else gun.get_chamber_insert_point()
				var radius:=.10 if kind=="rifle" else .09
				hand(gun,insert+offset(radius,axis,true),1)
				check(gun.reload_state in ["held_mag","holding_shells"],tag+"outside insertion reach rejected")
				hand(gun,insert+offset(radius,axis,false),1)
				# Shotgun's action updates its public reload label in _process, but action itself is authoritative.
				var state:String=gun.reload_state if kind=="rifle" else gun.action.state
				check(state in ["needs_rack","open_loaded"],tag+"new-only insertion seats ammunition")
				var rack:Vector3=Vector3(-.05,.064,-.10) if kind=="rifle" else gun.get_close_grip_point()
				hand(gun,rack+offset(.18,axis,true),0);hand(gun,rack+offset(.18,axis,true),1)
				check(not gun._rack_grabbed if kind=="rifle" else not gun._closing,tag+"outside rack/breech reach rejected")
				hand(gun,rack+offset(.18,axis,false),0);hand(gun,rack+offset(.18,axis,false),1)
				check(gun._rack_grabbed if kind=="rifle" else gun._closing,tag+"new-only rack/breech reach grabs")
				var movement:=Vector3(0,0,.08) if kind=="rifle" else Vector3(0,.10,0)
				hand(gun,rack+offset(.18,axis,false)+movement,1)
				state=gun.reload_state if kind=="rifle" else gun.action.state
				check(state=="ready" and gun.ammo==gun.magazine_size,tag+"full physical reload completes")
			gun.shutdown();gun.queue_free();await process_frame
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.queue_free();await process_frame;await create_timer(.1).timeout
	print("RELOAD_REACH_038 ",checks-failures,"/",checks);quit(1 if failures else 0)


