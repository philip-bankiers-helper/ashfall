extends SceneTree
const Enemy=preload("res://scripts/enemy.gd")
class Target extends Node3D:
	var exposure_provider:Node
	var tracking_available:=true
	var origin:XROrigin3D
	var view:XRCamera3D
	func _init()->void:
		origin=XROrigin3D.new();add_child(origin);view=XRCamera3D.new();origin.add_child(view);view.position.y=1.90
	func get_view_camera()->Camera3D:return view
	func measured_eye_height()->float:return view.global_position.y-global_position.y
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var floor:=StaticBody3D.new();floor.position.y=-.10;var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(80,.2,80);col.shape=shape;floor.add_child(col);root.add_child(floor)
	var target:=Target.new();target.position=Vector3(0,0,-14);root.add_child(target)
	var real_player=load("res://scripts/player.gd").new();root.add_child(real_player);real_player.setup(false);real_player.set_physics_process(false);real_player.set_process(false);real_player.xr_enabled=true;real_player.tracking_available=true
	var calibrated:=Enemy.new();calibrated.setup(real_player,0);root.add_child(calibrated);calibrated.set_physics_process(false);calibrated.set_process(false)
	real_player.xr_camera.position.y=1.45;calibrated._update_standing_height();check(is_equal_approx(calibrated._standing_eye_height,1.45),"actual player first valid shorter standing calibration replaces fallback")
	real_player.xr_camera.position.y=1.92;calibrated._update_standing_height();check(is_equal_approx(calibrated._standing_eye_height,1.92),"actual player authoritative standing API controls humanoid height")
	real_player.xr_camera.position.y=.70;real_player.xr_origin.position.y=8;real_player.position.y=10;calibrated._update_standing_height();check(is_equal_approx(calibrated._standing_eye_height,1.92),"actual player crouch and origin translations preserve calibration")
	real_player.xr_camera.position.y=NAN;calibrated._update_standing_height();check(is_equal_approx(calibrated._standing_eye_height,1.92),"actual player invalid raw tracking height preserves calibration")
	for kind in [1,3]:
		var drone:=Enemy.new();drone.setup(real_player,kind);root.add_child(drone);drone.set_physics_process(false);drone.set_process(false)
		var scale_before:Vector3=drone._visual.scale;drone._update_standing_height();check(drone._visual.scale==scale_before,"intentional drone size independent of humanoid calibration")
		drone._voice.stop();drone._impact_voice.stop();drone.free()
	calibrated._voice.stop();calibrated._impact_voice.stop();calibrated.free();real_player.free()
	var bots:Array=[]
	for i in range(6):
		var bot:=Enemy.new();bot.setup(target,2 if i==5 else 0);root.add_child(bot);bot.set_physics_process(false);bot.set_process(false)
		bot.position=Vector3((i%3)*.65-.65,.1,float(i/3)*.65)
		bot._has_last_known=true;bot._last_seen=target.position;bot._last_seen_aim=target.position+Vector3.UP*1.9;bot._has_sight=true;bot.state=Enemy.State.PURSUE;bot.attack_cooldown=9999;bot._sight_timer=9999
		bots.append(bot)
	check(is_equal_approx(bots[0]._standing_eye_height,1.90),"raw tracking standing eye calibration accepted")
	check(is_equal_approx(bots[0]._visual.scale.y,1.9/Enemy.HUMANOID_EYE_ABOVE_SUPPORT) and is_equal_approx(bots[5]._visual.scale.y,1.9/Enemy.HUMANOID_EYE_ABOVE_SUPPORT),"both humanoid variants match player eye plane")
	var stable_scale:Vector3=bots[0]._visual.scale
	target.view.position.y=.8;bots[0]._update_standing_height();check(bots[0]._visual.scale==stable_scale,"crouch never shrinks standing rig")
	target.origin.position.y=6;target.position.y=12;bots[0]._update_standing_height();check(bots[0]._visual.scale==stable_scale,"world jump and tracking origin shifts cannot inflate standing scale")
	target.origin.position.y=0;target.position.y=0;target.view.position.y=2.1;target.tracking_available=false;bots[0]._update_standing_height();check(bots[0]._visual.scale==stable_scale,"tracking loss ignores apparent new height")
	target.tracking_available=true;target.view.position.y=1.9
	for i in range(bots.size()):
		for j in range(i):check(bots[i].tactical_destination().distance_to(bots[j].tactical_destination())>1.5,"stable tactical slots are disjoint")
	var saved_goal:Vector3=bots[0].tactical_destination();target.position.x=10;check(bots[0].tactical_destination()==saved_goal,"unseen target movement cannot move tactical destination");target.position.x=0
	var minimum:=999.0
	var clearance:=999.0
	var penetrated:=false
	var wall:=StaticBody3D.new();wall.position=Vector3(0,1,-4);var wallcol:=CollisionShape3D.new();var wallshape:=BoxShape3D.new();wallshape.size=Vector3(3,2,.3);wallcol.shape=wallshape;wall.add_child(wallcol);root.add_child(wall)
	for frame in range(720):
		await physics_frame
		for bot in bots:bot._physics_process(1.0/90.0)
		for bot in bots:
			if absf(bot.position.x)<1.4 and absf(bot.position.z+4)<.14:penetrated=true
		if frame>360:
			for i in range(bots.size()):
				for j in range(i):
					var distance:=Vector2(bots[i].position.x-bots[j].position.x,bots[i].position.z-bots[j].position.z).length()
					minimum=minf(minimum,distance)
					clearance=minf(clearance,distance-bots[i]._humanoid_collider.shape.radius-bots[j]._humanoid_collider.shape.radius)
	print("BOT_SPACING minimum_after_settle=",minimum)
	print("BOT_HEIGHT bodyY=",bots[0].global_position.y," footboneY=",bots[0]._detail_visual._bone_world("foot_L").y," opticY=",bots[0]._visual.to_global(Vector3(0,1.66,0)).y)
	check(minimum>.95 and clearance>-.025,"actual six-agent movement resolves close spawns without capsule overlap")
	print("BOT_CAPSULE_CLEARANCE ",clearance)
	check(absf(bots[0]._visual.to_global(Vector3(0,1.66,0)).y-1.90)<.015,"grounded bot eye height matches calibrated player within15mm")
	check(not penetrated,"actual multi-agent steering never crosses obstacle volume")
	check(bots.any(func(bot):return bot.position.z < -5),"agents make actual progress around shared obstacle")
	check(bots.all(func(bot):return absf(bot.position.y)<.15 and bot.is_on_floor()),"resized humanoids stay grounded on same floor")
	for bot in bots:bot._voice.stop();bot._impact_voice.stop();bot.queue_free()
	target.queue_free();wall.queue_free();floor.queue_free();await process_frame;await create_timer(.15).timeout
	print("BOTS_046 checks=",checks," failures=",failures," headset_tested=false native_gpu_tested=false");quit(failures)




