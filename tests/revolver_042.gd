extends SceneTree
class Revolver extends "res://scripts/revolver.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var count:=2
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,n:int)->int:
		var amount:=mini(n,count);count-=amount;return amount
var checks:=0
var failures:=0
var gun
var actor
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._process(0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="revolver042_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
		actor.update_hand_input_rearm(.1)
		gun=Revolver.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		var reserve:=Reserve.new();root.add_child(reserve);gun.ammo_provider=reserve;gun.ammo_slot=0;gun._process(0)
		check(gun.ammo==6,side+" six live chambers")
		var raw:Transform3D=gun.right_hand.global_transform
		for i in range(6):
			gun.cooldown=0;trackers[gun.right_hand].set_input("trigger",0.0);gun._process(0);trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0)
			var count:int=gun.ammo;gun.cooldown=0;gun._process(0);check(gun.ammo==count,side+" held trigger cannot repeat")
		check(gun.ammo==0 and gun.chambers.count("spent")==6 and gun.reload_state=="ready",side+" spent cases stay in closed cylinder")
		trackers[gun.right_hand].set_input("trigger",0.0)
		sample(gun.LATCH_POINT,0);sample(gun.LATCH_POINT,1);sample(gun.LATCH_POINT+Vector3(-.08,0,0),1)
		check(gun.reload_state=="cylinder_open",side+" actual latch leftward travel opens cylinder")
		sample(gun.OPEN_POINT,0);sample(gun.OPEN_POINT,1);sample(gun.OPEN_POINT+Vector3(0,0,-.08),1)
		check(gun.chambers.count("empty")==6 and gun.ammo==0,side+" actual ejector press clears spent only")
		for i in range(2):
			sample(gun.ROUND_OFFER,0);sample(gun.ROUND_OFFER,1);check(gun.reload_state=="held_round",side+" finite loose round acquire")
			sample(gun.OPEN_POINT,1)
		check(gun.ammo==2 and reserve.count==0,side+" two single cartridges consume exactly finite reserve")
		sample(gun.ROUND_OFFER,0);sample(gun.ROUND_OFFER,1);check(gun.reload_state=="cylinder_open",side+" empty reserve offers no free round")
		sample(gun.OPEN_POINT,0);sample(gun.OPEN_POINT,1);sample(gun.OPEN_POINT+Vector3(.08,0,0),1)
		check(gun.reload_state=="ready" and gun.ammo==2,side+" inward cylinder closes partial load")
		check(gun.right_hand.global_transform.is_equal_approx(raw),side+" raw weapon tracker unchanged")
		check(gun.find_children("*","Label3D",true,false).size()==1,side+" only loaded reserve ammo label")
		gun.eject_magazine();reserve.count=1;gun.grab_magazine();gun._suspend_left_gestures()
		check(gun.reload_state=="cylinder_open" and reserve.count==1 and gun.ammo==2,side+" interrupted held round returns without consuming ammo")
		actor._grabs[actor.left_hand]=actor.left_hand.global_position;actor._grabs[actor.right_hand]=actor.right_hand.global_position;gun.eject_cases();gun.grab_magazine();gun.rack_bolt()
		check(gun.reload_state=="cylinder_open" and gun.ammo==2 and actor.climbing_left and actor.climbing_right,side+" wall grips block manipulation without releasing wall")
		actor._grabs.clear()
		gun._suspend_left_gestures();gun._resume_grip_release=true
		sample(gun.ROUND_OFFER,1);sample(gun.OPEN_POINT,1)
		check(gun.ammo==2 and reserve.count==1 and gun.reload_state=="cylinder_open",side+" held grip cannot resume stale insertion after suspension")
		sample(gun.ROUND_OFFER,0);sample(gun.ROUND_OFFER,1);sample(gun.OPEN_POINT,1)
		check(gun.ammo==3 and reserve.count==0,side+" neutral then new gesture rearms safely")
		gun.rack_bolt();actor.head_obstructed=true;gun._semi_armed=true;gun.cooldown=0;gun.fire()
		check(gun.ammo==3,side+" obstructed headset cannot fire")
		actor.head_obstructed=false
		gun.reset_weapon();gun.chambers.assign(["spent","empty","live","empty","empty","empty"]);gun._sync();reserve.count=1
		gun.desktop_reload_step();gun.desktop_reload_step()
		check(gun.chambers.count("live")==1 and gun.chambers.count("spent")==0,side+" desktop open then spent-only eject preserves live cartridge")
		gun.desktop_reload_step();gun.desktop_reload_step();gun.desktop_reload_step()
		check(gun.ammo==2 and reserve.count==0 and gun.reload_state=="ready",side+" desktop finite single load and close")
		gun.shutdown();await create_timer(.2).timeout;gun.free();reserve.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();await process_frame
	print("REVOLVER_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false");quit(failures)



