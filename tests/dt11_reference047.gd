extends SceneTree
class Double extends "res://scripts/shotgun.gd":
	func _vr_active()->bool:return true
var actor
var rack
var gun
var trackers:Dictionary={}
var checks:=0
var failures:=0
var shots:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._process(0)
func trigger(value:float)->void:
	trackers[gun.right_hand].set_input("trigger",value);gun.cooldown=0;gun._process(0)
func switches(label:String)->void:
	var state:String=gun.action.state;var loaded:int=gun.action.loaded
	var chambers:Array=gun.chamber_states.duplicate();var bank:Dictionary=rack.reserves.duplicate(true)
	check(rack.select_weapon(0),label+" switch away allowed")
	check(rack.select_inventory_weapon(1),label+" return allowed")
	for item in rack.weapons:item.set_process(false);item.set_physics_process(false)
	check(gun.action.state==state and gun.action.loaded==loaded and gun.chamber_states==chambers and rack.reserves==bank,label+" mechanical state and finite reserves unchanged")
	check(not gun._opening and not gun._closing and gun._requires_trigger_release,label+" stale contacts and trigger suspended")
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="dt11ref047_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var old=rack.weapons[1];old.shutdown();old.free()
	gun=Double.new();rack.add_child(gun);gun.setup(actor,false);gun.ammo_provider=rack;gun.ammo_slot=1;rack.weapons[1]=gun
	gun.pellet_shot.connect(func(_o,_d,_damage):shots+=1)
	for item in rack.weapons:item.set_process(false);item.set_physics_process(false)
	for side in ["right","left"]:
		actor.dominant_hand=side;gun.right_hand=actor.get_weapon_hand();gun.left_hand=actor.get_support_hand()
		for count in [2,1]:
			for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
			actor.update_hand_input_rearm(.1);rack.selected=1;rack.is_holstered=false;rack.is_selecting=false
			gun.reset_weapon();gun._resume_grip_release=false;gun._grip_previous=false;gun._eject_previous=false;rack.reserves.shells=count
			var prefix:String=side+" reserve%d "%count
			trigger(0);trigger(1);trigger(0);trigger(1);trigger(0)
			check(gun.ammo==0 and gun.action.state=="ready",prefix+" both shots empty closed action")
			gun.left_hand.global_position=gun.reload_world_point(Vector3(.7,-.5,.4));trackers[gun.left_hand].set_input("grip",0.0)
			trackers[gun.right_hand].set_input("primary",Vector2(0,-1));gun._process(.2)
			check(gun.action.state=="open_empty" and not gun._opening,prefix+" mapped open succeeds with offhand away and no mandatory latch")
			check(gun.hinge.rotation.x<-.6 and gun.shell_offer.visible,prefix+" reference74 open breech and cartridges offered above")
			check(gun.get_shell_offer_point().y-gun.get_chamber_insert_point().y>.10,prefix+" offered cartridges are actually above open chambers")
			var before:int=shots;trigger(0);trigger(1);check(shots==before,prefix+" open action cannot fire")
			trackers[gun.right_hand].set_input("primary",Vector2.ZERO);trigger(0)
			var offer:Vector3=gun.get_shell_offer_point();sample(offer,0);sample(offer,1)
			check(gun.action.state=="holding_shells" and rack.reserves.shells==count,prefix+" actual tracked pair grip does not grant ammo")
			sample(gun.get_chamber_insert_point(),1)
			check(gun.action.state=="open_loaded" and gun.action.loaded==count and rack.reserves.shells==0,prefix+" reference75 DOWN insertion seats exact finite count")
			check(gun.hinge.rotation.x<-.6 and gun.close_contact_cue.visible,prefix+" reference76 loaded barrels remain open")
			before=shots;trigger(1);check(shots==before,prefix+" loaded but open cannot fire")
			trigger(0);switches(prefix+" open loaded")
			var close:Vector3=gun.get_close_grip_point();sample(close,0);sample(close,1)
			check(gun._closing,prefix+" reference77 release then fresh grip takes actual fore-end")
			sample(close+Vector3(0,-.10,0),1)
			check(gun.action.state=="open_loaded",prefix+" wrong downward closing motion cannot close")
			sample(close+Vector3(0,.10,0),1);gun._process(.2)
			check(gun.action.state=="ready" and gun.ammo==count and absf(gun.hinge.rotation.x)<.001,prefix+" reference78 UP fore-end lift closes loaded barrels")
			before=shots;trigger(0);trigger(1);check(shots==before+1 and gun.ammo==count-1,prefix+" fresh shot fires only after closed")
			trigger(0);switches(prefix+" closed after firing")
			check(gun.right_hand==actor.get_weapon_hand() and gun.left_hand==actor.get_support_hand(),prefix+" mirrored physical hand mapping retained")
	rack.shutdown();await create_timer(.25).timeout;rack.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await process_frame
	print("DT11_REFERENCE047 checks=",checks," failures=",failures," synthetic=true source_motion_observed_by_root=true headset_tested=false");quit(failures)
