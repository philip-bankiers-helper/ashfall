extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title();freeze(game)
	var actor:Node3D=game.player;actor.input_enabled=true;var menu:Node3D=game.field_menu
	check(menu.audio_volumes.Music==0 and menu.audio_volumes.Ambience==0,"music and ambience default off")
	for bus in ["Music","Ambience"]:check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),"muted default bus "+bus)
	check(game.ambience._glide.bus=="SFX" and game.ambience._foot.bus=="SFX" and game.ambience._wind.bus=="Ambience","movement sounds remain separate from muted environmental bed")
	menu.apply_settings({"audio_volumes":{"Music":.7,"Ambience":.6,"SFX":.8,"Voice":.9}})
	check(menu.audio_volumes.Music==0 and menu.audio_volumes.Ambience==0 and menu.audio_volumes.SFX==.8,"one-time migration honors quiet defaults without changing other audio choices")
	var saved:Dictionary=menu.get_settings();saved.audio_volumes.Music=.2;saved.audio_volumes.Ambience=.1;menu.apply_settings(saved)
	check(menu.audio_volumes.Music==.2 and menu.audio_volumes.Ambience==.1,"later explicit volume changes survive reload")
	menu.set_open(true);menu._choose(1);check(menu.settings_page=="root","existing settings still reachable")
	check(menu._panel.get_node("SettingsBoard").mesh.size==Vector2(1.3,1.48),"settings retains full width")
	menu._choose(4);check(menu.settings_page=="pause","back returns to pause")
	check(menu._panel.get_node("SettingsBoard").mesh.size==Vector2(.70,1.25),"pause uses narrow reference-style panel")
	for i in 4:
		check(menu._pause_style0993.cards[i].visible and menu._pause_style0993.glyphs[i].visible,"pause icon/card visible "+str(i))
		check(absf(menu._pause_style0993.cards[i].position.y-menu._menu_row_y(i))<.00001,"card and hit row agree "+str(i))
	menu._choose(0);actor.input_enabled=true
	actor.initialize_vertical_combat_system();actor.xr_origin.position.y=.137
	var calibration:=[actor.vertical_combat_initialized,actor.vertical_combat_tracking_baseline,actor.vertical_combat_world_baseline_m,actor.vertical_combat_origin_lift,actor.xr_origin.position.y]
	actor.snap_degrees=75;menu.weapon_settings.motion_damping=1.1
	# Exercise the XR branch without initializing any XR runtime or session.
	game.xr_enabled=true
	for map in ["range","valley","range"]:
		game._return_home0992();game.front_menu.selected_map=map;game._start_from_title();freeze(game)
		check(not game.vertical_combat.active and not actor.vertical_combat_initializing,"map Ready does not initialize VCS "+map)
		check(calibration==[actor.vertical_combat_initialized,actor.vertical_combat_tracking_baseline,actor.vertical_combat_world_baseline_m,actor.vertical_combat_origin_lift,actor.xr_origin.position.y],"calibration survives map switch "+map)
		check(actor.snap_degrees==75 and menu.weapon_settings.motion_damping==1.1,"control settings survive map switch "+map)
	game.xr_enabled=false;actor.input_enabled=true;game.paused=false
	menu.set_open(true);menu._choose(2);check(game.vertical_combat.active,"explicit Initialize button remains functional");game.vertical_combat.cancel();actor.input_enabled=true
	var pads:Node3D=game.revive_paddles;pads.equip();pads._add_charge(1);pads.tick_ready_window097(.7)
	var original_audio:AudioStream=pads._audio.stream;var remaining:float=pads.ready_remaining097
	var first:=preload("res://scripts/rescue_training_dummy.gd").new();game.add_child(first);first.global_position=actor.global_position+Vector3(0,0,-1)
	var second:=preload("res://scripts/rescue_training_dummy.gd").new();game.add_child(second);second.global_position=first.global_position+Vector3.RIGHT
	await physics_frame
	for target in [first,second]:
		var points:Array=target.revive_contacts();pads._paddles[0].global_position=points[0];pads._paddles[1].global_position=points[1]
		check(pads.step_contacts(.01,points[0],points[1],true,Vector3.RIGHT,Vector3.LEFT),"real contact revives ally within the same ready window")
		check(pads.charge_ready and absf(pads.ready_remaining097-remaining)<.0001,"successful revive neither cancels nor extends ready timer")
		check(pads._audio.stream==original_audio and pads._audio.playing,"ready recording is not interrupted by contact cue")
	check(pads.successful_revives==2 and not first.can_revive() and not second.can_revive(),"two distinct allies revived once each")
	check(not pads._revive(first),"already revived ally cannot trigger duplicate rescue")
	pads.tick_ready_window097(remaining+.01);check(not pads.charge_ready,"original deadline still expires")
	var marks:Node3D=game.building_input.team_marks;var inventory:Node3D=game.weapon_inventory;var hand:Node3D=actor.get_weapon_hand()
	var ring:Node3D=inventory.aim_rings.get(hand)
	if ring==null:ring=inventory._create_aim_ring(hand);inventory.aim_rings[hand]=ring
	ring.set_meta("pickup_index",7);ring.show()
	if not inventory.pickups.has(7):inventory.pickups[7]=inventory._create_prop(7)
	check(marks._pointed_weapon0993().index==7,"visible ground weapon selector supplies contextual mark")
	marks.consume_state({"eligible":true,"pressed":false},.01)
	marks.consume_state({"eligible":true,"pressed":true,"hit":{}},.03)
	marks.consume_state({"eligible":true,"pressed":false},.01)
	check(marks.records.size()==1 and marks.records[0].action=="weapon" and marks.records[0].weapon_index==7,"B tap marks highlighted weapon even without a terrain hit")
	var icon:Sprite3D=marks._visuals[0].get_node("BasePingIcon")
	check(icon.texture==preload("res://scripts/weapon_icons_094.gd").icon(7),"weapon mark uses actual shared photograph thumbnail")
	check(marks._wheel.SLOT_ACTIONS.size()==8 and not marks.ACTIONS.slice(0,8).has("weapon") and marks.ACTIONS[5]=="emote_alt","weapon leaves wheel and second emote fills its slot")
	var hit:Dictionary={"position":actor.global_position+Vector3(0,0,-2),"normal":Vector3.UP}
	marks.consume_state({"eligible":true,"pressed":true,"hit":hit,"choice":Vector2(-1,-1)},.2)
	marks.consume_state({"eligible":true,"pressed":false},.01)
	check(marks.records[0].action=="emote_alt" and marks.records[0].surface_decal,"held B plus explicit wheel selection overrides contextual weapon mark")
	ring.hide();check(marks._pointed_weapon0993().is_empty(),"hidden selector cannot create contextual weapon mark")
	marks.consume_state({"eligible":true,"pressed":true,"hit":hit},.03)
	marks.consume_state({"eligible":true,"pressed":false},.01)
	check(marks.records[0].action=="location","ordinary B tap remains a location ping when no weapon selector is visible")
	for index in [3,4,5]:
		for normal in [Vector3.UP,Vector3.BACK,Vector3.DOWN,Vector3(.2,.9,.3).normalized()]:
			var point:Vector3=actor.global_position+Vector3(0,1,-3);var before:int=marks.ping_audio_events0993
			marks._create_mark(point,normal,index);var visual:Node3D=marks._visuals[0];icon=visual.get_node("BasePingIcon")
			check(marks.records.size()==1 and marks.records[0].surface_decal,"surface paint keeps single-mark invariant")
			check(visual.find_child("DottedSkyColumn",true,false)==null,"emote/target paint has no sky column")
			check(visual.global_basis.z.dot(normal)>.9999 and absf(visual.global_basis.determinant()-1)<.0001,"paint plane follows arbitrary surface normal without mirroring")
			check(absf(visual.global_position.distance_to(point)-.004)<.0001 and icon.position==Vector3.ZERO and icon.billboard==BaseMaterial3D.BILLBOARD_DISABLED,"paint lies on surface instead of floating or facing viewer")
			check(marks.ping_audio_events0993==before+1,"one mark emits one confirmation cue")
	for index in [0,1,2,6,7]:
		marks._create_mark(actor.global_position,Vector3.UP,index)
		check(marks._visuals[0].find_child("DottedSkyColumn",true,false)!=null,"regular location marks retain sky column")
	var ping:AudioStreamWAV=AshAudioBank.sample("mark_ping0993");check(ping.get_length()==.36 and ping.mix_rate==48000 and ping.format==AudioStreamWAV.FORMAT_16_BITS,"original bloop present and PCM format correct")
	var pcm_hash:=HashingContext.new();pcm_hash.start(HashingContext.HASH_SHA256);pcm_hash.update(ping.data);check(pcm_hash.finish().hex_encode()=="f04539e823c3ac7fd07a5eb4daa5641913438a1cf49f96ecdb84c8ec54798124","new ping PCM is exact in source and package")
	first.free();second.free();game.queue_free();await process_frame;await process_frame
	print("FEEDBACK_0993 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false");quit(failures)
