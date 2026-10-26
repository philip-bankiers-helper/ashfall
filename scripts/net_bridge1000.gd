extends Node
## Deliberate integration boundary around the accepted standalone interactions.
const Session=preload("res://scripts/net_session1000.gd")
var game:Node
var net:Node
var avatars:Dictionary={}
var indices:Dictionary={}
var local_ids:Dictionary={}
var supply_ids:Dictionary={}
var heal_ids:Dictionary={}
var world_props:Dictionary={}
var build_props:Dictionary={}
var mark_props:Dictionary={}
var applying =false
var _preparing =false
var _epoch =-1
var _spawn_revision =-1
var _stage ="offline"
var _pose_clock =0.0
var _pose_seq =0
var _reload_states:Dictionary={}
var _local_rules:Dictionary={}
var _reload_bound:Dictionary={}
var _projectiles:Dictionary={}
var _ended_projectiles:Dictionary={}
var _projectile_serial =0
var _flight_clock=0.0
var _last_damage =-100.0
var _consume_pending:Dictionary={}
var _map_pending =""
var _pickup_selection=""
var _catalog_before=false
var _grips:Array=[false,false]
var _grip_serial=0
var _loading_generation =0
var tactical:Node
func setup(g:Node)->void:
	game=g;name="NetworkBridge1000";process_priority=130
	net=Session.new();game.add_child(net);net.validator=_validate;net.spawn_provider=_spawn_point
	net.changed.connect(_changed);net.event_received.connect(_event);net.disconnected.connect(_disconnected)
	game.weapon_inventory.network_bridge=self;game.ammo_pickups.network_bridge=self;game.field_consumables.network_bridge=self;game.field_builder.network_bridge=self
	game.field_menu.network_bridge=self
	tactical=preload("res://scripts/tactical_map1000.gd").new();game.add_child(tactical);tactical.setup(game,net)
	if is_instance_valid(game.building_input) and "team_marks" in game.building_input:
		game.building_input.team_marks.mark_created.connect(_mark)
	var args =OS.get_cmdline_user_args();var display_name =_arg(args,"--name",OS.get_environment("USERNAME"))
	if "--server" in args:
		game.player.collision_layer=0;game.player.set_physics_process(false);game.body_visual.hide()
		net.host(display_name,int(_arg(args,"--port",str(Session.DEFAULT_PORT))),_arg(args,"--password",""),true)
		var rules =net.rules.duplicate(true);rules.map=_arg(args,"--map","range");rules.mode=_arg(args,"--mode","revive");net.rules=preload("res://scripts/net_rules1000.gd").validate(rules)
	elif "--host" in args:net.host(display_name,int(_arg(args,"--port",str(Session.DEFAULT_PORT))),_arg(args,"--password",""))
	elif "--join" in args:net.join(_arg(args,"--join","127.0.0.1"),display_name,int(_arg(args,"--port",str(Session.DEFAULT_PORT))),_arg(args,"--password",""))
func _arg(args:PackedStringArray,key:String,fallback:String)->String:
	var i =args.find(key);return args[i+1] if i>=0 and i+1<args.size() and not args[i+1].begins_with("--") else fallback
func live()->bool:return net!=null and net.active
func playing()->bool:return live() and net.stage=="match"
func personal_settings(settings:Dictionary)->Dictionary:
	var result:Dictionary=settings.duplicate(true)
	for key in ["walk_speed_multiplier","fling_power","sprint_slow_gain","sprint_fast_gain","sprint_stamina_seconds","player_damage_multiplier","enemy_damage_multiplier"]:
		if _local_rules.has(key):result[key]=_local_rules[key]
	return result
func _changed()->void:
	if not live():return
	if _local_rules.is_empty():_local_rules=game.field_menu.get_settings().duplicate(true);_catalog_before=game.item_catalog_088.testing
	if net.stage=="loading" and (_epoch!=int(net.epoch) or _stage!="loading") and not _preparing:_prepare()
	if net.stage=="match" and _epoch!=int(net.epoch) and not _preparing:_prepare()
	if net.stage=="lobby" and _stage in ["match","results","loading"]:
		_return_lobby()
	if net.stage=="match" and not _preparing:_sync_world();_sync_player()
	if net.stage=="results":
		if _stage!="results":_return_lobby()
		game.player.input_enabled=false;game.weapon.is_holstered=true;game.weapon._apply_selection();game._feedback("ROUND COMPLETE · Host can rematch or return to lobby",10)
	_stage=net.stage
	if is_instance_valid(game.front_menu) and game.front_menu.has_method("refresh_network"):game.front_menu.refresh_network()
func _prepare()->void:
	_clear_projectiles()
	_preparing=true;_loading_generation+=1;var generation =_loading_generation
	_epoch=int(net.epoch);_spawn_revision=-1;_reload_states.clear();_consume_pending.clear();indices.clear();local_ids.clear();supply_ids.clear();heal_ids.clear();world_props.clear();build_props.clear()
	_grip_serial=0;_grips=[true,true]
	game.front_menu.selected_map=str(net.rules.map)
	if game.front_end_active:game._start_from_title()
	else:preload("res://scripts/cyber_bird_registration.gd").select(game,str(net.rules.map))
	# Rebuild the round's loot from the accepted offline providers, with a bounded rack.
	applying=true;game.weapon.selected=0;game.weapon_inventory.owned.assign([0,2,9])
	for i in range(30,game.weapon.weapons.size()):game.weapon.weapons[i].queue_free()
	game.weapon.weapons.resize(30);game.weapon.weapon_names.resize(30);game.weapon.weapon_ids.resize(30);game.weapon.instance_catalog.clear()
	game._begin_chapter();applying=false
	game.player.input_enabled=false
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.queue_free()
	game.enemies.clear();game.encounter_active=false;game.complete=false;game.dead=false;game.waypoint.hide()
	game.field_menu.enemy_damage_multiplier=float(net.rules.npc_damage);game.field_menu.player_damage_multiplier=1.0
	if not net.server:game.field_builder.set_physics_process(false);game.practice_dummy.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	if not live() or generation!=_loading_generation:_preparing=false;return
	if net.server:_register_world()
	else:
		_clear_local_loot()
	_preparing=false;net.request("loaded",{"epoch":net.epoch})
	if net.dedicated:
		# A headless server participates in world loading, not in the player roster.
		for p in net.players.values():
			if not p.loaded:return
		net._try_start();net._publish()
	if net.stage=="match":_sync_world();_sync_player()
