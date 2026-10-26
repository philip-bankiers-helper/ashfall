extends SceneTree
class VRPistol extends "res://scripts/pistol.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	for side in ["right","left"]:
		var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.dominant_hand=side
		actor.set_process(false);actor.set_physics_process(false)
		var trackers:Dictionary={}
		for hand in [actor.left_hand,actor.right_hand]:
			var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="pistol042_"+str(hand.get_instance_id())
			XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
			tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
			tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
		await process_frame
		actor.update_hand_input_rearm(.1)
		var gun:=VRPistol.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		gun.global_transform=gun.corrected_grip_transform(gun.right_hand.global_transform);gun._poll_vr()
		var hand:XRController3D=gun.left_hand;var t:XRControllerTracker=trackers[hand]
		var raw_dominant:Transform3D=gun.right_hand.global_transform
		var camera:Transform3D=actor.get_view_camera().global_transform
		var label:String=side+" "
		check(hand==actor.get_support_hand() and gun.right_hand==actor.get_weapon_hand(),label+" mirrored roles")
		var initial_ammo:=gun.ammo
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]:
			t.set_input("grip",0.0);gun._update_support(0)
			hand.global_position=gun.reload_world_point(gun.PISTOL_SUPPORT_POINT+axis*.26);t.set_input("grip",1.0);gun._update_support(0)
			check(not gun.supported,label+" cannot acquire beyond25cm "+str(axis))
			hand.global_position=gun.reload_world_point(gun.PISTOL_SUPPORT_POINT+axis*.24);gun._update_support(.1)
			check(gun.supported,label+" acquire24cm "+str(axis))
			check(hand.global_position.is_equal_approx(gun.to_global(gun.PISTOL_SUPPORT_POINT+axis*.24)),label+" raw support pose unchanged")
			var glove:=hand.get_node("ArticulatedGlove") as Node3D
			check(glove.global_position.is_equal_approx(gun.model.to_global(gun.PISTOL_SUPPORT_POINT)),label+" glove cups pistol grip")
			hand.global_position=gun.reload_world_point(gun.PISTOL_SUPPORT_POINT+axis*.44);gun._update_support(.1);check(gun.supported,label+" retain44cm")
			hand.global_position=gun.reload_world_point(gun.PISTOL_SUPPORT_POINT+axis*.46);gun._update_support(.1);check(not gun.supported,label+" release46cm")
			hand.global_position=gun.reload_world_point(gun.PISTOL_SUPPORT_POINT);gun._update_support(.1);check(gun.supported,label+" reacquire near grip")
			t.set_input("grip",0.0);gun._update_support(.1);check(not gun.supported,label+" deliberate release")
		check(gun.ammo==initial_ammo,label+" support gestures cannot grant/consume ammunition")
		check(gun.right_hand.global_transform.is_equal_approx(raw_dominant) and actor.get_view_camera().global_transform.is_equal_approx(camera),label+" camera and firing tracker unchanged")
		hand.global_position=gun.reload_world_point(gun.PISTOL_SUPPORT_POINT);t.set_input("grip",1.0);gun._update_support(.1)
		gun._kick_recoil(.052,deg_to_rad(5.5));var supported_pitch:=gun.recoil_pitch
		gun.recoil_pitch=0;gun.recoil=0;gun.recoil_yaw=0;gun.recoil_pattern_index=0;t.set_input("grip",0.0);gun._update_support(.1)
		gun._kick_recoil(.052,deg_to_rad(5.5))
		check(is_equal_approx(supported_pitch/gun.recoil_pitch,.38),label+" real supported .38 versus onehand1 recoil")
		t.set_input("grip",1.0);gun._update_support(.1)
		var anchor:=hand.global_position;actor._grabs[hand]=anchor
		gun._update_support(.1)
		check(not gun.supported and actor._grabs.has(hand) and actor._grabs[hand]==anchor and not actor.left_hand_reserved,label+" wall owns hand and unchanged anchor")
		actor._grabs.clear();t.set_input("grip",0.0);gun._poll_vr();gun._update_support(.1)
		t.set_input("grip",1.0);gun._update_support(.1);check(gun.supported,label+" fresh grip after wall release")
		gun.eject_magazine();gun._update_support(.1)
		check(not gun.supported and gun.reload_state=="needs_mag",label+" reload releases support")
		gun.reset_weapon();t.set_input("grip",0.0);gun._poll_vr();gun._update_support(.1)
		gun.grip_toggle=true;t.set_input("grip",1.0);gun._update_support(.1);check(gun.supported,label+" toggle acquires")
		t.set_input("grip",0.0);gun._update_support(.1);check(gun.supported,label+" toggle retains on button release")
		t.set_input("grip",1.0);gun._update_support(.1);check(not gun.supported,label+" second toggle releases")
		t.set_input("grip",0.0);gun._update_support(.1);t.set_input("grip",1.0);gun._update_support(.1)
		actor.input_enabled=false;gun._update_support(.1)
		check(not gun.supported and gun._resume_grip_release,label+" input loss detaches and requires neutral")
		actor.input_enabled=true;gun._update_support(.1);check(not gun.supported,label+" held input cannot reconnect after loss")
		t.set_input("grip",0.0);gun._poll_vr();gun._update_support(.1);t.set_input("grip",1.0);gun._update_support(.1)
		check(gun.supported,label+" fresh neutral-rearmed input reconnects")
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_NONE)
		gun._update_support(.1)
		check(not gun.supported and gun._resume_grip_release,label+" invalid tracked pose detaches support")
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		gun._update_support(.1);check(not gun.supported,label+" tracking restore cannot reuse held grip")
		t.set_input("grip",0.0);gun._poll_vr();gun._update_support(.1);t.set_input("grip",1.0);gun._update_support(.1)
		check(gun.supported,label+" neutral after tracking restore permits fresh grip")
		gun.shutdown();await create_timer(.15).timeout;gun.free()
		for tracker in trackers.values():XRServer.remove_tracker(tracker)
		actor.free();await process_frame
	print("PISTOL_SUPPORT_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)

