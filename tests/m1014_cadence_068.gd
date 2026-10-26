extends SceneTree
var checks:=0
var failures:=0
var clock:=0.0
var stamps:Array[float]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func record(_origin:Vector3,_directions:Array[Vector3],_damage:float)->void:stamps.append(clock)
func stop_audio(node:Node)->void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop();node.stream=null
	for child in node.get_children():stop_audio(child)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for weapon in rack.weapons:weapon.set_process(false);weapon.set_physics_process(false)
	rack.selected=9;rack._apply_selection()
	var gun=rack.weapons[9];gun.set_process(false)
	var profile:Dictionary=preload("res://scripts/arsenal_data.gd").profile(9)
	check(profile.id=="m1014" and gun.magazine_size==6,"M1014 six-round identity preserved")
	check(absf(gun.fire_interval-.29071666666667395)<.0000001,"faster recorded conditional midpoint reaches production dispatch")
	check(gun.fire_interval>=.28701333333333423 and gun.fire_interval<=.2944200000000137,"period lies within faster burst frame bounds")
	check(not preload("res://scripts/recoil_observation.gd").has_profile("m1014"),"uncertain M1014 recoil curve is not silently installed")
	for hz in [72.0,90.0,120.0]:
		var first:Array[float]=[]
		for two in [false,true]:
			gun.reset_weapon();gun.supported=two;gun._requires_trigger_release=false
			stamps.clear();clock=0;gun.pellet_shot.connect(record)
			var dt:float=1.0/hz;gun.fire()
			for frame in int(hz*3):
				if stamps.size()==6:break
				clock+=dt;gun._process(dt);gun.supported=two;gun.fire()
			check(stamps.size()==6 and gun.ammo==0,"six actual volleys at %sHz support=%s"%[hz,two])
			check(stamps.size()==6 and absf(stamps[-1]-5*.29071666666667395)<=dt+.00001,"first-to-last cadence within one frame at %sHz support=%s"%[hz,two])
			if two:check(stamps==first,"one-/two-hand dispatch timestamps identical at "+str(hz))
			else:first=stamps.duplicate()
			gun.pellet_shot.disconnect(record)
	rack.shutdown();stop_audio(rack);rack.free();actor.free();await create_timer(.4).timeout
	print("M1014_CADENCE_068 checks=",checks," failures=",failures," native_headset=false recoil_timing_uncertain=true")
	quit(failures)
