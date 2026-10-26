extends SceneTree
var checks:=0
var failures:=0
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	game.process_mode=Node.PROCESS_MODE_DISABLED;game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var actor=game.player;actor.xr_enabled=true;actor.tracking_available=true;actor.input_enabled=true;actor.global_position=Vector3(1000,2,1000)
	actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="m10_061_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		tracker.set_input("trigger",0.0);tracker.set_input("grip",0.0);tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	var rack=game.weapon;var gun=rack.weapons[9]
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.sprint_binding="left_grip";rack._refresh_hands();game.weapon_inventory.owned.assign([9]);rack.selected=9;rack.is_holstered=false;rack.is_selecting=false;rack._apply_selection();rack._draw_delay=0
		gun.reset_weapon();gun.ammo=3;rack.reserves.shells=40
		var tracker=trackers[gun.right_hand];tracker.set_input("primary_click",false);gun._poll_vr()
		tracker.set_input("primary_click",true);gun._poll_vr()
		check(gun.reload_state=="needs_mag" and gun.ammo==0,side+" actual Main M10 dispatch handles fresh dominant stick CLICK")
		check(rack.reserves.shells==43,side+" tactical click refunds three live shells once")
		gun._poll_vr();check(rack.reserves.shells==43,side+" held click does not repeat refund")
		gun.reset_weapon();tracker.set_input("primary_click",false);tracker.set_input("primary",Vector2.ZERO);gun._poll_vr();tracker.set_input("primary",Vector2(0,-1));gun._poll_vr()
		check(gun.reload_state=="needs_mag",side+" retained stick DOWN opens M10")
		tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false)
		gun.reset_weapon();gun._poll_vr();actor.input_enabled=false;tracker.set_input("primary_click",true);gun._poll_vr();actor.input_enabled=true;gun._poll_vr()
		check(gun.reload_state=="ready",side+" held menu/tracking resume click cannot reload")
		tracker.set_input("primary_click",false);gun._poll_vr();tracker.set_input("primary_click",true);gun._poll_vr()
		check(gun.reload_state=="needs_mag",side+" fresh post-resume click reloads")
		tracker.set_input("primary_click",false)
	actor.dominant_hand="left";actor.sprint_binding="left_stick_click";rack._refresh_hands();gun.reset_weapon();gun._poll_vr();trackers[gun.right_hand].set_input("primary_click",true);gun._poll_vr()
	check(gun.reload_state=="ready","physical left-stick sprint binding keeps exclusive click ownership")
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	await create_timer(.4).timeout;print("M10_RELOAD_061 checks=",checks," failures=",failures," actual_main_polling=true physical_acceptance=false");quit(failures)
