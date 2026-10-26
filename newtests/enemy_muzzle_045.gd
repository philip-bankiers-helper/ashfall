extends SceneTree
const Enemy=preload("res://scripts/enemy.gd")
class Target extends Node3D:
	var exposure_provider:Node
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func obstacle(at:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();body.position=at
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.11,.10,.10);collision.shape=shape;body.add_child(collision);root.add_child(body)
	return body
func run()->void:
	var target:=Target.new();root.add_child(target);target.position=Vector3(0,0,-12)
	for kind in range(4):
		var enemy:=Enemy.new();enemy.setup(target,kind);root.add_child(enemy);enemy.set_physics_process(false);enemy.set_process(false)
		var hits:=[0];var visuals:Array=[]
		enemy.hit_player.connect(func(_amount:float):hits[0]+=1)
		enemy.shot_visual.connect(func(origin:Vector3,endpoint:Vector3):visuals.append([origin,endpoint]))
		var aim:=Vector3(0,1.65,-12);enemy.locked_aim=aim;enemy._warden_area=false
		var muzzle:Transform3D=enemy.get_weapon_muzzle_transform()
		check(muzzle.origin.is_equal_approx(enemy._weapon_muzzle.global_position),"variant%d uses actual visible muzzle marker"%kind)
		check(muzzle.origin.distance_to(enemy.global_position+Vector3.UP*1.4)>.5,"variant%d source differs from chest"%kind)
		if kind in [0,2]:check(enemy._detail_visual.get_muzzle_transform().is_equal_approx(muzzle),"ground adapter exposes actual weapon pose")
		else:check(enemy._detail_visual==null and enemy._weapon_muzzle.get_parent()==enemy._turret,"drone exposes own moving turret weapon")
		var initial:=muzzle.origin
		enemy._visual.rotation.y=.35;enemy._visual.rotation.x=-.06;enemy._turret.rotation.x=.22;enemy._turret.position.z=.048
		if enemy._detail_visual!=null:enemy._detail_visual.update_pose(.1,true,true,.4,.22)
		var animated:=enemy.get_weapon_muzzle_transform()
		check(animated.origin.distance_to(initial)>.05 and animated.is_equal_approx(enemy._weapon_muzzle.global_transform),"variant%d animated aim/recoil/sway inherited by muzzle"%kind)
		enemy._visual.rotation=Vector3.ZERO;enemy._turret.rotation=Vector3.ZERO;enemy._turret.position.z=0;muzzle=enemy.get_weapon_muzzle_transform()
		enemy._fire(aim)
		check(hits[0]==1 and visuals.size()==1 and visuals[0][0].is_equal_approx(muzzle.origin),"variant%d actual damage and tracer share muzzle origin"%kind)
		check(visuals[0][1].is_equal_approx(aim),"variant%d unobstructed tracer reaches telegraphed endpoint"%kind)
		var cover:=obstacle(muzzle.origin.lerp(aim,.10));await physics_frame
		check(enemy._clear_line(aim),"variant%d low muzzle cover leaves old chest line clear"%kind)
		enemy._fire(aim)
		check(hits[0]==1 and visuals.size()==2 and visuals[1][1].distance_to(aim)>5,"variant%d muzzle cover blocks damage and clips actual tracer"%kind)
		cover.queue_free();await physics_frame
		var chest:=enemy.global_position+Vector3.UP*1.4
		cover=obstacle(chest.lerp(aim,.10));await physics_frame
		check(not enemy._clear_line(aim),"variant%d chest-only cover actually blocks old source"%kind)
		enemy._fire(aim)
		check(hits[0]==2 and visuals[-1][1].is_equal_approx(aim),"variant%d clear muzzle shot is not incorrectly vetoed by chest cover"%kind)
		cover.queue_free();await physics_frame
		enemy._draw_beam(muzzle.origin,aim)
		var start:Vector3=enemy._beam.global_transform*Vector3(0,-.5,0)
		check(start.is_equal_approx(muzzle.origin),"variant%d warning beam also begins at actual visible muzzle"%kind)
		for i in range(50):enemy._emit_shot_streak(muzzle.origin,aim)
		check(enemy._shot_streaks.size()==3 and enemy.find_children("EnemyShotStreak*","MeshInstance3D",false,false).size()==3,"variant%d repeated shots keep fixed three-entry pool"%kind)
		check(enemy._shot_streaks[0].get_child_count()==1,"variant%d one soft halo per six-sided core"%kind)
		enemy.set_physics_process(true);enemy._process(.10)
		check(enemy._shot_streak_times.all(func(t:float):return t==0),"variant%d lifetimes expire at bounded65ms"%kind)
		enemy._emit_shot_streak(muzzle.origin,aim);enemy.set_physics_process(false);enemy._process(0)
		check(enemy._shot_streaks.all(func(mesh:MeshInstance3D):return not mesh.visible),"variant%d menu physics pause clears frozen streaks"%kind)
		enemy._emit_shot_streak(muzzle.origin,aim);enemy._notification(Node.NOTIFICATION_PAUSED)
		check(enemy._shot_streaks.all(func(mesh:MeshInstance3D):return not mesh.visible),"variant%d tree pause clears streaks"%kind)
		enemy._emit_shot_streak(muzzle.origin,aim);enemy.setup(target,kind)
		check(enemy._shot_streak_cursor==0 and enemy._shot_streak_times.all(func(t:float):return t==0),"variant%d reuse setup resets pool"%kind)
		enemy._emit_shot_streak(muzzle.origin,aim);enemy.state=Enemy.State.DEAD;enemy._process(0)
		check(enemy._shot_streaks.all(func(mesh:MeshInstance3D):return not mesh.visible),"variant%d dead state clears streaks"%kind)
		enemy._voice.stop();enemy._impact_voice.stop();enemy.queue_free();await process_frame
	target.queue_free();await process_frame;await create_timer(.15).timeout
	print("ENEMY_MUZZLE_045 checks=",checks," failures=",failures," headset_tested=false native_gpu_tested=false");quit(failures)
