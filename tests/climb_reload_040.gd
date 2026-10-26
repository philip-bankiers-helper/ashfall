extends SceneTree
class SyntheticPlayer extends "res://scripts/player.gd":
	func update_tracking()->bool:return tracking_available
const DT:=1.0/90.0
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func tracker(id:String,hand:XRController3D)->XRControllerTracker:
	var value:=XRControllerTracker.new();value.type=XRServer.TRACKER_CONTROLLER;value.name=id
	XRServer.add_tracker(value);hand.tracker=id;hand.pose="grip"
	value.set_pose("grip",hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	return value
func tick(actor,count:=1)->void:
	for i in range(count):actor._physics_process(DT)
func run()->void:
	var wall:=StaticBody3D.new();wall.position=Vector3(-.55,1.5,-.2)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.15,4,3);collision.shape=shape;wall.add_child(collision);root.add_child(wall)
	await physics_frame
	for side in ["right","left"]:
		for slot in [0,1,2,3,4]:
			var actor:=SyntheticPlayer.new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.xr_camera.position.y=1.65;actor.tracking_available=true;actor.dominant_hand=side
			actor.set_process(false);actor.set_physics_process(false)
			var left:=tracker("climb_left_"+str(actor.get_instance_id()),actor.left_hand)
			var right:=tracker("climb_right_"+str(actor.get_instance_id()),actor.right_hand)
			var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
			for weapon in rack.weapons:weapon.set_process(false);weapon.set_physics_process(false)
			rack.select_inventory_weapon(slot)
			var gun=rack.weapons[slot]
			var support=actor.get_support_hand();var dominant=actor.get_weapon_hand()
			var supporting=left if support==actor.left_hand else right
			var firing=right if dominant==actor.right_hand else left
			for t in [left,right]:t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
			tick(actor,12)
			support.global_position=Vector3(-.45,1.2,-.2)
			supporting.set_input("grip",1.0);tick(actor)
			var label:String=side+" slot"+str(slot)+" "
			check(actor._grabs.has(support),label+" production physics grips real wall")
			var anchor:Vector3=actor._grabs.get(support,Vector3.ZERO)
			gun._poll_vr();gun.cooldown=0
			gun.ammo=1
			if slot==4:gun.chambered=true;gun.tube_rounds=0;gun._sync_rounds()
			if slot==1:gun.action.loaded=1;gun.action.ammo=1
			if slot==2:gun._semi_armed=true
			if slot==3:gun._burst_armed=true
			firing.set_input("trigger",1.0);gun._poll_vr()
			check(gun.ammo==0,label+" actual controller final shot empties ammo")
			check(not actor.left_hand_reserved,label+" empty state cannot reserve climbing support")
			tick(actor,6)
			check(actor._grabs.has(support) and actor._grabs[support].is_equal_approx(anchor),label+" final shot preserves same wall anchor across physics ticks")
			gun._poll_vr()
			check(gun.reload_state!="held_mag" and gun.reload_state!="holding_shells" and not gun._rack_grabbed,label+" held wall grip cannot acquire reload item")
			firing.set_input("trigger",0.0);gun._poll_vr()
			gun.desktop_reload_step();tick(actor,3)
			check(actor._grabs.has(support),label+" manual reload command preserves wall")
			check(gun.reload_state not in ["held_mag","holding_shells","needs_rack","open_loaded"],label+" manual reload cannot steal occupied climbing hand")
			rack.set_holstered(true);tick(actor,3)
			check(actor._grabs.has(support),label+" holster preserves wall")
			rack.is_selecting=true;rack._apply_selection();tick(actor,3)
			check(actor._grabs.has(support),label+" wheel open preserves wall")
			rack.is_selecting=false;rack._apply_selection();tick(actor,3)
			check(actor._grabs.has(support),label+" wheel close preserves wall")
			# A stale independent reservation must also never release an existing grab.
			actor.left_hand_reserved=true;tick(actor,3)
			check(actor._grabs.has(support),label+" stale reservation cannot drop established grip")
			supporting.set_input("grip",0.0);tick(actor)
			check(not actor._grabs.has(support),label+" actual physical grip release removes anchor")
			rack.shutdown();await create_timer(.12).timeout;rack.free();actor.free()
			XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	wall.free();await process_frame
	print("CLIMB_RELOAD_040 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)




