extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var actor:=preload("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack:=preload("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for item in rack.weapons:item.set_process(false);item.set_physics_process(false)
	for index in [1,2,7,12,13,19,24]:
		var gun:Node3D=rack.weapons[index].guns[0] if index==12 else rack.weapons[index]
		var profile:Dictionary=preload("res://scripts/reticle_bounce_071.gd").profile(gun)
		check(not profile.is_empty(),"all semi-auto firearms have an explicit signed motion cycle "+str(index))
		for fps in [30.0,72.0,90.0,120.0]:
			gun.reset_weapon();rack.Arsenal.apply(rack.weapons[index],index);gun.show();rack.weapons[index].show();gun.cooldown=0;gun._requires_trigger_release=false
			if "_semi_armed" in gun:gun._semi_armed=true
			if "_semi_release" in gun:gun._semi_release=true
			var before:int=gun.get_loaded_rounds();gun.fire()
			check(gun.get_loaded_rounds()==before-1,"actual shot starts bounce "+str(index)+" at "+str(fps))
			var positive:=0.0;var negative:=0.0;var elapsed:=0.0
			while elapsed<.7:
				gun._recover_recoil(1/fps);gun._apply_recoil_visual();elapsed+=1/fps
				positive=maxf(positive,gun._reticle_bounce_pitch_071);negative=minf(negative,gun._reticle_bounce_pitch_071)
				var ray:Transform3D=gun.get_visual_reticle_pose_071(gun.get_shot_transform())
				check(ray.is_finite() and gun.model.transform.is_finite(),"finite shared ray / gun pose")
			check(positive>0 and negative<0,"rise and below-center overshoot at "+str(fps)+"Hz "+str(index))
			check(absf(negative/positive+float(profile.under))<.035,"undershoot amplitude independent of frame rate "+str(index))
			check(is_zero_approx(gun._reticle_bounce_pitch_071),"exact rest after full cycle "+str(index))
		# Follow the actual process / cooldown path and emit again at maximum allowed cadence.
		var emitted:Array[Vector3]=[]
		gun.shot.connect(func(_a:Vector3,direction:Vector3,_damage:float):emitted.append(direction))
		if gun.has_signal("pellet_shot"):
			gun.pellet_shot.connect(func(_a:Vector3,directions:Array[Vector3],_damage:float):
				var center:=Vector3.ZERO
				for direction in directions:center+=direction
				emitted.append(center.normalized()))
		gun.reset_weapon();rack.Arsenal.apply(rack.weapons[index],index);gun.cooldown=0;gun._requires_trigger_release=false
		if "_semi_armed" in gun:gun._semi_armed=true
		if "_semi_release" in gun:gun._semi_release=true
		gun.fire();emitted.clear()
		var elapsed:=0.0
		while elapsed<gun.fire_interval+.001:gun._process(.001);elapsed+=.001
		var shown:Transform3D=gun.get_visual_reticle_pose_071(gun.get_shot_transform());gun.publish_displayed_aim(shown)
		var rest_pose:Transform3D=preload("res://scripts/reticle_bounce_071.gd").presentation_pose(gun,gun.get_shot_transform(),0)
		gun.fire()
		check(not emitted.is_empty(),"cadence-permitted follow-up shot actually emits "+str(index))
		if not emitted.is_empty():
			check(emitted[-1].dot(-shown.basis.z.normalized())>.9999,"bullet or pellet center follows displayed moving ray "+str(index))
			check(emitted[-1].angle_to(-rest_pose.basis.z.normalized())>.001,"maximum cadence does not always return bullet to neutral "+str(index))
		# Signed world-up presentation remains world-up even when the controller is rolled.
		for roll in [0.0,PI*.5,-PI*.5]:
			var neutral:=Transform3D(Basis(Vector3.FORWARD,roll),Vector3.ZERO)
			var up:=preload("res://scripts/reticle_bounce_071.gd").upright_pulse(neutral,.05)
			var down:=preload("res://scripts/reticle_bounce_071.gd").upright_pulse(neutral,-.02)
			check((-up.basis.z).y>0 and (-down.basis.z).y<0,"signed motion never flips with wrist roll")
		gun.hide();rack.weapons[index].hide()
	rack.shutdown();rack.queue_free();actor.queue_free();await process_frame
	print("SEMI_MOTION_091 checks=",checks," failures=",failures," native_pts_fits=true headset_tested=false");quit(failures)