func _clear_local_loot()->void:
	for prop in game.weapon_inventory.pickups.values():
		if is_instance_valid(prop):prop.queue_free()
	game.weapon_inventory.pickups.clear()
	for prop in game.ammo_pickups.boxes:
		if is_instance_valid(prop):prop.queue_free()
	game.ammo_pickups.boxes.clear()
	for prop in game.field_consumables.pickups:
		if is_instance_valid(prop):prop.queue_free()
	game.field_consumables.pickups.clear()
func _register_world()->void:
	var world:Array=[];var n =0
	var inventory:Node=game.weapon_inventory
	var keys:Array=inventory.pickups.keys();keys.sort()
	for index in keys:
		var prop:Node3D=inventory.pickups[index];var gun:Node3D=game.weapon.weapons[index];var eid ="ground_%d_%d"%[_epoch,n];n+=1
		indices[eid]=int(index);local_ids[int(index)]=eid;world_props[eid]=prop;prop.set_meta("network_id1000",eid)
		world.append({"id":eid,"kind":"weapon","catalog":game.weapon.catalog_index(index),"owner":0,"ammo":gun.ammo,"capacity":gun.magazine_size,"reload":gun.reload_state,"seated":0,"position":prop.global_position,"basis":prop.global_basis,"rocket_reserve":2 if game.weapon.catalog_index(index)==27 else 0})
	for box in game.ammo_pickups.boxes:
		if not is_instance_valid(box) or not box.is_visible_in_tree():continue
		var eid ="supply_%d_%d"%[_epoch,n];n+=1;world_props[eid]=box;box.set_meta("network_id1000",eid)
		world.append({"id":eid,"kind":"builds" if box.get_meta("family")=="builds" else "ammo","family":box.get_meta("family"),"amount":box.get_meta("amount"),"owner":0,"position":box.global_position,"basis":box.global_basis})
	for prop in game.field_consumables.pickups:
		if not is_instance_valid(prop):continue
		var eid ="heal_%d_%d"%[_epoch,n];n+=1;world_props[eid]=prop;prop.set_meta("network_id1000",eid)
		world.append({"id":eid,"kind":str(prop.get_meta("kind")),"owner":0,"position":prop.global_position,"basis":prop.global_basis})
	net.register_world(world)
func _sync_world()->void:
	if _preparing:return
	applying=true
	var own:Array=[];var inventory:Node=game.weapon_inventory;var rack:Node=game.weapon
	var supply:Node=game.field_consumables
	var next_items:Dictionary={};var stock:Dictionary={"shaker":0,"soda":0,"banana":0}
	for eid in net.entities:
		var e:Dictionary=net.entities[eid];var owner =int(e.owner)
		if e.kind=="weapon":
			if not indices.has(eid):
				var index =rack.create_instance(int(e.catalog));indices[eid]=index;local_ids[index]=eid
			var index =int(indices[eid]);var gun:Node3D=rack.weapons[index]
			if owner==net.me():own.append(index);_sync_gun(eid,e,gun)
			if owner==0:
				if not is_instance_valid(world_props.get(eid)):
					var prop:Node3D=inventory._create_prop(index);world_props[eid]=prop;prop.set_meta("network_id1000",eid)
				var prop:Node3D=world_props[eid];prop.global_transform=Transform3D(e.basis,e.position);inventory.pickups[index]=prop;prop.show()
			else:
				inventory.pickups.erase(index)
				if is_instance_valid(world_props.get(eid)):world_props[eid].hide()
		elif e.kind in ["ammo","builds"]:
			if owner!=0:continue
			if not is_instance_valid(world_props.get(eid)):
				world_props[eid]=game.ammo_pickups.spawn_box(str(e.family),e.position,int(e.amount));world_props[eid].set_meta("network_id1000",eid)
			world_props[eid].set_meta("collected",false);world_props[eid].show()
		else:
			if owner==net.me():
				if e.kind!="backpack":next_items[eid]={"kind":e.kind};stock[e.kind]=int(stock.get(e.kind,0))+1
			if owner==0:
				if not is_instance_valid(world_props.get(eid)):
					var prop:Node3D=supply.make_prop(str(e.kind));supply.add_child(prop);prop.set_meta("kind",e.kind);prop.set_meta("network_id1000",eid);prop.set_meta("item_id",eid);supply.pickups.append(prop);world_props[eid]=prop
				world_props[eid].global_position=e.position;world_props[eid].set_meta("taken",false);world_props[eid].show()
			elif is_instance_valid(world_props.get(eid)):world_props[eid].set_meta("taken",true);world_props[eid].hide()
	for eid in world_props.keys():
		if not net.entities.has(eid):
			if is_instance_valid(world_props[eid]):world_props[eid].hide()
			if indices.has(eid):inventory.pickups.erase(int(indices[eid]))
	var old_owned:Array=inventory.owned.duplicate();inventory.owned.assign(own)
	if supply.items!=next_items:
		supply.items=next_items;supply.stock=stock
		if not supply.selected_instance.is_empty() and not next_items.has(supply.selected_instance):supply.stow(false);supply.selected_instance="";supply.selected_kind=""
		supply._refresh_pouch();supply.changed.emit()
	if old_owned!=own:inventory._sync_selection();inventory.changed.emit()
	if not _pickup_selection.is_empty() and net.entities.has(_pickup_selection) and int(net.entities[_pickup_selection].owner)==net.me():
		if indices.has(_pickup_selection):rack.selected=int(indices[_pickup_selection]);rack.is_holstered=false;rack._apply_selection()
		elif supply.items.has(_pickup_selection):supply.equip_instance(_pickup_selection)
		_pickup_selection=""
	_sync_builds();_sync_marks();_sync_projectiles();applying=false
	if not net.server and not net.training.is_empty():
		for key in net.training:game.practice_dummy.set(key,net.training[key])
		game.practice_dummy._update_readout()
