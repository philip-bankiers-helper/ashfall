extends SceneTree
class VRRifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
class VRPistol extends "res://scripts/pistol.gd":
	func _vr_active()->bool:return true
class VRBurst extends "res://scripts/burst_carbine.gd":
	func _vr_active()->bool:return true
class VRPump extends "res://scripts/pump_shotgun.gd":
	func _vr_active()->bool:return true
class VRBreak extends "res://scripts/shotgun.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
var trackers:Dictionary={}
var ray:=Vector3.ZERO
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func visible_extent(model:Node3D)->AABB:
	var result:=AABB();var first:=true
	for node in model.find_children("*","MeshInstance3D",true,false):
		var shown:=true;var ancestor=node
		while ancestor!=model:
			if ancestor is Node3D and not ancestor.visible:shown=false;break
			ancestor=ancestor.get_parent()
		if not shown:continue
		var transform:Transform3D=model.global_transform.affine_inverse()*node.global_transform
		var bounds:AABB=node.get_aabb()
		for i in range(8):
			var point:=transform*bounds.get_endpoint(i)
			if first:result=AABB(point,Vector3.ZERO);first=false
			else:result=result.expand(point)
	return result
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.name="recoil040_"+str(hand.get_instance_id());tracker.type=XRServer.TRACKER_CONTROLLER
		XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for kind in [VRRifle,VRPistol,VRBurst,VRPump,VRBreak]:
			for t in trackers.values():t.set_input("trigger",0.0);t.set_input("grip",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
			actor.update_hand_input_rearm(0.1)
			var gun=kind.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			gun.global_transform=gun.corrected_grip_transform(gun.right_hand.global_transform)
			gun._poll_vr()
			var label:String=side+" "+str(gun.magazine_size)+" "
			var camera_pose:Transform3D=actor.get_view_camera().global_transform
			var raw:Transform3D=gun.right_hand.global_transform
			var sequence:Array[Vector3]=[]
			for i in range(6):
				gun._kick_recoil(.052,deg_to_rad(5.5));sequence.append(gun.model.rotation);gun._recover_recoil(.12)
			gun.reset_weapon()
			for i in range(6):
				gun._kick_recoil(.052,deg_to_rad(5.5))
				check(gun.model.rotation.is_equal_approx(sequence[i]),label+" deterministic pattern step "+str(i))
				gun._recover_recoil(.12)
			gun._recover_recoil(.81);gun._apply_recoil_visual()
			check(gun.recoil_pattern_index==0 and gun.model.rotation==Vector3.ZERO,label+" idle predictably resets pattern")
			gun.reset_weapon();gun.supported=false
			gun._kick_recoil(.052,deg_to_rad(5.5))
			var one_pitch:float=gun.recoil_pitch;var one_distance:float=gun.recoil
			gun.reset_weapon();gun.supported=true
			gun._kick_recoil(.052,deg_to_rad(5.5))
			check(is_equal_approx(gun.recoil_pitch/one_pitch,0.38) and is_equal_approx(gun.recoil/one_distance,0.38),label+" supported .38 versus onehand1 exact ratio")
			if gun is VRRifle:
				check(is_equal_approx(one_pitch,deg_to_rad(5.5)) and is_equal_approx(one_distance,.052),label+" controllable original first-shot magnitude")
			gun.reset_weapon();gun._poll_vr();gun.cooldown=0
			if gun.has_signal("pellet_shot"):
				gun.pellet_shot.connect(func(_origin,dirs,_damage):ray=dirs[0])
			else:gun.shot.connect(func(_origin,direction,_damage):ray=direction)
			var forward:Vector3=-gun.get_shot_transform().basis.z
			gun.fire()
			check(ray.dot(forward)>0.998,label+" real emitted shot follows pre-kick aim")
			check(actor.get_view_camera().global_transform.is_equal_approx(camera_pose) and gun.right_hand.global_transform.is_equal_approx(raw),label+" camera and raw weapon tracker unchanged")
			gun.reset_weapon();gun._poll_vr()
			if not gun is VRPistol:
				gun.left_hand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(.24,0,0))
				trackers[gun.left_hand].set_input("grip",1.0);gun._update_support(0)
				check(gun.supported,label+" acquire at24cm")
				gun.left_hand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(.44,0,0));gun._update_support(0)
				check(gun.supported,label+" retain at44cm")
				trackers[gun.left_hand].set_input("grip",0.0);gun._update_support(0)
				check(not gun.supported,label+" intentional grip release detaches")
				gun.left_hand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(.24,0,0));trackers[gun.left_hand].set_input("grip",1.0);gun._update_support(0)
				gun.left_hand.global_position=gun.reload_world_point(gun.FOREGRIP_POINT+Vector3(.46,0,0));gun._update_support(0)
				check(not gun.supported,label+" outside45cm detaches")
			if gun is VRPistol:
				var bounds:=visible_extent(gun.model)
				print("PISTOL_VISIBLE_BOUNDS ",bounds)
				check(bounds.size.z<.45 and bounds.size.x<.2,label+" pistol visible silhouette below45cm")
			gun.shutdown();await create_timer(.2).timeout;gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	trackers.clear();actor.free();await process_frame
	print("ARSENAL_RECOIL_040 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)





