extends SceneTree
const Warning=preload("res://scripts/grenade_warning.gd")
class Host extends Node:
	var player:Node3D
	var paused:=false
	var dead:=false
	var complete:=false
	var blasts:=0
	var ticks:=0
	func apply_explosive_damage(_at:Vector3,_radius:float,_amount:float,instant:bool)->void:
		if instant:blasts+=1
		else:ticks+=1
var checks:=0
var failures:=0
var host:Host
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func projectile(kind:String):
	var value=load("res://scripts/explosive_projectile.gd").new();host.add_child(value)
	value.setup(host,{"kind":kind,"origin":Vector3(0,30,0),"velocity":Vector3.FORWARD*5});value.set_physics_process(false)
	return value
func step_for(value,seconds:float,step:float)->void:
	var elapsed:=0.0
	while elapsed<seconds-.0000001:
		var dt:=minf(step,seconds-elapsed);value._physics_process(dt);elapsed+=dt
func run()->void:
	host=Host.new();root.add_child(host);host.player=Node3D.new();host.add_child(host.player)
	for duration in [2.5,2.7,3.5]:
		var beats:=Warning.beat_times(duration);var gap:=INF;var accelerating:=true
		for i in range(1,beats.size()):
			var next:=float(beats[i]-beats[i-1]);accelerating=accelerating and next>0 and next<gap;gap=next
		check(accelerating and beats.size()>=8,"warning intervals strictly shorten, duration "+str(duration))
		check(beats[0]>.0 and beats[-1]<duration-.065,"all complete tones precede countdown end, duration "+str(duration))
	check(Warning.beat_times(NAN).is_empty() and Warning.beat_times(-1).is_empty() and Warning.beat_times(.05).is_empty(),"invalid/very short fuse produces no out-of-order warning schedule")
	for kind in ["frag","zone"]:
		var tone:AudioStreamWAV=Warning.tone(kind);var peak:=0
		for i in range(0,tone.data.size(),2):peak=maxi(peak,absi(tone.data.decode_s16(i)))
		check(tone==Warning.tone(kind) and tone.mix_rate==24000 and tone.format==AudioStreamWAV.FORMAT_16_BITS,"original "+kind+" warning PCM cached once")
		check(absf(tone.get_length()-.065)<.0001 and peak>10000 and peak<32767 and tone.data.decode_s16(0)==0,"original "+kind+" tone has finite unclipped 65 ms envelope")
	check(Warning.tone("frag").data!=Warning.tone("zone").data,"frag and zone warning timbres distinguishable")
	var frag=projectile("frag");var fine:Array=[];frag.warning_beep.connect(func(_kind,at,_remaining):fine.append(at))
	var fuse:float=frag.tuning.frag_fuse_seconds
	step_for(frag,fuse-.001,1.0/90)
	check(not frag.finished and fine.size()==Warning.beat_times(fuse).size(),"production frag emits every accelerating warning before detonation")
	frag._physics_process(.002)
	check(frag.finished and host.blasts==1 and frag._warning_times.is_empty() and not frag.warning_sound.playing,"frag detonates once and stops warning at configured fuse")
	var chunked=projectile("frag");var coarse:Array=[];chunked.warning_beep.connect(func(_kind,at,_remaining):coarse.append(at))
	step_for(chunked,fuse-.001,.37)
	check(fine==coarse,"production warning event times independent of frame partition")
	chunked.free()
	var paused=projectile("frag");paused._physics_process(.1);var before:float=paused.age;var next:int=paused._warning_next
	host.paused=true;paused._physics_process(.7);host.paused=false
	check(paused.age==before and paused._warning_next==next,"game pause advances neither fuse nor warning rhythm")
	paused.set_paused(true);paused._physics_process(.7)
	check(paused.age==before and paused._warning_next==next and paused.freeze,"direct pause also freezes countdown and physical projectile")
	paused.set_paused(false);paused._physics_process(.7)
	check(paused.age>before and paused._warning_next>next and not paused.warning_sound.stream_paused,"resume continues warnings from preserved countdown")
	paused.free()
	var zone=projectile("zone");var zone_beats:Array=[];zone.warning_beep.connect(func(_kind,at,_remaining):zone_beats.append(at))
	zone._physics_process(1.8)
	check(zone_beats.is_empty() and not zone.zone_active and zone.activation_age==0,"zone warning countdown waits for impact rather than throw")
	zone._on_contact(null);var delay:float=zone.tuning.zone_activation_delay
	step_for(zone,delay-.001,1.0/90)
	var prior_age:float=zone.activation_age;zone._on_contact(null)
	check(zone.stuck and not zone.zone_active and zone_beats.size()==Warning.beat_times(delay).size() and zone.activation_age==prior_age,"zone beeps accelerate through unchanged 2.7 s impact delay; repeat contact cannot reset it")
	zone._physics_process(.002)
	check(zone.zone_active and zone._warning_times.is_empty() and not zone.warning_sound.playing,"zone warning stops exactly when field activates")
	step_for(zone,10.0,.17)
	check(zone.finished and zone.zone_ticks==20 and host.ticks==20,"zone retains 10 s field and twenty half-second damage ticks")
	var rocket=projectile("smaw")
	check(rocket.warning_sound==null and rocket._warning_times.is_empty(),"SMAW flight sound remains separate from grenade warnings");rocket.free()
	print("WARNING_SCHEDULES=",JSON.stringify({"frag_seconds":fuse,"frag_beats":fine,"zone_impact_delay_seconds":delay,"zone_beats":zone_beats,"timing_original_not_measured_reference":true}))
	await process_frame;host.free();await create_timer(.1).timeout
	print("GRENADE_WARNING_061 checks=",checks," failures=",failures," actual_production_scheduler=true audio_driver=Dummy heard=false headset_tested=false")
	quit(failures)