func _sync_gun(eid:String,e:Dictionary,gun:Node)->void:
	var pending_shots =0;var pending_reload =false;var pending_hands:Array=[0,0]
	for request in net.pending:
		if str(request.data.get("id",""))!=eid:continue
		if request.action in ["shot","explosive"]:pending_shots+=1;pending_hands[clampi(int(request.data.get("side",0)),0,1)]+=1
		if request.action=="reload":pending_reload=true
	if pending_reload:return
	var previous_ammo:int=gun.ammo
	var staged_rounds:bool=str(e.reload)=="cylinder_loaded" or (int(e.catalog)==5 and str(e.reload)=="needs_bolt" and not e.get("cycle_only",false))
	gun.ammo=maxi(0,int(e.get("seated",e.ammo) if staged_rounds else e.ammo)-pending_shots)
	if "guns" in gun:
		var amounts:Array=e.get("hands",[ceili(float(e.ammo)*.5),floori(float(e.ammo)*.5)])
		for i in gun.guns.size():gun.guns[i].ammo=maxi(0,int(amounts[i])-int(pending_hands[i]));gun.guns[i].reload_state=str(e.get("hand_states",[e.reload,e.reload])[i])
		gun._sync_pair()
	else:
		gun.reload_state=str(e.reload)
		if "_seated_rounds" in gun:gun._seated_rounds=int(e.get("seated",0))
		if "seated" in gun:gun.seated=int(e.get("seated",e.ammo))
		if "action" in gun:
			gun.action.state=str(e.reload);gun.action.ammo=gun.ammo
			if str(e.reload)=="open_loaded":gun.action.loaded=int(e.capacity)
		if "chambers" in gun and previous_ammo!=int(gun.ammo):
			for i in gun.chambers.size():gun.chambers[i]="live" if i<int(gun.ammo) else "empty"
			gun._index=0
		if int(e.catalog)==27:gun.rocket_reserve=int(e.rocket_reserve)
	gun.update_ammo_display()
	_reload_states[eid]=str(gun.reload_state)
func _sync_player()->void:
	if not net.players.has(net.me()):return
	var p:Dictionary=net.players[net.me()];var actor:Node=game.player
	game.health=float(p.health);game.shield=float(p.shield);game.dead=p.life!="alive";game.complete=false
	game.weapon_inventory.capacity=int(p.capacity);game.field_builder.charges=int(p.builds)
	game.weapon.reserves=p.reserves.duplicate(true)
	if net.rules.infinite_ammo:
		for key in game.weapon.reserves:game.weapon.reserves[key]=maxi(1000000,int(game.weapon.reserves[key]))
	game.field_consumables.soda_left=0.0 # authoritative server owns heal-over-time
	actor.input_enabled=p.life=="alive" and (not game.field_menu.is_open or game.field_menu.backpack_is_open()) and (not game.xr_enabled or not game._xr_focus_suspended)
	actor.walk_speed_multiplier=minf(1.0,float(_local_rules.get("walk_speed_multiplier",1.0)))*float(net.rules.walk)
	actor.fling_power=float(net.rules.fling)
	actor.sprint_slow_gain=float(_local_rules.get("sprint_slow_gain",actor.RUN_SPEED/actor.WALK_SPEED))*float(net.rules.run)
	actor.sprint_fast_gain=float(_local_rules.get("sprint_fast_gain",actor.SPRINT_SPEED/actor.WALK_SPEED))*float(net.rules.run)
	actor.sprint_stamina_seconds=float(_local_rules.get("sprint_stamina_seconds",6.0))*float(net.rules.stamina)
	actor.network_flight_multiplier=float(net.rules.flight)
	if int(p.spawn_revision)!=_spawn_revision:
		_spawn_revision=int(p.spawn_revision);actor.global_position=p.get("spawn",actor.global_position);actor.reset_motion();actor.require_neutral_input();game.damage_timer=0.0
		game.weapon.is_holstered=p.life!="alive";game.weapon._apply_selection()
	game.field_builder.visible=bool(net.rules.builds)
	game.item_catalog_088.testing=bool(net.rules.catalog)
	if p.life=="downed":game._feedback("DOWNED · Waiting for a teammate",1)
	elif p.life=="eliminated":game._feedback("RESPAWN %.1f"%maxf(0,float(p.respawn_at)-net.now()) if net.rules.mode=="respawn" else "ELIMINATED · Spectating",1)
func _sync_builds()->void:
	var builder:Node=game.field_builder
	for bid in build_props.keys():
		if not net.builds.has(bid):
			if is_instance_valid(build_props[bid]):build_props[bid].collapse()
			build_props.erase(bid)
	for bid in net.builds:
		var e:Dictionary=net.builds[bid]
		if not is_instance_valid(build_props.get(bid)):
			var entry:Dictionary=builder._plan_entry(str(e.kind),e.at,{"found":false,"max_y":-INF,"min_y":INF,"rids":[]},bool(e.support));builder._spawn_entry(entry)
			var body:Node=builder.pieces.back();body.set_meta("network_id1000",bid);build_props[bid]=body
			body.destroyed.connect(func(_body:Node):
				if net.server and not applying and net.builds.has(bid):net.builds.erase(bid);net._publish())
		build_props[bid].health=float(e.health)
