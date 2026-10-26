extends "res://scripts/front_menu_091.gd"
const Maps1000=preload("res://scripts/map_catalog1000.gd")
const Rules1000=preload("res://scripts/net_rules1000.gd")
var _built1000 =false
var _actions1000:Dictionary={}
var _pages1000:Dictionary={}
var _map_views1000:Array=[]
var _net_label1000:Label
var _roster1000:Label
var _rule_labels1000:Array=[]
var _rule_buttons1000:Array=[]
var _team_buttons1000:Array=[]
var _kick_buttons1000:Array=[]
var _custom_backing1000:ColorRect
var _tabs1000:Array=[]
var _host_tab1000 =0
var _keyboard_field1000 ="name"
var _keyboard_label1000:Label
var fields1000 ={"name":"Player","address":"127.0.0.1","port":"24760","password":"","room":"ASHFALL FRIENDS"}
var _return_page1000 ="connect"
const TABS1000:=["SESSION","COMBAT","MOVEMENT","EQUIPMENT","RESPAWN"]
const KEYS1000:=[
	["max_players","teams","mode","late_join","spectators","locked","time_limit","score_limit","rounds"],
	["damage","build_damage","headshots","friendly_fire","starting_health","starting_shield"],
	["walk","run","flight","fling","stamina"],
	["loadout","loot","catalog","builds","starting_builds","infinite_builds","infinite_ammo","retain_inventory"],
	["respawn_delay","protection","downed_seconds"]]
