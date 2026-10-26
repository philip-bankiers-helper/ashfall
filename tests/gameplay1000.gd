extends SceneTree
const Arsenal=preload("res://scripts/arsenal_data.gd")
const Maps=preload("res://scripts/map_catalog1000.gd")
var game:Node
var net:Node
var bridge:Node
var checks:=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func grant(cat:int)->Node:
	var profile:Dictionary=Arsenal.profile(cat);var capacity:int=int(profile.magazine_per_hand)*(2 if cat in [11,12] else 1)
	var eid:="qa_gun_"+str(cat)
	var row:Dictionary={"id":eid,"kind":"weapon","catalog":cat,"owner":1,"ammo":0,"capacity":capacity,"reload":"ready","seated":0,"position":Vector3.ZERO,"basis":Basis.IDENTITY,"rocket_reserve":2 if cat==27 else 0}
	net._normalize_weapon(row);net.entities[eid]=row;net.players[1].inventory=[eid];net.players[1].reserves=game.weapon.INITIAL_RESERVES.duplicate(true)
	net._publish();game.weapon.selected=int(bridge.indices[eid]);game.weapon.is_holstered=false;game.weapon._apply_selection();game.weapon._draw_delay=0
	var gun:Node=game.weapon.weapons[game.weapon.selected];gun.cooldown=0;game.player.input_enabled=true
	bridge._bind_reload_events();return gun