func _sync_marks()->void:
	for id in mark_props.keys():
		if not net.marks.has(id) or float(net.marks[id].until)<net.now():mark_props[id].queue_free();mark_props.erase(id)
	for id in net.marks:
		if id==net.me() or not net.allied(net.me(),id):continue
		var m:Dictionary=net.marks[id]
		if float(m.until)<net.now():continue
		if mark_props.has(id) and mark_props[id].get_meta("until")==m.until:continue
		if mark_props.has(id):mark_props[id].queue_free()
		var root =Node3D.new();game.add_child(root);root.global_position=m.point;root.set_meta("until",m.until);mark_props[id]=root
		var icon =Sprite3D.new();root.add_child(icon);icon.texture=preload("res://scripts/weapon_icons_094.gd").icon(int(m.catalog)) if int(m.catalog)>=0 else load("res://assets/ui/ping0993_5.svg" if int(m.color)==5 else "res://assets/ui/ping072_%d.svg"%int(m.color));icon.pixel_size=.009;icon.no_depth_test=false
		if int(m.color) in [3,4,5]:root.global_basis=preload("res://scripts/team_marks.gd").surface_basis0993(m.normal)
		else:icon.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;icon.position.y=.6
func _return_lobby()->void:
	_clear_projectiles()
	applying=true;game.field_builder.set_physics_process(true);game._return_home0992();game.dead=false;game.complete=false;applying=false
	_spawn_revision=-1
func leave_session()->void:
	net.close();_restore_offline();game._return_home0992()
func _disconnected(reason:String)->void:
	_restore_offline();game._return_home0992();game._feedback(reason,8)
func _restore_offline()->void:
	_clear_projectiles()
	_loading_generation+=1;_preparing=false;_epoch=-1;_stage="offline"
	for avatar in avatars.values():avatar.queue_free()
	avatars.clear()
	for prop in mark_props.values():prop.queue_free()
	mark_props.clear()
	if not _local_rules.is_empty():
		for key in ["walk_speed_multiplier","fling_power","sprint_slow_gain","sprint_fast_gain","sprint_stamina_seconds"]:
			if _local_rules.has(key):game.player.set(key,_local_rules[key])
		game.field_menu.player_damage_multiplier=float(_local_rules.get("player_damage_multiplier",1.0));game.field_menu.enemy_damage_multiplier=float(_local_rules.get("enemy_damage_multiplier",1.0));_local_rules.clear()
	game.item_catalog_088.testing=_catalog_before
	game.player.network_flight_multiplier=1.0;game.player.input_enabled=true;game.field_builder.set_physics_process(true);game.dead=false;game.complete=false
	game.practice_dummy.set_process(true)
	game.weapon_inventory.owned.assign([0,2,9]);game.weapon.reset_weapon();game._begin_chapter()
func gateway(action:String,value:Variant,extra:Variant=null)->bool:
	if not live() or applying:return false
	if not playing():return true
	var inventory:Node=game.weapon_inventory
	match action:
		"weapon_pickup":
			var index =int(value)
			if not inventory.pickups.has(index):return true
			_request_pickup(str(inventory.pickups[index].get_meta("network_id1000","")))
		"ammo_pickup":_request_pickup(str(value.get_meta("network_id1000","")))
		"heal_pickup":
			var i =int(value)
			if i>=0 and i<game.field_consumables.pickups.size():_request_pickup(str(game.field_consumables.pickups[i].get_meta("network_id1000","")))
		"drop_weapon":_request_drop(str(local_ids.get(int(value),"")))
		"drop_heal":_request_drop(str(value))
		"drop_slot":
			for member in inventory.stack_members(str(value)):
				_request_drop(str(local_ids.get(int(str(member).trim_prefix("weapon_")),"")) if str(member).begins_with("weapon_") else str(member).trim_prefix("consumable:"))
		"consume":
			var eid =str(value)
			if _consume_pending.has(eid) and net.now()-float(_consume_pending[eid].time)>.3:_consume_pending.erase(eid)
			if not _consume_pending.has(eid):_consume_pending[eid]={"seq":net.request("consume",{"id":eid,"phase":game.field_consumables.phase}),"time":net.now()}
		"build":
			var entries:Array=[]
			for entry in value:entries.append({"kind":entry.kind,"at":entry.at,"key":entry.key,"support":entry.support})
			net.request("build",{"entries":entries})
		"catalog":net.request("catalog",value)
		"drop_reserve":net.request("drop_reserve",value)
	return true
func _request_pickup(eid:String)->void:
	if eid.is_empty():return
	var selected =str(local_ids.get(game.weapon.selected,""))
	if not game.field_consumables.selected_instance.is_empty():selected=game.field_consumables.selected_instance
	var point:Vector3=game.player.global_position
	if not selected.is_empty():
		var prop:Node3D=game.weapon_inventory._create_prop(game.weapon.selected)
		if game.weapon_inventory._place_reachable_drop(prop):point=prop.global_position
		prop.queue_free()
	net.request("pickup",{"id":eid,"replace":selected,"drop":point})
func _request_drop(eid:String)->void:
	if eid.is_empty():return
	var prop:Node3D=game.weapon_inventory._create_prop(game.weapon.selected)
	if game.weapon_inventory._place_reachable_drop(prop):net.request("drop",{"id":eid,"position":prop.global_position})
	prop.queue_free()
func shot(origin:Vector3,directions:Array)->void:
	var eid =str(local_ids.get(game.weapon.selected,""))
	if eid.is_empty() or not playing():return
	var cat =game.weapon.catalog_index(game.weapon.selected)
	var side =0
	if cat in [11,12] and game.weapon.weapons[game.weapon.selected].guns.size()==2:
		var guns:Array=game.weapon.weapons[game.weapon.selected].guns;side=0 if origin.distance_to(guns[0].model.global_position)<origin.distance_to(guns[1].model.global_position) else 1
	net.request("shot",{"id":eid,"origin":origin,"directions":directions,"time":net.now()-.06,"side":side})
	for d in directions:_show_ray(origin,d)
