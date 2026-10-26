extends SceneTree
# Production reload polling and firing, synthetic tracked poses. No GPU/headset claim.
class PDW extends "res://scripts/top_feed_pdw.gd":
	func _vr_active()->bool:return true
class Rifle extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
class SMG extends "res://scripts/compact_smg.gd":
	func _vr_active()->bool:return true
class LMG extends "res://scripts/belt_lmg.gd":
	func _vr_active()->bool:return true
class Sight extends "res://scripts/authored_reflex_sight.gd":
	var test_eyes:Array[Transform3D]=[]
	func get_view_eye_poses(view_camera:Camera3D)->Array[Transform3D]:
		return test_eyes if not test_eyes.is_empty() else super.get_view_eye_poses(view_camera)
class Rack extends Node3D:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
class Reserve extends Node:
	var count:=100
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,n:int)->int:
		var taken:=mini(count,n);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,n:int)->int:
		var credited:=mini(n,9999-count);count+=credited;return credited
var actor
var trackers:Dictionary={}
var checks:=0
var failures:=0
var shots:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip);gun._poll_vr()
func neutral()->void:
	actor._grabs.clear();actor.left_hand_reserved=false
	for t in trackers.values():
		t.set_input("trigger",0.0);t.set_input("grip",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
	actor.update_hand_input_rearm(.2)
func stop(gun)->void:gun.shutdown();gun.free()
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="follow048_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side;neutral()
		var pdw:=PDW.new();root.add_child(pdw);pdw.setup(actor,false);pdw.set_process(false);pdw.set_physics_process(false);pdw._process(0)
		var reserve:=Reserve.new();root.add_child(reserve);pdw.ammo_provider=reserve;pdw.ammo_slot=0
		pdw.ammo=1;pdw._requires_trigger_release=false;trackers[pdw.right_hand].set_input("trigger",1.0);pdw._poll_vr()
		check(pdw.ammo==0 and pdw.reload_state=="needs_mag" and not pdw.magazine.visible,side+" final held-trigger P90 shot auto-ejects without thumb input")
		trackers[pdw.right_hand].set_input("trigger",0.0)
		check(pdw.insertion_arrow.basis.y.dot(Vector3.FORWARD)>.999,side+" P90 insertion arrow points forward")
		sample(pdw,pdw.get_top_offer(),0);sample(pdw,pdw.get_top_offer(),1)
		sample(pdw,pdw.get_top_offer()+Vector3.UP*.15,1)
		check(pdw.reload_state=="held_mag" and reserve.count==100,side+" UP cannot substitute for P90 FORWARD load")
		sample(pdw,pdw.get_top_offer(),0);sample(pdw,pdw.get_top_offer(),1);sample(pdw,pdw.get_top_offer()+Vector3.FORWARD*.17,1)
		check(pdw.reload_state=="needs_rack" and pdw._seated_rounds==40 and reserve.count==60,side+" actual offhand FORWARD seats top magazine once")
		sample(pdw,pdw.get_charge_point(),1);sample(pdw,pdw.get_charge_point()+Vector3.FORWARD*.09,1)
		check(pdw.reload_state=="needs_rack",side+" forward handle motion cannot charge P90")
		sample(pdw,pdw.get_charge_point()+Vector3.BACK*.08,1)
		check(pdw.reload_state=="ready" and pdw.ammo==40 and reserve.count==60,side+" BACK charge completes with continuous grip and no return")
		check(signf(pdw.get_charge_point().x)==(1.0 if side=="left" else -1.0),side+" P90 handle mirrors toward free hand")
		pdw.ammo=13;pdw.eject_magazine();pdw.eject_magazine()
		check(pdw.ammo==0 and reserve.count==73 and pdw.reload_state=="needs_mag",side+" early P90 eject refunds thirteen live rounds once")
		pdw.grab_magazine();pdw.insert_magazine();var total:int=pdw.get_loaded_rounds()+reserve.count;pdw.suspend_for_selection()
		check(pdw.reload_state=="needs_rack" and pdw.get_loaded_rounds()+reserve.count==total,side+" P90 seated mag survives switching without loss")
		pdw.eject_magazine();reserve.count=3;pdw.grab_magazine();pdw.insert_magazine();pdw.rack_bolt()
		check(pdw.ammo==3 and reserve.count==0,side+" P90 finite three-round partial reload")
		stop(pdw);reserve.free();neutral()
		# Real sight projection + production world reticle + production shot emission.
		var gun:=Rifle.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun.global_transform=Transform3D.IDENTITY
		var sight:=Sight.new();gun.model.add_child(sight);sight.setup("window",Transform3D(Basis.IDENTITY,Vector3(0,.115,-.1)),gun);sight.set_process(false);gun.set_meta("reflex_sight",sight)
		var rack:=Rack.new();root.add_child(rack);rack.weapons=[gun]
		var game:=Game.new();root.add_child(game)
		var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false)
		var view:Camera3D=actor.get_view_camera();view.global_transform=Transform3D(Basis.IDENTITY,sight.collimated_dot.global_position+Vector3.BACK*.25)
		reticle.update_reticle();var target:Vector3=sight.aim_target
		check(not reticle.visible and gun._displayed_pose_valid,side+" looking through sight hides world crosshair and publishes aim")
		var projection:Dictionary=sight.project_aim_to_lens(view.global_position)
		check(projection.valid and (projection.point-view.global_position).normalized().dot((target-view.global_position).normalized())>.999999,side+" dot projects actual ballistic target through lens")
		gun.shot.connect(func(origin:Vector3,direction:Vector3,_damage:float):shots.append({"origin":origin,"direction":direction}))
		var shown:Transform3D=gun.get_firing_pose();gun.cooldown=0;gun.fire();var fired:Dictionary=shots.back()
		check(fired.origin.distance_to(shown.origin)<.00001 and fired.direction.dot(-shown.basis.z)>.999999,side+" ADS shot equals displayed sight ray before kick")
		check((target-fired.origin).normalized().dot(fired.direction)>.999999,side+" collimated target lies on emitted shot axis")
		reticle.update_reticle()
		check(not gun.get_firing_pose().basis.is_equal_approx(shown.basis) and sight.aim_target.distance_to(target)>1.0,side+" next sight pass publishes changed recoil pose instead of freezing hidden crosshair cache")
		gun.reset_weapon();gun.global_transform=Transform3D.IDENTITY;view.global_transform=Transform3D(Basis.IDENTITY,sight.collimated_dot.global_position+Vector3.BACK*.25)
		view.rotate_y(.4);reticle.update_reticle()
		check(reticle.visible,side+" looking away from sight restores ordinary crosshair")
		view.global_transform=Transform3D(Basis.IDENTITY,sight.collimated_dot.global_position+Vector3(.07,0,.25));reticle.update_reticle()
		check(reticle.visible,side+" eye outside lens aperture restores ordinary crosshair")
		view.global_position=sight.collimated_dot.global_position+Vector3(.032,0,.25)
		sight.test_eyes.assign([Transform3D(Basis.IDENTITY,view.global_position+Vector3.LEFT*.032),Transform3D(Basis.IDENTITY,view.global_position+Vector3.RIGHT*.032)])
		reticle.update_reticle()
		check(not sight.project_aim_to_lens(view.global_position).valid and not reticle.visible,side+" actual individual-eye alignment hides crosshair even when head centre misses aperture")
		sight.test_eyes.clear();reticle.free();rack.free();game.free();stop(gun);neutral()
	# Real automatic fire at each gun's cycle time must keep raising the next ray.
	var all_sequences:Array=[]
	for kind in [Rifle,SMG,PDW,LMG]:
		var observed:Array=[]
		var gun=kind.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun.set_weapon_settings({"motion_damping":1.0,"offhand_influence":0.0});neutral();gun._process(0)
		gun.shot.connect(func(origin:Vector3,direction:Vector3,_damage:float):observed.append({"origin":origin,"direction":direction}))
		var sequence:Array[float]=[];var increments:Array[float]=[]
		for repeat in 2:
			gun.reset_weapon();neutral();gun._process(0)
			var previous:=0.0
			for step in 6:
				gun.publish_displayed_aim(gun.get_shot_transform());trackers[gun.right_hand].set_input("trigger",1.0);gun._poll_vr()
				var pitch:float=gun.recoil_pitch
				if repeat==0:
					sequence.append(pitch);increments.append(pitch-previous)
					check(pitch>previous,str(gun.get_recoil_profile_key())+" sustained shot accumulates UP step%d"%step)
				else:check(is_equal_approx(pitch,sequence[step]),str(gun.get_recoil_profile_key())+" repeats same pitch sequence step%d"%step)
				previous=pitch
				trackers[gun.right_hand].set_input("trigger",0.0);gun._process(gun.fire_interval+.0001)
			check(observed.size()==(repeat+1)*6,str(gun.get_recoil_profile_key())+" six real trigger events emit six shots")
		check(not is_equal_approx(increments[1],increments[2]) and not is_equal_approx(increments[2],increments[3]),str(gun.get_recoil_profile_key())+" nonuniform learned increments")
		all_sequences.append(sequence)
		var raw:Transform3D=gun.right_hand.global_transform;var pitch:float=gun.recoil_pitch;var yaw:float=gun.recoil_yaw
		var base:Basis=gun.global_basis;gun.global_basis=base*Basis.from_euler(Vector3(pitch,yaw,0)).inverse()
		check(gun.get_shot_transform().basis.z.dot(base.z)>.99999,str(gun.get_recoil_profile_key())+" lowering raw gun aim cancels accumulated kick")
		check(gun.right_hand.global_transform.is_equal_approx(raw),str(gun.get_recoil_profile_key())+" recoil never rewrites tracked controller")
		gun._recover_recoil(.81);gun._apply_recoil_visual();check(gun.recoil_pattern_index==0 and gun.model.rotation==Vector3.ZERO,str(gun.get_recoil_profile_key())+" idle settles and resets deterministic sequence")
		stop(gun)
	check(all_sequences[0]!=all_sequences[1] and all_sequences[1]!=all_sequences[2] and all_sequences[2]!=all_sequences[3],"automatic weapon families have distinct recoil sequences")
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await create_timer(.2).timeout
	print("FOLLOWUP_CONTROLS_048 checks=",checks," failures=",failures," synthetic=true headset_tested=false rendered_alignment_tested=false")
	quit(failures)
