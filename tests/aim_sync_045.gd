extends "res://tests/shot_order_045.gd"
class Rack extends Node3D:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.xr_camera.position.y=1.65;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="aim_sync045_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";trackers[hand]=t
	var game:=Game.new();root.add_child(game)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for kind in [Rifle,Pistol,Double,Pump,Auto,Precision,Revolver,SMG,Burst,LMG,PDW,Pair]:
			actor.rotation=Vector3.ZERO
			for hand in trackers:
				trackers[hand].set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(-.22 if hand==actor.left_hand else .22,1.35,-.25)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
				trackers[hand].set_input("grip",0.0);trackers[hand].set_input("trigger",0.0);trackers[hand].set_input("primary",Vector2.ZERO)
			await process_frame;actor.update_hand_input_rearm(.2)
			var gun=kind.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun.set_weapon_settings({"motion_damping":1.0,"offhand_influence":0.0,"grip_toggle":false});gun._process(.02)
			var rack:=Rack.new();rack.weapons=[gun];root.add_child(rack)
			var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false);reticle.update_reticle()
			var tag:String=side+" "+str(gun.get_script().get_base_script().resource_path)+" "
			var live:Array=gun.guns if gun is Pair else [gun]
			var old:Array=[]
			var observed:Array=[]
			for i in range(live.size()):
				var actual_reticle=reticle._paired_children[i] if gun is Pair else reticle
				old.append({"origin":actual_reticle.ray_origin,"direction":actual_reticle.ray_direction})
				check(actual_reticle.visible and live[i]._displayed_pose_valid,tag+"actual production reticle publishes visible ray "+str(i))
				if live[i].has_signal("pellet_shot"):
					live[i].pellet_shot.connect(func(origin:Vector3,directions:Array[Vector3],_damage:float):
						var center:=Vector3.ZERO
						for d in directions:center+=d
						observed.append({"index":i,"origin":origin,"direction":center.normalized()}))
				else:live[i].shot.connect(func(origin:Vector3,direction:Vector3,_damage:float):observed.append({"index":i,"origin":origin,"direction":direction}))
			# Advance actual tracked poses and body turn after the visible reticle pass.
			actor.rotate_y(.32)
			for hand in trackers:
				trackers[hand].set_pose("grip",Transform3D(Basis(Vector3.UP,.4),Vector3(-.31 if hand==actor.left_hand else .31,1.43,-.34)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
			await process_frame
			if not gun is Pair:
				var next_grip:Transform3D=gun.corrected_grip_transform(gun.right_hand.global_transform)
				gun.left_hand.global_position=next_grip*gun.FOREGRIP_POINT
				trackers[gun.left_hand].set_input("grip",1.0)
			for child in live:trackers[child.right_hand].set_input("trigger",1.0)
			var raw:Array=[actor.left_hand.global_transform,actor.right_hand.global_transform]
			gun._process(0)
			check(observed.size()==live.size(),tag+"actual fresh tracked triggers emit expected count")
			for shot in observed:
				check(shot.origin.distance_to(old[shot.index].origin)<.00001 and shot.direction.dot(old[shot.index].direction)>.99999,tag+"physics shot equals last visible reticle despite controller/body/support changes "+str(shot.index))
			check(actor.left_hand.global_transform.is_equal_approx(raw[0]) and actor.right_hand.global_transform.is_equal_approx(raw[1]),tag+"firing preserves both raw tracking transforms")
			reticle.update_reticle()
			for i in range(live.size()):
				var actual_reticle=reticle._paired_children[i] if gun is Pair else reticle
				if live[i].reload_state=="ready" and live[i].ammo>0:
					check(actual_reticle.visible and actual_reticle.ray_origin.distance_to(live[i].get_shot_transform().origin)<.00001 and actual_reticle.ray_direction.dot(-live[i].get_shot_transform().basis.z)>.99999,tag+"next visible reticle publishes current kicked muzzle "+str(i))
				else:check(not actual_reticle.visible,tag+"mechanical cycle correctly hides unavailable reticle")
			gun.suspend_for_selection()
			for child in live:check(not child._displayed_pose_valid,tag+"selection invalidates each old visible cache")
			# Switch to another actual gun and publish its own reticle; no prior cache leaks.
			for hand in trackers:trackers[hand].set_input("grip",0.0);trackers[hand].set_input("trigger",0.0)
			var replacement:=Rifle.new();root.add_child(replacement);replacement.setup(actor,false);replacement.set_process(false);replacement.set_physics_process(false);replacement._process(.02);rack.weapons=[replacement];reticle.update_reticle()
			check(reticle.visible and replacement.get_firing_pose().origin.distance_to(reticle.ray_origin)<.00001 and replacement.get_firing_pose().basis.z.dot(-reticle.ray_direction)>.99999,tag+"new selection owns fresh production reticle publication")
			replacement.shutdown();replacement.free();reticle.free();rack.free();gun.shutdown();await create_timer(.12).timeout;gun.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	game.free();actor.free();await process_frame
	print("AIM_SYNC_045 checks=",checks," failures=",failures," synthetic=true headset_tested=false");quit(failures)
