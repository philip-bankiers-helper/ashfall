extends SceneTree
var checks:=0
var failures:=0
var actor
var rack
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(hand,grip:float)->void:
	trackers[hand].set_input("grip",grip);actor._objective_grip_frame=-1;actor.update_objective_grips()
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="reload051_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands()
		for index in rack.ACTIVE_WEAPON_INDICES:
			if index in [11,12,14,15,16,26,28]:continue
			rack.selected=index;rack.is_holstered=false;rack.is_selecting=false;rack._apply_selection()
			for child in rack.weapons:child.set_process(false);child.set_physics_process(false)
			var gun=rack.weapons[index];var hand:XRController3D=gun.left_hand
			actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset();trackers[hand].set_input("grip",0.0);actor.update_hand_input_rearm(.2)
			gun.reset_weapon();rack.Arsenal.apply(gun,index);gun.eject_magazine()
			if index==5:
				gun.bolt_sample(gun.get_bolt_grip_point(),false,true);gun.bolt_sample(gun.get_bolt_grip_point(),true,true);gun.bolt_sample(gun.get_bolt_grip_point()+Vector3.BACK*.12,true,true)
			if index==27:gun.cooldown=0;gun._requires_trigger_release=false;gun.fire()
			var zones:Array=gun.get_reload_zones();check(not zones.is_empty(),side+" R01 active reload exposes actual target "+str(index))
			if zones.is_empty():continue
			var zone:Dictionary=zones[0];var beside:Vector3=zone.position+Vector3.UP*(float(zone.radius)+.035)
			check(gun._in_reload_reach(beside,zone.position,zone.radius),side+" R0135mm beyond prior vertical radius now accepted "+str(index))
			check(not gun._in_reload_reach(zone.position+Vector3.RIGHT*.50,zone.position,zone.radius),side+" R01 distant unrelated part stays outside bounded volume "+str(index))
			hand.global_position=gun.reload_world_point(beside)
			check(rack.reload_claims_hand(hand),side+" R02 near reload part owns fresh-grip priority "+str(index))
			actor.objective_grip_provider=func()->Array:return [{"id":"nearby-control","position":hand.global_position,"hand":hand}]
			sample(hand,0);sample(hand,1)
			check(not actor.is_hand_grip_reserved(hand),side+" R02 nearby objective cannot steal expanded reload target "+str(index))
			actor.objective_grip_provider=func()->Array:return [{"id":"inventory_pickup:99","position":hand.global_position,"hand":hand,"reach":2.0}]
			sample(hand,0);sample(hand,1)
			check(not actor.is_hand_grip_reserved(hand),side+" R02 nearby ground pickup cannot steal reload grab "+str(index))
			hand.global_position=Vector3(2,1,0);actor.objective_grip_provider=func()->Array:return [{"id":"existing-control","position":hand.global_position,"hand":hand}]
			sample(hand,0);sample(hand,1);check(actor.is_hand_grip_reserved(hand),side+" R02 unrelated control remains available outside reload volume "+str(index))
			hand.global_position=gun.reload_world_point(beside)
			check(not rack.reload_claims_hand(hand),side+" R02 moving held objective into reload volume preserves its ownership "+str(index))
			var state:String=gun.reload_state;gun._poll_vr()
			check(gun.reload_state==state and actor.is_hand_grip_reserved(hand),side+" R03 polling does not steal held objective or advance reload "+str(index))
			sample(hand,0);actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
	# A magazine can be acquired at.55 before objective arbitration's.65 edge.
	# Raising grip pressure while carrying it must not let a nearby control steal it.
	rack.selected=0;rack._apply_selection();var rifle=rack.weapons[0];rifle.set_process(false);rifle.reset_weapon();rifle.eject_magazine()
	var load_hand:XRController3D=rifle.left_hand;load_hand.global_position=rifle.reload_world_point(rifle.OFFER_POINT)
	actor.objective_grip_provider=Callable();sample(load_hand,0);rifle._poll_vr();sample(load_hand,.60);rifle._poll_vr()
	check(rifle.reload_state=="held_mag","R03 actual.60 grip acquires magazine before objective threshold")
	load_hand.global_position=Vector3(2,1,0);actor.objective_grip_provider=func()->Array:return [{"id":"pressure-change-control","position":load_hand.global_position,"hand":load_hand}]
	sample(load_hand,.8);rifle._poll_vr()
	check(rifle.reload_state=="held_mag" and not actor.is_hand_grip_reserved(load_hand),"R02 held reload part keeps ownership outside target as pressure crosses objective threshold")
	sample(load_hand,0);rifle._poll_vr();sample(load_hand,1)
	check(actor.is_hand_grip_reserved(load_hand),"R02 release ends reload ownership and enables unrelated control")
	#057: the physical poller requires BACK before accepting the magazine,
	# then retain continuous grip through insertion and the sole BACK stroke.
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();rack.selected=5;rack._apply_selection()
		for item in rack.weapons:item.set_process(false);item.set_physics_process(false)
		var awp=rack.weapons[5];awp.reset_weapon();rack.Arsenal.apply(awp,5);awp.cooldown=0
		actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
		for hand in [awp.left_hand,awp.right_hand]:trackers[hand].set_input("grip",0.0);trackers[hand].set_input("trigger",0.0)
		actor.update_hand_input_rearm(.2);awp._poll_vr();trackers[awp.right_hand].set_input("trigger",1.0);awp._poll_vr();trackers[awp.right_hand].set_input("trigger",0.0);awp._poll_vr()
		check(awp.reload_state=="needs_bolt",side+" actual AWP trigger produces spent chamber")
		awp.left_hand.global_position=awp.reload_world_point(awp.OFFER_POINT);sample(awp.left_hand,1);awp._poll_vr()
		check(awp.reload_state=="needs_bolt",side+" magazine grip cannot skip first AWP BACK")
		sample(awp.left_hand,0);awp._poll_vr();awp.eject_magazine()
		awp.left_hand.global_position=awp.reload_world_point(awp.get_bolt_grip_point());sample(awp.left_hand,1);awp._poll_vr();awp.left_hand.global_position+=awp.global_basis*Vector3.BACK*.12;awp._poll_vr()
		check(awp.reload_state=="needs_mag",side+" actual first BACK ejects AWP magazine")
		sample(awp.left_hand,0);awp._poll_vr();awp.left_hand.global_position=awp.reload_world_point(awp.OFFER_POINT);sample(awp.left_hand,1);awp._poll_vr()
		check(awp.reload_state=="held_mag",side+" fresh grip acquires magazine after first BACK")
		awp.left_hand.global_position=awp.reload_world_point(awp.INSERT_POINT);awp._poll_vr()
		check(awp.reload_state=="needs_bolt",side+" actual held-grip UP inserts magazine directly")
		awp.left_hand.global_position=awp.reload_world_point(awp.get_bolt_grip_point());awp._poll_vr();awp.left_hand.global_position+=awp.global_basis*Vector3.BACK*.12;awp._poll_vr()
		check(awp.reload_state=="ready" and awp.chambered,side+" actual continuous grip single BACK completes loaded AWP")
		sample(awp.left_hand,0)
	for t in trackers.values():XRServer.remove_tracker(t)
	trackers.clear();rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("RELOAD_GRABS_057_CARRY checks=",checks," failures=",failures," synthetic=true native_rendered=false headset_tested=false")
	quit(failures)