func setup(player:Node3D)->void:
	super.setup(player)
	fields1000.name=OS.get_environment("USERNAME").left(24)
	if not OS.get_cmdline_user_args().has("--scope-playtest"):selected_map="cyber_bird"
	# Existing gallery and READY keep their action IDs and release activation.
	buttons[11].position=Vector2(60,430);buttons[11].size=Vector2(350,76)
	buttons[12].position=Vector2(465,430);buttons[12].size=Vector2(350,76)
	_add1000("CYBER BIRD",Vector2(870,430),Vector2(350,76),["maps"],func():_select_map1000("cyber_bird"))
	for i in Maps1000.IDS.size():
		var pic =TextureRect.new();pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.texture=Maps1000.image(Maps1000.IDS[i]);pic.position=Vector2(60+i*405,145);pic.size=Vector2(350,260);pic.clip_contents=true;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;pic.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(pic);_map_views1000.append(pic)
	_net_label1000=words("",Vector2(40,105),19,Color("7ceaf4"));_net_label1000.size=Vector2(1180,70);_net_label1000.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_custom_backing1000=ColorRect.new();_custom_backing1000.size=Vector2(SIZE);_custom_backing1000.color=Color(.015,.04,.065,.97);_custom_backing1000.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(_custom_backing1000);viewport.move_child(_custom_backing1000,0)
	_roster1000=words("",Vector2(42,220),21,Color.WHITE);_roster1000.size=Vector2(365,400)
	_roster1000.position.y=206;_roster1000.add_theme_constant_override("line_spacing",10)
	_add1000("HOST / JOIN",Vector2(970,580),Vector2(270,64),["lobby"],func():page="connect";refresh_page())
	_add1000("HOST CONTROLS",Vector2(970,655),Vector2(270,64),["lobby"],func():page="host";refresh_page())
	_add1000("LEAVE LOBBY",Vector2(970,730),Vector2(270,48),["lobby"],func():game.network_bridge.leave_session();refresh_page())
	_add1000("REMATCH",Vector2(465,584),Vector2(350,88),["lobby"],func():game.network_bridge.net.request("restart"))
	_add1000("RETURN TO LOBBY",Vector2(465,490),Vector2(350,58),["lobby"],func():game.network_bridge.net.request("home"))
	for i in ["name","address","port","password","room"].size():
		var field:String=["name","address","port","password","room"][i]
		_add1000(field.to_upper(),Vector2(180,195+i*74),Vector2(900,64),["connect"],func():_keyboard_field1000=field;_return_page1000="connect";page="keyboard";refresh_page())
	_add1000("HOST PRIVATE LOBBY",Vector2(180,600),Vector2(430,76),["connect"],_host_lobby1000)
	_add1000("JOIN LOBBY",Vector2(650,600),Vector2(430,76),["connect"],func():game.network_bridge.net.join(fields1000.address,fields1000.name,int(fields1000.port),fields1000.password);page="lobby";refresh_page())
	_add1000("JOIN AS SPECTATOR",Vector2(650,690),Vector2(430,58),["connect"],func():game.network_bridge.net.join(fields1000.address,fields1000.name,int(fields1000.port),fields1000.password,true);page="lobby";refresh_page())
	_add1000("BACK",Vector2(40,710),Vector2(170,58),["connect","host","keyboard"],func():page=_return_page1000 if page=="keyboard" else "lobby";refresh_page())
	for i in TABS1000.size():
		var tab =i
		_add1000(TABS1000[i],Vector2(35+i*250,160),Vector2(240,54),["host"],func():_host_tab1000=tab;refresh_page())
	for i in 9:
		var row =i
		var text =words("",Vector2(130,238+i*43),21,Color.WHITE);text.size=Vector2(800,40);_rule_labels1000.append(text)
		var minus =_add1000("−",Vector2(950,232+i*43),Vector2(95,39),["host"],func():_adjust1000(row,-1))
		var plus =_add1000("+",Vector2(1060,232+i*43),Vector2(95,39),["host"],func():_adjust1000(row,1));_rule_buttons1000.append([minus,plus])
	_add1000("PRACTICE",Vector2(260,655),Vector2(210,50),["host"],func():_preset1000("practice"))
	_add1000("TEAM REVIVE",Vector2(485,655),Vector2(230,50),["host"],func():_preset1000("team_revive"))
	_add1000("TEAM RESPAWN",Vector2(730,655),Vector2(240,50),["host"],func():_preset1000("team_respawn"))
	_add1000("FFA",Vector2(985,655),Vector2(170,50),["host"],func():_preset1000("free_for_all"))
	_add1000("SAVE RULES",Vector2(260,720),Vector2(210,50),["host"],func():_save_preset1000())
	_add1000("LOAD RULES",Vector2(485,720),Vector2(230,50),["host"],func():_load_preset1000())
	_add1000("BALANCE TEAMS",Vector2(730,720),Vector2(240,50),["host"],func():game.network_bridge.net.request("balance"))
	_add1000("CANCEL READY",Vector2(985,720),Vector2(240,50),["host"],func():game.network_bridge.net.request("cancel"))
	for i in 8:
		var row =i
		_team_buttons1000.append(_add1000("TEAM",Vector2(350,205+i*43),Vector2(90,37),["lobby"],func():_cycle_team1000(row)))
		_kick_buttons1000.append(_add1000("×",Vector2(445,205+i*43),Vector2(37,37),["lobby"],func():_kick1000(row)))
	_keyboard_label1000=words("",Vector2(120,165),30,Color("ffef5a"));_keyboard_label1000.size=Vector2(1080,80)
	var chars ="1234567890QWERTYUIOPASDFGHJKLZXCVBNM.:-_"
	for i in chars.length():
		var c =chars[i]
		_add1000(c,Vector2(120+(i%10)*105,275+floori(i/10)*80),Vector2(94,66),["keyboard"],func():fields1000[_keyboard_field1000]=(str(fields1000[_keyboard_field1000])+c).left(64);refresh_page())
	_add1000("SPACE",Vector2(225,635),Vector2(230,60),["keyboard"],func():fields1000[_keyboard_field1000]+=" ";refresh_page())
	_add1000("⌫",Vector2(480,635),Vector2(230,60),["keyboard"],func():fields1000[_keyboard_field1000]=str(fields1000[_keyboard_field1000]).left(maxi(0,str(fields1000[_keyboard_field1000]).length()-1));refresh_page())
	_add1000("DONE",Vector2(740,635),Vector2(335,60),["keyboard"],func():page="connect";refresh_page())
	_built1000=true;refresh_page()
func _add1000(label:String,at:Vector2,size_value:Vector2,pages:Array,action:Callable)->int:
	var index =buttons.size();button(label,at,size_value);buttons[index].action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;_actions1000[index]=action;_pages1000[index]=pages;return index
