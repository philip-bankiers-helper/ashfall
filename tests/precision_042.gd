extends SceneTree
class Precision extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
class FiniteAmmo extends Node:
	var reserve:=3
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":reserve}
	func consume_weapon_reserve(_slot:int,requested:int)->int:
		var taken:=mini(reserve,requested);reserve-=taken;return taken
var checks:=0
var failures:=0
var actor
var gun
var trackers:Dictionary={}
var supply
var shots:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip)
	gun._process(0)
func trigger(value:float)->void:
	trackers[gun.right_hand].set_input("trigger",value);gun.cooldown=0;gun._process(0)
func cycle(prefix:String)->void:
	var start:Vector3=gun.get_bolt_grip_point()
	sample(start,0);sample(start,1)
	sample(start+Vector3(0,.025,0),1)
	check(gun.bolt_phase=="lift",prefix+" short lift cannot unlock")
	sample(start+Vector3(0,.070,0),1)
	check(gun.bolt_phase=="back",prefix+" lift unlocks")
	sample(start+Vector3(0,.070,.12),1)
	check(gun.bolt_phase=="forward" and not gun.spent_chamber,prefix+" back stroke ejects spent casing")
	sample(start+Vector3(0,.070,0),1)
	check(gun.bolt_phase=="lower" and not gun.chambered,prefix+" forward alone not fireable")
	sample(start,1)
	check(gun.bolt_phase=="locked" and gun.reload_state=="ready",prefix+" lower locks actual action")
	sample(start,0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	supply=FiniteAmmo.new();root.add_child(supply)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="precision042_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.climbing_left=false;actor.climbing_right=false;actor.head_obstructed=false;actor.input_enabled=true
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
		actor.update_hand_input_rearm(.1)
		gun=Precision.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		gun.ammo_provider=supply;gun.ammo_slot=0;supply.reserve=3
		gun.shot.connect(func(_o:Vector3,_d:Vector3,_damage:float):shots+=1)
		# The real inventory duplicates the model before an unselected gun processes.
		var clone:Node3D=gun.model.duplicate()
		root.add_child(clone)
		for obsolete in [gun.bolt,gun.firing_carrier,gun.guide,gun.insertion_arrow,gun.charging_arrow]:
			var copied:Node3D=clone.get_child(obsolete.get_index())
			check(not obsolete.visible and not copied.visible,side+" precision pre-process clone hides replaced hardware "+str(obsolete.get_index()))
		check(clone.get_child(gun.magazine.get_index()).visible,side+" precision pre-process clone retains legitimate five-round magazine")
		check(clone.get_child(gun.bolt_handle.get_index()).visible,side+" precision pre-process clone retains manual bolt")
		clone.free()
		gun._process(0)
		var prefix:String=side+" precision "
		var raw:Transform3D=gun.right_hand.global_transform
		check(gun.ammo==5 and gun.chambered,prefix+" five loaded initial rounds")
		check(gun.find_children("*","Label3D",true,false).size()==1,prefix+" only loaded/reserve text")
		check(gun.sight_front!=null and gun.sight_rear!=null,prefix+" usable zeroed sight references")
		sample(gun.FOREGRIP_POINT,0);sample(gun.FOREGRIP_POINT,1)
		check(gun.supported,prefix+" inherited actual foregrip support")
		sample(gun.FOREGRIP_POINT,0)
		var before:=shots
		trigger(1)
		check(gun.ammo==4 and not gun.chambered and shots==before+1,prefix+" actual trigger consumes one chamber")
		check(is_equal_approx(gun.recoil_pitch,deg_to_rad(55)),prefix+" deterministic inherited tenfold one-hand recoil")
		trigger(1)
		check(shots==before+1,prefix+" held trigger cannot repeat")
		trigger(0);trigger(1)
		check(shots==before+1,prefix+" uncycled bolt blocks fresh trigger")
		trigger(0)
		cycle(prefix)
		check(gun.chambered and gun.ammo==4 and supply.reserve==3,prefix+" cycling existing magazine never gifts or consumes reserve")
		gun._recover_recoil(1.0)
		sample(gun.FOREGRIP_POINT,0);sample(gun.FOREGRIP_POINT,1)
		trigger(1);trigger(0)
		check(gun.ammo==3,prefix+" second shot only after complete cycle")
		check(is_equal_approx(gun.recoil_pitch,deg_to_rad(5.5)*3.0*.38),prefix+" deterministic inherited supported recoil")
		# Wrong direction cannot skip lift. Tracking loss cancels partial contact.
		var grip_point:Vector3=gun.get_bolt_grip_point()
		sample(grip_point,0);sample(grip_point,1);sample(grip_point+Vector3(0,0,.20),1)
		check(gun.bolt_phase=="lift",prefix+" pulling locked bolt cannot skip lift")
		trackers[gun.left_hand].invalidate_pose("grip");gun._process(0)
		check(not gun._bolt_contact and not gun.chambered,prefix+" tracking loss cancels mechanical contact")
		trackers[gun.left_hand].set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		await process_frame
		actor.update_hand_input_rearm(.1)
		sample(grip_point+Vector3(0,.08,0),1)
		check(gun.bolt_phase=="lift",prefix+" held grip after tracking restore cannot complete gesture")
		sample(grip_point,0)
		actor._grabs[gun.left_hand]=Vector3.ZERO
		sample(grip_point,1);sample(grip_point+Vector3(0,.08,0),1)
		check(gun.bolt_phase=="lift" and actor._grabs.has(gun.left_hand),prefix+" bolt never steals wall anchor")
		gun.eject_magazine()
		check(gun.ammo==3 and actor._grabs.has(gun.left_hand),prefix+" reload while wall held blocked without clearing wall grip")
		actor._grabs.erase(gun.left_hand);sample(grip_point,0)
		gun.eject_magazine()
		check(gun.reload_state=="needs_mag" and gun.ammo==0,prefix+" tactical magazine removal discards old rounds")
		sample(gun.OFFER_POINT,0);sample(gun.OFFER_POINT,1)
		check(gun.reload_state=="held_mag" and supply.reserve==3,prefix+" offered magazine grab does not grant ammo")
		sample(gun.OFFER_POINT+Vector3(0,.02,0),1)
		check(gun.reload_state=="held_mag",prefix+" short insertion jitter cannot load")
		sample(gun.INSERT_POINT,1)
		check(gun.reload_state=="needs_bolt" and gun.ammo==3 and supply.reserve==0 and not gun.chambered,prefix+" physical magazine seat consumes finite partial reserve")
		cycle(prefix+" reloaded ")
		check(gun.chambered and gun.ammo==3,prefix+" finite magazine chambers after full cycle")
		# Dry fire and empty reload do not create free rounds.
		gun.eject_magazine();gun.grab_magazine();gun.insert_magazine()
		check(gun.reload_state=="needs_mag" and gun.ammo==0,prefix+" zero reserve cannot offer or load magazine")
		gun.reload_state="ready";gun.chambered=false;before=shots
		trigger(0);trigger(1)
		check(shots==before and gun.ammo==0,prefix+" dry trigger emits no damaging shot")
		# Desktop debug exposes each distinct step using the same state and finite supply.
		supply.reserve=2;gun.desktop_reload_step();gun.desktop_reload_step()
		check(gun.reload_state=="needs_bolt" and gun.ammo==2 and supply.reserve==0,prefix+" desktop finite seat matches VR")
		for phase in ["back","forward","lower","locked"]:
			gun.desktop_reload_step();check(gun.bolt_phase==phase,prefix+" desktop phase "+phase)
		check(gun.chambered and gun.ammo==2,prefix+" desktop complete finite action")
		check(gun.right_hand.global_transform.is_equal_approx(raw),prefix+" raw tracker never mutated")
		gun.shutdown();await create_timer(.2).timeout;gun.free();gun=null
	for t in trackers.values():XRServer.remove_tracker(t)
	trackers.clear();supply.free();actor.free();await process_frame
	print("PRECISION_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)

