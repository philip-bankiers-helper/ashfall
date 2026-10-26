extends SceneTree
const Session=preload("res://scripts/net_session1000.gd")
const Rules=preload("res://scripts/net_rules1000.gd")
var net:Node
var checks:=0
var failures:Array=[]
var seq:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func command(id:int,action:String,data:Dictionary={})->void:
	seq[id]=int(seq.get(id,0))+1;net._accept(id,action,data,int(seq[id]))
func run()->void:
	var validated:=Rules.validate({"damage":NAN,"walk":1000,"teams":99,"max_players":-2,"fling":-1,"friendly_fire":"yes","map":"unknown","unknown":true})
	check(validated.damage==1.0,"NaN damage rejected");check(validated.walk==3.0,"speed bounded");check(validated.teams==8,"teams bounded");check(validated.max_players==2,"capacity bounded");check(validated.fling==0,"fling lower bound");check(validated.friendly_fire==false,"boolean schema");check(validated.map=="range","map allowlist");check(not validated.has("unknown"),"unknown rules removed")
	net=Session.new();root.add_child(net);check(net.host("Host",24871)==OK,"real UDP server initialized")
	net.validator=func(_action:String,_id:int,_data:Dictionary)->bool:return true
	net.spawn_provider=func(_id:int,_players:Dictionary,_rules:Dictionary)->Vector3:return Vector3(0,.2,0)
	net._add_player(2,"Friend","");net._add_player(3,"Third","")
	check(net.players[1].team==0 and net.players[2].team==1 and net.players[3].team==0,"balanced initial teams")
	command(1,"rules",{"teams":0});check(net.players[1].team==-1 and net.players[2].team==-1,"FFA removes team assignment")
	command(1,"rules",{"teams":2});check(net.players[1].team==0 and net.players[2].team==1 and net.players[3].team==0,"changing team count restores balanced valid teams")
	command(2,"rules",{"damage":4});check(net.rules.damage==1.0,"guest cannot change rules")
	command(1,"rules",{"mode":"respawn","protection":0,"respawn_delay":1.0,"score_limit":0,"time_limit":0})
	check(net.rules.mode=="respawn","host config applies");check(net.players[1].ready==false,"config clears ready")
	for id in [1,2,3]:command(id,"ready")
	check(net.stage=="countdown","all ready starts countdown")
	command(2,"rules",{"map":"cyber_bird"});check(net.rules.map=="range","guest cannot alter countdown rules")
	command(1,"cancel");check(net.stage=="lobby","host cancels countdown")
	command(1,"ready");check(net.stage=="countdown","ready returns countdown")
	net._begin_loading();check(net.stage=="loading" and net.epoch==1,"round epoch/loading")
	for id in [1,2,3]:command(id,"loaded",{"epoch":0})
	check(not net.players[1].loaded,"stale loading acknowledgments rejected")
	for id in [1,2,3]:command(id,"loaded",{"epoch":1})
	check(net.stage=="loading","server world barrier enforced")
	net.register_world([]);check(net.stage=="match","all clients and world ready starts match")
	check(not net.snapshot().players[1].has("token"),"reconnect secrets excluded from replicated state")
	var pose:Dictionary={"root":Transform3D(Basis.IDENTITY,Vector3(0,.2,0)),"head":Transform3D(Basis.IDENTITY,Vector3(0,1.9,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.3,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.3,-.3)),"seq":1}
	for id in [1,2,3]:net._accept_pose(id,pose)
	check(net.poses.size()==3,"poses accepted for all participants")
	var before:Dictionary=net.poses[2].duplicate(true);var bad:=pose.duplicate();bad.seq=2;bad.root=Transform3D(Basis.IDENTITY,Vector3(9999,0,0));net._accept_pose(2,bad)
	check(net.poses[2]==before,"teleport/bad relative tracking rejected")
	var e:Dictionary={"id":"shared","kind":"weapon","catalog":7,"owner":0,"ammo":0,"capacity":6,"reload":"ready","seated":0,"position":Vector3(0,.7,-1),"basis":Basis.IDENTITY,"rocket_reserve":0}
	net.register_world([e]);command(1,"pickup",{"id":"shared"});command(2,"pickup",{"id":"shared"})
	check(int(net.entities.shared.owner)==1,"contested pickup has one owner");check(not net.players[2].inventory.has("shared"),"loser cannot duplicate gun")
	command(1,"drop",{"id":"shared","position":Vector3(.3,.7,-1)})
	check(net.entities.shared.owner==0 and net.entities.shared.ammo==0,"empty dropped gun preserves ammo")
	command(2,"pickup",{"id":"shared"});check(net.entities.shared.ammo==0,"empty gun remains empty on another client")
	for state in ["cylinder_open","cylinder_loaded","ready"]:command(2,"reload",{"id":"shared","state":state})
	check(net.entities.shared.ammo==6 and net.entities.shared.reload=="ready","magnum authoritative reload")
	var before_ammo:int=net.entities.shared.ammo
	command(2,"shot",{"id":"shared","origin":Vector3(0,1.3,-.4),"directions":[Vector3.FORWARD],"time":net.now()})
	check(net.entities.shared.ammo==before_ammo-1,"server consumes one shot")
	command(2,"shot",{"id":"shared","origin":Vector3(0,1.3,-.4),"directions":[Vector3.FORWARD],"time":net.now()})
	check(net.entities.shared.ammo==before_ammo-1,"impossibly fast shot rejected")
	var ammo:Dictionary={"id":"ammo","kind":"ammo","family":"pistol","amount":16,"owner":0,"position":Vector3(0,.7,-1),"basis":Basis.IDENTITY}
	net.players[1].reserves.pistol=1000000;net.register_world([ammo]);command(1,"pickup",{"id":"ammo"})
	check(net.players[1].reserves.pistol==1000016,"ammo accumulation uncapped");check(not net.entities.has("ammo"),"ammo box consumed exactly once")
	net.players[1].builds=1000000;var builds:=ammo.duplicate();builds.id="build_supply";builds.kind="builds";builds.amount=6;net.register_world([builds]);command(1,"pickup",{"id":"build_supply"})
	check(net.players[1].builds==1000006,"build pickup adds six without cap")
	var hp:float=net.players[3].health;net.hurt(3,50,1);check(net.players[3].health==hp and net.players[3].shield==100,"friendly fire off")
	net.players[2].protection_until=0;net.hurt(2,250,1)
	check(net.players[2].life=="eliminated" and net.players[1].score==1,"death and score authoritative")
	net.players[2].respawn_at=net.now()-1;net._process(.11);check(net.players[2].life=="alive" and net.players[2].health==100,"timed autorespawn")
	net.rules.mode="revive";net.players[2].protection_until=0;net.hurt(2,250,1)
	check(net.players[2].life=="downed","revive mode produces downed state")
	net.stage="match";net.players[1].team=1;net._ready_until[1]=net.now()+3.5
	var until:float=net._ready_until[1];command(1,"revive",{"id":2})
	check(net.players[2].life=="alive" and net.players[2].health==50,"charged teammate revive")
	check(net._ready_until[1]==until,"revive does not consume or extend ready window")
	command(1,"mark",{"point":Vector3(1,1,0),"normal":Vector3.UP,"color":2});command(1,"mark",{"point":Vector3(2,1,0),"normal":Vector3.UP,"color":7})
	check(net.marks.size()==1 and net.marks[1].point.x==2,"one replicated mark per player")
	var token:String=net.players[2].token;net._peer_left(2)
	check(not net.players.has(2) and net._reconnect.has(token),"disconnect reserves reconnect identity")
	net._add_player(20,"Renamed",token);check(net.players[20].name=="Friend" and not net.players[20].inventory.is_empty(),"reconnect preserves player and inventory")
	for eid in net.players[20].inventory:check(net.entities[eid].owner==20,"reconnect rebinds item ownership")
	var belt:Dictionary={"id":"belt_test","kind":"weapon","catalog":8,"owner":1,"ammo":0,"capacity":75,"reload":"holding_box","seated":0,"position":Vector3.ZERO,"basis":Basis.IDENTITY}
	net.entities.belt_test=belt;net.players[1].inventory.append("belt_test")
	for i in 4:
		var state:String=["needs_feed","box_seated","needs_charge","ready"][i]
		command(1,"grip",{"serial":i+1})
		check(net._reload(1,{"id":"belt_test","state":state,"xr":true,"grip_serial":i+1}),"fresh grip permits M60 stroke "+str(i+1))
		if i<3:check(not net._reload(1,{"id":"belt_test","state":["box_seated","needs_charge","ready"][i],"xr":true,"grip_serial":i+1}),"held grip cannot complete next M60 stroke")
	check(belt.ammo==75,"four separate M60 strokes fill exactly once")
	var pair:Dictionary={"id":"dual_test","kind":"weapon","catalog":11,"owner":1,"ammo":60,"capacity":60,"reload":"ready","seated":60,"position":Vector3.ZERO,"basis":Basis.IDENTITY}
	net.entities.dual_test=pair;net._normalize_weapon(pair)
	for side in 2:check(net._shoot(1,{"id":"dual_test","side":side,"origin":Vector3(0,1.3,-.4),"directions":[Vector3.FORWARD]}),"simultaneous dual hand "+str(side)+" can fire")
	check(pair.hands==[29,29],"paired cadence and ammo independent per hand")
	check(not net._reload(20,{"id":"belt_test","state":"needs_feed"}),"other player cannot reload owned gun")
	var replica:Node=Session.new();root.add_child(replica);var received:Array=[]
	replica.event_received.connect(func(kind:String,_data:Dictionary):received.append(kind))
	replica.epoch=net.epoch;replica._event_rpc("old",{"net_epoch":net.epoch-1});check(received.is_empty(),"previous-round events discarded")
	replica._event_rpc("future",{"net_epoch":net.epoch+1});check(received.is_empty(),"future-round event waits for snapshot")
	var state:Dictionary=net.snapshot();state.epoch=net.epoch+1;replica._state(state)
	check(received==["future"],"queued event delivered after matching state")
	replica.queue_free()
	net.projectile_poses[42]={"id":42,"kind":"frag","player":1,"origin":Vector3.ZERO,"velocity":Vector3.ZERO}
	check(net.snapshot().projectiles.has(42),"late join snapshot includes live projectiles")
	command(1,"home");check(net.stage=="lobby","host returns whole session to lobby")
	net.players[20].waiting_round=true;net.players[20].spectator=true
	net._begin_loading();check(net.projectile_poses.is_empty(),"round reset clears old projectiles")
	check(not net.players[20].spectator,"revive late join becomes active next round")
	var report:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var file:=FileAccess.open("user://SESSION1000.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SESSION1000 checks=",checks," failures=",failures.size());net.close();net.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
