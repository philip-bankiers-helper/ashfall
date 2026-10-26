extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var reference=preload("res://scripts/reference_audio_096.gd")
	check(not reference.enabled(),"authored comparison argument recognized")
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	for index in game.weapon.ACTIVE_WEAPON_INDICES:
		var gun:Node3D=game.weapon.weapons[index]
		if gun.has_method("sample_motion"):continue
		var guns:Array=gun.guns if "guns" in gun else [gun]
		for part in guns:
			check(reference.weapon("shot",part,0)==null,"reference weapon bypassed "+str(index))
			check(AshAudioBank.for_weapon(part,"shot")==AshAudioBank.sample(part.shot_sound_kind_089()),"original report active "+str(index))
	for kind in ["metal_step","build_place","katana_shield","katana_shield_raise"]:
		check(reference.generic(kind,0)==null,"generic reference bypassed "+kind)
		check(AshAudioBank.sample(kind).data.size()>4000,"authored generic available "+kind)
	check(reference.action("consume_drink","shaker",0)==null,"reference action bypassed")
	check(AshAudioBank.for_action("shaker","consume_drink")==AshAudioBank.sample("consume_drink"),"authored shaker available")
	game.queue_free();await process_frame;await process_frame
	print("AUDIO_FALLBACK_096 checks=",checks," failures=",failures," authored_audio=true xr_runtime=off")
	quit(0 if failures==0 else 1)
