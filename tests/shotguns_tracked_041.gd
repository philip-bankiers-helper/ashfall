extends SceneTree
class Pump extends "res://scripts/pump_shotgun.gd":
	func _vr_active()->bool:return true
class Double extends "res://scripts/shotgun.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
var actor
var gun
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip)
	gun._process(0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="shotgun041_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for kind in [Pump,Double]:
			for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
			actor.update_hand_input_rearm(.1)
			gun=kind.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._process(0)
			var prefix:String=side+" "+str(gun.magazine_size)+" "
			var raw:Transform3D=gun.right_hand.global_transform
			if gun is Pump:
				gun.cooldown=0;trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0)
				check(gun.ammo==4 and not gun.chambered,prefix+" tracked trigger consumes one chamber")
				trackers[gun.right_hand].set_input("trigger",0.0)
				sample(gun.PUMP_REST,0);sample(gun.PUMP_REST,1)
				sample(gun.PUMP_REST+Vector3(0,0,.13),1)
				check(gun.reload_state=="needs_pump_forward",prefix+" actual tracked backward pump opens action")
				sample(gun.PUMP_REST,1)
				check(gun.chambered and gun.tube_rounds==3 and gun.ammo==4,prefix+" actual tracked forward chambers existing tube round")
				sample(gun.SHELL_OFFER,0);sample(gun.SHELL_OFFER,1)
				check(gun.reload_state=="held_shell",prefix+" fresh underreceiver shell grip")
				sample(gun.SHELL_OFFER+Vector3(0,.02,0),1)
				check(gun.reload_state=="held_shell",prefix+" small shell jitter does not seat")
				sample(gun.SHELL_PORT,1)
				check(gun.ammo==5 and gun.tube_rounds==4,prefix+" tracked upward shell seats one tube round")
				gun.cooldown=0;sample(gun.PUMP_REST,0);trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0);trackers[gun.right_hand].set_input("trigger",0.0)
				sample(gun.PUMP_REST,0);sample(gun.PUMP_REST,1);sample(gun.PUMP_REST+Vector3(0,0,.13),1);sample(gun.PUMP_REST+Vector3(0,0,.13),0)
				check(not gun.chambered and gun.reload_state=="needs_pump_back",prefix+" release during stroke cannot chamber")
			else:
				sample(Vector3(0,.065,-.025),0);sample(Vector3(0,.065,-.025),1);sample(Vector3(0,.005,-.025),1)
				check(gun.action.state=="open_empty",prefix+" tracked latch downward movement opens barrels")
				gun._process(.2)
				check(gun.hinge.rotation.x<-.6 and gun.chamber_states==["empty","empty"],prefix+" both chamber mouths exposed by actual hinge")
				var offer:Vector3=gun.get_shell_offer_point()
				sample(offer,0);sample(offer,1)
				check(gun.action.state=="holding_shells",prefix+" tracked shell pair acquire above mouths")
				sample(gun.get_chamber_insert_point(),1)
				check(gun.action.state=="open_loaded" and gun.chamber_live[0].visible and gun.chamber_live[1].visible,prefix+" actual downward insertion fills two visible chambers")
				var close:Vector3=gun.get_close_grip_point()
				sample(close,0);sample(close,1);sample(close+Vector3(0,.10,0),1)
				check(gun.action.state=="ready" and gun.ammo==2,prefix+" tracked fore-end lift closes latch to fire")
				gun._process(.2);sample(close,0);gun.cooldown=0;trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0)
				check(gun.ammo==1 and gun.chamber_states.count("spent")==1,prefix+" shot changes exactly one live chamber to spent")
			check(gun.right_hand.global_transform.is_equal_approx(raw),prefix+" mechanics preserve raw weapon tracker")
			check(gun.find_children("*","Label3D",true,false).size()==1,prefix+" only ammo text actual runtime")
			gun.shutdown();await create_timer(.2).timeout;gun.free();gun=null
	for t in trackers.values():XRServer.remove_tracker(t)
	trackers.clear();actor.free();await process_frame
	print("SHOTGUNS_TRACKED_041 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)