func explosive(spec:Dictionary)->void:
	var eid =str(local_ids.get(game.weapon.selected,""))
	if not eid.is_empty():net.request("explosive",{"id":eid,"origin":spec.origin,"velocity":spec.velocity})
func melee(target:Node,point:Vector3,amount:float,direction:Vector3)->void:
	if not playing():return
	var eid =str(local_ids.get(game.weapon.selected,""))
	net.request("melee",{"id":eid,"point":point,"direction":direction})
func _show_ray(origin:Vector3,direction:Vector3)->void:
	var query =PhysicsRayQueryParameters3D.create(origin,origin+direction*180,1|4|8,[game.player.get_rid()]);var hit =game.get_world_3d().direct_space_state.intersect_ray(query)
	game._tracer(origin,hit.position if not hit.is_empty() else origin+direction*120)
	if not hit.is_empty():game._impact(hit.position,hit.normal)
func _process(delta:float)->void:
	if not live():return
	if net.server and playing():
		var target:Node=game.practice_dummy
		var training_state:Dictionary={"health":target.health,"shield":target.shield,"total_damage":target.total_damage,"last_damage":target.last_damage}
		if net.training!=training_state:net.training=training_state;net._publish()
	for id in avatars.keys():
		if not net.players.has(id):avatars[id].queue_free();avatars.erase(id)
	for id in net.players:
		if id==net.me():continue
		if not avatars.has(id):
			var avatar =preload("res://scripts/net_avatar1000.gd").new();game.add_child(avatar);avatar.setup(id,net,self);avatars[id]=avatar
	_flight_clock+=delta
	if net.server and _flight_clock>=.04:
		_flight_clock=0
		for id in _projectiles.keys():
			if not is_instance_valid(_projectiles[id]):_projectiles.erase(id);continue
			var projectile:Node=_projectiles[id]
			var state:Dictionary=projectile.get_meta("spawn1000").duplicate(true)
			state.merge({"id":id,"at":projectile.global_transform,"velocity":projectile.linear_velocity,"age":projectile.age,"zone":projectile.zone_active,"zone_age":projectile.zone_age,"net_epoch":net.epoch},true)
			net.projectile_poses[id]=state;net._flight.rpc(state)
	if net.dedicated:return
	_pose_clock+=delta
	if _pose_clock>=.04:
		_pose_clock=0;_pose_seq+=1
		var actor:Node=game.player;var camera:Camera3D=actor.get_view_camera();var left:Transform3D=actor.left_hand.global_transform;var right:Transform3D=actor.right_hand.global_transform
		if not actor.xr_enabled:left=camera.global_transform.translated_local(Vector3(-.25,-.25,-.4));right=camera.global_transform.translated_local(Vector3(.25,-.25,-.4))
		if game.revive_paddles.active and game.revive_paddles._paddles.size()==2:left=game.revive_paddles._paddles[0].global_transform;right=game.revive_paddles._paddles[1].global_transform
		if not actor.xr_enabled and game.revive_paddles.active and game.revive_paddles._facing:left.basis=camera.global_basis*Basis(Vector3.UP,PI*.5);right.basis=camera.global_basis*Basis(Vector3.UP,-PI*.5)
		var gun:Node=game.weapon.weapons[game.weapon.selected];var guard:bool=bool(gun.get("shield_active")) if "shield_active" in gun else false
		var packet:Dictionary={"root":actor.global_transform.orthonormalized(),"head":camera.global_transform.orthonormalized(),"left":left.orthonormalized(),"right":right.orthonormalized(),"weapon":game.weapon.catalog_index(game.weapon.selected),"holstered":game.weapon.is_holstered,"grip_left":actor.left_hand.get_float("grip") if actor.xr_enabled else 0.0,"grip_right":actor.right_hand.get_float("grip") if actor.xr_enabled else 0.0,"paddles":game.revive_paddles.active,"shield":guard,"gun_pose":gun.model.global_transform,"desktop":not actor.xr_enabled,"motion":actor.movement_mode,"seq":_pose_seq}
		if guard:packet.shield_plane=gun.shield_visual.global_transform
		packet.hand=actor.dominant_hand
		if "guns" in gun:packet.pair0=gun.guns[0].model.global_transform;packet.pair1=gun.guns[1].model.global_transform
		net.send_pose(packet)
	if playing() and not _preparing:
		_sample_grips();_bind_reload_events();_poll_reloads()
		if not game.field_menu.is_open:_sync_player()
		if game.player.global_position.y<-25 and net.server:net.hurt(net.me(),1000,0,false,true)
func _bind_reload_events()->void:
	for index in game.weapon_inventory.owned:
		var gun:Node=game.weapon.weapons[index]
		if gun.get_instance_id() in _reload_bound:continue
		_reload_bound[gun.get_instance_id()]=true
		if gun.has_signal("network_reload_stage1000"):gun.network_reload_stage1000.connect(_reload_event.bind(index,-1))
		if "guns" in gun:
			for side in gun.guns.size():
				if gun.guns[side].has_signal("network_reload_stage1000"):gun.guns[side].network_reload_stage1000.connect(_reload_event.bind(index,side))
func _reload_event(state:String,index:int,side:int)->void:
	if applying or not playing():return
	var eid =str(local_ids.get(index,""))
	if eid.is_empty():return
	_sample_grips()
	_reload_states[eid+":"+str(side)]=state
	net.request("reload",{"id":eid,"state":state,"side":side,"xr":game.player.xr_enabled,"grip_serial":_grip_serial})
func _sample_grips()->void:
	if not game.player.xr_enabled:return
	for i in 2:
		var hand:XRController3D=game.player.left_hand if i==0 else game.player.right_hand
		var pressed:bool=hand.get_float("grip")>.55 or hand.is_button_pressed("grip_click")
		if pressed and not _grips[i]:_grip_serial+=1;net.request("grip",{"serial":_grip_serial})
		_grips[i]=pressed
