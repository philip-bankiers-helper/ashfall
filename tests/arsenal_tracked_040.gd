# Pump production gestures moved to shotguns_tracked_041.gd; this fixture retains magazine-fed pistol/burst contracts.
extends SceneTree
class VRPistol extends "res://scripts/pistol.gd":
	func _vr_active()->bool:return true
class VRBurst extends "res://scripts/burst_carbine.gd":
	func _vr_active()->bool:return true
class VRPump extends "res://scripts/pump_shotgun.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
var actor
var gun
var firing:XRControllerTracker
var support:XRControllerTracker
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func tracker(id:String,hand:XRController3D)->XRControllerTracker:
	var value:=XRControllerTracker.new()
	value.type=XRServer.TRACKER_CONTROLLER;value.name=id
	XRServer.add_tracker(value);hand.tracker=id;hand.pose="grip"
	value.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	return value
func hand_at(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	support.set_input("grip",grip)
	gun._poll_vr()
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_physics_process(false);actor.set_process(false)
	var left:=tracker("arsenal_left",actor.left_hand)
	var right:=tracker("arsenal_right",actor.right_hand)
	await process_frame
	for handedness in ["right","left"]:
		actor.dominant_hand=handedness
		firing=right if handedness=="right" else left
		support=left if handedness=="right" else right
		for scene in [VRPistol,VRBurst]:
			gun=scene.new();root.add_child(gun);gun.setup(actor,false)
			gun.set_process(false);gun.set_physics_process(false)
			firing.set_input("trigger",0.0);firing.set_input("primary",Vector2.ZERO);firing.set_input("primary_click",false)
			support.set_input("grip",0.0);actor.update_hand_input_rearm(0.1);gun._poll_vr()
			firing.set_input("primary_click",true);gun._poll_vr()
			if handedness=="left":
				check(gun.reload_state=="ready","physical left click remains sprint-owned")
				firing.set_input("primary",Vector2(0,-1));gun._poll_vr()
			check(gun.reload_state=="needs_mag",handedness+" actual dominant eject "+str(gun.magazine_size))
			firing.set_input("primary_click",false);firing.set_input("primary",Vector2.ZERO);gun._poll_vr()
			hand_at(gun.OFFER_POINT,0);hand_at(gun.OFFER_POINT,1)
			check(gun.reload_state=="held_mag",handedness+" tracked offered mag acquire")
			hand_at(gun.INSERT_POINT,1)
			check(gun.reload_state=="needs_rack" and gun.ammo==0,handedness+" upward tracked mag insertion")
			hand_at(Vector3(-0.05,0.064,-0.10),0)
			hand_at(Vector3(-0.05,0.064,-0.10),1)
			hand_at(Vector3(-0.05,0.064,-0.02),1)
			check(gun.reload_state=="ready" and gun.ammo==gun.magazine_size,handedness+" tracked pull chambers exact magazine")
			firing.set_input("trigger",0.0);support.set_input("grip",0.0);gun._process(0.2)
			firing.set_input("trigger",1.0);gun._process(0.01)
			check(gun.ammo==gun.magazine_size-1,handedness+" actual tracked trigger consumes round")
			if gun is VRPump:
				firing.set_input("trigger",0.0)
				support.set_input("grip",0.0);gun._process(0)
				gun.left_hand.global_position=gun.reload_world_point(gun.PUMP_REST)
				support.set_input("grip",1.0);gun._process(0)
				gun.left_hand.global_position=gun.reload_world_point(gun.PUMP_REST+Vector3(0,0,0.13));gun._process(0)
				check(gun.reload_state=="needs_pump_forward",handedness+" production process tracked pump back")
				gun.left_hand.global_position=gun.reload_world_point(gun.PUMP_REST);gun._process(0)
				check(gun.reload_state=="ready",handedness+" production process tracked pump forward")
			check(gun.model.rotation.x>0 and gun.model.position.z>0,handedness+" recoil changes real model")
			if gun is VRBurst:
				check(gun.burst_remaining>0,"burst has queued concrete rounds")
				gun._suspend_gestures()
				check(gun.burst_remaining==0,"selection suspension cancels queued burst")
			gun.reset_weapon()
			firing.set_input("trigger",0.0);support.set_input("grip",0.0);gun._process(0)
			var visual=gun.left_hand.get_node("ArticulatedGlove")
			var rest:Transform3D=visual.transform
			gun.left_hand.global_position=gun.reload_world_point(gun.PISTOL_SUPPORT_POINT if gun is VRPistol else gun.FOREGRIP_POINT)
			var raw:Transform3D=gun.left_hand.global_transform
			support.set_input("grip",1.0);gun._process(0)
			if gun is VRPistol:
				check(gun.supported and visual.global_position.distance_to(gun.model.to_global(gun.PISTOL_SUPPORT_POINT))<.001,handedness+" pistol support cups grip")
				check(gun.left_hand.global_transform.is_equal_approx(raw),handedness+" pistol support preserves raw pose")
				support.set_input("grip",0.0);gun._process(0)
				check(not gun.supported and visual.transform.is_equal_approx(rest),handedness+" pistol grip release restores glove")
			else:
				check(gun.supported and visual.global_position.distance_to(gun.model.to_global(gun.FOREGRIP_POINT))<0.001,handedness+" long weapon rendered foregrip attachment")
				check(gun.left_hand.global_transform.is_equal_approx(raw),handedness+" foregrip preserves raw controller pose")
				support.set_input("grip",0.0);gun._process(0)
				check(not gun.supported and visual.transform.is_equal_approx(rest),handedness+" foregrip release restores glove")
			gun.shutdown();await create_timer(0.2).timeout;gun.free();gun=null
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	left=null;right=null;firing=null;support=null
	actor.free();actor=null
	await process_frame
	print("ARSENAL_TRACKED_040 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)



