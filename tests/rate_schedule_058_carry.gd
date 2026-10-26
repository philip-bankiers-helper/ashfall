extends SceneTree
var checks:=0
var failures:=0
var time:=0.0
var stamps:Array[float]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func record(_origin:Vector3,_direction:Vector3,_damage:float)->void:stamps.append(time)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for index in [0,6,10,17,18,20,21,23]:
		var gun=rack.weapons[index];gun.show();gun.set_process(false);gun.reset_weapon();gun.cooldown=0;gun.shot.connect(record);stamps.clear();time=0
		var wanted:int=gun.magazine_size
		gun.fire()
		for frame in 1200:
			if stamps.size()>=wanted:break
			time+=1.0/90.0;gun._process(1.0/90.0);gun.fire()
		var expected:float=float(wanted-1)*gun.fire_interval
		print("SCHEDULE ",rack.weapon_names[index]," count=",stamps.size()," elapsed=",stamps.back() if not stamps.is_empty() else -1," expected=",expected)
		check(stamps.size()==wanted and absf(stamps.back()-expected)<1.0/90.0+.0001,"actual full-mag dispatcher90Hz matches configured cadence "+rack.weapon_names[index])
		gun.shot.disconnect(record);gun.hide()
	var burst=rack.weapons[3];burst.show();burst.reset_weapon();burst.cooldown=0;burst.shot.connect(record);stamps.clear();time=0;burst.fire()
	for frame in 90:
		if stamps.size()==3:break
		time+=1.0/90.0;burst._process(1.0/90.0)
	check(stamps.size()==3 and absf(stamps[2]-2.0*.080)<1.0/90.0,"MK18 tuned first-to-third .160s within one90Hzframe")
	check(absf(burst.cooldown-.24)<.001,"MK18 post-burst .24s is separate from intra interval")
	rack.shutdown();rack.free();actor.free();await create_timer(.1).timeout
	print("RATE_SCHEDULE_058_CARRY checks=",checks," failures=",failures," reference_rates_verified=false")
	quit(failures)
