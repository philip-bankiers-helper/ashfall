extends SceneTree
class Sword extends "res://scripts/melee_sword.gd":
	func _vr_active()->bool:return true
class Victim extends StaticBody3D:
	var hits:=0
	func take_melee_damage(_amount:float)->void:hits+=1
var checks:=0
var failures:=0
var actor
var sword
var trackers:Dictionary={}
func _initialize()->void:Engine.max_fps=120;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func step(angle:float,height:float,hz:int)->void:
	var desired:=Transform3D(Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,PI*.5),Vector3(0,height,-.4))
	var raw:=desired*Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)
	trackers[actor.get_weapon_hand()].set_pose("grip",raw,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	actor.update_hand_input_rearm(1.0/hz)
	sword._physics_process(1.0/hz)
func stroke(signum:int,height:float,hz:int)->void:
	for i in 121:await step(signum*lerpf(-.6,.6,float(i)/120),height,hz)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	actor.xr_enabled=true;actor.tracking_available=true;actor.input_enabled=true;actor.xr_camera.position.y=1.404
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.name="diagnostic_"+str(hand.get_instance_id());t.type=XRServer.TRACKER_CONTROLLER;XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	sword=Sword.new();root.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false)
	for side in ["left","right"]:
		actor.dominant_hand=side;sword.refresh_hands()
		for hz in [72,90,120]:
			for height in [1.1]:
				for signum in [-1,1]:
					var target:=Victim.new();root.add_child(target);target.collision_layer=4
					target.position=Vector3(0,height,-.4)+Basis(Vector3.RIGHT,PI*.5)*sword.blade_base.position.lerp(sword.blade_tip.position,.8)
					var col:=CollisionShape3D.new();var ball:=SphereShape3D.new();ball.radius=.045;col.shape=ball;target.add_child(col)
					var cb:=func(body:Node3D,_point:Vector3,amount:float,_direction:Vector3):
						if body==target:target.take_melee_damage(amount)
					sword.melee_contact.connect(cb);await physics_frame;await physics_frame
					sword._history_valid=false;sword._reset_stroke();sword._target_next_ms.clear()
					await step(-.6*signum,height,hz)
					check(sword._usable() and sword._history_valid,"tracked usable/history "+side)
					var base0:Vector3=sword.blade_base.global_position;var tip0:Vector3=sword.blade_tip.global_position
					await step(-.55*signum,height,hz)
					check(tip0.distance_to(sword.blade_tip.global_position)>base0.distance_to(sword.blade_base.global_position),"wrist-only tip speed exceeds blade root speed")
					await stroke(signum,height,hz)
					check(target.hits==1,"tracked horizontal %s %dHz height%.1f direction%d"%[side,hz,height,signum])
					# Use actual wall clock cooldown, not simulated delta or clearing the map.
					pass # continuous alternating stroke, no rest/reset
					await stroke(-signum,height,hz)
					check(target.hits==2,"exit/reverse/reenter after300ms hits again")
					for i in 20:await step(-.6*signum,height,hz)
					check(target.hits==2,"resting contact does not repeat damage")
					await create_timer(.31).timeout
					await step(0,height,hz)
					var before_jitter:int=target.hits
					for j in 80:await step(.001 if j%2==0 else -.001,height,hz)
					check(target.hits==before_jitter,"sub-threshold reversal jitter never rearms damage")
					sword.melee_contact.disconnect(cb);target.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	sword.shutdown();sword._sound.stream=null;sword._hum.stream=null;sword.free();actor.free();await create_timer(.5).timeout
	print("HORIZONTAL_DIAGNOSTIC checks=",checks," failures=",failures," vr_runtime_off=true")
	quit(failures)