func activate(index:int)->void:
	if not active or index<0 or index>=buttons.size() or not buttons[index].visible or buttons[index].disabled:return
	if _actions1000.has(index):
		preload("res://scripts/sound_cues099.gd").play_ui(self,"menu_click");_pressed_button097=-1;_actions1000[index].call();return
	var net:Node=game.network_bridge.net if game.get("network_bridge")!=null else null
	if index==0 and net!=null and net.active:net.request("ready");return
	if index in [11,12]:_select_map1000("valley" if index==11 else "range");return
	super.activate(index)
	if index==9 and net!=null and net.active:net.request("character",{"style":gallery.style})
func _host_lobby1000()->void:
	var chosen:String=selected_map;var net:Node=game.network_bridge.net
	if net.host(fields1000.name,int(fields1000.port),fields1000.password)==OK:
		net.room_name=net.clean_name(fields1000.room);net.request("rules",{"map":chosen});page="lobby"
	refresh_page()
func refresh_page()->void:
	super.refresh_page()
	if not _built1000:return
	if page not in ["lobby","maps","loadout"]:
		for i in 13:buttons[i].hide()
	var net:Node=game.network_bridge.net
	_custom_backing1000.visible=page in ["host","connect","keyboard"]
	for index in _pages1000:buttons[index].visible=page in _pages1000[index];buttons[index].disabled=false
	for pic in _map_views1000:pic.visible=page=="maps"
	for label in _rule_labels1000:label.visible=false
	_keyboard_label1000.visible=page=="keyboard";_keyboard_label1000.text=_keyboard_field1000.to_upper()+": "+str(fields1000[_keyboard_field1000])
	_roster1000.visible=page=="lobby" and net.active;_net_label1000.visible=page!="loadout"
	_net_label1000.text=net.status if not net.active else "%s · %s · %s · %d/%d PLAYERS%s"%[net.room_name,net.stage.to_upper(),str(net.rules.mode).to_upper(),net.players.size(),int(net.rules.max_players)," · HOST" if net.is_host() else ""]
	if net.active and net.stage=="countdown":_net_label1000.text+=" · %.1f"%maxf(0,net.countdown_end-net.now())
	if net.active:selected_map=str(net.rules.map)
	buttons[0].text="READY" if not net.active or not net.players.has(net.me()) or not net.players[net.me()].ready else "CANCEL READY"
	buttons[0].disabled=false
	if net.active and net.players.has(net.me()):buttons[0].disabled=net.players[net.me()].spectator or net.stage not in ["lobby","countdown"]
	var roster ="";var ids:Array=net.players.keys()
	for id in ids:
		var p:Dictionary=net.players[id];roster+="%s%s  %dms\n"%["✓ " if p.ready else "○ ",p.name.left(15)+(" ★" if id==net.admin else ""),int(p.ping)]
	_roster1000.text=roster
	for i in _team_buttons1000.size():
		var b:Button=buttons[int(_team_buttons1000[i])];b.visible=page=="lobby" and net.active and i<ids.size()
		if b.visible:b.text="FFA" if int(net.players[ids[i]].team)<0 else "TEAM %d"%(int(net.players[ids[i]].team)+1);b.disabled=not net.is_host() and int(ids[i])!=net.me()
		buttons[int(_kick_buttons1000[i])].visible=page=="lobby" and net.active and net.is_host() and i<ids.size() and int(ids[i])!=net.me()
	for index in _actions1000:
		var b:Button=buttons[index]
		if b.text=="HOST CONTROLS":b.visible=page=="lobby" and net.active and net.is_host()
		elif b.text=="LEAVE LOBBY":b.visible=page=="lobby" and net.active
		elif b.text=="HOST / JOIN":b.visible=page=="lobby" and not net.active
		elif b.text in ["REMATCH","RETURN TO LOBBY"]:b.visible=page=="lobby" and net.active and net.stage=="results" and net.is_host()
		elif page=="connect" and b.text.split(":")[0].to_lower() in fields1000:
			var key =b.text.split(":")[0].to_lower();b.text=key.to_upper()+": "+("••••" if key=="password" and not fields1000.password.is_empty() else str(fields1000[key]))
	if page=="host":
		title_text.text="HOST CONTROLS";var keys:Array=KEYS1000[_host_tab1000]
		for i in 9:
			var shown =i<keys.size();_rule_labels1000[i].visible=shown
			for b in _rule_buttons1000[i]:buttons[int(b)].visible=shown;buttons[int(b)].disabled=not net.is_host() or net.stage!="lobby"
			if shown:_rule_labels1000[i].text=str(keys[i]).to_upper().replace("_"," ")+"     "+_value1000(str(keys[i]),net.rules[keys[i]])
	elif page=="connect":title_text.text="PRIVATE MULTIPLAYER"
	elif page=="keyboard":title_text.text="ENTER "+_keyboard_field1000.to_upper()
	selection_text.visible=page=="lobby" or page=="loadout"
	if page=="lobby":selection_text.text=str(Maps1000.info(selected_map).title)
	if net.active and net.stage=="results" and page=="lobby":buttons[0].hide();buttons[4].hide();selection_text.text="ROUND COMPLETE"
