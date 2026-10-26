extends SceneTree
class Rifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
class Pistol extends "res://scripts/pistol.gd":
	func _vr_active()->bool:return true
class Double extends "res://scripts/shotgun.gd":
	func _vr_active()->bool:return true
class Pump extends "res://scripts/pump_shotgun.gd":
	func _vr_active()->bool:return true
class Auto extends "res://scripts/auto_shotgun.gd":
	func _vr_active()->bool:return true
class Precision extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
class Revolver extends "res://scripts/revolver.gd":
	func _vr_active()->bool:return true
class SMG extends "res://scripts/compact_smg.gd":
	func _vr_active()->bool:return true
class Burst extends "res://scripts/burst_carbine.gd":
	func _vr_active()->bool:return true
class LMG extends "res://scripts/belt_lmg.gd":
	func _vr_active()->bool:return true
class PDW extends "res://scripts/top_feed_pdw.gd":
	func _vr_active()->bool:return true
class Pair extends "res://scripts/dual_pistols.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
var captured:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var trackers:Array=[]
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="shot_order045_"+str(hand.get_instance_id());XRServer.add_tracker(t);trackers.append(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0)
	await process_frame;actor.update_hand_input_rearm(.1)
	for kind in [Rifle,Pistol,Double,Pump,Auto,Precision,Revolver,SMG,Burst,LMG,PDW]:
		var gun=kind.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._requires_trigger_release=false
		captured.clear()
		if gun.has_signal("pellet_shot"):
			gun.pellet_shot.connect(func(origin:Vector3,directions:Array[Vector3],_damage:float):
				var center:=Vector3.ZERO
				for direction in directions:center+=direction
				captured.append({"origin":origin,"direction":center.normalized()}))
		else:gun.shot.connect(func(origin:Vector3,direction:Vector3,_damage:float):captured.append({"origin":origin,"direction":direction}))
		var fallback:Transform3D=gun.get_shot_transform();gun.fire()
		check(captured.size()==1 and captured[0].origin.distance_to(fallback.origin)<.00001 and captured[0].direction.dot(-fallback.basis.z)>.99999,"first undisplayed fallback is captured before kick")
		gun.reset_weapon();gun._requires_trigger_release=false
		for property in gun.get_property_list():
			if property.name in ["_semi_armed","_semi_release","_semi_ready","_burst_armed"]:gun.set(property.name,true)
		captured.clear()
		var displayed:Transform3D=gun.get_shot_transform();gun.publish_displayed_aim(displayed)
		gun.model.rotate_y(.25) # A newly sampled aim must not replace the actually displayed ray.
		gun.fire()
		var label:String=str(gun.get_script().get_base_script().resource_path)
		check(captured.size()==1,label+" emits one shot")
		if captured.size()==1:
			check(captured[0].origin.distance_to(displayed.origin)<.00001,label+" exact displayed muzzle origin before recoil")
			check(captured[0].direction.dot(-displayed.basis.z.normalized())>.99999,label+" displayed aim or pellet center before recoil")
		check(gun.recoil_pitch>0 and gun.recoil_pitch<.25,label+" controllable nonzero kick replaces extreme multiplier")
		if gun is Burst:
			gun._process(.10)
			check(captured.size()==2 and captured[1].origin.distance_to(displayed.origin)<.00001 and captured[1].direction.dot(-displayed.basis.z)>.99999,"burst timer after base process retains exact public displayed aim until next publication")
		gun.suspend_for_selection();check(not gun._displayed_pose_valid,label+" switch invalidates old aim publication")
		gun.shutdown();await create_timer(.12).timeout;gun.free()
	var pair:=Pair.new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
	for i in range(2):
		var gun=pair.guns[i];captured.clear();gun.shot.connect(func(origin:Vector3,direction:Vector3,_damage:float):captured.append({"origin":origin,"direction":direction}))
		var shown:Transform3D=gun.get_shot_transform();shown.origin+=Vector3(i*.1,0,0);gun.publish_displayed_aim(shown);gun._requires_trigger_release=false;gun.fire()
		check(captured.size()==1 and captured[0].origin.distance_to(shown.origin)<.00001 and captured[0].direction.dot(-shown.basis.z)>.99999,"dual "+str(i)+" owns displayed pre-kick shot ray")
	pair.shutdown();await create_timer(.12).timeout;pair.free()
	var baseline:=Rifle.new();root.add_child(baseline);baseline.setup(actor,false);baseline.set_process(false);baseline.set_physics_process(false)
	baseline.supported=false;baseline._kick_recoil(.052,deg_to_rad(5.5));var one:float=baseline.recoil_pitch
	baseline.recoil_pitch=0;baseline.recoil=0;baseline.recoil_pattern_index=0;baseline.supported=true;baseline._kick_recoil(.052,deg_to_rad(5.5))
	check(is_equal_approx(one,deg_to_rad(5.5)) and is_equal_approx(baseline.recoil_pitch,one*.38),"deterministic 1.0 one-hand and .38 supported baseline")
	baseline.shutdown();baseline.free()
	for t in trackers:XRServer.remove_tracker(t)
	actor.free();await process_frame
	print("SHOT_ORDER_045 checks=",checks," failures=",failures," synthetic=true headset_tested=false");quit(failures)