func _poll_reloads()->void:
	for index in game.weapon_inventory.owned:
		var eid =str(local_ids.get(index,""))
		if eid.is_empty():continue
		var gun:Node=game.weapon.weapons[index];var parts:Array=gun.guns if "guns" in gun else [gun]
		for side in parts.size():
			var part:Node=parts[side];var actual_side =side if parts.size()>1 else -1;var key =eid+":"+str(actual_side);var state =str(part.reload_state)
			if _reload_states.has(key) and _reload_states[key]!=state:_reload_event(state,index,actual_side)
			_reload_states[key]=state
func _mark(payload:Dictionary)->void:
	if not playing():return
	var a:Array=payload.position;var n:Array=payload.normal
	net.request("mark",{"point":Vector3(a[0],a[1],a[2]),"normal":Vector3(n[0],n[1],n[2]),"color":preload("res://scripts/team_marks.gd").ACTIONS.find(str(payload.action)),"catalog":int(payload.get("catalog_index",-1))})
func _event(kind:String,data:Dictionary)->void:
	match kind:
		"pickup":
			if int(data.player)==net.me():
				_pickup_selection=str(data.id)
				if str(data.get("kind","")) in ["ammo","builds"]:preload("res://scripts/sound_cues099.gd").play_at(game,"build_pickup" if data.kind=="builds" else "ammo_pickup",data.position)
		"reload":
			if int(data.player)!=net.me():
				var cue="bolt" if data.state=="ready" else ("mag_insert" if data.state in ["needs_rack","needs_feed","open_loaded","cylinder_loaded"] else "mag_eject")
				var voice=AudioStreamPlayer3D.new();game.add_child(voice);voice.global_position=data.position;voice.bus="SFX";voice.max_distance=30;voice.unit_size=4;voice.stream=preload("res://scripts/audio_bank.gd").for_weapon(game.weapon.weapons[int(data.catalog)],cue);voice.finished.connect(voice.queue_free);voice.play()
		"shot":
			if int(data.player)==net.me():return
			for direction in data.directions:_show_ray(data.origin,direction)
			var gun:Node=game.weapon.weapons[int(data.catalog)];var audio =AudioStreamPlayer3D.new();game.add_child(audio);audio.global_position=data.origin;audio.bus="SFX";audio.max_distance=140;audio.unit_size=12;audio.stream=preload("res://scripts/audio_bank.gd").for_weapon(gun,"shot");audio.finished.connect(audio.queue_free);audio.play()
		"hit":
			if int(data.player)==net.me():game.combat_hud.notify_incoming(float(data.amount));game._play_sound("hurt");_last_damage=net.now()
			if int(data.by)==net.me() and avatars.has(int(data.player)):game.combat_hud.damage_numbers0992.emit_hit(float(data.amount),avatars[int(data.player)],bool(data.shield))
		"target_hit":
			if int(data.by)==net.me():game.combat_hud.damage_numbers0992.emit_hit(float(data.amount),game.practice_dummy,bool(data.shield))
		"revive":
			var p:Vector3=data.position;var fx =preload("res://scripts/revive_discharge_fx_091.gd").new();game.add_child(fx);fx.start(p+Vector3(-.2,1,0),p+Vector3(.2,1,0),[p+Vector3(-.13,1,0),p+Vector3(.13,1,0)])
			preload("res://scripts/sound_cues099.gd").play_at(game,"revive_discharge",p)
		"build":game.field_builder._play_build_sound(data.position)
		"mark":
			_sync_marks()
			if int(data.player)!=net.me():preload("res://scripts/sound_cues099.gd").play_ui(game,"mark_ping0993")
		"projectile":_spawn_projectile(data)
		"projectile_pose":
			if net.server:return
			if _ended_projectiles.has(int(data.id)):return
			if not is_instance_valid(_projectiles.get(int(data.id))):_spawn_projectile(data)
			var projectile:Node=_projectiles.get(int(data.id))
			if is_instance_valid(projectile) and not projectile.finished:
				projectile.freeze=true;projectile.global_transform=projectile.global_transform.interpolate_with(data.at,.7);projectile.age=float(data.age)
				if data.zone and not projectile.zone_active:projectile._activate_zone()
				projectile.zone_age=float(data.zone_age)
		"projectile_end":
			if net.server:return
			_ended_projectiles[int(data.id)]=true
			var projectile:Node=_projectiles.get(int(data.id))
			if is_instance_valid(projectile):
				projectile.global_position=data.position
				if projectile.kind!="zone":projectile.detonate()
				else:projectile.queue_free()
			_projectiles.erase(int(data.id))
		"blocked":
			preload("res://scripts/sound_cues099.gd").play_at(game,"katana_shield_raise",data.position)
		"blast":
			if not net.server:game._impact(data.position,Vector3.UP)
		"consume":
			if int(data.player)==net.me():game.field_consumables._play_cue("drink")
func _spawn_point(id:int,players:Dictionary,rules:Dictionary)->Vector3:
	var map_id =str(rules.map);var base:Vector3=game.active_sandbox_map.spawn if is_instance_valid(game.active_sandbox_map) else game.world.player_spawn
	var candidates:Array[Vector3]=[]
	if map_id=="cyber_bird" and is_instance_valid(game.active_sandbox_map):
		for i in range(8):candidates.append(game.active_sandbox_map.global_position+Vector3(-55+(i%4)*35,1,330-floori(i/4)*660))
	else:
		for i in range(8):candidates.append(base+Vector3(-15+(i%4)*10,2,-6-floori(i/4)*30))
	var best =base;var best_score =-INF
	for i in candidates.size():
		var at:Vector3=candidates[(i+id)%candidates.size()];var hit =game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*20,at-Vector3.UP*30,1))
		if hit.is_empty() or hit.normal.y<.65:continue
		at=hit.position+Vector3.UP*.2;var score =1000.0
		for other in players:
			if other==id or not net.poses.has(other) or net.allied(id,other):continue
			score=minf(score,at.distance_to(net.poses[other].root.origin))
		if score>best_score:best_score=score;best=at
	return best
