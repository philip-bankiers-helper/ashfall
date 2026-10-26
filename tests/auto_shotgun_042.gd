extends SceneTree
class Auto extends "res://scripts/auto_shotgun.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var remaining:=2
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":remaining}
	func consume_weapon_reserve(_slot:int,count:int)->int:
		var taken:=mini(count,remaining);remaining-=taken;return taken
var checks:=0
var failures:=0
var gun
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip);gun._process(0)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var reserve:=Reserve.new();root.add_child(reserve)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="auto042_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
		actor.update_hand_input_rearm(.1)
		gun=Auto.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.ammo_provider=reserve;reserve.remaining=2;gun._process(0)
		var raw:Transform3D=gun.right_hand.global_transform
		trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0)
		check(gun.ammo==4 and gun.chambered and gun.tube_rounds==3,side+" automatic cycling chambers existing tube round")
		gun.cooldown=0;gun._process(0);check(gun.ammo==4,side+" held trigger cannot repeat")
		trackers[gun.right_hand].set_input("trigger",0.0);gun._process(0);trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0)
		check(gun.ammo==3,side+" fresh trigger fires next round")
		trackers[gun.right_hand].set_input("trigger",0.0)
		gun.chambered=false;gun.tube_rounds=0;gun.reload_state="needs_charge";gun._sync_rounds()
		sample(gun.AUTO_BOLT,0);sample(gun.AUTO_BOLT,1);sample(gun.AUTO_BOLT+Vector3(0,0,.1),1);sample(gun.AUTO_BOLT,1)
		check(not gun.chambered and gun.ammo==0,side+" empty charging cannot create ammo")
		sample(gun.SHELL_OFFER,0);sample(gun.SHELL_OFFER,1);sample(gun.SHELL_OFFER+Vector3(0,.02,0),1)
		check(gun.reload_state=="held_shell" and reserve.remaining==2,side+" jitter and acquisition do not consume reserve")
		sample(gun.SHELL_PORT,1)
		check(gun.tube_rounds==1 and not gun.chambered and reserve.remaining==1,side+" upward seat consumes one shell")
		sample(gun.AUTO_BOLT,0);sample(gun.AUTO_BOLT,1);sample(gun.AUTO_BOLT+Vector3(0,0,.10),1);sample(gun.AUTO_BOLT+Vector3(0,0,.10),0)
		check(not gun.chambered,side+" release at rear cancels chambering")
		sample(gun.AUTO_BOLT,0);sample(gun.AUTO_BOLT,1);sample(gun.AUTO_BOLT+Vector3(0,0,.10),1);sample(gun.AUTO_BOLT,1)
		check(gun.chambered and gun.tube_rounds==0 and gun.ammo==1,side+" complete tracked bolt pull return chambers one")
		sample(gun.SHELL_OFFER,0);sample(gun.SHELL_OFFER,1);sample(gun.SHELL_PORT,1)
		check(gun.ammo==2 and reserve.remaining==0,side+" partial finite reserve seats last shell")
		sample(gun.SHELL_OFFER,0);sample(gun.SHELL_OFFER,1);sample(gun.SHELL_PORT,1)
		check(gun.ammo==2 and not gun.shell_offer.visible,side+" zero reserve hides shell and grants none")
		gun.pump_sample(false,gun.PUMP_REST,true);gun.pump_sample(true,gun.PUMP_REST+Vector3(0,0,.2),true)
		check(gun.pump.position==gun.PUMP_REST,side+" fixed handguard never pumps")
		check(gun.right_hand.global_transform.is_equal_approx(raw),side+" raw controller untouched")
		check(gun.find_children("*","Label3D",true,false).size()==1,side+" ammo only text")
		gun.chambered=false;gun.tube_rounds=0;gun.reload_state="needs_charge";reserve.remaining=1
		gun.desktop_reload_step();check(gun.tube_rounds==1 and not gun.chambered,side+" desktop shell loading")
		gun.desktop_reload_step();check(gun.reload_state=="charge_return",side+" desktop rear bolt stage")
		gun.desktop_reload_step();check(gun.chambered and gun.ammo==1,side+" desktop forward bolt stage")
		gun.chambered=false;gun.tube_rounds=1;gun.reload_state="needs_charge"
		gun.bolt_sample(false,gun.AUTO_BOLT,true);gun.bolt_sample(true,gun.AUTO_BOLT,true);gun.bolt_sample(true,gun.AUTO_BOLT+Vector3(0,0,.1),true)
		gun.bolt_sample(true,gun.AUTO_BOLT,false);gun.bolt_sample(true,gun.AUTO_BOLT,true)
		check(not gun.chambered and not gun._bolt_contact,side+" invalid tracker aborts rear stroke and held reentry")
		actor._grabs[gun.left_hand]=gun.left_hand.global_position
		gun.bolt_sample(false,gun.AUTO_BOLT,true);gun.bolt_sample(true,gun.AUTO_BOLT,true);gun.bolt_sample(true,gun.AUTO_BOLT+Vector3(0,0,.1),true);gun.bolt_sample(true,gun.AUTO_BOLT,true)
		gun.grab_magazine()
		check(not gun.chambered and actor._grabs.has(gun.left_hand),side+" wall grip blocks reload without dropping anchor")
		actor._grabs.clear()
		gun.chambered=true;gun.tube_rounds=4;gun.reload_state="ready";reserve.remaining=2;gun._sync_rounds();gun.grab_magazine();gun.insert_magazine()
		check(gun.ammo==5 and reserve.remaining==2,side+" full tube cannot overfill or consume reserve")
		gun.shutdown();await create_timer(.2).timeout;gun.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	reserve.free();actor.free();await process_frame
	print("AUTO_SHOTGUN_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false");quit(failures)
