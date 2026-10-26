extends SceneTree
class Actor extends CharacterBody3D:
	var xr_enabled:=true
	var input_enabled:=true
	var head_obstructed:=false
	var climbing_left:=false
	var climbing_right:=false
	var dominant_hand:="right"
	var _grabs:Dictionary={}
	var right_hand:=XRController3D.new()
	var left_hand:=XRController3D.new()
	var view:=Camera3D.new()
	func get_weapon_hand()->XRController3D:return right_hand
	func get_support_hand()->XRController3D:return left_hand
	func get_view_camera()->Camera3D:return view
	func is_hand_input_ready(_hand:XRController3D)->bool:return true
	func weapon_hand_climbing()->bool:return false
class Rack extends Node3D:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func make_gun(actor:Node3D,id:String):
	var path:="res://scripts/dt11.gd" if id=="dt11" else ("res://scripts/pistol.gd" if id=="px4" else "res://scripts/catalog_firearm.gd")
	var gun=load(path).new()
	if path.ends_with("catalog_firearm.gd"):gun.profile_id=id;gun.mode="semi" if id=="1911" else "auto"
	root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._desktop_signals=true
	var arsenal=load("res://scripts/arsenal_data.gd")
	for p in arsenal.manifest().profiles:
		if p.id==id:arsenal.apply(gun,int(p.index))
	return gun
func capture(gun,shots:Array)->void:
	if gun.has_signal("pellet_shot"):
		gun.pellet_shot.connect(func(origin:Vector3,directions:Array[Vector3],_damage:float):shots.append({"origin":origin,"directions":directions.duplicate(),"expected":gun.get_meta("expected_072_direction")}))
	else:gun.shot.connect(func(origin:Vector3,direction:Vector3,_damage:float):shots.append({"origin":origin,"directions":[direction],"expected":gun.get_meta("expected_072_direction")}))
