extends SceneTree
class SyntheticPlayer extends "res://scripts/player.gd":
	func update_tracking() -> bool: return tracking_available
class HeldItem extends Node:
	var hand: Node3D
	func hand_holds_item(value: Node3D) -> bool: return value==hand
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func tracker(id: String,hand: XRController3D) -> XRControllerTracker:
	var value := XRControllerTracker.new(); value.type = XRServer.TRACKER_CONTROLLER; value.name = id; XRServer.add_tracker(value); hand.tracker = id; hand.pose = "grip"
	value.set_pose("grip",hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	value.set_input("grip",0.0); value.set_input("trigger",0.0)
	return value
func wall(at: Vector3) -> StaticBody3D:
	var value := StaticBody3D.new(); value.position = at
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=Vector3(.15,4,3); collision.shape=shape; value.add_child(collision); root.add_child(value)
	return value
func run() -> void:
	var surface := wall(Vector3(-.55,1.5,-.2)); await physics_frame
	for side in ["right","left"]:
		var actor := SyntheticPlayer.new(); root.add_child(actor); actor.setup(false); actor.set_physics_process(false); actor.set_process(false); actor.xr_enabled = true; actor.tracking_available = true; actor.xr_camera.position.y = 2.0; actor.dominant_hand=side
		var lt := tracker("empty_left_"+str(actor.get_instance_id()),actor.left_hand); var rt := tracker("empty_right_"+str(actor.get_instance_id()),actor.right_hand)
		actor._hand_input_ready[actor.left_hand]=true; actor._hand_input_ready[actor.right_hand]=true
		var rack = load("res://scripts/weapon_rack.gd").new(); root.add_child(rack); rack.setup(actor); rack.set_process(false); rack.set_physics_process(false)
		for gun in rack.weapons: gun.set_process(false); gun.set_physics_process(false)
		for slot in [0,1,2,3,4,5,6,7,8,9,10]:
			if slot>=rack.weapons.size(): continue
			rack.select_inventory_weapon(slot)
			var gun = rack.weapons[slot]
			if not gun.has_method("_set_stage"): continue
			if gun.has_method("hand_for") or gun.has_method("sample_motion"): continue
			var support := actor.get_support_hand(); var firing := actor.get_weapon_hand()
			var st := lt if support==actor.left_hand else rt
			st.set_input("grip",0.0); actor._grabs.clear(); gun._suspend_gestures(); gun.ammo=0
			gun._set_stage("needs_mag",""); gun.global_position=Vector3(0,1.3,-1.4)
			support.global_position=Vector3(-.45,1.2,-.2); firing.global_position=Vector3(-.45,1.5,-.2)
			check(actor.left_hand_reserved,side+" slot"+str(slot)+" empty reload requests broad support reservation")
			check(not gun.reload_claims_hand(support),side+" slot"+str(slot)+" support far from reload zones is physically free")
			st.set_input("grip",1.0); actor._update_grab(support,true)
			check(actor._grabs.has(support),side+" slot"+str(slot)+" free offhand acquires real wall after gun already empty")
			actor._update_grab(firing,true)
			check(not actor._grabs.has(firing),side+" slot"+str(slot)+" drawn weapon hand cannot acquire wall")
			var anchor: Vector3=actor._grabs.get(support,Vector3.ZERO); gun._poll_vr(); actor._update_grab(support,true)
			check(actor._grabs.has(support) and actor._grabs[support].is_equal_approx(anchor),side+" slot"+str(slot)+" weapon polling preserves offhand wall ownership")
			actor._update_grab(support,false,false); st.set_input("grip",0.0)
			# Exercise production generic magazine held-state ownership independently
			# of each weapon's distinct reload state machine.
			if slot==0:
				gun._set_stage("held_mag",""); st.set_input("grip",1.0)
				actor._update_grab(support,true)
				check(gun.reload_claims_hand(support) and not actor._grabs.has(support),side+" held magazine retains hand away from insertion zone")
				gun._set_stage("needs_mag",""); st.set_input("grip",0.0)
				var zone: Dictionary = gun.get_reload_zones()[0]
				gun.global_position = support.global_position-zone.position*gun.visual_model_scale()
				actor._update_grab(support,true)
				check(gun.reload_claims_hand(support) and not actor._grabs.has(support),side+" actual magazine offer zone retains priority over overlapping wall")
				gun.global_position=Vector3(0,1.3,-1.4)
			actor._grabs.clear(); st.set_input("grip",0.0)
		# Reproduce the order that escaped the older carry test: fire the final
		# live round FIRST, then make a NEW free-hand wall claim afterward.
		for slot in [0,1,5,7,8,9,10]:
			rack.select_inventory_weapon(slot)
			var gun = rack.weapons[slot]; gun.set_process(false); gun.set_physics_process(false)
			var support := actor.get_support_hand(); var firing := actor.get_weapon_hand(); var st := lt if support==actor.left_hand else rt
			actor._grabs.clear(); st.set_input("grip",0.0); gun.reset_weapon(); gun.cooldown = 0.0; gun.ammo = 1
			if slot==1: gun.action.loaded=1; gun.action.ammo=1
			if slot==5: gun.chambered=true
			if slot==7: gun.chambers.fill("empty"); gun.chambers[0]="live"; gun._sync()
			gun.global_position=Vector3(0,1.3,-1.4); support.global_position=Vector3(-.45,1.2,-.2); firing.global_position=Vector3(-.45,1.5,-.2)
			gun.fire()
			check(gun.ammo==0 and gun.reload_state!="ready",side+" "+rack.weapon_names[slot]+" final production shot enters actual empty/cycle state "+gun.reload_state)
			st.set_input("grip",1.0); actor._update_grab(support,true)
			check(actor._grabs.has(support),side+" "+rack.weapon_names[slot]+" NEW free offhand wall claim works after final shot")
			actor._update_grab(firing,true)
			check(not actor._grabs.has(firing),side+" "+rack.weapon_names[slot]+" final-shot drawn hand still cannot climb")
			actor._update_grab(support,false,false); st.set_input("grip",0.0)
		var item := HeldItem.new(); root.add_child(item); actor.held_item_provider=item; item.hand=actor.get_support_hand(); item.hand.global_position=Vector3(-.45,1.2,-.2)
		rack.set_holstered(true); actor._update_grab(item.hand,true)
		check(not actor._grabs.has(item.hand),side+" held consumable hand cannot also grab wall")
		item.hand=null; actor._update_grab(actor.get_support_hand(),true)
		check(actor._grabs.has(actor.get_support_hand()),side+" hand freed from consumable can acquire wall")
		actor._update_grab(actor.get_support_hand(),false,false); item.free(); rack.shutdown(); await create_timer(.12).timeout; rack.free(); actor.free(); XRServer.remove_tracker(lt); XRServer.remove_tracker(rt)
	surface.free(); await process_frame
	print("EMPTY_WEAPON_CLIMB_061 checks=",checks," failures=",failures," real_wall_queries=true synthetic_tracking=true headset_tested=false")
	quit(0 if failures==0 else 1)
