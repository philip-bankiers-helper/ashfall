extends SceneTree
var checks:=0
var failures:=0
var heard:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func advance(ambience,seconds:float)->void:
	for frame in roundi(seconds*90):ambience._physics_process(1.0/90.0)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_physics_process(false);actor.set_process(false)
	actor.xr_enabled=true;actor.tracking_available=true;actor.xr_camera.position.y=1.7;actor.get_standing_eye_height();actor._supported=true
	var a=load("res://scripts/ambience.gd").new();root.add_child(a);a.setup(actor,null);a.set_physics_process(false);a.movement_foley.connect(func(kind):heard.append(kind))
	actor.velocity=Vector3(3.4,0,0);actor.sprinting=false;advance(a,10)
	check(heard.count("walk")>=19 and heard.count("walk")<=21,"ten seconds actual walking emits20 bounded footfalls")
	check(is_equal_approx(a._foot.volume_db,-22),"walk mix retains quiet gain")
	heard.clear();a._stride=0;actor.sprinting=true;actor.velocity.x=19.5;advance(a,10)
	var sprint_count:=heard.count("sprint")
	check(sprint_count>=29 and sprint_count<=31,"ten seconds actual sprint emits30 natural footfalls")
	check(is_equal_approx(a._foot.volume_db,-15) and a._foot.max_db>=a._foot.volume_db,"sprint is7dB louder and spatial max does not clamp it to old quiet gain")
	heard.clear();a._stride=0;actor.velocity.x=1000;advance(a,10)
	check(heard.count("sprint")==sprint_count,"extreme speed does not accelerate cadence")
	heard.clear();actor.xr_camera.position.y=1.0;advance(a,10)
	check(heard.is_empty(),"physically crouched walking is silent")
	actor.xr_camera.position.y=1.7;actor.gliding=true;advance(a,2)
	check(heard.is_empty() and absf(db_to_linear(a._glide.volume_db)-.45)<.001,"gliding has no footsteps and reaches bounded louder wind gain")
	check(a._glide.volume_db>-7.1 and a._glide.volume_db<-6.8,"glide peak gain rises13.1dB over052")
	actor.gliding=false;actor.climbing=true;actor.velocity=Vector3.UP;heard.clear();advance(a,3)
	check(heard.count("climb")==5 and heard.size()==5,"moving climb emits modest bounded glove/cloth contacts only")
	check(a._climb.volume_db<=-25 and a._climb.stream.get_length()>.2,"climbing sound is short and modest")
	actor.velocity=Vector3.ZERO;heard.clear();advance(a,3);check(heard.is_empty(),"stationary wall grip has no repeating climb sound")
	a.set_paused(true);actor.velocity=Vector3.ONE;advance(a,3);check(heard.is_empty(),"paused movement cannot emit foley")
	var bank=load("res://scripts/audio_bank.gd");var clip:AudioStreamWAV=bank.sample("climb");var max_sample:=0
	for i in clip.data.size()/2:max_sample=maxi(max_sample,absi(clip.data.decode_s16(i*2)))
	check(max_sample<30000 and max_sample>1000,"original climb PCM has signal and no clipped samples")
	var limiter:=false
	for i in AudioServer.get_bus_effect_count(0):
		var fx=AudioServer.get_bus_effect(0,i)
		if fx is AudioEffectHardLimiter:limiter=fx.ceiling_db<=-1.0
	check(limiter,"master peak ceiling remains-1dB")
	a.shutdown();a.queue_free();actor.queue_free();await create_timer(.2).timeout
	print("MOVEMENT_AUDIO_053 checks=",checks," failures=",failures," dispatch_tested=true auditioned=false")
	quit(failures)