func run()->void:
	game=Node3D.new();game.set_script(load("res://scripts/main.gd"));root.add_child(game)
	for i in 5:await process_frame
	bridge=game.network_bridge;net=bridge.net
	check(Maps.IDS.size()==3,"all three maps registered")
	for id in Maps.IDS:
		check(Maps.image(id)!=null,id+" selector screenshot")
		check(ResourceLoader.exists("res://assets/maps1000/%s_top.png"%id),id+" cartographic image")
	check(Maps.uv("range",Vector3(0,0,600)).is_equal_approx(Vector2(.5,.5)),"range north-up coordinates")
	check(Maps.uv("cyber_bird",Vector3(0,0,2400)).is_equal_approx(Vector2(.5,.5)),"city north-up coordinates")
	check(net.host("Al",24882)==OK,"integrated state host")
	net.rules.map="range";net.rules.mode="respawn";net.rules.protection=0.0;net.rules.score_limit=0;net.rules.time_limit=0;net._add_player(2,"Friend","")
	net._begin_loading();net._publish()
	for i in range(30):
		await process_frame
		if not bridge._preparing and net.players[1].loaded:break
	net.players[2].loaded=true;net._try_start();net._publish()
	for i in 5:await process_frame
	game.set_process(false);game.paused=false;game.player.set_physics_process(false);game.player.input_enabled=true
	check(net.stage=="match","integrated match entered")
	check(game.weapon_inventory.owned.size()==3,"six-slot inventory starts with three weapons")
	for cat in [0,2,3,9,10,13,17,18,19,20,21,23,24,25]:
		var gun:Node=grant(cat)
		gun.eject_magazine();gun.grab_magazine();gun.insert_magazine();gun.rack_bolt()
		var eid:="qa_gun_"+str(cat)
		check(net.entities[eid].reload=="ready",game.weapon.weapon_names[cat]+" reload state reaches ready")
		check(int(net.entities[eid].ammo)>0 and gun.ammo==int(net.entities[eid].ammo),game.weapon.weapon_names[cat]+" real mechanism agrees with server ammo")
	var magnum:Node=grant(7);magnum.eject_magazine();magnum.insert_magazine();magnum.rack_bolt()
	check(net.entities.qa_gun_7.reload=="ready" and magnum.ammo==magnum.magazine_size,"magnum chambers survive synchronous server confirmation")
	var dt:Node=grant(1);dt.eject_magazine();dt.grab_magazine();dt.insert_magazine();dt.rack_bolt()
	check(net.entities.qa_gun_1.reload=="ready" and dt.ammo==2,"DT11 action and network reload agree")
	var m60:Node=grant(8)
	m60.open_cover();m60.remove_box();m60.grab_magazine();m60.insert_magazine();m60.feed_belt();m60.close_cover();m60.rack_bolt()
	check(net.entities.qa_gun_8.reload=="ready","M60 four-stroke mechanism complete")
	check(m60.ammo==m60.magazine_size and m60.seated==m60.magazine_size,"M60 seated belt survives confirmation")
	var awp:Node=grant(5)
	awp.desktop_reload_step();awp.desktop_reload_step();awp.desktop_reload_step()
	check(awp.reload_state=="ready" and awp.ammo==awp.magazine_size,"AWP magazine and bolt reload agree")
	net.entities.qa_gun_5.ammo-=1;net.entities.qa_gun_5.reload="needs_bolt";net.entities.qa_gun_5.cycle_only=true;net._publish()
	var awp_rounds:int=awp.ammo;awp._finish_cycle()
	check(awp.ammo==awp_rounds and net.entities.qa_gun_5.ammo==awp_rounds,"AWP cycling a spent chamber does not refill magazine")
	for cat in [11,12]:
		var pair:Node=grant(cat)
		for gun in pair.guns:gun.reload_flick()
		pair._sync_pair()
		check(pair.ammo==pair.magazine_size,"both "+game.weapon.weapon_names[cat]+" hands reload independently")
		check(int(net.entities["qa_gun_"+str(cat)].ammo)==pair.ammo,"paired server rounds match both mechanisms")
		check(not bridge.tactical.map_eligible(),"equipped dual gun preserves left-trigger firing")
		game.weapon.set_holstered(true);check(bridge.tactical.map_eligible(),"A holster makes map available with dual guns")
	var rocket:Node=grant(27);rocket.reload_state="needs_mag";net.entities.qa_gun_27.reload="needs_mag"
	rocket.grab_magazine();rocket.insert_magazine()
	check(rocket.ammo==1 and net.entities.qa_gun_27.ammo==1,"rocket chamber reload authoritative")
	check(rocket.rocket_reserve==1 and int(net.entities.qa_gun_27.rocket_reserve)==1,"finite rocket reserve decremented once")
	var tactical:Node=bridge.tactical
	tactical.consume_trigger(false,true);tactical.consume_trigger(true,true);check(tactical.opened,"left trigger rising edge opens map")
	tactical.consume_trigger(true,true);check(tactical.opened,"held trigger does not toggle repeatedly")
	check(not rocket._input_allowed(),"map trigger cannot simultaneously fire weapon")
	tactical.consume_trigger(false,true);tactical.consume_trigger(true,true);check(not tactical.opened,"second press closes map")
	tactical.consume_trigger(false,false);tactical.consume_trigger(true,false);check(not tactical.opened,"menu input does not open tactical map")
	var local_settings:Dictionary=bridge.personal_settings(game.field_menu.get_settings())
	check(local_settings.fling_power==bridge._local_rules.fling_power,"host fling not saved over personal preferences")
	game.field_menu.settings_page="movement";var before:float=game.player.fling_power;game.field_menu._adjust_setting(4,1)
	check(game.player.fling_power==before,"guest settings cannot override host fling")
	game.field_menu.settings_page="weapons";before=game.field_menu.weapon_settings.motion_damping;game.field_menu._adjust_setting(0,1)
	check(game.field_menu.weapon_settings.motion_damping!=before,"personal weapon comfort remains editable")
	var friends:Node=game.network_bridge.avatars.get(2)
	if friends!=null:
		net.players[2].team=net.players[1].team;friends._process(.1)
		check(friends.title.no_depth_test and friends.pools.no_depth_test,"friendly name/health/shield depth disabled")
		net.players[2].team=1-int(net.players[1].team);friends._process(.1);check(not friends.tag.visible,"enemy name/health/shield tag hidden")
	var receipt:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()};var file:=FileAccess.open("user://GAMEPLAY1000.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt,"\t"));file.close()
	print("GAMEPLAY1000 checks=",checks," failures=",failures.size());net.close(false);game._quitting=true;game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
