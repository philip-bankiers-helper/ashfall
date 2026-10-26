extends SceneTree
# Synthetic XR trackers exercise real hand publication, grip correction, sword
# physics sampling, world shape queries and contact callbacks. No XR runtime.
class Sword extends "res://scripts/melee_sword.gd":
	func _vr_active()->bool:return true
class Victim extends StaticBody3D:
	var amounts:Array[float]=[]
	func take_melee_damage(amount:float)->void:amounts.append(amount)
var actor
var sword
var trackers:Dictionary={}
var checks:=0
var failures:=0
var origin:=Vector3(0,1.1,-.8)
const POSE_BASIS:=Basis(Vector3.RIGHT,PI*.5)
func _initialize()->void:Engine.max_fps=240;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func step(at:Vector3,hz:int,basis:Basis=POSE_BASIS)->void:
	var desired:=Transform3D(basis,at)
	var raw:=desired*Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)
	trackers[actor.get_weapon_hand()].set_pose("grip",raw,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	actor.update_hand_input_rearm(1.0/hz)
	sword._physics_process(1.0/hz)
func move_between(a:Vector3,b:Vector3,hz:int,speed:float=2.0)->void:
	var steps:=maxi(1,ceili(a.distance_to(b)/speed*hz))
	for i in range(1,steps+1):await step(a.lerp(b,float(i)/steps),hz)
func target(at:Vector3,radius:float=.04)->Victim:
	var v:=Victim.new();v.collision_layer=4;root.add_child(v);v.position=at
	var c:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=radius;c.shape=shape;v.add_child(c)
	return v
func clear_history()->void:sword._history_valid=false;sword._reset_stroke()
func run()->void:
	load("res://scripts/audio_bank.gd").ensure_buses()
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	actor.xr_enabled=true;actor.tracking_available=true;actor.input_enabled=true;actor.xr_camera.position.y=1.404
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.name="melee071_"+str(hand.get_instance_id());t.type=XRServer.TRACKER_CONTROLLER;XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	sword=Sword.new();root.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false)
	sword.melee_contact.connect(func(body:Node3D,_point:Vector3,amount:float,_direction:Vector3):body.take_melee_damage(amount))
	var midpoint:Vector3=sword.blade_base.position.lerp(sword.blade_tip.position,.65)
	for side in ["left","right"]:
		actor.dominant_hand=side;sword.refresh_hands()
		for hz in [30,72,90,120]:
			for axis in [Vector3.RIGHT,Vector3.UP]:
				var v:=target(origin+POSE_BASIS*midpoint);await physics_frame;await physics_frame
				clear_history();await step(origin-axis*.18,hz)
				check(sword._usable() and sword._history_valid,"real tracker usable "+side+str(hz))
				for repeat in 4:
					var a:Vector3=origin+axis*(-.18 if repeat%2==0 else .18)
					var b:Vector3=origin+axis*(.18 if repeat%2==0 else -.18)
					await move_between(a,b,hz)
					check(v.amounts.size()==repeat+1,"exit/reenter %s %dHz %s strike%d"%[side,hz,str(axis),repeat])
					if not v.amounts.is_empty():check(v.amounts.back()>=68 and v.amounts.back()<=75.01,"hand speed controls25..75 damage")
				# Enter then move along the blade axis: speed/direction changes inside
				# the body must not cause another hit, even after audio resets.
				await move_between(origin-axis*.18,origin,hz)
				var count:=v.amounts.size()
				for i in 20:await step(origin+Vector3(0,0,.025 if i%2==0 else -.025),hz)
				check(v.amounts.size()==count,"continuous intersection never repeats")
				for i in 20:await step(origin+axis*(.0005 if i%2==0 else -.0005),hz)
				check(v.amounts.size()==count,"resting jitter never repeats")
				# Equip/rest contact primes occupancy without damage.
				clear_history();v.amounts.clear();await step(origin,hz)
				for i in 8:await step(origin+axis*(.0002 if i%2==0 else -.0002),hz)
				check(v.amounts.is_empty(),"initial overlap and resting jitter do not hit")
				v.free()
			# A full crossing and immediate return each fit inside one frame. No
			# endpoint overlap, wall-clock wait, reset or vertical lift required.
			var thin:=target(origin+POSE_BASIS*midpoint,.008);await physics_frame;await physics_frame
			clear_history();await step(origin+Vector3.LEFT*.2,hz);await step(origin+Vector3.RIGHT*.2,hz);await step(origin+Vector3.LEFT*.2,hz)
			check(thin.amounts.size()==2,"thin target swept tunneling reentry "+side+str(hz));thin.free()
			var a:=target(origin+POSE_BASIS*midpoint+Vector3.LEFT*.12)
			var b:=target(origin+POSE_BASIS*midpoint+Vector3.RIGHT*.12);await physics_frame;await physics_frame
			clear_history();await step(origin+Vector3.LEFT*.3,hz);await step(origin+Vector3.RIGHT*.3,hz)
			check(a.amounts.size()==1 and b.amounts.size()==1,"independent contact state per target")
			await step(origin+Vector3.LEFT*.3,hz)
			check(a.amounts.size()==2 and b.amounts.size()==2,"both targets immediately rearm on exit")
			a.free();b.free()
			# Wrist-only arc: tip movement enables contact, stationary hand gives25.
			var wrist:=target(origin+POSE_BASIS*midpoint,.035);await physics_frame;await physics_frame
			clear_history();await step(origin,hz,Basis(Vector3.UP,-.35)*POSE_BASIS)
			await step(origin,hz,Basis(Vector3.UP,.35)*POSE_BASIS)
			await step(origin,hz,Basis(Vector3.UP,-.35)*POSE_BASIS)
			check(wrist.amounts.size()==2,"wrist rotational reversal reenters "+side+str(hz))
			for amount in wrist.amounts:check(is_equal_approx(amount,25),"stationary hand rotational tip is minimum damage")
			wrist.free()
	check(is_equal_approx(sword.swing_damage(0),25) and is_equal_approx(sword.swing_damage(1),50) and is_equal_approx(sword.swing_damage(2),75) and is_equal_approx(sword.swing_damage(10),75),"linear hand damage curve clamps25..75 at2m/s")
	sword.full_damage_hand_speed=4.0;check(is_equal_approx(sword._damage_for_swing(2,999),50),"full-damage hand threshold tunable, travel does not inflate damage")
	for t in trackers.values():XRServer.remove_tracker(t)
	sword.shutdown();sword.free();actor.free();await process_frame;await create_timer(.5).timeout
	print("MELEE_CONTACT_071 checks=",checks," failures=",failures," synthetic_trackers=true actual_physics_queries=true xr_runtime_off=true headset_verified=false")
	quit(failures)


