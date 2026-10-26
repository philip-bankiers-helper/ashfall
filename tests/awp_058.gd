extends SceneTree
class TrackedAWP extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true # CPU seam; no XR runtime is initialized.
var checks:=0
var failures:=0
var actor
var rack
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._process(0)
func pull(gun)->void:
	sample(gun,gun.get_bolt_grip_point(),0);sample(gun,gun.get_bolt_grip_point(),1);sample(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
func neutral(gun)->void:
	for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
	actor.update_hand_input_rearm(.2);gun._process(0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.xr_camera.position.y=1.65;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="awp058_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame
	rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var old=rack.weapons[5];old.shutdown();old.free()
	var tracked:=TrackedAWP.new();rack.add_child(tracked);tracked.setup(actor,false);tracked.ammo_provider=rack;tracked.ammo_slot=5;tracked.motion_damping=0;rack.weapons[5]=tracked;rack._connect_weapon_events(tracked)
	for g in rack.weapons:g.set_process(false);g.set_physics_process(false)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();rack.selected=5;rack.is_holstered=false;rack._apply_selection()
		for g in rack.weapons:g.set_process(false);g.set_physics_process(false)
		var gun=rack.weapons[5];gun.reset_weapon();rack.Arsenal.apply(gun,5);actor.left_hand_reserved=false;neutral(gun)
		gun.right_hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,1.4,-.3));gun._process(0)
		check(gun.ammo==3 and gun.get_action_mode()=="loaded_support" and gun.get_reload_zones().is_empty(),side+" actual catalog AWP loaded3 belongs to support with no bolt claim")
		sample(gun,gun.FOREGRIP_POINT,0);sample(gun,gun.FOREGRIP_POINT,1)
		check(gun.supported and gun.optic.active and gun.reload_state=="ready" and not gun._reload_pending and not gun._bolt_contact,side+" actual offhand foregrip activates scope without grabbing overlapping bolt")
		sample(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
		check(gun.reload_state=="ready" and gun.ammo==3,side+" loaded offhand movement cannot enable reload")
		sample(gun,gun.FOREGRIP_POINT,0);sample(gun,gun.FOREGRIP_POINT,1)
		gun.cooldown=0;trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0)
		check(gun.ammo==2 and gun.get_action_mode()=="cycle_spent_bolt" and gun.magazine.visible and not gun._reload_pending and not gun._bolt_contact,side+" supported shot fires and requests only normal spent cycle")
		sample(gun,gun.FOREGRIP_POINT+Vector3.BACK*.13,1)
		check(gun.reload_state=="needs_bolt" and not gun._bolt_contact,side+" held foregrip is not silently acquired as bolt after firing")
		trackers[gun.right_hand].set_input("trigger",0.0);pull(gun)
		check(gun.reload_state=="ready" and gun.chambered and gun.ammo==2,side+" between-shot BACK retains loaded magazine without thumb input")
		for i in 2:
			trackers[gun.right_hand].set_input("trigger",0.0);gun._process(0);gun.cooldown=0;trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0)
			if i==0:trackers[gun.right_hand].set_input("trigger",0.0);pull(gun)
		check(gun.ammo==0 and gun.get_action_mode()=="reload_eject_bolt" and gun.magazine.visible,side+" third round enables empty reload automatically")
		trackers[gun.right_hand].set_input("trigger",0.0);pull(gun)
		check(gun.reload_state=="needs_mag" and not gun.magazine.visible,side+" empty BACK ejects without thumbstick")
		sample(gun,gun.OFFER_POINT,0);sample(gun,gun.OFFER_POINT,1);var reserve:int=gun.reserve_rounds();sample(gun,gun.INSERT_POINT,1)
		check(gun.get_action_mode()=="chamber_inserted_magazine" and gun.ammo==3 and not gun.chambered and gun.reserve_rounds()==reserve-3,side+" magazine seats three funded rounds, separately awaiting chamber BACK")
		sample(gun,gun.get_bolt_grip_point(),1);sample(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
		check(gun.get_action_mode()=="loaded_support" and gun.chambered and gun.ammo==3,side+" continuous post-insertion BACK chambers, then bolt claim disappears")
		neutral(gun);sample(gun,gun.FOREGRIP_POINT,1);trackers[gun.right_hand].set_input("primary",Vector2(0,-1));gun._process(0)
		check(gun.get_action_mode()=="reload_eject_bolt" and gun.magazine.visible and gun.ammo==3,side+" dominant thumbstick explicitly enables loaded early reload but does not eject")
		sample(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
		check(gun.magazine.visible and not gun._bolt_contact,side+" thumb request does not recycle the held foregrip into a bolt grab")
		trackers[gun.right_hand].set_input("primary",Vector2.ZERO);pull(gun)
		check(gun.reload_state=="needs_mag" and gun.ammo==0,side+" deliberate early reload first BACK ejects magazine")
		gun.reset_weapon();rack.Arsenal.apply(gun,5);neutral(gun);trackers[gun.right_hand].set_input("primary",Vector2(0,1));gun._process(0)
		check(gun.reload_state=="ready" and not gun._reload_pending,side+" forward zoom direction cannot request reload")
		neutral(gun);trackers[gun.right_hand].set_input("primary",Vector2(0,-1));gun._process(0)
		trackers[gun.right_hand].set_input("primary",Vector2.ZERO);sample(gun,gun.get_bolt_grip_point(),1);sample(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
		check(gun.reload_state=="needs_mag",side+" already-released offhand may grab bolt immediately after thumb request without an extra release")
		gun.reset_weapon();rack.Arsenal.apply(gun,5)
		neutral(gun);actor.input_enabled=false;trackers[gun.right_hand].set_input("primary",Vector2(0,-1));gun._process(0)
		check(gun.reload_state=="ready" and not gun._reload_pending,side+" disabled input cannot enable loaded reload")
		actor.input_enabled=true;neutral(gun)
	for t in trackers.values():XRServer.remove_tracker(t)
	rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("AWP_058 checks=",checks," failures=",failures," actual_controller_polling=true headset_tested=false")
	quit(failures)
