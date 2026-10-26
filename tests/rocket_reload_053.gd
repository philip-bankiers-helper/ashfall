extends SceneTree
class Reserve extends Node:
	var rounds:=2
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":rounds}
	func consume_weapon_reserve(_slot:int,wanted:int)->int:
		var amount:=mini(rounds,wanted);rounds-=amount;return amount
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_physics_process(false);actor.set_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="rocket053_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var reserve:=Reserve.new();root.add_child(reserve)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();rack.selected=27;rack.is_holstered=false;rack._apply_selection()
		for item in rack.weapons:item.set_process(false);item.set_physics_process(false)
		var gun=rack.weapons[27];reserve.rounds=2;gun.ammo_provider=reserve;gun.ammo_slot=27;gun.reset_weapon();rack.Arsenal.apply(gun,27);gun._process(0);gun.cooldown=0;gun._requires_trigger_release=false;gun.fire()
		var hand:XRController3D=gun.left_hand;var t=trackers[hand]
		check(gun.reload_state=="needs_mag",side+" fired rocket exposes reload stage")
		gun._process(0)
		check(gun.rocket_offer.visible and not gun.hip_source.visible and not gun.loose_magazine.visible,side+" actual offer is rocket at tube end, no bottom magazine")
		var offer:Transform3D=gun.get_offered_magazine_transform()
		check(offer.origin.distance_to(gun.rocket_offer.global_position)<.001 and gun.get_reload_zones()[0].position.distance_to(gun.to_local(offer.origin))<.001,side+" visual offer and arbitration share exact model-relative point")
		t.set_input("grip",0.0);gun._poll_vr();hand.global_position=offer.origin;t.set_input("grip",1.0);gun._poll_vr()
		check(gun.reload_state=="held_mag",side+" fresh support grip grabs rocket")
		hand.global_position=offer.origin+gun.model.global_basis*Vector3.UP*.20;gun._poll_vr()
		check(gun.reload_state=="held_mag" and gun.ammo==0,side+" upward magazine-like stroke cannot load rocket")
		hand.global_position=gun.model.to_global(gun.ROCKET_INSERT+Vector3.RIGHT*.3);gun._poll_vr()
		check(gun.reload_state=="held_mag",side+" off-axis push cannot load outside tube")
		hand.global_position=gun.model.to_global(gun.ROCKET_INSERT);gun._poll_vr()
		check(gun.reload_state=="ready" and gun.ammo==1 and reserve.rounds==1 and gun._requires_trigger_release,side+" continuous grip push+Z into end consumes exactly one reserve and rearms trigger safely")
		gun._process(0);check(not gun.rocket_offer.visible and not gun.rocket_held.visible and not gun.rocket_arrow.visible,side+" completed reload hides all load cues")
		t.set_input("grip",0.0);gun._poll_vr();gun.cooldown=0;gun._requires_trigger_release=false;gun.fire();hand.global_position=gun.get_offered_magazine_transform().origin;t.set_input("grip",1.0);gun._poll_vr()
		check(gun.reload_state=="held_mag" and reserve.rounds==1,side+" picking up rocket does not prematurely spend reserve")
		t.set_input("grip",0.0);gun._poll_vr();check(gun.reload_state=="needs_mag" and gun.ammo==0 and reserve.rounds==1,side+" releasing uninserted rocket cancels without ammo loss or duplication")
		t.set_input("grip",0.0)
	for t in trackers.values():XRServer.remove_tracker(t)
	rack.shutdown();rack.queue_free();actor.queue_free();reserve.queue_free();await create_timer(.2).timeout
	print("ROCKET_RELOAD_053 checks=",checks," failures=",failures," actual_poll=true headset_tested=false")
	quit(failures)
