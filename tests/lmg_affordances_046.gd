# Retained entry updated for visually observed 047 four-motion sequence.
extends SceneTree
class Gun extends "res://scripts/belt_lmg.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var count:=7
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,n:int)->int:
		var taken:=mini(count,n);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,n:int)->int:
		var credited:=mini(n,9999-count);count+=credited;return credited
var checks:=0
var failures:=0
var gun
var actor
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._process(0)
func begin()->Vector3:
	var point:Vector3=gun.get_reload_grab_point();sample(point,0);sample(point,1);return point
func release()->void:sample(gun.to_local(gun.left_hand.global_position),0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="atlas047_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
		actor.update_hand_input_rearm(.1)
		gun=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		var provider:=Reserve.new();root.add_child(provider);gun.ammo_provider=provider;gun.ammo_slot=0;gun.ammo=0;gun.seated=0;gun._process(0)
		var raw:Transform3D=gun.right_hand.global_transform
		check(gun.reload_state=="ready" and gun.cover.rotation.x==0 and not gun.reload_arrow.visible,side+" empty weapon stays closed until reload intent")
		trackers[gun.right_hand].set_input("primary",Vector2(0,-1));gun._process(0)
		check(gun.reload_state=="box_removed" and gun.cover.rotation.x< -1.3 and gun.offered_box.visible and not gun.belt_box.visible,side+" actual fresh mapped reload intent auto-opens and removes old box")
		gun._process(0);check(provider.count==7,side+" held reload intent cannot repeat refund")
		trackers[gun.right_hand].set_input("primary",Vector2.ZERO);gun._process(0)
		check(gun.box_grip.get_parent()==gun.belt_box and gun.cover_grip.get_parent()==gun.cover and gun.reload_arrow.get_parent()==gun,side+" real moving handles and runtime-only chevrons preserved")
		check(gun.belt_box.position.x*gun.feed_direction()<0 and gun.offered_box.position.x*gun.feed_direction()<0,side+" box and offered geometry mirror physical firing hand")
		var point:Vector3=begin()
		check(gun.reload_state=="holding_box" and gun.held_box.visible and gun.feed_socket.material_override==gun._cue_active,side+" first motion acquires real offered box and shows seating target")
		sample(gun.get_box_seat()+Vector3(0,-.15,0),1);check(gun.reload_state=="holding_box" and provider.count==7,side+" short upward movement cannot seat")
		sample(gun.get_box_seat(),1);release()
		check(gun.reload_state=="needs_feed" and gun.seated==7 and gun.ammo==0 and provider.count==0,side+" BOX UP seats finite seven and requires separate feed step")
		check(gun.belt_feed_grip.material_override==gun._cue_active and gun.reload_arrow.basis.y.dot(gun.model.basis.x*gun.feed_direction())>.9999,side+" BELT ACROSS cue points toward receiver with mirrored grip")
		gun.close_cover();gun.rack_bolt();check(gun.reload_state=="needs_feed",side+" cannot bypass feed by closing cover or charging")
		point=begin();sample(point+Vector3(.035*gun.feed_direction(),0,0),1)
		check(absf(gun.belt.position.x)<.06 and absf(gun.belt.position.x)>.02 and gun.reload_state=="needs_feed",side+" partial across motion moves actual linked belt continuously")
		sample(point+Vector3(.085*gun.feed_direction(),0,0),1);release()
		check(gun.belt_fed and gun.reload_state=="box_seated" and gun.belt.position.x==0 and provider.count==0,side+" BELT ACROSS finishes without consuming extra ammunition")
		check(gun.cover_grip.material_override==gun._cue_active and gun.reload_arrow.basis.y.dot(-gun.model.basis.y)>.9999,side+" COVER DOWN is the third motion")
		point=begin();sample(point+Vector3(0,-.035,0),1)
		check(gun.cover.rotation.x<-.5 and gun.cover.rotation.x>-.95 and gun.reload_state=="box_seated",side+" cover follows partial downward hand motion")
		sample(point+Vector3(0,-.08,0),1);release()
		check(gun.reload_state=="needs_charge" and gun.cover.rotation.x==0,side+" cover closes before final charging operation")
		check(gun.charging_handle.material_override==gun._cue_active and gun.reload_arrow.basis.y.dot(gun.model.basis.z)>.9999,side+" CHARGE BACK is final cue")
		point=begin();sample(point+Vector3(0,0,.05),1)
		check(gun.charging_handle.position.z>gun.get_handle_point().z+.04 and gun.reload_state=="needs_charge",side+" real charging knob moves partway without readying")
		sample(point+Vector3(0,0,.11),1);release()
		check(gun.reload_state=="ready" and gun.ammo==7 and gun.seated==7 and provider.count==0,side+" fourth motion readies only actually seated rounds")
		gun.cooldown=0;gun._requires_trigger_release=false;trackers[gun.right_hand].set_input("trigger",1.0);gun._process(0);trackers[gun.right_hand].set_input("trigger",0.0)
		check(gun.ammo==6 and gun.seated==6 and gun.right_hand.global_transform.is_equal_approx(raw),side+" firing retains 045 live count and raw-pose behavior")
		gun.begin_reload();gun.begin_reload();check(provider.count==6 and gun.ammo==0 and gun.reload_state=="box_removed",side+" tactical reload intent refunds remaining rounds exactly once")
		gun.grab_magazine();gun.suspend_for_selection();check(gun.reload_state=="box_removed" and provider.count==6 and not gun.contact,side+" selection safely returns uncharged held box")
		actor._grabs[gun.left_hand]=gun.left_hand.global_position;gun.reload_state="ready";gun.ammo=2;gun.seated=2
		check(not gun.begin_reload() and gun.ammo==2 and actor._grabs.has(gun.left_hand),side+" wall anchor owns hand before reload initiation")
		actor._grabs.clear();provider.count=9998;gun.ammo=5;gun.seated=5;gun.reload_state="ready"
		check(not gun.begin_reload() and gun.ammo==4 and gun.seated==4 and provider.count==9999 and gun.reload_state=="ready",side+" capped reserve retains uncredited rounds and aborts opening")
		gun.begin_reload();check(gun.ammo==4 and provider.count==9999,side+" repeated capped request neither farms nor loses rounds")
		provider.count=0;gun.ammo=3;gun.seated=3;gun.reload_state="ready"
		for step in range(5):gun.desktop_reload_step()
		check(gun.reload_state=="ready" and gun.ammo==3 and provider.count==0,side+" desktop init plus four loading motions matches tracked state order")
		gun.ammo=1;gun.seated=1;gun.cooldown=0;gun._requires_trigger_release=false;gun.fire()
		check(gun.ammo==0 and gun.reload_state=="box_removed" and provider.count==0,side+" base empty-eject policy safely begins new four-motion reload")
		check(gun.find_children("*","Label3D",true,false).size()==1,side+" only loaded-reserve weapon text")
		trackers[gun.right_hand].invalidate_pose("grip");gun._process(0);check(not gun.reload_arrow.visible,side+" tracking loss hides detached cue")
		trackers[gun.right_hand].set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		gun.shutdown();await create_timer(.15).timeout;gun.free();provider.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await process_frame
	print("LMG_AFFORDANCES_046 checks=",checks," failures=",failures," synthetic=true qualitative_order_verified_by_root=true exact_cm_or_button_verified=false headset_tested=false");quit(failures)


