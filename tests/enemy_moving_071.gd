extends SceneTree
const Enemy=preload("res://scripts/enemy.gd")
class Target extends CharacterBody3D:
	var exposure_provider:Node
	func get_aim_position()->Vector3:return global_position+Vector3.UP*1.4
var checks:=0
var failures:=0
var hits:=0
var visuals:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func offset_at(t:float,speed:float,mode:String,fire_time:float)->float:
	if mode=="stationary":return 0.0
	var reverse_at:=fire_time-.20
	return speed*t if mode=="lateral" or t<reverse_at else speed*(2*reverse_at-t)
func run()->void:
	var target:=Target.new();root.add_child(target);target.collision_layer=2
	var col:=CollisionShape3D.new();var ball:=SphereShape3D.new();ball.radius=.2;col.shape=ball;col.position.y=1.4;target.add_child(col)
	var unit:=Enemy.new();unit.setup(target,0);root.add_child(unit);unit.set_physics_process(false)
	unit.hit_player.connect(func(_amount:float):hits+=1)
	unit.shot_visual.connect(func(_a:Vector3,_b:Vector3):visuals+=1)
	var records:Array=[]
	for difficulty in [.25,.5,.9]:
		unit.set_difficulty(difficulty)
		for distance in [8.0,20.0,40.0]:
			for mode in ["stationary","lateral","reverse"]:
				var row:={"difficulty":difficulty,"range_m":distance,"motion":mode}
				for fixed in [false,true]:
					var initial_hits:=hits;var initial_visuals:=visuals
					for trial in 10:
						seed(7100+trial)
						unit.position=Vector3(0,0,distance);target.position=Vector3.ZERO
						unit.set_guard_heading(Vector3.FORWARD);unit.alert_memory=6;unit.detection_level=1;unit._has_sight=true;unit._has_last_known=true;unit._last_seen_aim=target.get_aim_position()
						unit._motion_observation_valid_071=false;unit._motion_velocity_071=Vector3.ZERO;unit._has_sensed_aim=false;unit.age=0
						unit.locked_aim=target.get_aim_position();unit._change_state(Enemy.State.WINDUP)
						var duration:float=unit._reaction_duration();var frames:=ceili(duration*90)+1
						var speed:float=(1.5+trial*.35)*(-1 if trial%2 else 1)
						# Warm visible motion samples before windup; a teleported/reacquired
						# target must first supply consecutive observations to estimate speed.
						for j in range(-5,1):
							var t:=j*.1;unit.age=t;target.position.x=offset_at(t,speed,mode,float(frames)/90)
							unit._update_detection(target.get_aim_position(),distance,.1)
						for frame in range(1,frames+1):
							var t:=float(frame)/90;unit.age=t;unit.state_time=t
							target.position.x=offset_at(t,speed,mode,float(frames)/90)
							if frame%9==0:unit._update_detection(target.get_aim_position(),distance,.1)
							if t<duration-unit._dodge_window() and unit._has_sight:
								unit.locked_aim=unit._predicted_lock_071(duration-t) if fixed else unit._last_seen_aim+unit._aim_error
						await physics_frame;await physics_frame
						unit._fire(target.get_aim_position())
					row["fixed_hits" if fixed else "baseline_hits"]=hits-initial_hits
					row["shots_per_case"]=10
					check(visuals-initial_visuals==10,"actual fire emits10 shot rays")
				records.append(row)
				if mode=="lateral":check(row.fixed_hits>row.baseline_hits,"lateral improvement "+str(row))
				if mode=="reverse":check(row.fixed_hits<10,"late reversal still evades "+str(row))
				if mode=="stationary":check(row.fixed_hits==row.baseline_hits,"stationary difficulty unchanged")
	unit._observe_motion_071(Vector3.ZERO,.1,false)
	check(not unit._motion_observation_valid_071 and unit._motion_velocity_071==Vector3.ZERO,"occlusion resets prediction, no hidden motion tracking")
	unit._last_seen_aim=Vector3(0,1,0);unit._aim_error=Vector3.ZERO;unit._observe_motion_071(Vector3(100,1,0),.1,true)
	check(unit._motion_velocity_071==Vector3.ZERO,"first reacquired observation has no inferred velocity")
	unit._observe_motion_071(Vector3(1000,1,0),.1,true)
	check(unit._motion_velocity_071.length()<=6 and unit._predicted_lock_071(100).distance_to(unit._last_seen_aim)<=2.001,"speed and lead caps reject tracking jumps")
	unit.variant=3;check(unit._predicted_lock_071(1)==unit._last_seen_aim,"warden telegraph preserved")
	print("ENEMY_MOVING_071_DATA ",JSON.stringify(records))
	unit.queue_free();target.queue_free();await process_frame;await create_timer(.5).timeout
	print("ENEMY_MOVING_071 checks=",checks," failures=",failures," actual_fire_rays=true projectile_travel=hitscan xr_off=true headset_verified=false")
	quit(failures)
