extends SceneTree
class Revolver extends "res://scripts/revolver.gd":
	func _vr_active()->bool:return true
class Dual extends "res://scripts/dual_pistols.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var count:=100
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,n:int)->int:
		var taken:=mini(count,n);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,n:int)->int:
		var credited:=mini(n,9999-count);count+=credited;return credited
var checks:=0
var failures:=0
var actor
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip);gun._poll_vr()
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="reload048_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side;actor._grabs.clear();actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
		actor.update_hand_input_rearm(.2)
		var gun:=Revolver.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._process(0)
		var reserve:=Reserve.new();root.add_child(reserve);gun.ammo_provider=reserve;gun.ammo_slot=0
		check(gun.magazine_size==7 and gun.cartridges.size()==7,side+" seven authored visible rounds")
		for i in 7:
			gun.cooldown=0;gun._semi_armed=true;gun.fire()
			check(gun.ammo==6-i and gun.cartridges.filter(func(p):return p.visible).size()==6-i,side+" fired round immediately disappears %d"%i)
		check(gun.reload_state=="cylinder_open" and gun.cylinder.position.x*gun.mirror_point(Vector3.LEFT).x>0,side+" empty cylinder automatically opens toward free hand")
		var offer:Vector3=gun.get_reload_grab_point();sample(gun,offer,0);sample(gun,offer,1)
		sample(gun,offer+Vector3.UP*.13,1);check(gun.reload_state=="cylinder_open" and reserve.count==100,side+" upward first motion cannot load")
		sample(gun,offer,0);sample(gun,offer,1);sample(gun,offer+Vector3.FORWARD*.145,1)
		check(gun.reload_state=="cylinder_loaded" and gun.ammo==7 and reserve.count==93,side+" actual tracked FORWARD swipe inserts all seven once")
		check(gun.reload_arrow.basis.y.dot(Vector3.UP)>.999,side+" second arrow points UP")
		var seated:Vector3=offer+Vector3.FORWARD*.145
		sample(gun,seated+Vector3.RIGHT*.12,1);check(gun.reload_state=="cylinder_loaded",side+" rightward motion never closes")
		sample(gun,seated+Vector3.UP*.09,1);check(gun.reload_state=="ready" and reserve.count==93,side+" distinct UP swipe closes with continuous grip")
		gun._semi_armed=true;gun.cooldown=0;gun.fire();gun.eject_magazine()
		gun.insert_magazine();gun.rack_bolt();check(gun.ammo==7 and reserve.count==92,side+" tactical top-up consumes only missing round")
		gun.chambers.fill("empty");gun._sync();gun.eject_magazine();reserve.count=2;gun.insert_magazine();gun.rack_bolt()
		check(gun.ammo==2 and reserve.count==0,side+" finite partial reserve remains usable")
		gun.shutdown();gun.free();reserve.free();actor.left_hand_reserved=false
		var pair:=Dual.new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
		var bank:=Reserve.new();root.add_child(bank);pair.ammo_provider=bank;pair.ammo_slot=0;pair.update_ammo_display()
		check(pair.guns.size()==2 and pair.guns[0].magazine_size==32 and pair.guns[1].magazine_size==32,side+" both hands hold automatic Uzi-style assets")
		for index in 2:
			var uzi=pair.guns[index]
			uzi._requires_trigger_release=false;uzi.cooldown=0;var before:int=uzi.ammo
			trackers[uzi.right_hand].set_input("trigger",1.0);uzi._poll_vr();uzi.cooldown=0;uzi._poll_vr()
			check(uzi.ammo==before-2,side+" held trigger fires automatically in hand%d"%index)
			trackers[uzi.right_hand].set_input("trigger",0.0)
			uzi.ammo=0;uzi.eject_magazine();uzi._reset_flick()
			for tick in 4:uzi.flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
			uzi.flick_sample(Vector3.DOWN*.15,Vector3.FORWARD,.1,true,false)
			check(uzi.ammo==0,side+" downward motion cannot reload hand%d"%index)
			uzi._reset_flick();for tick in 4:uzi.flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
			var other:int=pair.guns[1-index].ammo;var reserve_before:int=bank.count
			uzi.flick_sample(Vector3.UP*.15,Vector3.FORWARD,.1,true,false)
			check(uzi.ammo==32 and bank.count==reserve_before-32 and pair.guns[1-index].ammo==other,side+" upward flick reloads only occupied hand%d"%index)
			var total:int=uzi.ammo+bank.count;uzi.ammo-=4;total-=4
			uzi.reload_flick();check(uzi.ammo+bank.count==total,side+" partial flick conserves all remaining ammo hand%d"%index)
			bank.count=100
		pair.guns[0].ammo=0;pair.guns[0].eject_magazine();pair.guns[0]._reset_flick()
		for tick in 4:pair.guns[0].flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
		pair.guns[0].flick_sample(Vector3.ZERO,Vector3(0,.85,-.527),.1,true,false)
		check(pair.guns[0].ammo==32,side+" upward wrist pitch also reloads without a translation requirement")
		pair.guns[0].ammo=0;pair.guns[0]._reset_flick();pair.guns[0].flick_sample(Vector3.UP,Vector3.UP,.05,false,false)
		check(pair.guns[0].ammo==0,side+" tracking loss cannot create reload")
		check(not pair.toggle_stow(0) and not pair.toggle_stow(1),side+" no forced hand holstering in Uzi reload")
		pair.shutdown();pair.free();bank.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await create_timer(.2).timeout
	print("RELOAD_CONTROLS_048 checks=",checks," failures=",failures," synthetic=true video_observed=true headset_tested=false")
	quit(failures)