func refresh_network()->void:
	if _built1000:refresh_page()
func _process(delta:float)->void:
	super._process(delta)
	if active and _built1000 and game.network_bridge.net.stage=="countdown":refresh_page()
func _select_map1000(id:String)->void:
	var net:Node=game.network_bridge.net
	if net.active:
		if not net.is_host():return
		net.request("rules",{"map":id})
	else:selected_map=id
	page="lobby";refresh_page()
func leave_lobby()->void:
	if not _entered:return
	_entered=false;actor.global_transform=_return_pose;actor.reset_motion();actor.get_world_3d().environment=_previous_environment;lobby.hide();gallery.close()
	preload("res://scripts/cyber_bird_registration.gd").select(game,selected_map)
func _adjust1000(row:int,direction:int)->void:
	var net:Node=game.network_bridge.net
	if not net.is_host():return
	var key:String=KEYS1000[_host_tab1000][row];var value:Variant=net.rules[key]
	if value is bool:value=not value
	elif Rules1000.CHOICES.has(key):
		var options:Array=Rules1000.CHOICES[key];value=options[posmod(options.find(value)+direction,options.size())]
	else:
		var step:float=.25 if value is float else 1.0
		if key in ["starting_health","starting_shield","starting_builds"]:step=10
		if key=="time_limit":step=60
		value=float(value)+step*direction
	net.request("rules",{key:value})
func _preset1000(id:String)->void:game.network_bridge.net.request("rules",Rules1000.preset(id))
func _save_preset1000()->void:
	if not game.network_bridge.net.is_host():return
	var file =FileAccess.open("user://lobby-preset1000.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(game.network_bridge.net.rules))
func _load_preset1000()->void:
	if not FileAccess.file_exists("user://lobby-preset1000.json"):return
	var value=JSON.parse_string(FileAccess.get_file_as_string("user://lobby-preset1000.json"))
	if value is Dictionary:game.network_bridge.net.request("rules",Rules1000.validate(value))
func _cycle_team1000(index:int)->void:
	var net:Node=game.network_bridge.net;var ids:Array=net.players.keys()
	if index>=ids.size() or int(net.rules.teams)==0:return
	var id:int=ids[index];net.request("team",{"id":id,"team":(int(net.players[id].team)+1)%int(net.rules.teams)})
func _kick1000(index:int)->void:
	var net:Node=game.network_bridge.net;var ids:Array=net.players.keys()
	if index<ids.size():net.request("kick",{"id":int(ids[index])})
func _value1000(key:String,value:Variant)->String:
	if value is bool:return "ON" if value else "OFF"
	if key in ["damage","npc_damage","build_damage","headshots","walk","run","flight","fling","stamina"]:return "%d%%"%roundi(float(value)*100)
	if key in ["respawn_delay","protection","downed_seconds"]:return "%.1f s"%float(value)
	if key=="time_limit":return "UNLIMITED" if int(value)==0 else "%d MIN"%roundi(float(value)/60)
	if key=="score_limit" and int(value)==0:return "UNLIMITED"
	if key=="teams" and int(value)==0:return "FREE-FOR-ALL"
	return str(value).to_upper().replace("_"," ")
