extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	var ref=preload("res://scripts/reference_audio_097.gd")
	for spec in [[24,"mag_insert"],[24,"bolt"],[13,"bolt"]]:
		var gun:Node3D=game.weapon.weapons[spec[0]]
		var stream:=AshAudioBank.for_weapon(gun,spec[1])
		check(stream==ref.weapon(spec[1],gun,0) and stream.get_length()>.20,"specific reload stroke "+str(spec))
		gun._play(stream);check(gun._sound.stream==stream,"actual reload audio player "+str(spec))
	for kind in ["soda","shaker"]:
		game.field_consumables.held_kind=kind;game.field_consumables._play_cue("drink")
		check(game.field_consumables._audio.stream==ref.action("consume_drink",kind,game.field_consumables.audio_events.size()),"actual drink callback "+kind)
		game.field_consumables._play_cue("open")
		check(game.field_consumables._audio.stream==ref.action("consume_open",kind,game.field_consumables.audio_events.size()),"actual opening callback "+kind)
	var sword:Node3D=game.weapon.weapons[14];game.player.left_hand_reserved=false;game.player.head_obstructed=false
	sword.show();sword.model.show()
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true;Input.parse_input_event(press)
	await create_timer(.08).timeout
	sword._update_guard()
	await create_timer(.08).timeout
	var stream:AudioStreamWAV=AshAudioBank.sample("katana_shield")
	check(stream==ref.generic("katana_shield",0) and stream.get_length()>8,"continuous long reference loop selected")
	check(sword.shield_active and sword._hum.playing and sword._hum.stream==stream,"real shield starts sampled sustain")
	for i in 23:
		await create_timer(.40).timeout
		sword._update_guard()
		check(sword._hum.stream==stream and sword._hum.playing,"sampled sustain still playing at "+str((i+1)*.4)+" seconds")
	check(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and sword._hum.get_playback_position()<stream.get_length(),"playback crossed full loop without authored substitution")
	press.pressed=false;Input.parse_input_event(press);await process_frame;sword._update_guard();await physics_frame
	check(not sword._hum.playing,"shield release stops sustain")
	game.queue_free();await process_frame;await process_frame
	print("AUDIO_SUSTAIN_097 checks=",checks," failures=",failures," xr_runtime=off by_ear_verified=false");quit(failures)
