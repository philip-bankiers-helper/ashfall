extends SceneTree
class Rocket extends "res://scripts/explosive_weapon.gd":
	func _vr_active()->bool:return true
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
	var old=rack.weapons[27];old.shutdown();old.free()
	var rocket:=Rocket.new();rocket.profile_id="smaw";rack.add_child(rocket);rocket.setup(actor,false);rack.weapons[27]=rocket;rack._connect_weapon_events(rocket)
	var reserve:=Reserve.new();root.add_child(reserve)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();rack.selected=27;rack.is_holstered=false;rack._apply_selection()
		for item in rack.weapons:item.set_process(false);item.set_physics_process(false)
		var gun=rack.weapons[27];gun.ammo_provider=reserve;gun.ammo_slot=27
		check(absf(gun.ROCKET_GRIP.z-((.20-.839)*.5))<.000001,side+" primary grip centered on authored tube")
		check(gun.ROCKET_INSERT==Vector3(0,.045,-.96) and gun.ROCKET_MOUTH==Vector3(0,.045,-.83),side+" original insertion and mouth datums unchanged")
		# Includes generic reach padding (.055): actual rear boundary is .295,
		# not the advertised zone radius .18 plus center extension .06 alone.
		for rear in [.296,.294,.25,.03]:
			reserve.rounds=2;gun.reset_weapon();rack.Arsenal.apply(gun,27);gun._process(0);gun.cooldown=0;gun._requires_trigger_release=false;gun.fire()
			var hand:XRController3D=gun.left_hand;var t=trackers[hand]
			t.set_input("grip",0.0);gun._poll_vr()
			hand.global_position=gun.model.to_global(gun.ROCKET_OFFER)+gun.global_basis*Vector3.BACK*rear # metres, independent of visual size
			var old_reach:bool=gun._in_reload_reach(gun.to_local(hand.global_position),gun._rocket_local(gun.ROCKET_OFFER),.18)
			check(old_reach==(rear==.03),side+" probe original offer membership "+str(rear))
			t.set_input("grip",1.0);gun._poll_vr()
			if rear>.295:
				check(gun.reload_state=="needs_mag" and reserve.rounds==2,side+" just outside rear extension rejects grab")
			else:
				check(gun.reload_state=="held_mag" and reserve.rounds==2,side+" inside rear extension actual grip grabs "+str(rear))
				var grabbed:Vector3=gun.model.to_local(hand.global_position)
				check(gun._mag_grab_local.distance_to(grabbed)<.00001,side+" true grab datum retained")
				gun._poll_vr();check(gun.reload_state=="held_mag",side+" stationary grip cannot auto-load")
				hand.global_position=gun.model.to_global(grabbed+Vector3.BACK*.01);gun._poll_vr()
				check(gun.reload_state=="held_mag",side+" one centimeter push cannot load")
				if rear==.03:check(absf(gun.required_rocket_insertion_travel()-.14)<.00001,side+" original central14cm stroke retained")
				if rear==.294:check(gun.required_rocket_insertion_travel()*gun.visual_model_scale()>=.01999 and grabbed.z+gun.required_rocket_insertion_travel()<=gun.ROCKET_MOUTH.z+.08,side+" extreme rear pickup has deliberate finishable push after visual resize")
				# Upward and off-axis positions cannot bypass the original loading rule.
				hand.global_position=gun.model.to_global(gun.ROCKET_INSERT+Vector3.UP*.2);gun._poll_vr()
				check(gun.reload_state=="held_mag",side+" upward stroke rejected")
				hand.global_position=gun.model.to_global(Vector3(.141,.045,gun.ROCKET_MOUTH.z+.079));gun._poll_vr()
				check(gun.reload_state=="held_mag",side+" radial outside .14 rejected")
				hand.global_position=gun.model.to_global(Vector3(0,.045,gun.ROCKET_MOUTH.z+.081));gun._poll_vr()
				check(gun.reload_state=="held_mag",side+" outside mouth rejected despite enough travel")
				hand.global_position=gun.model.to_global(grabbed+Vector3.BACK*(gun.required_rocket_insertion_travel()-.001));gun._poll_vr()
				check(gun.reload_state=="held_mag",side+" just short of required gesture rejected")
				# Furthest permitted point inside mouth bound: any direct +Z stroke
				# from a reachable rear pickup must be able to complete by here.
				hand.global_position=gun.model.to_global(Vector3(0,.045,gun.ROCKET_MOUTH.z+.079));gun._poll_vr()
				check(gun.reload_state=="ready" and gun.ammo==1 and reserve.rounds==1,side+" accepted rear pickup can finish unchanged insertion "+str(rear))
			t.set_input("grip",0.0);gun._poll_vr()
	for t in trackers.values():XRServer.remove_tracker(t)
	rack.shutdown();rack.queue_free();actor.queue_free();reserve.queue_free();await create_timer(.2).timeout
	print("ROCKET_REACH_073 checks=",checks," failures=",failures," actual_poll=true headset_tested=false");quit(failures)