func _validate(action:String,id:int,data:Dictionary)->bool:
	match action:
		"pickup":
			if not net.poses.has(id):return false
			var pose:Dictionary=net.poses[id];var point:Vector3=data.position
			if minf(point.distance_to(pose.left.origin),point.distance_to(pose.right.origin))>2.5:return false
			return _clear(pose.head.origin,point)
		"drop":return _clear(net.poses[id].head.origin,data.position)
		"consume":
			if str(data.get("phase",""))!="consume" or not net.poses.has(id):return false
			var pose:Dictionary=net.poses[id]
			return minf(pose.head.origin.distance_to(pose.left.origin),pose.head.origin.distance_to(pose.right.origin))<1.0
		"movement":
			if not net.poses.has(id):return true
			var previous:Dictionary=net.poses[id]
			if previous.head.origin.distance_to(data.head.origin)<.01:return true
			return _clear(previous.head.origin,data.head.origin)
		"build":return _validate_builds(id,data)
		"shot":_hit_rays(id,data);return true
		"melee":return _melee_hit(id,data)
		"revive":
			if not net.poses.has(id) or not net.poses.has(int(data.target)):return false
			var pose:Dictionary=net.poses[id];var chest:Vector3=net.poses[int(data.target)].head.origin+Vector3.DOWN*.6
			return pose.left.origin.distance_to(chest)<1.0 and pose.right.origin.distance_to(chest)<1.0 and _clear(pose.left.origin,chest) and _clear(pose.right.origin,chest)
		"explosive":
			if not net._valid_vector(data.get("origin")) or not net._valid_vector(data.get("velocity")) or not net.poses.has(id):return false
			if data.origin.distance_to(net.poses[id].head.origin)>3.5 or data.velocity.length()>100:return false
			var cat =int(net.entities[str(data.id)].catalog);var kind ="smaw" if cat==27 else ("zone" if cat==28 else "frag")
			_projectile_serial+=1;var event:Dictionary={"id":_projectile_serial,"player":id,"kind":kind,"origin":data.origin,"velocity":data.velocity}
			net._event("projectile",event);return true
	return false
func _clear(a:Vector3,b:Vector3)->bool:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1|8,[game.player.get_rid()])).is_empty()
func _validate_builds(id:int,data:Dictionary)->bool:
	if not net.poses.has(id):return false
	var builder:Node=game.field_builder;var pose:Dictionary=net.poses[id];var entries:Array=[]
	for e in data.entries:
		if not e is Dictionary or e.get("kind") not in ["wall","floor"] or not e.get("at") is Transform3D or not e.at.is_finite() or absf(e.at.basis.determinant()-1)>.01:return false
		if e.at.origin.distance_to(pose.head.origin)>builder.placement_range+builder.PANEL_SIDE:return false
		var key:String=builder._slot_for(e.at,e.kind)
		if str(e.get("key",""))!=key:return false
		for existing in net.builds.values():
			if existing.key==key:return false
		var entry:Dictionary=builder._plan_entry(e.kind,e.at,{"found":false,"max_y":-INF,"min_y":INF,"rids":[]},bool(e.get("support",false)))
		var exclusions:Array[RID]=[game.player.get_rid()]
		if e.kind=="wall" and builder._wall_fully_buried_091(e.at,exclusions):return false
		var ground:Dictionary=builder._ground_samples(e.at,e.at.origin.y,e.kind,exclusions)
		if e.kind=="floor" and ground.get("found",false) and float(ground.get("min_y",-INF))>=e.at.origin.y-.15:return false
		if not builder._entry_clear(entry,exclusions,{"head":pose.head.origin,"origin":pose.right.origin,"direction":-pose.right.basis.z}).is_empty():return false
		for other in net.poses.values():
			if entry.mesh.get_aabb().grow(.2).has_point(entry.at.affine_inverse()*other.head.origin):return false
		entries.append(entry)
	return builder._connected_to_supported(entries)
static func sphere_ray(origin:Vector3,direction:Vector3,center:Vector3,radius:float)->float:
	var offset =origin-center;var b =offset.dot(direction);var c =offset.length_squared()-radius*radius;var d =b*b-c
	if d<0:return INF
	var t =-b-sqrt(d);return t if t>=0 else INF
