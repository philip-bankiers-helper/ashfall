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
	var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/recoil_observed_062.json"))
	var manifest:Dictionary=util.manifest()
	check(manifest.profiles.size()==4 and util.has_profile("tec9"),"066 adds TEC9 pair while retaining existing3 observed profiles")
	for id in ["m60","mp5","mp9"]:
		check(manifest.profiles[id]==old.profiles[id],id+" complete sample/provenance content stays unchanged")
	check(manifest.profiles.tec9.one.samples.size()==25 and manifest.profiles.tec9.two.samples.size()==24,"TEC9 retains every selected native frame rather than a generic gain")
	check(absf(util.sample("tec9",false,.805490).x-23.590016)<.00001 and absf(util.sample("tec9",false,.805490).y-1.447374)<.00001,"one-hand final native PTS carries independent pitch and RIGHT-positive yaw")
	check(absf(util.sample("tec9",true,.763840).x-8.804292)<.00001 and absf(util.sample("tec9",true,.763840).y+.307950)<.00001,"supported final native PTS carries separate output")
	for two in [false,true]:
		var end_time:=.763840 if two else .805490
		check(util.sample("tec9",two,end_time+1.0).distance_to(util.sample("tec9",two,end_time))<.000001,"new TEC9 continuation holds last sample instead of inventing a reflected descent "+str(two))
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	rack.selected=20;rack.is_holstered=false;rack._apply_selection()
	var gun=rack.weapons[20];gun.set_process(false)
	check(gun.get_meta("reference_id")=="tec9" and gun.magazine_size==12,"real catalog TEC9 still has12 rounds")
	check(absf(gun.fire_interval-1.0/14.4)<.000001,"recorded12-round output target14.4rps reaches actual production dispatcher")
	var file:=FileAccess.open("user://tec9-production-066.csv",FileAccess.WRITE)
	file.store_line("hz,hands,seconds,shots,pitch_up_deg,yaw_right_deg")
	var one_peak:=0.0;var two_peak:=0.0
	for hz in [72.0,90.0,120.0]:
		for two in [false,true]:
			gun.reset_weapon();gun.set_process(false);gun.supported=two;gun._requires_trigger_release=false
			stamps.clear();clock=0;gun.shot.connect(record)
			var dt:float=1.0/hz;var peak:=0.0;var axis_error:=0.0
			gun.fire()
			for frame in ceili(.9*hz):
				clock+=dt;gun._process(dt);gun.supported=two;gun.fire();gun._apply_recoil_visual()
				peak=maxf(peak,rad_to_deg(gun.recoil_pitch))
				if gun._observed_burst_active and gun.recoil_idle<=.32:
					var p:Vector2=util.sample("tec9",gun._observed_shot_supported,gun._observed_burst_time)
					var pitch:=deg_to_rad(p.x);var yaw:=deg_to_rad(p.y)
					var expected:=Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
					var actual:Vector3=gun.global_basis.inverse()*(-gun.get_shot_transform().basis.z.normalized())
					axis_error=maxf(axis_error,actual.distance_to(expected))
				file.store_line("%.0f,%s,%.6f,%d,%.6f,%.6f"%[hz,"two" if two else "one",clock,stamps.size(),rad_to_deg(gun.recoil_pitch),-rad_to_deg(gun.recoil_yaw)])
			var elapsed:float=stamps[-1]-stamps[0] if not stamps.is_empty() else -1.0
			check(stamps.size()==12 and gun.get_loaded_rounds()==0,"actual full-mag firing emits12 projectiles then depletes at"+str(hz)+"Hz support="+str(two))
			check(absf(elapsed-11.0/14.4)<=dt+.0001,"first-to-last emission matches recorded target within one simulation frame at"+str(hz)+"Hz")
			check(peak>7.0 if two else peak>22.0,"production model reaches the separate filmed output envelope at"+str(hz)+"Hz support="+str(two))
			check(axis_error<.0001,"actual barrel uses the measured UP/RIGHT axes at"+str(hz)+"Hz support="+str(two))
			var last_pitch:float=gun.recoil_pitch;gun.supported=not two;gun._recover_recoil(.001)
			check(absf(gun.recoil_pitch-last_pitch)<.00001,"empty/reload grip release retains final-shot hand condition")
			gun._recover_recoil(1.0)
			check(gun.recoil_pitch==0 and gun.recoil_yaw==0 and not gun._observed_burst_active,"shared release decay/reset rearms a new burst")
			if two:two_peak=maxf(two_peak,peak)
			else:one_peak=maxf(one_peak,peak)
			gun.shot.disconnect(record)
	check(one_peak>two_peak*2.5,"actual one-hand output differs materially from supported output")
	file.close();print("TEC9_PRODUCTION_066_CSV=",ProjectSettings.globalize_path("user://tec9-production-066.csv"))
	rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("TEC9_OBSERVED_066 checks=",checks," failures=",failures," actual_production=true rendered=false observed_output=true wrist_removed=false headset_tested=false source_rarity_verified=false")
	quit(failures)
