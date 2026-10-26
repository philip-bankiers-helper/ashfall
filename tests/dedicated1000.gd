extends SceneTree
var game:Node
var net:Node
var role:String
var output:String
var port:int
var checks:=0
var failures:Array=[]
var steps:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func run()->void:
	var args:=OS.get_cmdline_user_args();role=args[0];output=args[1];port=int(args[2])
	game=load("res://scripts/main.gd").new();root.add_child(game)
	for i in 4:await process_frame
	net=game.network_bridge.net
	if role=="host":
		game.player.collision_layer=0;game.player.set_physics_process(false);game.body_visual.hide()
		check(net.host("Server",port,"private",true)==OK,"dedicated server created without XR")
	else:
		await create_timer(12 if role=="friend2" else 3).timeout
		check(net.join("127.0.0.1",role,port,"private")==OK,"client join requested")
	var deadline:float=Time.get_ticks_msec()*.001+90
	while Time.get_ticks_msec()*.001<deadline:
		await process_frame
		if role=="friend1" and net.is_host() and net.stage=="lobby" and not steps.has("ready"):
			steps.ready=true;check(net.admin==net.me(),"first dedicated guest controls lobby")
			net.request("rules",{"map":"range","mode":"respawn","teams":0,"catalog":true,"time_limit":0,"score_limit":0,"damage":0.0});net.request("ready")
		if net.stage=="match" and not game.network_bridge._preparing and (role=="host" or net.players[net.me()].loaded):
			if not steps.has("match"):
				steps.match=Time.get_ticks_msec()*.001
				check(not net.players.has(1),"headless server is not a player")
				check(game.active_sandbox_map.name=="StandaloneSandboxRange091","dedicated match loads actual world")
				if role=="host":
					net._event("projectile",{"id":9902,"player":net.admin,"kind":"zone","origin":game.active_sandbox_map.spawn+Vector3(0,.2,4),"velocity":Vector3.ZERO})
					var projectile:Node=game.network_bridge._projectiles[9902];projectile.freeze=true;projectile.stuck=true;projectile._activate_zone()
				if role=="friend2":
					check(net.projectile_poses.has(9902),"late join snapshot carries active zone")
					check(is_instance_valid(game.network_bridge._projectiles.get(9902)),"late joining game renders active zone")
					check(not net.players[net.me()].spectator,"respawn mode permits active late join")
			if net.players.size()==2 and not steps.has("peers"):
				steps.peers=true;check(net.players.size()==2,"second friend joins running match")
			if role=="friend1" and steps.has("peers") and Time.get_ticks_msec()*.001-float(steps.match)>14:net.request("home")
		if net.stage=="lobby" and steps.has("match"):
			check(steps.has("peers"),"dedicated late join sequence completed");break
		await create_timer(.03).timeout
	check(steps.has("match") and net.stage=="lobby","dedicated match returned to lobby")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"role":role,"checks":checks,"failures":failures,"passed":failures.is_empty()},"\t"));file.close()
	print("DEDICATED_WIRE1000 role=",role," checks=",checks," failures=",failures.size())
	if role=="host":await create_timer(.5).timeout
	net.close();game._quitting=true;game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
