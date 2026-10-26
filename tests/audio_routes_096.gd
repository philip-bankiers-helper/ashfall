extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
const Reference=preload("res://scripts/reference_audio_096.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func rms(sound:AudioStreamWAV)->float:
	var sum:=0.0;var count:=mini(12000,sound.data.size()/2)
	for i in count:sum+=pow(float(sound.data.decode_s16(i*2))/32768,2)
	return sqrt(sum/maxi(1,count))
func run()->void:
	game=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	var manifest:=Reference.manifest()
	check(ProjectSettings.get_setting("application/config/version")=="0.9.6","isolated096 version")
	check(manifest.files.size()==52 and manifest.weapons.size()==21,"reviewed52file21weapon manifest")
	var lookup:Dictionary={}
	for record in manifest.files:
		lookup[record.file]=record
		check(ResourceLoader.exists(record.file),"sample in source/package "+record.file)
		var sound:AudioStreamWAV=Reference.variant([record.file],0,record.loop)
		check(sound!=null and sound.mix_rate==48000 and not sound.stereo and sound.format==AudioStreamWAV.FORMAT_16_BITS,"spatial mono48k16bit "+record.file)
		var peak:=0.0
		for i in sound.data.size()/2:peak=maxf(peak,absf(float(sound.data.decode_s16(i*2))/32768))
		check(peak>.015 and peak<.95,"audible unclipped runtime sample")
		check(not record.listening_approved,"no invented listening approval")
		if record.loop:
			check(sound.loop_mode==AudioStreamWAV.LOOP_FORWARD,"real katana loop flag")
		else:
			check(sound.data.decode_s16(0)==0 and abs(sound.data.decode_s16(sound.data.size()-2))<50,"fade/pad edges")
	var loudest:=0.0;var awp_energy:=0.0
	for index in game.weapon.ACTIVE_WEAPON_INDICES:
		var gun:Node3D=game.weapon.weapons[index]
		if gun.has_method("sample_motion"):continue
		var guns:Array=gun.guns if "guns" in gun else [gun]
		for part in guns:
			var id:=str(part.get_meta("reference_id",""));if id=="uzi":id="uzis"
			var sound:AudioStreamWAV=AshAudioBank.for_weapon(part,"shot",0)
			if not manifest.weapons.has(id):continue
			check(sound==Reference.weapon("shot",part,0),"weapon-specific discharge route "+id)
			var saved:int=part._shot_voice_cursor
			part._play_shot()
			check(part._shot_voices[saved].stream==sound,"actual gun voice plays assigned report "+id)
			var energy:=rms(sound)*db_to_linear(-1 if id=="awp" else -5)
			if id=="awp":awp_energy=energy
			else:loudest=maxf(loudest,energy)
	check(awp_energy>loudest*1.4,"AWP remains strongest early report at actual voice gain")
	var s85:Node3D=game.weapon.weapons[25]
	check(AshAudioBank.for_weapon(s85,"shot")==AshAudioBank.sample(s85.shot_sound_kind_089()),"unverifiedS85 retains authored shot")
	for index in [2,3,5,7,13,25]:
		var gun:Node3D=game.weapon.weapons[index]
		check(AshAudioBank.for_weapon(gun,"mag_eject")==AshAudioBank.sample("mag_eject"),"no mixed sequence replaces reload stroke "+str(index))
	for index in [11,12]:
		var gun:Node3D=game.weapon.weapons[index].guns[0]
		var sound:=AshAudioBank.for_weapon(gun,"mag_insert")
		check((sound==Reference.weapon("mag_insert",gun,0))==(index==11),"Uzi-specific flip; Matador fallback")
	for kind in ["metal_step","build_place","katana_shield","katana_shield_raise"]:
		check(AshAudioBank.sample(kind)==Reference.generic(kind,0),"specific verified generic cue "+kind)
	check(AshAudioBank.for_action("shaker","consume_drink")==Reference.action("consume_drink","shaker",0),"shaker drinking exact action route")
	for subject in ["soda","banana"]:
		check(AshAudioBank.for_action(subject,"consume_drink")==AshAudioBank.sample("consume_drink"),"shaker sound not assigned to "+subject)
	for kind in ["revive_charge","revive_discharge","build_break","consume_shake","glide","climb"]:
		check(Reference.generic(kind,0)==null,"unverified cue retains authored bank "+kind)
	var shaker:Node3D=game.field_consumables
	shaker.held_kind="shaker";shaker._play_cue("drink")
	check(shaker._audio.stream==Reference.action("consume_drink","shaker",shaker.audio_events.size()),"actual consumable callback routes shaker")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/reference096/manifest.json"))
	for weapon in ["akm","cx4","m60","mk18","rfb","tec9","mp5","mp9","p90","ump","uzis"]:
		for path in report.weapons[weapon].shot:
			var record:Dictionary=lookup[path]
			check(record.master_end_seconds-record.master_start_seconds<=.116,"one attack per automatic shot "+weapon)
	game.queue_free();await process_frame;await process_frame
	print("AUDIO_ROUTES_096 checks=",checks," failures=",failures," xr_runtime=off headset_mix_unverified=true")
	quit(0 if failures==0 else 1)
