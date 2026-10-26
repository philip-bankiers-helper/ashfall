extends SceneTree
const Session=preload("res://scripts/net_session1000.gd")
var net:Node
var role:=""
var output:=""
var checks:=0
var failures:Array=[]
var clock:=0.0
var steps:Dictionary={}
var pose_seq:=0
var joined:=false
var port:=24872
var peer_count:=3
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func run()->void:
	var args:=OS.get_cmdline_user_args();role=args[0];output=args[1]
	if args.size()>2:port=int(args[2])
	if args.size()>3:peer_count=int(args[3])
	net=Session.new();root.add_child(net)
	net.validator=func(_action:String,_id:int,_data:Dictionary)->bool:return true
	net.spawn_provider=func(_id:int,_players:Dictionary,_rules:Dictionary)->Vector3:return Vector3(0,.2,0)
	if role=="host":
		check(net.host("Host",port,"private")==OK,"host UDP listen")
		net.request("rules",{"mode":"respawn","protection":0.0,"respawn_delay":1.0,"score_limit":0,"time_limit":0})
	else:check(net.join("127.0.0.1",role,port,"private")==OK,"client connect requested")
	for frame in range(2500):
		await process_frame
		clock+=.02
		if clock>40:check(false,"watchdog stage="+net.stage+" players="+str(net.players.size()));break
		await create_timer(.02).timeout
		if net.players.size()>=peer_count and not steps.has("ready"):
			steps.ready=true;check(net.players.has(net.me()),"own identity replicated");check(net.rules.mode=="respawn","host rules replicated");net.request("ready")
		if net.stage=="loading" and not steps.has("loaded"):
			steps.loaded=true
			if role=="host":net.register_world([{"id":"contested","kind":"weapon","catalog":7,"owner":0,"ammo":0,"capacity":6,"reload":"ready","seated":0,"position":Vector3(0,.7,-1),"basis":Basis.IDENTITY,"rocket_reserve":0}])
			net.request("loaded",{"epoch":net.epoch})
		if net.stage=="match":
			pose_seq+=1;var at:=Vector3(0,.2,0)
			net.send_pose({"root":Transform3D(Basis.IDENTITY,at),"head":Transform3D(Basis.IDENTITY,at+Vector3.UP*1.7),"left":Transform3D(Basis.IDENTITY,at+Vector3(-.3,1.2,0)),"right":Transform3D(Basis.IDENTITY,at+Vector3(.3,1.2,0)),"weapon":0,"holstered":false,"seq":pose_seq})
			if not steps.has("match"):
				steps.match=clock;check(net.entities.has("contested"),"world snapshot arrived before match");net.request("pickup",{"id":"contested"})
			if clock-float(steps.match)>1.5 and not steps.has("ownership"):
				steps.ownership=true;var owner:=int(net.entities.contested.owner);var claims:=0
				for p in net.players.values():
					if p.inventory.has("contested"):claims+=1
				check(owner>0 and claims==1,"real network contested pickup atomic")
				check(net.poses.size()==peer_count,"all player poses relayed")
				if role=="host":
					var target:int=net.players.keys()[1];net.players[target].protection_until=0;net.hurt(target,250,1);steps.victim=target
			if clock-float(steps.match)>3 and not steps.has("respawn"):
				steps.respawn=true
				if role=="host":check(net.players[int(steps.victim)].life=="alive","real client automatically respawned")
				else:check(net.players.has(net.me()) and net.players[net.me()].health>0,"client state stays usable after death cycle")
			if role=="host" and clock-float(steps.match)>4.0:net.request("home")
		if net.stage=="lobby" and steps.has("match"):
			check(net.rules.mode=="respawn","rules retained on round return");check(steps.has("ownership"),"completed pickup stage");break
	var result:Dictionary={"role":role,"checks":checks,"failures":failures,"passed":failures.is_empty(),"players":net.players.size(),"steps":steps,"status":net.status,"port":port}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("WIRE1000 role=",role," checks=",checks," failures=",failures.size())
	if role=="host":await create_timer(.3).timeout
	net.close();net.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
