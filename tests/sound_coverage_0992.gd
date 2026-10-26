extends SceneTree
const Reference=preload("res://scripts/reference_audio_099.gd")
const Cues=preload("res://scripts/sound_cues099.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func voices(owner:Node)->int:
	var count:=0
	for child in owner.get_children():
		if child is AudioStreamPlayer3D:count+=1
	return count
func run()->void:
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game)
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	for kind in ["menu_click","menu_hover","game_start_music","vr_initialize","item_pickup","item_highlight","concrete_step","concrete_run_step","glide","sword_swing","zone_bloom","frag_blast","grenade_throw","build_lightning","build_place","revive_facing","revive_ready_full0992","revive_charge","revive_discharge","harmonica"]:
		check(Reference.generic(kind,0)!=null,"new reference category available "+kind)
	for kind in ["glide","build_lightning","revive_facing"]:
		check(Reference.generic(kind,0).loop_mode==AudioStreamWAV.LOOP_FORWARD,"bounded sustained loop "+kind)
	check(Reference.generic("game_start_music",0).stereo and Reference.generic("vr_initialize",0).stereo,"menu music and initialization retain stereo")
	check(Reference.manifest().generic.harmonica.size()==3,"three harmonica phrases bank-ready")
	var menu:Node3D=game.front_menu;menu.set_active(true);menu._menu_edge097(false,-1)
	var music_voice:AudioStreamPlayer=Cues.play_ui(menu,"game_start_music")
	check(music_voice.bus=="Music","start music respects the music bus")
	music_voice.stop();music_voice.queue_free()
	menu._menu_edge097(true,3);check(menu.page=="lobby","menu press captures without selecting")
	menu._menu_edge097(false,3);check(menu.page=="loadout","menu release performs selection")
	game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	var owner:Node
	for node in game.get_children():
		if node.get_script()==Cues:owner=node;break
	check(owner!=null,"interaction audio coordinator attached")
	game.player.input_enabled=true;game.paused=false
	var ring:=Node3D.new();game.add_child(ring);var label:=Label3D.new();label.text="PISTOL AMMO";ring.add_child(label)
	game.weapon_inventory.aim_rings={"test":ring};game.ammo_pickups.aim_rings.clear();game.field_consumables.aim_rings.clear()
	var count:=voices(owner);owner._process(.01);check(voices(owner)==count+1,"first highlighted item emits one cue")
	owner._process(.01);owner._process(.01);check(voices(owner)==count+1,"steady hover never replays every frame")
	label.text="SNIPER AMMO";owner.next_hover_ms=0;owner._process(.01);check(voices(owner)==count+2,"new highlighted target emits one cue")
	game.player.input_enabled=false;owner._process(.01);check(voices(owner)==count+2,"disabled input emits no hover cue")
	game.player.input_enabled=true;game.weapon_inventory.capacity=6
	count=voices(owner);var picked:bool=game.weapon_inventory.pickup_weapon(7)
	check(picked and voices(owner)==count+1,"actual successful weapon transfer emits pickup cue")
	game.weapon_inventory.pickup_weapon(7);check(voices(owner)==count+1,"rejected duplicate transfer emits no pickup cue")
	var actor:Node3D=game.player;var ambience:Node3D=game.ambience
	actor.global_position=Vector3(200,20,0);actor.sprinting=false;ambience._step(false)
	check(ambience._foot.stream==Reference.generic("concrete_step",0),"walking uses recorded walking footfall")
	actor.sprinting=true;ambience._step(false)
	check(ambience._foot.stream==Reference.generic("concrete_run_step",1),"running uses separate recorded footfall variant")
	check(ambience._glide.stream==Reference.generic("glide",0),"real flight bed loads recorded glide loop")
	var cyber:Node3D=game.weapon.weapons[16]
	check(cyber._hum.stream==Reference.action("shield_sustain","cyberblade",0),"Cyberblade holds its actual sustained shield recording")
	var pads:Node3D=game.revive_paddles;pads.equip();pads._facing=true;pads.charge=.5;pads._update_reference099(Vector3.ZERO)
	check(pads._reference099.playing and pads._reference099.stream==Reference.generic("revive_facing",0),"facing paddles start recorded charging layer")
	pads._facing=false;pads._update_reference099(Vector3.ZERO);check(not pads._reference099.playing,"facing away stops charging layer")
	pads._add_charge(1);pads._update_reference099(Vector3.ZERO)
	check(not pads._reference099.playing and pads._audio.playing and pads._audio.stream==Reference.generic("revive_ready_full0992",0) and pads._audio.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"charged paddles play full activation once even separated")
	pads.tick_ready_window097(3.51);check(not pads._reference099.playing and not pads.charge_ready,"measured3.5second expiry stops one-shot")
	var effect:Node3D=load("res://scripts/explosive_effect.gd").new();game.add_child(effect);effect.setup("frag");effect._process(2.6)
	check(not effect.visible and not effect.is_queued_for_deletion() and effect._tail_sound099.playing,"blast visuals end while natural audio decay continues")
	effect._tail_sound099.stop();effect._process(.01);check(effect.is_queued_for_deletion(),"finished decay releases transient effect")
	game.queue_free();await process_frame;await process_frame
	print("SOUND_COVERAGE_0992 checks=",checks," failures=",failures," xr_runtime=off by_ear_approved=false");quit(failures)
