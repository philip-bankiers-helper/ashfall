extends SceneTree
class VRTop extends "res://scripts/top_feed_pdw.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var rounds:=80
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":rounds}
	func consume_weapon_reserve(_slot:int,request:int)->int:
		var count:=mini(rounds,request)
		rounds-=count
		return count
var checks:=0
var failures:=0
var gun
var actor
var support:XRControllerTracker
var firing:XRControllerTracker
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func tracker(id:String,hand:XRController3D)->XRControllerTracker:
	var value:=XRControllerTracker.new()
	value.type=XRServer.TRACKER_CONTROLLER
	value.name=id
	XRServer.add_tracker(value)
	hand.tracker=id
	hand.pose="grip"
	value.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	return value
func hand_at(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	support.set_input("grip",grip)
	gun._poll_vr()
func run()->void:
	actor=load("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_physics_process(false)
	actor.set_process(false)
	var left:=tracker("top_left",actor.left_hand)
	var right:=tracker("top_right",actor.right_hand)
	await process_frame
	for handedness in ["right","left"]:
		actor.dominant_hand=handedness
		firing=right if handedness=="right" else left
		support=left if handedness=="right" else right
		gun=VRTop.new()
		root.add_child(gun)
		gun.setup(actor,false)
		gun.set_process(false)
		gun.set_physics_process(false)
		var provider:=Reserve.new()
		root.add_child(provider)
		gun.ammo_provider=provider
		gun.ammo_slot=0
		firing.set_input("trigger",0.0)
		firing.set_input("primary",Vector2.ZERO)
		firing.set_input("primary_click",false)
		support.set_input("grip",0.0)
		actor.update_hand_input_rearm(0.1)
		gun._poll_vr()
		firing.set_input("primary",Vector2(0,-1))
		gun._poll_vr()
		check(gun.reload_state=="remove_top",handedness+" latch requests physical top removal")
		hand_at(gun.TOP_SEAT,0)
		hand_at(gun.TOP_SEAT,1)
		hand_at(gun.TOP_SEAT+Vector3(0,0.05,0),1)
		check(gun.reload_state=="remove_top" and gun.magazine.position.y>gun.TOP_SEAT.y,"partial lift visibly raises magazine without completing")
		hand_at(gun.TOP_SEAT+Vector3(0,-0.12,0),1)
		check(gun.reload_state=="remove_top","pushing down cannot remove top magazine")
		gun.fire()
		check(gun.ammo==40,"open top latch blocks discharge")
		hand_at(gun.TOP_SEAT,0)
		check(gun.magazine.position.is_equal_approx(gun.TOP_SEAT),"releasing incomplete removal resets physical magazine")
		hand_at(gun.TOP_SEAT,1)
		hand_at(gun.TOP_SEAT+Vector3(0,0.11,0),1)
		check(gun.reload_state=="needs_mag",handedness+" lift clears horizontal top magazine")
		firing.set_input("primary",Vector2.ZERO)
		hand_at(gun.OFFER_POINT,0)
		hand_at(gun.OFFER_POINT,1)
		check(gun.reload_state=="needs_mag","bottom-well gesture cannot acquire top offer")
		hand_at(gun.TOP_OFFER,0)
		hand_at(gun.TOP_OFFER,1)
		check(gun.reload_state=="held_mag",handedness+" fresh grip offered magazine")
		hand_at(gun.TOP_OFFER+Vector3(0,0.12,0),1)
		check(gun.reload_state=="held_mag" and provider.rounds==80,"upward movement cannot seat horizontal top magazine")
		hand_at(gun.TOP_SEAT,1)
		check(gun.reload_state=="needs_rack" and gun.ammo==0 and provider.rounds==40,handedness+" downward seat consumes exact reserve before chamber")
		hand_at(Vector3(-0.05,0.064,-0.10),0)
		hand_at(Vector3(-0.05,0.064,-0.10),1)
		hand_at(Vector3(-0.05,0.064,-0.02),1)
		check(gun.reload_state=="ready" and gun.ammo==40,handedness+" charging handle chambers")
		support.set_input("grip",0.0)
		firing.set_input("trigger",0.0)
		gun._process(0.2)
		var head_before:Transform3D=actor.get_view_camera().global_transform
		firing.set_input("trigger",1.0)
		gun._process(0.01)
		check(gun.ammo==39,handedness+" tracked automatic shot")
		gun._process(0.08)
		check(gun.ammo==38,handedness+" held trigger produces second shot")
		check(actor.get_view_camera().global_transform.is_equal_approx(head_before),"no camera kick")
		check(gun.model.rotation.x>0 and gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,0.045,-0.46)))<0.001,"recoiling real compact muzzle")
		firing.set_input("trigger",0.0)
		gun._process(1.0)
		gun.left_hand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(0.24,0,0))
		var raw:Transform3D=gun.left_hand.global_transform
		support.set_input("grip",1.0)
		gun._update_support(0.1)
		check(gun.supported,handedness+" acquires inside 25cm")
		check(gun.left_hand.global_transform.is_equal_approx(raw),"raw tracked pose preserved")
		var glove:=gun.left_hand.get_node("ArticulatedGlove") as Node3D
		check(glove.global_position.distance_to(gun.model.to_global(gun.FOREGRIP_POINT))<0.001,"glove contacts compact foregrip")
		gun.left_hand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(0.44,0,0))
		gun._update_support(0.1)
		check(gun.supported,"support retained within 45cm")
		gun.left_hand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(0.46,0,0))
		gun._update_support(0.1)
		check(not gun.supported,"support released beyond 45cm")
		support.set_input("grip",0.0)
		gun._update_support(0.1)
		gun.eject_magazine()
		gun.desktop_reload_step()
		provider.rounds=5
		gun.desktop_reload_step()
		gun.desktop_reload_step()
		check(gun.ammo==5 and provider.rounds==0,"desktop fallback partial reserve physical stages")
		gun.eject_magazine()
		gun.desktop_reload_step()
		check(gun.reload_state=="needs_mag" and not gun.hip_source.visible,"zero reserve cannot conjure magazine")
		check(gun.model.find_children("*","Label3D",true,false).size()==1,"only ammo readout text")
		gun.reset_weapon()
		gun.supported=false
		gun._kick_recoil(0.052,deg_to_rad(5.5))
		var one_pitch:float=gun.recoil_pitch
		check(is_equal_approx(one_pitch,deg_to_rad(55.0)),"deterministic tenfold one-hand kick")
		gun.reset_weapon()
		gun.supported=true
		gun._kick_recoil(0.052,deg_to_rad(5.5))
		check(is_equal_approx(gun.recoil_pitch,deg_to_rad(5.5)*3.0*0.38),"threefold prior supported kick")
		gun.reset_weapon()
		gun._kick_recoil(0.052,deg_to_rad(5.5))
		check(is_equal_approx(gun.recoil_pitch,one_pitch),"reset repeats deterministic first recoil")
		gun.reset_weapon()
		firing.set_input("trigger",1.0)
		gun._suspend_gestures()
		gun._poll_vr()
		check(gun.ammo==40,"held trigger after suspension cannot fire")
		firing.set_input("trigger",0.0)
		gun._poll_vr()
		firing.set_input("trigger",1.0)
		gun._poll_vr()
		check(gun.ammo==39,"fresh trigger after suspension fires")
		firing.set_input("trigger",0.0)
		gun.shutdown()
		await create_timer(0.2).timeout
		gun.free()
		provider.free()
	XRServer.remove_tracker(left)
	XRServer.remove_tracker(right)
	actor.free()
	await process_frame
	print("TOP_FEED_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)




