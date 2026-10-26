extends SceneTree
class Rack extends Node3D:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	var trackers:Array=[]
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="crosshair040_"+str(hand.get_instance_id())
		XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		for input in ["grip","trigger"]:tracker.set_input(input,0.0)
		tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false)
		trackers.append(tracker)
	await process_frame
	actor.update_hand_input_rearm(.2);actor.xr_enabled=true
	for side in ["right","left"]:
		actor.dominant_hand=side
		for path in ["weapon","shotgun","pistol","burst_carbine","pump_shotgun","precision_rifle","compact_smg","revolver","belt_lmg","auto_shotgun","top_feed_pdw"]:
			var gun=load("res://scripts/"+path+".gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			var rack:=Rack.new();rack.weapons=[gun];root.add_child(rack)
			var game:=Game.new();root.add_child(game)
			var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false)
			var tag=side+" "+path+" "
			check(reticle.get_child_count()==8 and reticle.white_parts.size()==4,tag+"four black and four red arms")
			for child in reticle.get_children():
				var half:Vector2=child.mesh.size*.5
				check(absf(child.position.x)>half.x or absf(child.position.y)>half.y,tag+"arm leaves exact center empty")
			var black=reticle.get_child(0)
			check(is_equal_approx(black.position.x+black.mesh.size.x*.5,.5),tag+"normalized outer extent retained")
			for kick in [false,true]:
				gun.recoil_pitch=deg_to_rad(12) if kick else 0.0
				gun.model.rotation.x=gun.recoil_pitch;gun.model.position.z=.08 if kick else 0
				reticle.update_reticle()
				if path=="precision_rifle":
					check(not reticle.visible,tag+"S01 no ordinary sniper crosshair even with recoil "+str(kick))
					continue
				var pose:Transform3D=gun.get_shot_transform()
				check(reticle.visible and reticle.ray_origin.distance_to(pose.origin)<.00001 and reticle.ray_direction.dot(-pose.basis.z.normalized())>.999999,tag+"camera reticle follows actual muzzle including recoil "+str(kick))
				var old_size:=clampf(actor.get_view_camera().global_position.distance_to(reticle.global_position)*.010,.010,.60)
				check(is_equal_approx(reticle.scale.x,old_size*4),tag+"exactly fourfold 039 extent "+str(kick))
				check(reticle.global_basis.orthonormalized().is_equal_approx(actor.get_view_camera().global_basis.orthonormalized()),tag+"camera facing preserved")
				check(reticle.global_position.distance_to(reticle.hit_position-reticle.ray_direction*.015)<.00001,tag+"open center remains on weapon ray")
				for arm in reticle.white_parts:check(is_equal_approx(arm.position.z*reticle.scale.x,.01),tag+"red depth separation constant")
			gun.queue_free();rack.queue_free();game.queue_free();reticle.queue_free();await process_frame
	for tracker in trackers:XRServer.remove_tracker(tracker)
	actor.queue_free();await process_frame
	print("CROSSHAIR_042 ",checks," checks ",failures," failures; headset_tested=false")
	quit(1 if failures else 0)