func _hit_rays(id:int,data:Dictionary)->void:
	var cat =int(data.catalog);var profile =preload("res://scripts/arsenal_data.gd").profile(cat);var row:Dictionary=preload("res://scripts/one_star0991.gd").data().get(str(profile.id),{})
	var base =float(row.get("body",20))/maxi(1,int(row.get("pellets",1)));var grouped:Dictionary={};var heads:Dictionary={}
	if net.poses.has(id) and not _clear(net.poses[id].head.origin,data.origin):return
	for ray in data.directions:
		var direction:Vector3=ray.normalized();var origin:Vector3=data.origin
		var exclusions:Array[RID]=[game.player.get_rid()]
		for avatar in avatars.values():exclusions.append(avatar.get_rid())
		var hit =game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*180,1|4|8,exclusions))
		var closest =origin.distance_to(hit.position) if not hit.is_empty() else 180.0;var target =0;var headshot =false
		for other in net.players:
			if other==id or net.players[other].life!="alive":continue
			var pose:Dictionary=net.historical_pose(other,float(data.time))
			if pose.is_empty():continue
			var head_t =sphere_ray(origin,direction,pose.head.origin,.17)
			var chest_t =sphere_ray(origin,direction,pose.head.origin+Vector3.DOWN*.45,.29)
			var hip_t =sphere_ray(origin,direction,pose.head.origin+Vector3.DOWN*.92,.27)
			var t =minf(head_t,minf(chest_t,hip_t))
			if t<closest:closest=t;target=other;headshot=head_t<=minf(chest_t,hip_t)
		var blocked:bool=false
		for other in net.players:
			if other==id:continue
			var guard:Dictionary=net.historical_pose(other,float(data.time))
			if guard.get("shield",false) and guard.has("shield_plane"):
				var stop:Dictionary=preload("res://scripts/directional_shield.gd").intersect_bullet(origin,origin+direction*closest,guard.shield_plane,preload("res://scripts/melee_sword.gd").SHIELD_RADII)
				if not stop.is_empty():blocked=true;net._event("blocked",{"player":other,"position":stop.position});break
		if blocked:continue
		if target>0:
			var amount =base
			if headshot:amount*=float(row.get("head",base))/maxf(1,float(row.get("body",base)))*float(net.rules.headshots)
			if data.directions.size()>1:amount*=lerpf(1.0,.25,clampf((closest-8)/17,0,1))
			grouped[target]=float(grouped.get(target,0))+amount;heads[target]=bool(heads.get(target,false)) or headshot
		elif not hit.is_empty():
			var collider:Node=hit.collider
			if collider.has_meta("network_id1000"):net.hurt_build(str(collider.get_meta("network_id1000")),base)
			elif collider.is_in_group("practice_targets") and collider.has_method("take_damage"):
				var amount:float=base
				if collider.hit_zone_at0991(hit.position)=="head":amount*=float(row.get("head",base))/maxf(1,float(row.get("body",base)))*float(net.rules.headshots)
				var shield_before:float=collider.shield;collider.take_damage(amount*float(net.rules.damage))
				net._event("target_hit",{"by":id,"amount":collider.last_damage,"shield":collider.shield<shield_before})
	for target in grouped:net.hurt(int(target),float(grouped[target]),id,bool(heads[target]))
func _melee_hit(id:int,data:Dictionary)->bool:
	var eid =str(data.get("id",""))
	if not net.entities.has(eid) or int(net.entities[eid].owner)!=id or not net.poses.has(id):return false
	var cat =int(net.entities[eid].get("catalog",-1))
	if cat not in [14,15,16,29] or not net._valid_vector(data.get("point")):return false
	var history:Array=net._history.get(id,[])
	if history.size()<2:return false
	var a:Dictionary=history[-2];var b:Dictionary=history[-1];var dt =float(b.time)-float(a.time)
	if dt<=0:return false
	var hand_key:String=str(b.get("hand","right"))
	var speed:float=(b.root.affine_inverse()*b[hand_key].origin).distance_to(a.root.affine_inverse()*a[hand_key].origin)/dt
	if speed<.2 or speed>12:return false
	var key ="melee_%d"%id
	if int(b.seq)==int(net._shot_clock.get(key,-1)):return false
	net._shot_clock[key]=int(b.seq)
	if not _clear(b[hand_key].origin,data.point):return false
	for target in net.players:
		if target==id or not net.poses.has(target):continue
		if data.point.distance_to(net.poses[target].head.origin+Vector3.DOWN*.5)<.8 and data.point.distance_to(b[hand_key].origin)<2.5:net.hurt(target,35.0 if cat==29 else preload("res://scripts/melee_sword.gd").swing_damage(speed),id,false,true)
	return true
func _spawn_projectile(data:Dictionary)->void:
	if int(data.get("net_epoch",net.epoch))!=int(net.epoch) or _ended_projectiles.has(int(data.id)) or is_instance_valid(_projectiles.get(int(data.id))):return
	# Server simulates authoritative collision/damage. Clients render the same trajectory.
	var proxy =preload("res://scripts/net_projectile_proxy1000.gd").new();game.add_child(proxy);proxy.setup(self,int(data.player),not net.server)
	var projectile:RigidBody3D=preload("res://scripts/explosive_projectile.gd").new() if net.server else preload("res://scripts/net_projectile_visual1000.gd").new()
	game.add_child(projectile);projectile.add_to_group("ashfall_projectile");projectile.setup(proxy,{"kind":data.kind,"origin":data.origin,"velocity":data.velocity});_projectiles[int(data.id)]=projectile
	projectile.set_meta("spawn1000",data.duplicate(true))
	if not net.server:
		projectile.freeze=true;projectile.collision_layer=0;projectile.collision_mask=0
		if data.has("at"):projectile.global_transform=data.at
		projectile.age=float(data.get("age",0))
		if data.get("zone",false):projectile._activate_zone();projectile.zone_age=float(data.get("zone_age",0))
	else:net.projectile_poses[int(data.id)]=data.duplicate(true)
	projectile.tree_exited.connect(proxy.queue_free)
	if net.server:
		var round_epoch:int=net.epoch
		projectile.tree_exiting.connect(func():
			_projectiles.erase(int(data.id))
			if net.active and net.server and net.epoch==round_epoch and net.stage=="match":
				net.projectile_poses.erase(int(data.id));net._event("projectile_end",{"id":data.id,"position":projectile.global_position}))
func _sync_projectiles()->void:
	if net.server:return
	for state in net.projectile_poses.values():
		if not is_instance_valid(_projectiles.get(int(state.id))):_spawn_projectile(state)
func _clear_projectiles()->void:
	for projectile in _projectiles.values():
		if is_instance_valid(projectile):projectile.queue_free()
	_projectiles.clear()
	_ended_projectiles.clear()
func explosion(owner:int,point:Vector3,radius:float,power:float,falloff:bool)->void:
	if not net.server:return
	for id in net.players:
		if not net.poses.has(id):continue
		var distance =point.distance_to(net.poses[id].head.origin+Vector3.DOWN*.5)
		if distance<=radius:net.hurt(id,power*(maxf(0,1-distance/radius) if falloff else 1.0),owner)
	for bid in net.builds.keys():
		var distance =point.distance_to(net.builds[bid].at.origin)
		if distance<=radius:net.hurt_build(bid,power*(maxf(0,1-distance/radius) if falloff else 1.0))
	net._event("blast",{"position":point,"radius":radius})
