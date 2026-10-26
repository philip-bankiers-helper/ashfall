extends SceneTree
class Pair extends "res://scripts/dual_pistols.gd":
	func _vr_active()->bool:return true
class DT11 extends "res://scripts/dt11.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var count:=200
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,wanted:int)->int:
		var taken:=mini(count,wanted);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,wanted:int)->int:
		var returned:=mini(wanted,9999-count);count+=returned;return returned
var checks:=0
var failures:=0
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func neutral(gun)->void:
	gun._reset_flick()
	for tick in 4:gun._process(.05)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="arsenal054_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;actor.left_hand_reserved=false
		for matadors in [false,true]:
			var pair:=Pair.new();pair.shotgun_mode=matadors;root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
			var bank:=Reserve.new();root.add_child(bank);pair.ammo_provider=bank;pair.ammo_slot=0;pair.update_ammo_display()
			load("res://scripts/arsenal_data.gd").apply(pair,12 if matadors else 11)
			var label:String=dominance+(" Matadors" if matadors else " Uzis")
			for index in 2:
				var gun=pair.guns[index];gun.ammo=0;gun.eject_magazine();neutral(gun)
				var head:Node3D=gun.camera;var eye_start:Vector3=head.position
				var other:int=pair.guns[1-index].ammo;var funded:=bank.count
				head.position+=Vector3.DOWN*.15;gun._process(.1)
				check(gun.ammo==0 and bank.count==funded,label+" HMD lowering cannot reload stationary hand "+str(index))
				head.position=eye_start;gun.ammo=0;gun.eject_magazine();neutral(gun)
				actor.position+=Vector3.UP*.15;gun._process(.1)
				check(gun.ammo==0,label+" shared player movement cannot create hand flick "+str(index))
				actor.position-=Vector3.UP*.15;neutral(gun)
				gun.right_hand.position+=Vector3.UP*.15;gun._process(.1)
				check(gun.ammo==gun.magazine_size and pair.guns[1-index].ammo==other,label+" actual occupied-hand UP reload stays independent "+str(index))
				gun.right_hand.position-=Vector3.UP*.15
				gun.ammo=0;gun.eject_magazine();gun._reset_flick()
				for tick in 4:gun.flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
				gun.flick_sample(Vector3(0,INF,0),Vector3.FORWARD,.1,true,false)
				check(gun.ammo==0,label+" nonfinite pose cannot spend reserve "+str(index))
				gun.ammo=0;gun.eject_magazine();gun._reset_flick()
				for tick in 4:gun.flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
				gun.flick_sample(Vector3.UP,Vector3.FORWARD,.1,true,false)
				check(gun.ammo==0,label+" discontinuous metre jump cannot count as deliberate flick "+str(index))
			pair.shutdown();pair.free();bank.free();actor.left_hand_reserved=false
		var dt:=DT11.new();root.add_child(dt);dt.setup(actor,false);dt.set_process(false);dt.set_physics_process(false)
		var shells:=Reserve.new();root.add_child(shells);shells.count=1;dt.ammo_provider=shells;dt.ammo_slot=0
		dt.action.ammo=0;dt.action.loaded=0;dt.chamber_states.fill("empty");dt.eject_magazine()
		var offer:Vector3=dt.get_shell_offer_point();dt.reload_sample(offer,false,true);dt.reload_sample(offer,true,true)
		dt.left_hand.global_position=dt.reload_world_point(offer+Vector3.LEFT*.05);dt._update_reload_affordances()
		check(dt.shell_pair.visible and not dt.shell_offer.visible and dt.shell_pair.global_position.is_equal_approx(dt.left_hand.global_position),dominance+" DT11 offered shell follows actual acquired offhand")
		check(dt.shell_pair.get_children().filter(func(part):return part.visible).size()==2,dominance+" DT11 one reserve shows one authored shell with two mesh pieces")
		dt.reload_sample(offer,false,true);dt._update_reload_affordances()
		check(not dt.shell_pair.visible and dt.shell_offer.visible and shells.count==1,dominance+" DT11 release returns unspent shell to offer")
		dt.reload_sample(offer,true,true);dt.reload_sample(offer+Vector3.DOWN*.08,true,true)
		check(dt.action.state=="open_loaded" and dt.get_loaded_rounds()==1 and shells.count==0,dominance+" DT11 existing DOWN stroke seats one finite shell")
		check(not dt.shell_pair.visible and not dt.shell_offer.visible and dt.swipe_arrow.visible,dominance+" DT11 after seating shows only retained UP close cue")
		dt.shutdown();dt.free();shells.free();actor.left_hand_reserved=false
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();await create_timer(.2).timeout
	print("ARSENAL_054_GESTURES checks=",checks," failures=",failures," synthetic_input=true native_visual=false film_thresholds_verified=false")
	quit(failures)
