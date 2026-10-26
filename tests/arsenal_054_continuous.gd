extends SceneTree
class Rifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
class RFB extends "res://scripts/catalog_firearm.gd":
	func _init()->void:profile_id="rfb"
	func _vr_active()->bool:return true
class Reserve extends Node:
	var count:=1000
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,wanted:int)->int:
		var taken:=mini(count,wanted);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,wanted:int)->int:
		var returned:=mini(wanted,9999-count);count+=returned;return returned
var checks:=0
var failures:=0
var trackers:Dictionary={}
var actor
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._poll_vr()
func stage(gun,rfb:bool)->void:
	gun.reset_weapon();gun.ammo=0;gun.eject_magazine()
	var offer:Vector3=Vector3(0,-.28,.14) if rfb else gun.OFFER_POINT
	var well:Vector3=Vector3(0,-.10,.14) if rfb else gun.INSERT_POINT
	sample(gun,offer,0);sample(gun,offer,1);sample(gun,well,1)
	check(gun.reload_state=="needs_rack" and gun._seated_rounds==gun.magazine_size,"fixture staged fully funded magazine; remaining reserve="+str(gun.reserve_rounds()))
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="continuous054_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;actor.left_hand_reserved=false
		for rfb in [false,true]:
			var gun=RFB.new() if rfb else Rifle.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			var bank:=Reserve.new();root.add_child(bank);gun.ammo_provider=bank;gun.ammo_slot=0
			var label:String=dominance+(" RFB" if rfb else " base magazine")
			var handle:=Vector3(.065,.055,-.10) if rfb else Vector3(-.05,.064,-.10)
			stage(gun,rfb);check(gun.reload_state=="needs_rack",label+" actual held UP inserts magazine")
			sample(gun,handle+Vector3.RIGHT,1);check(not gun._rack_grabbed and gun.reload_state=="needs_rack",label+" unrelated target cannot acquire handle")
			sample(gun,handle,1);check(gun._rack_grabbed and gun.reload_state=="needs_rack",label+" continuous held grip acquires actual handle without autocharging")
			sample(gun,handle+Vector3.FORWARD*.12,1);check(gun.reload_state=="needs_rack",label+" wrong FORWARD stroke cannot charge")
			sample(gun,handle+Vector3.BACK*.11,1);check(gun.reload_state=="ready" and gun.ammo==gun.magazine_size and gun._requires_trigger_release,label+" BACK completes continuous reload and requires fresh trigger")
			stage(gun,rfb);sample(gun,handle,0);sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="ready" and gun.ammo==gun.magazine_size,label+" release/re-grab alternative stays usable")
			stage(gun,rfb);actor._grabs[gun.left_hand]=gun.left_hand.global_position
			sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="needs_rack" and not gun._rack_grabbed and actor._grabs.has(gun.left_hand),label+" existing wall anchor prevents handle capture")
			actor._grabs.clear();sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="needs_rack",label+" held grip after reserved hand requires neutral")
			sample(gun,handle,0);sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="ready",label+" neutral rearm restores reload after wall release")
			stage(gun,rfb);actor.input_enabled=false;sample(gun,handle,1);actor.input_enabled=true
			sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="needs_rack",label+" menu resume cannot replay held grip")
			sample(gun,handle,0);sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="ready",label+" neutral rearm restores reload after menu")
			stage(gun,rfb);trackers[gun.left_hand].invalidate_pose("grip");sample(gun,handle,1)
			trackers[gun.left_hand].set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
			sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="needs_rack" and not gun._rack_grabbed,label+" tracking return cannot replay held grip")
			sample(gun,handle,0);sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="ready",label+" neutral rearm restores reload after tracking loss")
			stage(gun,rfb)
			actor.objective_grip_provider=func()->Array:return [{"id":"held_control","hand":gun.left_hand,"position":Vector3(2,1,0)}]
			gun.left_hand.global_position=Vector3(2,1,0);trackers[gun.left_hand].set_input("grip",0.0);actor._objective_grip_frame=-1;actor.update_objective_grips();trackers[gun.left_hand].set_input("grip",1.0);actor._objective_grip_frame=-1;actor.update_objective_grips()
			check(actor.is_hand_grip_reserved(gun.left_hand),label+" fixture actually acquires objective before approaching handle")
			sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.11,1)
			check(gun.reload_state=="needs_rack" and actor.is_hand_grip_reserved(gun.left_hand),label+" existing objective grip remains owned")
			trackers[gun.left_hand].set_input("grip",0.0);actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
			gun.shutdown();gun.free();bank.free();actor.left_hand_reserved=false
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();await create_timer(.2).timeout
	print("ARSENAL_054_CONTINUOUS checks=",checks," failures=",failures," actual_polling=true reference_button_parity=false")
	quit(failures)
