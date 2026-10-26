extends SceneTree
var game:Node
var net:Node
var role:String
var output:String
var checks:=0
var failures:Array=[]
var steps:Dictionary={}
var started:=0.0
var port:=24876
var rounds_seen:=0
var initial_rack:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func run()->void:
	var args:=OS.get_cmdline_user_args();role=args[0];output=args[1];port=int(args[2]);started=Time.get_ticks_msec()*.001
	game=Node3D.new();game.set_script(load("res://scripts/main.gd"));root.add_child(game)
	for i in 4:await process_frame
	net=game.network_bridge.net
	if role=="host":check(net.host("Al",port,"friends")==OK,"game listen host started");net.request("rules",{"map":"cyber_bird","mode":"respawn","protection":0.0,"time_limit":0,"score_limit":0,"respawn_delay":1.0})
	else:
		# A game host may spend several seconds importing/constructing its weapon rack.
		await create_timer(3).timeout
		check(net.join("127.0.0.1","Friend",port,"friends")==OK,"game join requested")
	while Time.get_ticks_msec()*.001-started<115:
		await process_frame
		if net.players.size()==2 and net.stage=="lobby" and not steps.has("ready"):steps.ready=true;net.request("ready")
		if net.stage=="match":
			if game.practice_dummy.total_damage==25.0:steps.target_seen=true
			if not steps.has("match"):
				steps.match=Time.get_ticks_msec()*.001
				check(not game.front_end_active,"READY enters real map")
				check(is_instance_valid(game.active_sandbox_map) and game.active_sandbox_map.name=="CyberBird","city integrated lifecycle")
				initial_rack=game.weapon.weapons.size()
				check(game.weapon_inventory.owned.size()==3,"own starting inventory replicated")
				check(game.weapon_inventory.pickups.size()>=25,"shared real grabbable weapon props")
				check(net.entities.size()>40,"world includes weapons, heals, all ammo/build supplies")
			var age:float=Time.get_ticks_msec()*.001-float(steps.match)
			if age>2 and not steps.has("avatars"):
				steps.avatars=true
				check(game.network_bridge.avatars.size()==1,"remote avatar created")
				var avatar:Node=game.network_bridge.avatars.values()[0]
				check(avatar.suit.pieces.size()==game.body_visual.pieces.size() and avatar.gloves.size()==2,"remote camo suit and skinned hands")
				check(avatar.title.no_depth_test and avatar.pools.no_depth_test,"friendly name and pools tag through walls")
				check(net.poses.size()==2,"real player root/head/hands relayed")
				game.network_bridge.tactical.set_open(true)
				await process_frame
				check(game.network_bridge.tactical.opened,"tactical map opens without stopping match")
				check(game.network_bridge.tactical.roster.text.is_empty()==false,"tactical roster populated")
				game.network_bridge.tactical.set_open(false)
			if age>3 and not steps.has("fire"):
				steps.fire=true
				var selected:int=game.weapon.selected;var gun:Node=game.weapon.weapons[selected];gun.cooldown=0;game.weapon._draw_delay=0;gun._requires_trigger_release=false
				if role=="host":game.weapon.fire()
				if role=="host":game.practice_dummy.take_damage(25.0)
			if age>4 and not steps.has("target"):
				steps.target=true;check(steps.get("target_seen",false),"shared practice target state reaches both games")
			if role=="host" and age>5 and not steps.has("death"):
				steps.death=true;var victim:int=net.players.keys()[1];net.players[victim].protection_until=0;net.hurt(victim,250,1)
			if age>4 and not steps.has("grenade"):
				steps.grenade=true
				if role=="host":net._event("projectile",{"id":9901,"player":1,"kind":"frag","origin":game.player.global_position+Vector3(0,2,3),"velocity":Vector3(0,2,1)})
			if age>5.5 and not steps.has("flight"):
				steps.flight=true;check(not game.network_bridge._projectiles.is_empty(),"authoritative grenade trajectory reaches both games")
			if role=="host" and age>8 and not steps.has("rematch"):steps.rematch=true;net.request("restart")
			if int(net.epoch)>=2 and not steps.has("second"):
				steps.second=true
				check(game.weapon.weapons.size()<=initial_rack+3,"rematch rack is bounded")
				check(not net.projectile_poses.has(9901),"rematch excludes previous-round grenade")
			if role=="host" and age>12 and steps.has("second") and not steps.has("home"):steps.home=true;net.request("home")
		if net.stage=="lobby" and steps.has("match"):
			check(game.front_end_active,"session returns to pedestal lobby")
			check(game.player.xr_origin!=null,"XR origin retained without recalibration")
			break
		await create_timer(.03).timeout
	check(steps.has("match") and steps.has("avatars"),"complete real-game network sequence")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"role":role,"checks":checks,"failures":failures,"passed":failures.is_empty(),"status":net.status,"stage":net.stage},"\t"));file.close()
	print("GAME_WIRE1000 role=",role," checks=",checks," failures=",failures.size())
	if role=="host":await create_timer(.3).timeout
	net.close();game._quitting=true;game.set_process(false);game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
