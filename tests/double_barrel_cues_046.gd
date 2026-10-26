extends SceneTree
class Double extends "res://scripts/shotgun.gd":
	var lost:=false
	func _vr_active()->bool:return true
	func _hand_input_ready(hand:XRController3D)->bool:return not lost and super._hand_input_ready(hand)
class Reserve extends Node:
	var remaining:=4
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":remaining}
	func consume_weapon_reserve(_slot:int,count:int)->int:
		var taken:=mini(count,remaining);remaining-=taken;return taken
	func refund_weapon_reserve(_slot:int,count:int)->int:remaining+=count;return count
var gun
var actor
var reserve
var trackers:Dictionary={}
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._process(0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	reserve=Reserve.new();root.add_child(reserve)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="cinder046_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
		actor.update_hand_input_rearm(.1)
		gun=Double.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun.ammo_provider=reserve;reserve.remaining=4;gun._process(0)
		var raw:Transform3D=gun.right_hand.global_transform
		check(gun.open_contact_cue.visible and not gun.chamber_contact_cue.visible and not gun.close_contact_cue.visible,side+" closed gun exposes only local latch contact")
		check(gun.get_open_grip_point().distance_to(gun.to_local(gun.open_contact_cue.global_position))<.00001,side+" visible latch and actual interaction target coincide")
		var latch:Vector3=gun.get_open_grip_point();sample(latch,0);sample(latch,1);sample(latch+Vector3(0,-.06,0),1);gun._process(.2)
		check(gun.action.state=="open_empty" and gun.hinge.rotation.x<-.6,side+" actual tracked lower gesture reveals moving chambers")
		check(not gun.open_contact_cue.visible and gun.chamber_contact_cue.visible and not gun.close_contact_cue.visible,side+" opening transitions cues to paired chamber seating")
		for i in range(2):
			check(gun.chamber_contact_cue.get_child(i).global_position.distance_to(gun.chamber_markers[i].global_position)<.00001,side+" ghost follows moving chamber %d"%i)
			check(gun.chamber_contact_cue.get_child(i).get_child(0).global_basis.is_equal_approx(gun.chamber_markers[i].global_basis*Basis(Vector3.RIGHT,PI/2)),side+" ghost ring rotates with actual chamber mouth %d"%i)
		check(not gun.insert_guide.visible and not gun.latch_guide.visible,side+" obsolete fixed arrows replaced")
		var offer:Vector3=gun.get_shell_offer_point();sample(offer,0);sample(offer,1)
		check(gun.action.state=="holding_shells" and gun.shell_pair.visible,side+" fresh tracked shell pair acquisition")
		sample(gun.get_chamber_insert_point(),1)
		check(gun.action.state=="open_loaded" and gun.close_contact_cue.visible and not gun.chamber_contact_cue.visible,side+" actual insertion transitions to fore-end lift affordance")
		check(gun.close_contact_cue.global_position.distance_to(gun.fore_end_marker.global_position)<.00001,side+" visible grab outline matches actual moving fore-end")
		var close:Vector3=gun.get_close_grip_point();sample(close,0);sample(close,1);sample(close+Vector3(0,.045,0),1)
		check(gun.hinge.rotation.x>-.5 and gun.hinge.rotation.x<-.1,side+" actual close gesture visibly raises barrels partway")
		sample(close+Vector3(0,.10,0),1);gun._process(.2)
		check(gun.action.state=="ready" and gun.ammo==2 and gun.hinge.rotation.x==0,side+" lift completes mechanical close")
		check(gun.open_contact_cue.visible and not gun.close_contact_cue.visible,side+" closed loaded gun clears lift ghost")
		for interruption in ["menu","tracking","climb"]:
			if interruption=="menu":actor.input_enabled=false
			elif interruption=="tracking":gun.lost=true
			else:actor._grabs[gun.left_hand]=gun.left_hand.global_position
			gun._process(0)
			check(not gun.open_contact_cue.visible and not gun.chamber_contact_cue.visible and not gun.close_contact_cue.visible,side+" "+interruption+" hides actionable affordances")
			actor.input_enabled=true;gun.lost=false;actor._grabs.clear();gun._resume_grip_release=false;gun._process(0)
		gun.eject_magazine();gun._process(.2);reserve.remaining=1;gun._process(0)
		check(gun.chamber_contact_cue.get_child(0).visible and not gun.chamber_contact_cue.get_child(1).visible,side+" partial reserve shows only one chamber ghost")
		check(gun.shell_offer.get_child(0).visible and not gun.shell_offer.get_child(2).visible,side+" partial offer visible shell count matches reserve")
		reserve.remaining=0;gun._process(0);check(not gun.chamber_contact_cue.visible and not gun.shell_offer.visible,side+" no reserve no shell affordance")
		check(gun.find_children("*","Label3D",true,false).size()==1,side+" only numeric ammo text exists")
		check(gun.right_hand.global_transform.is_equal_approx(raw),side+" raw tracker unchanged")
		check(gun._affordance_finish.emission_energy_multiplier<=1 and gun.open_contact_cue.find_children("*","Light3D",true,false).is_empty(),side+" bounded emission with no dynamic light")
		gun.reset_weapon();check(not gun.chamber_contact_cue.visible and not gun.close_contact_cue.visible,side+" reset clears transient ghosts before process")
		gun.shutdown();await create_timer(.2).timeout;gun.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();reserve.free();await process_frame
	print("DOUBLE_BARREL_CUES_046 checks=",checks," failures=",failures," synthetic=true headset_tested=false");quit(failures)
