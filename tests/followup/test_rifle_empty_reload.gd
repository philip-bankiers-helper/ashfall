extends SceneTree
## Synthetic controller inputs through production readiness and rifle gesture code.
class VRRifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
var failures:=0
var checks:=0
var shot_count:=0
var actor
var gun
var left:XRControllerTracker
var right:XRControllerTracker
func check(ok:bool,message:String)->void:
	checks+=1
	print("PASS " if ok else "FAIL ",message)
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
func neutral()->void:
	left.set_input("grip",0.0)
	right.set_input("trigger",0.0)
	right.set_input("primary_click",false)
	right.set_input("primary",Vector2.ZERO)
	actor.update_hand_input_rearm(0.1)
	gun._poll_vr()
func hand_at(local_point:Vector3,grip:float)->void:
	actor.left_hand.global_position=gun.to_global(local_point)
	left.set_input("grip",grip)
	gun._poll_vr()
func physical_reload()->void:
	var offer:Vector3=gun.to_local(gun.get_offered_magazine_transform().origin)
	hand_at(offer,0)
	hand_at(offer,1)
	check(gun.reload_state=="held_mag" and gun.loose_magazine.visible and not gun.magazine.visible and not gun.hip_source.visible,"fresh grip acquires visible offered magazine")
	hand_at(offer+Vector3(0,.02,0),1)
	check(gun.reload_state=="held_mag","small upward jitter does not insert")
	hand_at(gun.INSERT_POINT,1)
	check(gun.reload_state=="needs_rack" and gun.magazine.visible and not gun.loose_magazine.visible and gun.ammo==0,"actual upward insertion seats visible magazine without ammunition readiness")
	hand_at(Vector3(-.05,.064,-.10),1)
	check(not gun._rack_grabbed,"continued insertion grip cannot grab charging handle")
	hand_at(Vector3(-.05,.064,-.10),0)
	hand_at(Vector3(-.05,.064,-.10),1)
	hand_at(Vector3(-.05,.064,-.02),1)
	check(gun.reload_state=="ready" and gun.ammo==24 and gun.magazine.visible and not gun.hip_source.visible,"fresh charging grip and rearward travel complete physical reload")
func _initialize()->void:call_deferred("run")
func run()->void:
	actor=load("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_physics_process(false)
	actor.set_process(false)
	left=tracker("rifle_reload_test_left",actor.left_hand)
	right=tracker("rifle_reload_test_right",actor.right_hand)
	await process_frame
	gun=VRRifle.new()
	root.add_child(gun)
	gun.setup(actor,false)
	gun.set_process(false)
	gun.set_physics_process(false)
	gun.global_transform=Transform3D.IDENTITY
	gun.shot.connect(func(_origin,_direction,_damage):shot_count+=1)
	neutral()
	gun.ammo=1
	gun.cooldown=0
	right.set_input("trigger",1.0)
	gun._poll_vr()
	check(shot_count==1 and gun.ammo==0 and gun.reload_state=="needs_mag","last round emits one shot then automatically ejects")
	check(not gun.magazine.visible and not gun.loose_magazine.visible and gun.hip_source.visible,"empty rifle immediately offers visible replacement magazine")
	physical_reload()
	gun.cooldown=0
	gun._poll_vr()
	check(shot_count==1 and gun.ammo==24,"held trigger after physical reload cannot fire")
	right.set_input("trigger",0.0);gun._poll_vr()
	right.set_input("trigger",1.0);gun._poll_vr()
	check(shot_count==2 and gun.ammo==23,"released then freshly pressed trigger fires after reload")
	neutral()
	gun.cooldown=0
	gun.ammo=0
	right.set_input("trigger",1.0);gun._poll_vr()
	check(gun.reload_state=="needs_mag" and gun.hip_source.visible and shot_count==2,"legacy ready plus zero ammunition recovers without phantom shot")
	gun.reset_weapon();neutral()
	gun.ammo=7
	right.set_input("primary_click",true);gun._poll_vr()
	check(gun.reload_state=="needs_mag" and gun.ammo==0,"fresh thumbstick click ejects partial magazine")
	physical_reload()
	gun._poll_vr()
	check(gun.reload_state=="ready" and gun.ammo==24,"held click throughout reload cannot eject newly seated magazine")
	right.set_input("primary_click",false);gun._poll_vr()
	right.set_input("primary_click",true);gun._poll_vr()
	check(gun.reload_state=="needs_mag","release then fresh click ejects again")
	gun.reset_weapon();neutral()
	actor.input_enabled=false
	right.set_input("primary_click",true);gun._poll_vr()
	actor.input_enabled=true
	gun._poll_vr()
	check(gun.reload_state=="ready","held click across paused input does not eject on resume")
	neutral()
	right.set_input("primary_click",true);gun._poll_vr()
	check(gun.reload_state=="needs_mag","fresh click after neutral recovery ejects")
	var action_map=load("res://openxr_action_map.tres")
	var touch_binding:=false
	for profile in action_map.interaction_profiles:
		if str(profile.interaction_profile_path)!="/interaction_profiles/oculus/touch_controller":continue
		for binding in profile.bindings:
			if binding.action.resource_name=="primary_click" and binding.binding_path=="/user/hand/right/input/thumbstick/click":touch_binding=true
	check(touch_binding,"Oculus Touch OpenXR profile binds right thumbstick click to primary_click")
	gun.shutdown()
	await create_timer(.2).timeout
	gun.free();actor.free()
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	left=null;right=null
	action_map=null
	await process_frame
	print("RIFLE_EMPTY_RELOAD_RESULT checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)
