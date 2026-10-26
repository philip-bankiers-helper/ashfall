extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;print("FAIL ",label)
func component(wav:AudioStreamWAV,hz:float)->float:
	var real_value:=0.0;var imag:=0.0;var count:=wav.data.size()/2
	for i in count:
		var sample:=float(wav.data.decode_s16(i*2))/32768.0;var angle:=TAU*hz*i/wav.mix_rate
		real_value+=sample*cos(angle);imag+=sample*sin(angle)
	return Vector2(real_value,imag).length()/count
func run()->void:
	var kinds:={"sword_swing":1,"katana_shield_raise":1,"katana_shield":1,"revive_shepard":1,"rifle":4,"shot_pistol":3,"shot_smg":3,"shot_shotgun":3,"shot_sniper":3,"shot_lmg":3,"shot_launcher":3,"shot_suppressed":3,"mag_eject":2,"mag_insert":2,"bolt":2,"dry":2,"pouch":2,"impact_metal":3,"impact_concrete":3,"ammo_pickup":1,"build_pickup":1,"build_place":3,"build_break":3,"build_lightning":1,"build_start":1,"revive_charge":10,"revive_ready":1,"revive_discharge":1,"consume_open":2,"consume_drink":2,"consume_shake":2,"consume_ready":1,"item_equip":1,"item_stow":1}
	var total:=0
	for kind in kinds:
		for variant in kinds[kind]:
			var path:String="res://assets/audio/sfx/%s_%02d.wav"%[kind,variant]
			check(ResourceLoader.exists(path),"authored file is packaged "+path)
			var wav:AudioStreamWAV=AshAudioBank.sample(kind,variant);total+=1
			check(wav.mix_rate==48000 and not wav.stereo and wav.format==AudioStreamWAV.FORMAT_16_BITS,"spatial mono48k16bit "+path)
			var count:=wav.data.size()/2;var peak:=0.0;var dc:=0.0;var power:=0.0
			for i in count:
				var sample:=float(wav.data.decode_s16(i*2))/32768.0;peak=maxf(peak,absf(sample));dc+=sample;power+=sample*sample
			check(count>4000 and peak>.1 and peak<.80,"nonempty unclipped PCM "+path)
			check(absf(dc/count)<.01 and sqrt(power/count)>.005,"controlled DC and audible energy "+path)
			if kind in ["katana_shield","revive_shepard"]:
				var seam:float=float(wav.data.decode_s16(0)-wav.data.decode_s16((count-1)*2))/32768.0
				var derivative:float=float(wav.data.decode_s16(2)-wav.data.decode_s16(0))/32768.0
				check(absf(seam-derivative)<.005,"phase-continuous loop boundary "+path)
			else:check(wav.data.decode_s16(0)==0 and abs(wav.data.decode_s16((count-1)*2))<100,"faded transient or loop boundary "+path)
	check(total==76,"75authored variants in delivery")
	var charge:AudioStreamWAV=AshAudioBank.sample("revive_charge",0)
	check(component(charge,880)>component(charge,1000)*8 and component(charge,1100)>component(charge,1000)*8,"Tartini-style5to4carrier pair present")
	check(component(charge,220)>component(charge,1000)*3,"low difference component reinforces charge tone")
	check(AshAudioBank.sample("build_lightning").loop_mode==AudioStreamWAV.LOOP_FORWARD,"lightning uses cached bounded loop")
	print("AUDIO_091 checks=",checks," failures=",failures," pcm_analyzed=true subjective_headset_mix_unverified=true")
	quit(0 if failures==0 else 1)
