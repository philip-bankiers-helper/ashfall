extends SceneTree
# Production player/controller input, production _process/_poll_vr/fire/model paths.
# Only XR session presence is adapted; this is not a physical headset test.
class Rifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
class Shotgun extends "res://scripts/shotgun.gd":
	func _vr_active()->bool:return true
class Rack extends Node3D:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var failures:=0
var checks:=0
var trackers:Dictionary={}
var actor
var last_ray:=Vector3.ZERO
var last_origin:=Vector3.ZERO
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _initialize():call_deferred("run")
func fired(origin:Vector3,direction:Vector3,_damage:float):
	last_ray=direction;last_origin=origin
func pellets(origin:Vector3,directions:Array[Vector3],_damage:float):
	last_origin=origin;last_ray=Vector3.ZERO
	for direction in directions:last_ray+=direction
	last_ray=last_ray.normalized()
func frame(gun,delta:float=.011111):gun._process(delta)
func neutral(gun):
	for t in trackers.values():
		t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
	actor.update_hand_input_rearm(.2)
	gun._poll_vr()
func run():
	print("SCOPE synthetic XR trackers, production input-to-mesh/shot; headset_tested=false")
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="recoil038_"+str(hand.get_instance_id())
		XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trackers[hand]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for kind in ["rifle","shotgun"]:
			var gun=Rifle.new() if kind=="rifle" else Shotgun.new()
			root.add_child(gun);gun.setup(actor,false);gun.set_process(false)
			if kind=="rifle":gun.shot.connect(fired)
			else:gun.pellet_shot.connect(pellets)
			neutral(gun);gun.reset_weapon();neutral(gun)
			frame(gun)
			var rack:=Rack.new();rack.weapons=[gun];root.add_child(rack)
			var game:=Game.new();root.add_child(game)
			var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false)
			actor.xr_enabled=true
			var tag=side+" "+kind+" "
			var camera_before:Transform3D=actor.get_view_camera().global_transform
			var offhand=gun.left_hand
			var visual=offhand.get_node("ArticulatedGlove")
			var rest:Transform3D=visual.transform
			# A grip at a distant location cannot attach.
			offhand.global_position=gun.reload_world_point(Vector3(.5,0,-.36))
			trackers[offhand].set_input("grip",1.0);frame(gun)
			check(not gun.supported and visual.transform.is_equal_approx(rest),tag+"distant grip does not attach")
			trackers[offhand].set_input("grip",0.0);frame(gun)
			reticle.update_reticle()
			var baseline:Transform3D=gun.get_shot_transform()
			var before_ammo:int=gun.ammo
			trackers[gun.right_hand].set_input("trigger",1.0);frame(gun)
			check(gun.ammo==before_ammo-1,tag+"real tracker trigger consumes round")
			var first_kicked:Transform3D=gun.get_shot_transform()
			check(last_origin.distance_to(baseline.origin)<.001 and last_ray.dot(-baseline.basis.z)>.9999,tag+"first emitted ray follows pre-kick displayed muzzle")
			var one_angle:float=gun.model.rotation.x
			var one_distance:float=gun.model.position.z
			check(one_angle>deg_to_rad(4) and one_distance>.04,tag+"shot visibly pitches and translates actual model")
			check((-gun.get_shot_transform().basis.z).angle_to(last_ray)>.001 and last_ray.angle_to(-baseline.basis.z)<.001,tag+"visible kick follows shot instead of moving its target")
			reticle.update_reticle()
			check(reticle.visible and reticle.ray_origin.distance_to(gun.get_shot_transform().origin)<.001 and reticle.ray_direction.dot(-gun.get_shot_transform().basis.z)>.99999,tag+"actual reticle follows post-shot kicked barrel")
			trackers[gun.right_hand].set_input("trigger",0.0);frame(gun,.05)
			check(gun.model.rotation.x>one_angle*.5,tag+"kick survives several headset frames")
			# Respect normal cooldown and semi-auto release; compare the next actual ray.
			frame(gun,gun.fire_interval-.05+.001)
			reticle.update_reticle()
			var followup:Transform3D=gun.get_shot_transform()
			trackers[gun.right_hand].set_input("trigger",1.0);frame(gun,0.0)
			var second_kicked:Transform3D=gun.get_shot_transform()
			check(last_ray.dot(-followup.basis.z)>.99999 and last_origin.distance_to(followup.origin)<.001 and last_ray.angle_to(-second_kicked.basis.z)>.001,tag+"second trigger uses displayed recovered aim then adds new kick")
			check(last_ray.angle_to(-baseline.basis.z)>.001,tag+"second emitted shot contains accumulated recoil")
			# Identical reset, attach through spatial controller grip, then fire.
			gun.reset_weapon();neutral(gun);frame(gun)
			offhand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(.035,0,0))
			var raw_before:Transform3D=offhand.global_transform
			trackers[offhand].set_input("grip",1.0);frame(gun)
			check(gun.supported and visual.global_position.distance_to(gun.model.to_global(gun.FOREGRIP_POINT))<.001,tag+"grip input attaches rendered hand at foregrip")
			check(offhand.global_transform.is_equal_approx(raw_before),tag+"attachment preserves raw tracking")
			trackers[gun.right_hand].set_input("trigger",1.0);frame(gun)
			check(gun.model.rotation.x>0 and gun.model.rotation.x<one_angle*.5 and gun.model.position.z<one_distance*.5,tag+"spatially supported shot has less visible angular and linear recoil")
			reticle.update_reticle()
			check(reticle.visible and reticle.ray_direction.dot(-gun.get_shot_transform().basis.z)>.99999,tag+"supported reticle follows reduced recoil")
			check(visual.global_position.distance_to(gun.model.to_global(gun.FOREGRIP_POINT))<.001,tag+"attached glove follows kicked foregrip")
			check(actor.get_view_camera().global_transform.is_equal_approx(camera_before),tag+"fire never changes headset camera")
			trackers[offhand].set_input("grip",0.0);trackers[gun.right_hand].set_input("trigger",0.0);frame(gun)
			check(not gun.supported and visual.transform.is_equal_approx(rest),tag+"physical grip release restores tracked glove")
			trackers[offhand].set_input("grip",1.0);frame(gun)
			offhand.global_position+=Vector3(1,0,0);frame(gun)
			check(not gun.supported and visual.transform.is_equal_approx(rest),tag+"leaving grip reach detaches")
			trackers[offhand].set_input("grip",0.0);frame(gun)
			offhand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT)
			trackers[offhand].set_input("grip",1.0);frame(gun)
			trackers[offhand].invalidate_pose("grip");actor.update_hand_input_rearm(.01);frame(gun)
			check(not gun.supported and visual.transform.is_equal_approx(rest),tag+"tracking loss detaches without stale support")
			trackers[offhand].set_input("grip",0.0)
			trackers[offhand].set_pose("grip",offhand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
			for v in gun._shot_voices:v.stop()
			gun._sound.stop();gun.queue_free();reticle.queue_free();rack.queue_free();game.queue_free();await process_frame
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.queue_free();await process_frame;await create_timer(.1).timeout
	print("RECOIL_FOREGRIP_038 ",checks-failures,"/",checks)
	quit(1 if failures else 0)



