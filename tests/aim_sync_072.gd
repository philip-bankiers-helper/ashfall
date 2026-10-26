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
	var names:Dictionary={"dt11":"dt11","px4":"pistol","magnum":"revolver","spr":"spr","awp":"precision_rifle","matadors":"dual_matadors","m60":"belt_lmg"}
	var path:String="res://scripts/"+str(names.get(id,"catalog_firearm"))+".gd"
	var gun=load(path).new()
	if path.ends_with("catalog_firearm.gd"):
		gun.profile_id=id;gun.mode="semi" if id in ["fal","1911"] else ("bolt" if id=="s85" else "auto")
	root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._desktop_signals=true
	for p in preload("res://scripts/arsenal_data.gd").manifest().profiles:
		if p.id==id:preload("res://scripts/arsenal_data.gd").apply(gun,int(p.index))
	return gun
func arm(gun)->void:
	if gun.get("_semi_armed")!=null:gun._semi_armed=true
	if gun.get("_semi_release")!=null:gun._semi_release=true
func capture(gun,shots:Array)->void:
	if gun.has_signal("pellet_shot"):
		gun.pellet_shot.connect(func(origin:Vector3,directions:Array[Vector3],_damage:float):shots.append({"origin":origin,"directions":directions.duplicate()}))
	else:gun.shot.connect(func(origin:Vector3,direction:Vector3,_damage:float):shots.append({"origin":origin,"directions":[direction]}))
func verify_shot(gun,shots:Array,pose:Transform3D,label:String)->void:
	var before:int=shots.size();arm(gun);gun.fire()
	check(shots.size()==before+1,label+" actual emission")
	if shots.size()==before:return
	var axis:=Vector3.ZERO
	for direction in shots[-1].directions:axis+=direction
	check(axis.normalized().distance_to(-pose.basis.z.normalized())<.00001,label+" shot/pellet centroid matches last displayed aim")
	if gun._vr_active():check(shots[-1].origin.distance_to(pose.origin)<.00001,label+" muzzle matches publication")
func run()->void:
	check(not root.use_xr,"XR off")
	var actor:=Actor.new();root.add_child(actor);actor.add_child(actor.right_hand);actor.add_child(actor.left_hand);actor.add_child(actor.view)
	var game:=Game.new();root.add_child(game)
	for id in ["fal","1911","px4","dt11","magnum","spr","awp","s85","mp5","mp9","cx4","tec9","m60"]:
		for hz in [30,72,90,120]:
			for refresh_first in [false,true]:
				var gun=make_gun(actor,id);var shots:Array=[];capture(gun,shots)
				var rack:=Rack.new();root.add_child(rack);rack.weapons=[gun]
				var ui=load("res://scripts/aim_reticle.gd").new();root.add_child(ui);ui.setup(actor,rack,game);ui.set_process(false)
				var scoped:bool=id in ["spr","awp"]
				if scoped:gun.optic._commit_displayed_frame()
				else:ui.update_reticle()
				var shown:Transform3D=gun.get_firing_pose()
				verify_shot(gun,shots,shown,id+" initial")
				var frames:int=ceili(maxf(gun.fire_interval,.12)*hz)+1
				for frame in range(1,frames+1):
					gun._process(1.0/hz)
					if id in ["awp","s85"]:gun.reload_state="ready";gun.ammo=2
					if id=="awp":gun.chambered=true
					# Fire before UI refresh must use the last displayed frame, even
					# after current recoil recovery has advanced. Other ordering uses
					# the new frame. No cooldown bypass: second shot waits real cadence.
					if frame==frames and not refresh_first:verify_shot(gun,shots,shown,id+" fire before refresh")
					if scoped:gun.optic._commit_displayed_frame()
					else:ui.update_reticle()
					shown=gun.get_firing_pose()
					if not scoped and gun.reload_state=="ready" and gun.ammo>0:
						check((-shown.basis.z.normalized()).distance_to(ui.ray_direction)<.00001,id+" published ray")
						check(ui.ray_direction.distance_to(ui.presentation_direction_071)<.00001,id+" visible ray and firing authority agree during return")
						if id in ["mp5","mp9","cx4","tec9","m60"]:check(shown.is_equal_approx(gun.get_shot_transform()),id+" protected auto ballistic pose unchanged")
					if frame==frames and refresh_first:verify_shot(gun,shots,shown,id+" fire after refresh")
				ui.free();rack.free();gun.shutdown();gun.free()
	# Paired Matadors: each hand has independent recovery/publication at all rates.
	for hz in [30,72,90,120]:
		var pair=make_gun(actor,"matadors");var pair_rack:=Rack.new();root.add_child(pair_rack);pair_rack.weapons=[pair]
		var pair_ui=load("res://scripts/aim_reticle.gd").new();root.add_child(pair_ui);pair_ui.setup(actor,pair_rack,game);pair_ui.set_process(false)
		pair_ui.update_reticle()
		check(pair_ui._paired_children.size()==2,"Matadors both reticles")
		for i in pair.guns.size():
			var gun=pair.guns[i];gun._desktop_signals=true;var shots:Array=[];capture(gun,shots)
			var shown:Transform3D=gun.get_firing_pose();verify_shot(gun,shots,shown,"Matadors hand"+str(i))
			var frames:int=ceili(gun.fire_interval*hz)+1
			for frame in range(1,frames+1):
				gun._process(1.0/hz)
				if frame==frames and i==0:verify_shot(gun,shots,shown,"Matadors before refresh")
				pair_ui.update_reticle();shown=gun.get_firing_pose()
				check((-shown.basis.z.normalized()).distance_to(pair_ui._paired_children[i].ray_direction)<.00001,"Matadors published return ray")
				if frame==frames and i==1:verify_shot(gun,shots,shown,"Matadors after refresh")
		pair_ui.free();pair_rack.free();pair.shutdown();pair.free()
	game.free();actor.free()
	print("AIM_SYNC_072 checks=",checks," failures=",failures," frame_rates=30,72,90,120 cpu_only=true xr_off=true headset_verified=false");quit(failures)