func run()->void:
	check(not root.use_xr,"CPU test must leave viewport XR off")
	var actor:=Actor.new();root.add_child(actor);actor.add_child(actor.right_hand);actor.add_child(actor.left_hand);actor.add_child(actor.view)
	var game:=Game.new();root.add_child(game)
	for id in ["dt11","fal","1911","px4"]:
		var a=make_gun(actor,id);var b=make_gun(actor,id);var sa:Array=[];var sb:Array=[];capture(a,sa);capture(b,sb)
		var rack:=Rack.new();root.add_child(rack);rack.weapons=[a]
		var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false)
		var control_rack:=Rack.new();root.add_child(control_rack);control_rack.weapons=[b]
		var control_reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(control_reticle);control_reticle.setup(actor,control_rack,game);control_reticle.set_process(false)
		var initial_bounce:=0.0
		for step in range(121):
			for gun in [a,b]:gun._process(0.0 if step==0 else 1.0/120.0)
			# Control differs only in UI pulse; actual placement code/state is identical.
			b._reticle_bounce_pitch_071=0.0
			reticle.update_reticle();control_reticle.update_reticle()
			if step in [0,48,96]:
				for gun in [a,b]:
					if id=="dt11":gun._semi_release=true
					else:gun._semi_armed=true
					gun.set_meta("expected_072_direction",-gun.get_firing_pose().basis.z)
					gun.fire()
				# Both real UI paths publish the same post-shot frame. Previously
				# only A was refreshed here, comparing A's post-kick cache with B's
				# pre-kick cache on precisely the eleven frames that emitted shots.
				b._reticle_bounce_pitch_071=0.0
				reticle.update_reticle();control_reticle.update_reticle()
			if step==0:
				initial_bounce=a._reticle_bounce_pitch_071
				check(initial_bounce>0,id+" actual shot starts pulse")
				check(reticle.visible,id+" production reticle visible")
				check((a.global_basis.inverse()*reticle.presentation_direction_071).y>0,id+" actual projected direction rises")
				if id=="dt11":check(initial_bounce>deg_to_rad(11),"DT11 higher upward bounce")
			if step==36:check(a._reticle_bounce_pitch_071<initial_bounce*.07,id+" presentation promptly returns")
			check((-a.get_firing_pose().basis.z).is_equal_approx(reticle.ray_direction),id+" shared publication matches displayed ray")
			check((-b.get_firing_pose().basis.z).is_equal_approx(control_reticle.ray_direction),id+" control publication matches its own displayed ray")
			var local_direction:Vector3=a.global_basis.inverse()*reticle.presentation_direction_071
			check(absf(local_direction.x)<.00001,id+" visible bounce has no lateral recoil")
		check(sa.size()>0 and sa.size()==sb.size(),id+" actual emitted shot counts match")
		for i in mini(sa.size(),sb.size()):
			check(sa[i].origin.is_equal_approx(sb[i].origin),id+" origins unchanged")
			check(sa[i].directions.size()==sb[i].directions.size(),id+" pellet count unchanged")
			var center_a:=Vector3.ZERO;var center_b:=Vector3.ZERO
			for direction in sa[i].directions:center_a+=direction
			for direction in sb[i].directions:center_b+=direction
			check(center_a.normalized().dot(sa[i].expected)>.9999 and center_b.normalized().dot(sb[i].expected)>.9999,id+" actual emitted shot axes match each displayed aim")
		a.reset_weapon();check(a._reticle_bounce_pitch_071==0,id+" reset clears presentation")
		reticle.free();rack.free();control_reticle.free();control_rack.free();a.shutdown();b.shutdown();a.free();b.free()
	# Real presentation path under rolled, yawed and pitched aim, including poles.
	var rolled=make_gun(actor,"fal")
	var rolled_rack:=Rack.new();root.add_child(rolled_rack);rolled_rack.weapons=[rolled]
	var rolled_reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(rolled_reticle);rolled_reticle.setup(actor,rolled_rack,game);rolled_reticle.set_process(false)
	for rotation in [Vector3(0,0,PI*.5),Vector3(.4,.7,PI*.5),Vector3(-.6,-1.1,-PI*.5),Vector3(PI*.5,0,1.2),Vector3(-PI*.5,0,-.8),Vector3(PI*.5-.01,.6,PI*.5)]:
		rolled.global_basis=Basis.from_euler(rotation)
		rolled.recoil_pitch=.22;rolled.recoil_yaw=.17;rolled._apply_recoil_visual()
		var original:Transform3D=rolled.get_shot_transform()
		var rest:Transform3D=preload("res://scripts/reticle_bounce_071.gd").presentation_pose(rolled,original,0.0)
		rolled._reticle_bounce_pitch_071=.2
		var visual:Transform3D=rolled.get_visual_reticle_pose_071(original)
		var forward:Vector3=-rest.basis.z.normalized();var risen:Vector3=-visual.basis.z.normalized()
		check(visual.is_finite() and visual.is_equal_approx(rolled.get_visual_reticle_pose_071(original)),"pole/rolled presentation finite and deterministic")
		check(visual.origin.is_equal_approx(rest.origin),"rolled pulse does not move muzzle origin sideways")
		check(rolled.get_shot_transform().is_equal_approx(original),"rolled presentation does not mutate shot transform")
		check(risen.y>=forward.y-.00001,"rolled/yawed/pitched pulse never bounces downward")
		var horizontal:=Vector3(forward.x,0,forward.z)
		if horizontal.length_squared()>.000001:
			var side:Vector3=horizontal.normalized().cross(Vector3.UP)
			check(absf(risen.dot(side))<.00001,"world-upright pulse preserves intentional aim azimuth")
		if forward.y>.999999:check(risen.is_equal_approx(forward),"upper pole saturates without azimuth flip")
		rolled_reticle.update_reticle()
		check(rolled_reticle.visible and rolled_reticle.presentation_direction_071.is_equal_approx(risen),"production reticle uses world-upright rolled pose")
		check(rolled.get_firing_pose().is_equal_approx(visual),"rolled production reticle publishes exact visible pose")
	rolled_reticle.free();rolled_rack.free();rolled.shutdown();rolled.free()
	var neutral=make_gun(actor,"mp5");neutral.recoil_pitch=.2;neutral.recoil_yaw=.1;neutral._apply_recoil_visual();var ballistic:Transform3D=neutral.get_shot_transform()
	check(neutral.get_visual_reticle_pose_071(ballistic).is_equal_approx(ballistic),"accepted MP5 profile remains exact ballistic presentation")
	neutral.shutdown();neutral.free();game.free();actor.free()
	print("RETICLE_BOUNCE_071 checks=",checks," failures=",failures," cpu_only=true xr_off=true headset_tested=false");quit(failures)
