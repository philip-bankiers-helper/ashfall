extends "res://tests/lmg_reference_047.gd"
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="m60swipe048_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side;actor._grabs.clear();actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
		actor.update_hand_input_rearm(.2)
		gun=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._process(0)
		var provider:=Reserve.new();provider.count=60;root.add_child(provider);gun.ammo_provider=provider;gun.ammo_slot=0;gun.ammo=0;gun.seated=0;gun.begin_reload()
		var point:Vector3=gun.get_reload_grab_point();sample(point,0);sample(point,1);sample(gun.get_box_seat(),1)
		check(gun.reload_state=="needs_feed" and provider.count==0,side+" swipe1 UP inserts box using actual tracked grip")
		point=gun.get_reload_grab_point();sample(point,1);sample(point+Vector3(-.09*gun.feed_direction(),0,0),1)
		check(gun.reload_state=="needs_feed",side+" feed outward swipe rejected")
		sample(point+Vector3(.09*gun.feed_direction(),0,0),1)
		check(gun.reload_state=="box_seated",side+" swipe2 ACROSS feeds with held grip and no release requirement")
		point=gun.get_reload_grab_point();sample(point,1);sample(point+Vector3(0,-.09,0),1)
		check(gun.reload_state=="needs_charge",side+" swipe3 DOWN closes cover")
		point=gun.get_reload_grab_point();sample(point,1);sample(point+Vector3(0,0,.115),1)
		check(gun.reload_state=="ready" and gun.ammo==60 and provider.count==0,side+" swipe4 BACK charges with no extra lift, extraction or return")
		gun.ammo=1;gun.seated=1;gun.cooldown=0;gun._requires_trigger_release=false;actor._grabs[gun.left_hand]=gun.left_hand.global_position
		trackers[gun.right_hand].set_input("trigger",1.0);gun._poll_vr();trackers[gun.right_hand].set_input("trigger",0.0)
		check(gun.ammo==0 and gun.reload_state=="box_removed" and actor._grabs.has(gun.left_hand),side+" exhausted M60 offers reload automatically while preserving offhand wall anchor")
		actor._grabs.clear();gun.shutdown();gun.free();provider.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await create_timer(.2).timeout
	print("M60_SWIPES_048 checks=",checks," failures=",failures," actual_synthetic_tracking=true headset_tested=false")
	quit(failures)
