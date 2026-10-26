extends SceneTree
class Rifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
class Shotgun extends "res://scripts/shotgun.gd":
	func _vr_active()->bool:return true
var actor
var trackers:Dictionary={}
var failures:=0
var checks:=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",message)
func _initialize():call_deferred("run")
func hand_input(gun,pos:Vector3,value:float):
	gun.left_hand.global_position=gun.to_global(pos)
	trackers[gun.left_hand].set_input("grip",value)
	gun._poll_vr()
func run():
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="dominance_"+str(hand.get_instance_id())
		XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trackers[hand]=tracker
	await process_frame
	actor.update_hand_input_rearm(0.1)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for kind in ["rifle","shotgun"]:
			for tracker in trackers.values():
				tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false)
			actor.update_hand_input_rearm(0.1)
			var gun=Rifle.new() if kind=="rifle" else Shotgun.new()
			root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			gun.global_transform=gun.corrected_grip_transform(actor.get_weapon_hand().global_transform)
			check(gun.right_hand==actor.get_weapon_hand() and gun.left_hand==actor.get_support_hand(),side+" "+kind+" logical hands map correctly")
			gun._poll_vr()
			if kind=="rifle":
				actor.sprint_binding="left_stick_click"
				trackers[gun.right_hand].set_input("primary_click",true);gun._poll_vr()
				check(gun.reload_state==("ready" if side=="left" else "needs_mag"),side+" click routes exclusively to sprint or eject")
				if side=="left":
					actor.sprint_binding="left_grip"
					gun._poll_vr()
					check(gun.reload_state=="ready","binding change while click held cannot eject")
					trackers[gun.right_hand].set_input("primary_click",false);gun._poll_vr()
					trackers[gun.right_hand].set_input("primary_click",true);gun._poll_vr()
					check(gun.reload_state=="needs_mag","left-grip sprint permits fresh left click eject")
				actor.sprint_binding="left_stick_click"
				trackers[gun.right_hand].set_input("primary_click",false)
				gun.reset_weapon();gun._poll_vr()
			trackers[gun.right_hand].set_input("primary",Vector2(0,-1));gun._poll_vr()
			check(gun.ammo==0 and gun.reload_state!="ready",side+" "+kind+" dominant stick opens reload")
			if kind=="rifle":
				var spent_index:int=gun.CASING_POOL_SIZE+(gun._magazine_cursor+gun.MAGAZINE_POOL_SIZE-1)%gun.MAGAZINE_POOL_SIZE
				check(gun._debris[spent_index].global_position.distance_to(gun.model.to_global(gun.magazine.position*0.7))<0.001,side+" spent magazine spawns at 70 percent gun offset")
				hand_input(gun,gun.OFFER_POINT,0);hand_input(gun,gun.OFFER_POINT,1);hand_input(gun,gun.INSERT_POINT,1)
				check(gun.reload_state=="needs_rack",side+" rifle support hand inserts magazine")
				hand_input(gun,Vector3(-0.05,0.064,-0.10),0);hand_input(gun,Vector3(-0.05,0.064,-0.10),1);hand_input(gun,Vector3(-0.05,0.064,-0.01),1)
			else:
				hand_input(gun,gun.SHELL_OFFER,0);hand_input(gun,gun.SHELL_OFFER,1);hand_input(gun,gun.CHAMBER,1)
				check(gun.reload_state=="open_loaded",side+" shotgun support hand seats shells")
				hand_input(gun,Vector3(0,-0.20,-0.4),0);hand_input(gun,Vector3(0,-0.20,-0.4),1);hand_input(gun,Vector3(0,-0.10,-0.4),1)
			check(gun.reload_state=="ready" and gun.ammo==gun.magazine_size,side+" "+kind+" full physical reload completes")
			trackers[gun.left_hand].set_input("grip",0.0)
			gun._update_support(0.1)
			gun.left_hand.global_position=gun.to_global(Vector3(0,-0.025,-0.36))
			trackers[gun.left_hand].set_input("grip",0.8)
			gun._update_support(0.1)
			check(gun.supported,side+" "+kind+" mirrored support hand grips fore-end")
			if kind=="shotgun":gun._semi_release=true
			gun.cooldown=0.0
			gun.fire()
			var braced_recoil:float=gun.recoil
			gun.recoil=0.0
			gun.cooldown=0.0
			gun.supported=false
			if kind=="shotgun":gun._semi_release=true
			gun.fire()
			check(braced_recoil>0.0 and braced_recoil<gun.recoil,side+" "+kind+" offhand brace reduces fired recoil")
			gun.reset_weapon()
			gun.eject_magazine();gun.grab_magazine()
			actor.dominant_hand="left" if side=="right" else "right"
			gun.refresh_hands()
			check(gun.ammo==0 and gun.reload_state in ["needs_mag","open_empty"] and gun._requires_trigger_release,kind+" dominance change cancels carried contact without free ammo")
			actor.dominant_hand=side
			gun.shutdown();await create_timer(0.12).timeout;gun.free()
		for tracker in trackers.values():
			tracker.set_input("grip",0.0);tracker.set_input("primary",Vector2.ZERO);tracker.set_input("ax_button",false)
		actor.update_hand_input_rearm(0.1)
		var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
		for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
		actor.xr_enabled=true
		rack._process(0.1)
		trackers[actor.get_support_hand()].set_input("ax_button",true);rack._process(0.1)
		trackers[actor.get_support_hand()].set_input("ax_button",false);rack._process(0.1)
		check(not rack.is_holstered,side+" support AX cannot holster weapon")
		trackers[actor.get_weapon_hand()].set_input("ax_button",true);rack._process(0.1)
		trackers[actor.get_weapon_hand()].set_input("ax_button",false);rack._process(0.1)
		check(rack.is_holstered,side+" dominant AX tap holsters")
		trackers[actor.get_weapon_hand()].set_input("ax_button",true);rack._process(0.4)
		check(rack.is_selecting,side+" dominant AX hold opens wheel")
		check(rack._pointer_transform().is_equal_approx(rack.weapons[0].corrected_grip_transform(actor.get_weapon_hand().global_transform)),side+" wheel ray uses corrected dominant hand")
		var opening_ray:Transform3D=rack._pointer_transform()
		check(rack.wheel.global_position.distance_to(opening_ray.origin-opening_ray.basis.z*0.85)<0.001,side+" wheel opens at current weapon aim")
		check(rack.wheel.get_node_or_null("WeaponIcon0") is Sprite3D and rack.wheel.get_node_or_null("WeaponIcon1") is Sprite3D,side+" selector uses two flat image icons")
		check(rack.wheel.SLOT_ACTIONS.size()==8 and rack.wheel.SLOT_ACTIONS.count("empty")==1,side+" five owned, one empty weapon position plus revive and backpack")
		check(rack.wheel.weapon_index_at_slot(["backpack","weapon_1","empty","weapon_0"],1)==1 and rack.wheel.weapon_index_at_slot(["backpack","weapon_1","empty","weapon_0"],3)==0 and rack.wheel.weapon_index_at_slot(["backpack","weapon_1","empty","weapon_0"],0)==-1,side+" permuted slot actions resolve weapons without position assumptions")
		check(rack.wheel.get_node("WeaponIcon0").position.distance_to(rack.wheel.slot_position(rack.wheel.SLOT_ACTIONS.find("weapon_0"),0.215)+Vector3(0,0,0.022))<0.001,side+" flat icon position follows slot action data")
		check(rack.wheel.get_node_or_null("WheelDivider0")!=null and rack.wheel.get_node_or_null("WheelDivider7")!=null and rack.wheel.get_node("WheelDivider0").material_override.no_depth_test,side+" eight visible depth-independent sector dividers")
		check(rack.wheel.get_node_or_null("CancelDisc")!=null and rack.wheel.get_node_or_null("CancelMarkA")!=null and rack.wheel.get_node_or_null("CancelMarkB")!=null,side+" center cancel uses graphic mark")
		check(rack.wheel.get_node_or_null("ReviveCrossVertical")!=null and rack.wheel.get_node_or_null("BackpackBody")!=null and rack.wheel.get_node_or_null("EmptySlot0Top")==null,side+" utilities keep graphics while empty wedge is undecorated")
		var caption_count:=0
		for child in rack.wheel.get_children():
			if child is Label3D:caption_count+=1
		check(caption_count==0,side+" wheel has no text labels")
		var center_ray:Transform3D=rack.wheel.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,0.4))
		check(rack.wheel.point(center_ray)==-1 and rack.wheel.point_action()=="cancel",side+" graphic center preserves cancel")
		var bag_ray:Transform3D=rack.wheel.global_transform*Transform3D(Basis.IDENTITY,rack.wheel.slot_position(4,0.225)+Vector3(0,0,0.4))
		check(rack.wheel.point(bag_ray)==-1 and rack.wheel.point_action()=="backpack",side+" graphic backpack remains an explicit action")
		var revive_ray:Transform3D=rack.wheel.global_transform*Transform3D(Basis.IDENTITY,rack.wheel.slot_position(3,0.225)+Vector3(0,0,0.4))
		check(rack.wheel.point(revive_ray)==-1 and rack.wheel.point_action()=="revive_unavailable",side+" graphic revive remains unavailable")
		check(rack.weapons[0].OFFER_POINT.distance_to(rack.weapons[0].INSERT_POINT)<Vector3(0,-0.32,-0.15).distance_to(rack.weapons[0].INSERT_POINT),side+" rifle reload offer shortens real insertion reach")
		check(rack.weapons[1].SHELL_OFFER.distance_to(rack.weapons[1].CHAMBER)<Vector3(0,0.16,-0.16).distance_to(rack.weapons[1].CHAMBER),side+" shotgun shell offer shortens real chamber reach")
		var wheel_target:Vector3=rack.wheel.to_global(Vector3(0.2,0,0))
		var pointer:=Transform3D(Basis.looking_at(wheel_target-actor.get_view_camera().global_position,Vector3.UP),actor.get_view_camera().global_position)
		for tracker in trackers.values():tracker.set_input("grip",0.8);tracker.set_input("primary",Vector2(0.6,0));tracker.set_input("trigger",0.7)
		rack.update_a_input(0.01,false,true,pointer)
		check(rack.selected==1,"explicit wheel choice works while holding grips and moving sticks")
		check(rack.weapons[1]._requires_trigger_release,"new weapon still requires fresh trigger after draw")
		check(rack.wheel.pointer.material_override.no_depth_test,"wheel pointer remains visible against nearby geometry")
		rack.select_weapon(0);rack.weapons[0].eject_magazine()
		check(rack.select_weapon(1) and rack.weapons[0].ammo==0 and rack.weapons[0].reload_state=="needs_mag","empty rifle switches away without free ammunition")
		rack.select_weapon(0);rack.weapons[0].grab_magazine()
		check(not rack.select_weapon(1),"carried magazine still blocks switching")
		check(not rack.select_inventory_weapon(1),side+" inventory cannot bypass carried magazine")
		rack.weapons[0].reset_weapon()
		rack.weapons[0].ammo=5
		actor.input_enabled=false
		trackers[actor.get_weapon_hand()].set_input("trigger",0.8)
		check(rack.select_inventory_weapon(1) and rack.selected==1,side+" inventory equips while menu input is paused and trigger held")
		check(rack.select_inventory_weapon(0) and rack.ammo==5,side+" inventory preserves prior rifle ammunition")
		check(rack.select_inventory_weapon(1) and rack.weapons[0].ammo==5,side+" inventory redraw does not replenish stowed rifle")
		actor.input_enabled=true
		rack.weapons[1].cooldown=0.0
		var draw_ammo:int=rack.weapons[1].ammo
		rack.weapons[1]._poll_vr()
		check(rack.weapons[1].ammo==draw_ammo,side+" held menu trigger cannot fire newly drawn shotgun")
		trackers[actor.get_weapon_hand()].set_input("trigger",0.0)
		rack.weapons[1]._poll_vr()
		trackers[actor.get_weapon_hand()].set_input("trigger",0.8)
		rack.weapons[1]._poll_vr()
		check(rack.weapons[1].ammo==draw_ammo-1,side+" fresh post-menu trigger can fire")
		rack._wheel_log_count=64
		for i in range(40):rack._record_wheel_event("test_bound")
		check(rack.wheel_events.size()==32 and rack._wheel_log_count==64,"diagnostic memory and log count bounded")
		rack.shutdown();await create_timer(0.12).timeout;rack.free();actor.xr_enabled=false
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	trackers.clear();actor.free()
	print("DOMINANT_WEAPON_RESULT checks=",checks," failures=",failures)
	quit(failures)





