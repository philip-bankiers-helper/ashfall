extends SceneTree
class Gun extends "res://scripts/belt_lmg.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var amount:=7
	func refund_weapon_reserve(_slot:int,n:int)->int:amount+=n;return n
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":amount}
	func consume_weapon_reserve(_slot:int,count:int)->int:
		var n:=mini(count,amount);amount-=n;return n
var failures:=0
var checks:=0
var gun
var actor
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip)
	gun._process(0)
func gesture(point:Vector3,delta:Vector3)->void:
	sample(point,0);sample(point,1);sample(point+delta,1);sample(point+delta,0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="lmg042_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
		actor.update_hand_input_rearm(.1)
		gun=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		check(not gun.offered_box.visible and not gun.held_box.visible,side+" offers hidden immediately before processing")
		for part in [gun.magazine,gun.loose_magazine,gun.hip_source,gun.guide,gun.insertion_arrow,gun.charging_arrow,gun.bolt,gun.firing_carrier]:
			check(not part.visible,side+" obsolete base hardware hidden before processing "+str(part.name))
		var clone:Node3D=gun.model.duplicate()
		root.add_child(clone)
		var offer_copy:Node3D=clone.get_child(gun.offered_box.get_index())
		check(not offer_copy.visible,side+" ground model clone inherits hidden belt offer")
		for part in [gun.magazine,gun.guide,gun.insertion_arrow,gun.charging_arrow,gun.bolt,gun.firing_carrier]:
			check(not clone.get_child(part.get_index()).visible,side+" ground clone has hidden base hardware "+str(part.name))
		clone.free();gun._process(0)
		var provider:=Reserve.new();root.add_child(provider);gun.ammo_provider=provider;gun.ammo_slot=0
		var raw:Transform3D=gun.right_hand.global_transform
		gun.insert_magazine();gun.rack_bolt();check(gun.ammo==60,side+" wrong order rejected")
		gun.ammo=0;gun.seated=0;gun.eject_magazine();gun._process(0);check(gun.reload_state=="box_removed",side+" mapped intent automatically opens and removes old empty box")
		gun.eject_magazine();check(gun.reload_state=="box_removed" and gun.ammo==0 and provider.amount==7,side+" repeated intent cannot refund old box twice")
		sample(gun.get_reload_grab_point(),0);sample(gun.get_reload_grab_point(),1);check(gun.reload_state=="holding_box",side+" tracked belt box acquired")
		# Grab must stay held during upward seating.
		sample(gun.get_box_seat(),1);sample(gun.get_box_seat(),0)
		check(gun.reload_state=="needs_feed" and gun.seated==7 and provider.amount==0,side+" partial finite belt seats exactly seven")
		gun.rack_bolt();check(gun.ammo==0,side+" unfed belt cannot charge")
		gesture(gun.get_reload_grab_point(),Vector3(.085*gun.feed_direction(),0,0));check(gun.reload_state=="box_seated",side+" actual mirrored belt-across step precedes cover close")
		gesture(gun.COVER_POINT,Vector3(0,-.08,0));check(gun.reload_state=="needs_charge",side+" tracked cover close")
		gesture(gun.get_handle_point(),Vector3(0,0,.11));check(gun.reload_state=="ready" and gun.ammo==7,side+" tracked charging handle completes")
		gun.cooldown=0;gun._requires_trigger_release=false;trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0);trackers[gun.right_hand].set_input("trigger",0.0)
		check(gun.ammo==6 and gun.seated==6,side+" shot consumes actual belt")
		check(gun.right_hand.global_transform.is_equal_approx(raw),side+" no raw head or hand kick")
		check(gun.find_children("*","Label3D",true,false).size()==1,side+" ammo only text")
		gun.open_cover();provider.amount=0;gun.grab_magazine();check(gun.reload_state=="box_removed",side+" empty reserve no phantom box")
		gun.reload_sample(gun.COVER_POINT,true,false);check(not gun.contact and gun.previous,side+" tracking loss cancels contact")
		actor._grabs[gun.left_hand]=Vector3.ZERO;gun.reload_state="ready";gun.open_cover();check(gun.reload_state=="ready",side+" climb blocks reload")
		actor._grabs.clear()
		provider.amount=3;gun.reload_state="box_removed";gun.grab_magazine();gun._suspend_left_gestures()
		check(provider.amount==3 and gun.reload_state=="box_removed",side+" interruption loses no offered reserve")
		gun.reload_state="ready"
		for step in range(5):gun.desktop_reload_step()
		check(gun.reload_state=="ready" and gun.ammo==3 and provider.amount==0,side+" desktop init plus same four loading motions finite partial")
		gun.ammo=1;gun.seated=1;gun.cooldown=0;gun._requires_trigger_release=false;gun.fire()
		check(gun.ammo==0 and gun.reload_state=="box_removed",side+" empty belt safely enters four-motion loading path")
		check(gun.cover.name=="HingedFeedCover" and gun.belt.get_child_count()==13,side+" original linked belt and feed cover geometry")
		gun.shutdown();await create_timer(.15).timeout;gun.free();provider.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await process_frame
	print("LMG_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)







