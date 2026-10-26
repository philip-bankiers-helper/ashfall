extends SceneTree
class M10 extends "res://scripts/auto_shotgun.gd":
	func _vr_active()->bool:return true
class DT11 extends "res://scripts/dt11.gd":
	func _vr_active()->bool:return true
class Matadors extends "res://scripts/dual_matadors.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var count:=100
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,n:int)->int:
		var taken:=mini(count,n);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,n:int)->int:count+=n;return n
var checks:=0
var failures:=0
var actor
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._poll_vr()
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="shotgun048_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.left_hand_reserved=false;actor._grabs.clear()
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
		actor.update_hand_input_rearm(.2)
		var gun:=M10.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._process(0)
		var bank:=Reserve.new();root.add_child(bank);gun.ammo_provider=bank;gun.ammo_slot=0
		check(gun.ammo==6 and gun.magazine_size==6,side+" M10 holds exactly six")
		trackers[gun.right_hand].set_input("trigger",1.0);gun._requires_trigger_release=false
		for i in 6:gun.cooldown=0;gun._poll_vr()
		check(gun.ammo==0 and gun.reload_state=="needs_mag",side+" M10 sustained trigger fires all six automatically")
		trackers[gun.right_hand].set_input("trigger",0.0)
		var offer:Vector3=gun.get_reload_grab_point();sample(gun,offer,0);sample(gun,offer,1);sample(gun,offer+Vector3.DOWN*.16,1)
		check(gun.reload_state=="needs_mag" and bank.count==100,side+" M10 wrong load direction rejected")
		sample(gun,offer,0);sample(gun,offer,1);sample(gun,offer+Vector3.UP*.15,1)
		check(gun.reload_state=="needs_rack" and gun.get_loaded_rounds()==6 and bank.count==94,side+" M10 UP loads all six in one stroke")
		var handle:Vector3=gun.get_reload_grab_point();sample(gun,handle,1);sample(gun,handle+Vector3.FORWARD*.10,1)
		check(gun.reload_state=="needs_rack",side+" M10 forward charge rejected")
		sample(gun,handle+Vector3.BACK*.10,1)
		check(gun.reload_state=="ready" and gun.ammo==6 and bank.count==94,side+" M10 BACK charges without an extra release or forward return")
		gun.shutdown();gun.free();bank.free();actor.left_hand_reserved=false
		var dt:=DT11.new();root.add_child(dt);dt.setup(actor,false);dt.set_process(false);dt.set_physics_process(false);dt._process(0)
		bank=Reserve.new();root.add_child(bank);dt.ammo_provider=bank;dt.ammo_slot=0
		for i in 2:dt.cooldown=0;dt._semi_release=true;dt.fire()
		check(dt.ammo==0 and dt.action.state=="open_empty" and is_equal_approx(dt.hinge.rotation.x,-.72),side+" DT11 final shot automatically breaks barrels open before any offhand stroke")
		var start:Vector3=dt.get_reload_grab_point();sample(dt,start,0);sample(dt,start,1);sample(dt,start+Vector3.UP*.10,1)
		check(dt.action.state=="open_empty" and bank.count==100,side+" DT11 upward first stroke cannot load or close empty barrels")
		sample(dt,start+Vector3.DOWN*.08,1)
		check(dt.action.state=="open_loaded" and dt.get_loaded_rounds()==2 and bank.count==98,side+" DT11 DOWN inserts two shells into already open barrels")
		sample(dt,start+Vector3.UP*.02,1)
		check(dt.action.state=="ready" and dt.ammo==2 and bank.count==98,side+" DT11 UP closes in second stroke with continuous grip")
		var total:int=dt.ammo+bank.count;dt.desktop_reload_step();dt.desktop_reload_step()
		check(dt.action.state=="ready" and dt.ammo+bank.count==total,side+" DT11 tactical two-step reload conserves live shells")
		for i in 2:dt.cooldown=0;dt._semi_release=true;dt.fire()
		bank.count=1;dt._swipe_previous=true;dt._swipe_contact=false
		start=dt.get_reload_grab_point();sample(dt,start,1);sample(dt,start+Vector3.DOWN*.08,1)
		check(dt.action.state=="open_loaded" and dt.get_loaded_rounds()==1 and bank.count==0,side+" DT11 held support grip can start DOWN insert without an extra release and use one remaining shell")
		dt.suspend_for_selection();check(dt.action.state=="open_loaded" and dt.get_loaded_rounds()==1,side+" DT11 loaded-open shells survive selection without refund or duplication")
		dt.rack_bolt();check(dt.ammo==1 and dt.action.state=="ready",side+" DT11 single shell closes and remains usable")
		dt.shutdown();dt.free();bank.free();actor.left_hand_reserved=false
		var pair:=Matadors.new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
		bank=Reserve.new();root.add_child(bank);pair.ammo_provider=bank;pair.ammo_slot=0;pair.update_ammo_display()
		check(pair.guns[0].ammo==8 and pair.guns[1].ammo==8 and pair.magazine_size==16,side+" Matadors hold eight each")
		for index in 2:
			var child=pair.guns[index];child.ammo=0;child.eject_magazine();child._reset_flick()
			for i in 4:child.flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
			var other:int=pair.guns[1-index].ammo
			child.flick_sample(Vector3.UP*.15,Vector3.FORWARD,.1,true,false)
			check(child.ammo==8 and pair.guns[1-index].ammo==other,side+" independent Matador up flick hand%d"%index)
		pair.shutdown();pair.free();bank.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await create_timer(.2).timeout
	print("SHOTGUNS_048 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)
