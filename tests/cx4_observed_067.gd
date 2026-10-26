extends SceneTree
var checks:=0
var failures:=0
var clock:=0.0
var stamps:Array[float]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func record(_origin:Vector3,_direction:Vector3,_damage:float)->void:stamps.append(clock)
func run()->void:
	var util=load("res://scripts/recoil_observation.gd")
	var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/recoil_observed_066.json"))
	var manifest:Dictionary=util.manifest()
	check(manifest.profiles.size()==5 and util.has_profile("cx4"),"067 has new CX4 pair")
	for id in ["m60","mp5","mp9","tec9"]:
		check(manifest.profiles[id]==old.profiles[id],id+" previous complete profile/provenance remains unchanged")
	check(manifest.profiles.cx4.one.samples.size()==172 and manifest.profiles.cx4.two.samples.size()==149,"CX4 retains both complete native candidate traces")
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var index:=-1
	for i in rack.weapons.size():
		if rack.weapons[i].get_meta("reference_id","")=="cx4":index=i;break
	if index<0:
		check(false,"production rack contains CX4");rack.shutdown();rack.free();actor.free();quit(1);return
	rack.selected=index;rack.is_holstered=false;rack._apply_selection()
	var gun=rack.weapons[index];gun.set_process(false)
	check(gun.magazine_size==25,"production CX4 retains carried capacity25")
	check(absf(gun.fire_interval-1.0/6.0)<.000001,"clip-matching6rps reaches actual production dispatch")
	var file:=FileAccess.open("user://cx4-production-067.csv",FileAccess.WRITE)
	file.store_line("hz,hands,seconds,shots,pitch_up_deg,yaw_right_deg")
	var one_peak:=0.0;var two_peak:=0.0
	for hz in [72.0,90.0,120.0]:
		for two in [false,true]:
			gun.reset_weapon();gun.set_process(false);gun.supported=two;gun._requires_trigger_release=false
			stamps.clear();clock=0;gun.shot.connect(record)
			var dt:float=1.0/hz;var peak:=0.0
			gun.fire()
			for frame in ceili(6.0*hz):
				clock+=dt;gun._process(dt);gun.supported=two;gun.fire();gun._apply_recoil_visual()
				peak=maxf(peak,rad_to_deg(gun.recoil_pitch))
				file.store_line("%.0f,%s,%.6f,%d,%.6f,%.6f"%[hz,"two" if two else "one",clock,stamps.size(),rad_to_deg(gun.recoil_pitch),-rad_to_deg(gun.recoil_yaw)])
				if stamps.size()>=25:break
			var elapsed:float=stamps[-1]-stamps[0] if not stamps.is_empty() else -1.0
			check(stamps.size()==25 and gun.get_loaded_rounds()==0,"actual full magazine emits25 projectiles at"+str(hz)+"Hz support="+str(two))
			check(absf(elapsed-24.0/6.0)<=dt+.0001,"first-to-last emission matches target within one simulation frame at"+str(hz)+"Hz")
			check(peak>6.3 if two else peak>8.8,"production reaches separate recorded output envelope within carried magazine at"+str(hz)+"Hz support="+str(two))
			gun.supported=not two;gun._recover_recoil(.0001)
			var expected:Vector2=util.sample("cx4",two,gun._observed_burst_time)
			check(absf(rad_to_deg(gun.recoil_pitch)-expected.x)<.0001 and absf(-rad_to_deg(gun.recoil_yaw)-expected.y)<.0001,"empty grip change retains last shot hand condition")
			if two:two_peak=maxf(two_peak,peak)
			else:one_peak=maxf(one_peak,peak)
			gun.shot.disconnect(record)
	check(one_peak>two_peak*1.2,"CX4 separate hand trajectories survive real dispatch")
	file.close();rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("CX4_OBSERVED_067 checks=",checks," failures=",failures," actual_production=true rendered=false wrist_removed=false headset_tested=false source_rarity_verified=false")
	quit(failures)
