extends SceneTree
class TrackedGrenade extends "res://scripts/explosive_weapon.gd":
	func _vr_active()->bool:return true # CPU seam; no XR runtime is initialized.
var checks:=0
var failures:=0
var actor
var trackers:Dictionary={}
var events:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="grenade058_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for kind in ["frag","zone"]:
			var gun:=TrackedGrenade.new();gun.profile_id=kind;root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			gun.explosive_launch.connect(func(spec:Dictionary)->void:events.append(spec));var hand=gun.right_hand;var t=trackers[hand];t.set_input("trigger",0.0);gun._process(.016)
			check(gun.arc.visible and not gun.armed and gun.arc_mesh.get_surface_count()==1,side+" "+kind+" preview visible at rest before trigger")
			check(is_equal_approx(gun.ARC_HALF_WIDTH,.028*1.5),side+" "+kind+" trajectory cue width increases50percent without range scaling")
			var expected:Vector3=gun.prepared_velocity(gun.assisted_throw_velocity(Vector3.ZERO));var before:=events.size()
			t.set_input("trigger",1.0);gun._process(.016)
			check(events.size()==before+1 and gun.ammo==1 and events.back().kind==kind,side+" "+kind+" actual trigger press immediately emits one projectile")
			check(events.back().velocity.distance_to(expected)<.001,side+" "+kind+" preview and actual stationary launch use same assisted velocity")
			for i in 35:gun._process(.016)
			check(events.size()==before+1 and gun.ammo==1 and gun.arc.visible,side+" "+kind+" held trigger cannot repeat, preview remains for held next grenade")
			t.set_input("trigger",0.0);gun._process(.016)
			check(events.size()==before+1 and gun.ammo==1,side+" "+kind+" release rearms without throwing")
			t.set_input("trigger",1.0);gun._process(.016)
			check(events.size()==before+2 and gun.ammo==0 and not gun.arc.visible,side+" "+kind+" second fresh press spends last grenade and hides arc")
			gun.reset_weapon();gun.cooldown=0;t.set_input("trigger",0.0);gun._process(.016);gun.hide();gun._update_trajectory();check(not gun.arc.visible,side+" "+kind+" hidden/holstered grenade has no preview")
			gun.show();actor.head_obstructed=true;gun._update_trajectory();check(not gun.arc.visible,side+" "+kind+" head obstruction hides preview")
			actor.head_obstructed=false;before=events.size();t.invalidate_pose("grip");t.set_input("trigger",1.0);gun._process(.016)
			check(events.size()==before and gun.ammo==2 and not gun.arc.visible,side+" "+kind+" tracking loss blocks throw and stale preview")
			t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);gun._process(.016)
			check(events.size()==before and gun.ammo==2,side+" "+kind+" returning held trigger cannot manufacture throw")
			t.set_input("trigger",0.0);gun._process(.016);t.set_input("trigger",1.0);gun._process(.016)
			check(events.size()==before+1 and gun.ammo==1,side+" "+kind+" fresh press works after tracking recovery/release")
			t.set_input("trigger",0.0);gun.shutdown();gun.free();actor.left_hand_reserved=false
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await create_timer(.2).timeout
	print("GRENADE_058 checks=",checks," failures=",failures," actual_controller_polling=true native_rendered=false headset_tested=false");quit(failures)
