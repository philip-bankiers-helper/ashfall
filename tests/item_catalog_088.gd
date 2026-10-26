extends SceneTree
class GameFixture extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
	var player:Node3D
	var weapon:Node3D
	var weapon_inventory:Node3D
	var field_consumables:Node3D
	var field_builder:Node3D
	var ammo_pickups:Node3D
	var revive_paddles:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var game:=GameFixture.new();root.add_child(game)
	game.player=load("res://scripts/player.gd").new();game.add_child(game.player);game.player.setup(false);game.player.set_process(false);game.player.set_physics_process(false)
	game.weapon=load("res://scripts/weapon_rack.gd").new();game.add_child(game.weapon);game.weapon.setup(game.player);game.weapon.set_process(false);game.weapon.set_physics_process(false)
	for gun in game.weapon.weapons:gun.set_process(false);gun.set_physics_process(false)
	game.weapon_inventory=load("res://scripts/weapon_inventory.gd").new();game.add_child(game.weapon_inventory);game.weapon_inventory.setup(game.player,game.weapon)
	game.field_consumables=load("res://scripts/field_consumables.gd").new();game.add_child(game.field_consumables);game.field_consumables.setup(game.player,game.weapon,game)
	game.revive_paddles=load("res://scripts/revive_paddles.gd").new();game.add_child(game.revive_paddles);game.revive_paddles.setup(game.player,game.weapon)
	game.field_builder=load("res://scripts/field_builder.gd").new();game.add_child(game.field_builder);game.field_builder.setup(game.player,game.weapon,game)
	game.ammo_pickups=load("res://scripts/ammo_pickups.gd").new();game.add_child(game.ammo_pickups);game.ammo_pickups.setup(game.player,game.weapon,[]);game.ammo_pickups._builder=game.field_builder;game.ammo_pickups.set_physics_process(false)
	var service=load("res://scripts/item_catalog_service_088.gd").new();game.add_child(service);service.setup(game,true)
	var cards:Array[Dictionary]=service.cards()
	check(cards.size()==52,"12fixed cells plus40current catalog entries")
	for item in [[0,0],[1,1],[4,2],[5,3],[8,4],[9,5]]:check(cards[item[0]].kind=="slot" and cards[item[0]].slot==item[1],"six inventory slots stay in left two columns")
	for item in [[2,"pistol"],[3,"rifle"],[6,"shells"],[7,"sniper"],[10,"smg"],[11,"builds"]]:check(cards[item[0]].kind=="reserve" and cards[item[0]].family==item[1],"fixed ammo/build position "+item[1])
	check(game.weapon_inventory.SLOT_LIMIT==6,"catalog does not enlarge carried inventory")
	var amounts:={"pistol":16,"smg":20,"rifle":32,"shells":6,"sniper":5,"builds":6}
	for family in amounts:
		var box:Node3D=game.ammo_pickups.spawn_box(family,Vector3(30,1,30))
		check(box.get_meta("amount")==amounts[family],"wiki screenshot per-box count "+family)
		if family=="builds":
			game.field_builder.charges=100
			check(game.ammo_pickups.collect_box(box)==6 and game.field_builder.charges==106,"build item adds six charges")
		else:
			var before:Dictionary=game.weapon.reserves.duplicate();game.weapon.reserves[family]=10
			check(game.ammo_pickups.collect_box(box)==amounts[family] and game.weapon.reserves[family]==10+amounts[family],"collect credits correct reserve family "+family)
		check(game.ammo_pickups.collect_box(box)==0,"one box cannot be collected twice "+family)
	for item in [[5,"sniper"],[6,"smg"],[10,"smg"],[11,"smg"],[13,"sniper"],[17,"smg"],[18,"smg"],[25,"sniper"]]:check(game.weapon.AMMO_FAMILIES[item[0]]==item[1],"five-family production weapon routing "+str(item[0]))
	game.weapon.reserves.pistol=3
	var box_count:int=game.ammo_pickups.boxes.size()
	check(service.activate({"kind":"reserve","family":"pistol"}) and game.weapon.reserves.pistol==0,"finite reserve drop debits only actual available rounds")
	var dropped:Node3D=game.ammo_pickups.boxes[-1]
	check(dropped.get_meta("amount")==3 and game.ammo_pickups.boxes.size()==box_count+1,"partial dropped box retains exact count")
	check(game.ammo_pickups.collect_box(dropped)==3 and game.weapon.reserves.pistol==3,"drop/pickup conserves reserve")
	game.field_builder.charges=999
	var build_box:Node3D=game.ammo_pickups.spawn_box("builds",Vector3(30,1,30))
	check(game.ammo_pickups.collect_box(build_box)==0 and build_box.visible,"full build capacity leaves supply available")
	game.field_builder.charges=997
	check(game.ammo_pickups.collect_box(build_box)==2 and build_box.get_meta("amount")==4 and build_box.visible,"partial build collection preserves remainder")
	game.field_builder.charges=990
	check(game.ammo_pickups.collect_box(build_box)==4 and game.field_builder.charges==994,"remaining builds can be collected without duplicate event credit")
	service.testing=false
	check(service.cards().size()==12 and not service.activate({"kind":"weapon","catalog":17}),"normal game has fixed inventory/resources and rejects free spawning")
	service.testing=true
	var old_count:int=game.weapon.weapons.size();var owned:Array=game.weapon_inventory.owned.duplicate()
	check(service.activate({"kind":"weapon","catalog":17}) and game.weapon.weapons.size()==old_count+1,"test catalog creates independent persistent weapon")
	check(game.weapon_inventory.owned==owned and game.weapon_inventory.pickups.has(old_count),"spawned gun is a ground pickup and does not replace carried slot")
	check(service.activate({"kind":"consumable","item":"banana"}),"test catalog includes consumables")
	var menu=load("res://scripts/menu.gd").new();game.add_child(menu);menu.setup(game.player);menu.set_item_catalog(service);menu.set_open(true);menu.settings_page="loadout";menu._refresh();await process_frame;await process_frame
	var ui:Node3D=menu.catalog_ui
	check(ui.pinned.columns==4 and ui.pinned_buttons.size()==12,"actual board top grid4columns3rows")
	check(ui.catalog.columns==4 and ui.catalog_buttons.size()==40,"all test items accessible in lower4column grid")
	check(ui.scroll.get_v_scroll_bar().max_value>ui.scroll.size.y,"real vertical scrolling exposes rows beyond eight visible rows")
	if OS.get_cmdline_user_args().has("--catalog-capture"):
		ui.scroll.scroll_vertical=0;await process_frame;await RenderingServer.frame_post_draw
		ui.viewport.get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1]+"/BACKPACK-088-TOP.png")
	var pinned_position:Vector2=ui.pinned.position
	ui.scroll.scroll_vertical=200;await process_frame
	check(ui.pinned.position==pinned_position and ui.scroll.scroll_vertical>0,"top12remain fixed while lower catalog scrolls")
	if OS.get_cmdline_user_args().has("--catalog-capture"):
		await RenderingServer.frame_post_draw;ui.viewport.get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1]+"/BACKPACK-088-SCROLLED.png")
		game.player.xr_enabled=true;game.player.tracking_available=true;ui.set_active(false);ui.set_active(true);await process_frame;await process_frame;await RenderingServer.frame_post_draw
		ui.viewport.get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1]+"/BACKPACK-088-VR-TEXTURE.png")
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1]+"/BACKPACK-088-VR-PANEL.png")
		game.player.xr_enabled=false;ui.set_active(false);ui.set_active(true)
	check(not game.player.input_enabled,"catalog suspends locomotion through existing menu")
	await process_frame
	check(ui.point_index(Vector2(580,130))==2,"actual board image coordinates hit fixed pistol cell")
	ui.point_input(Vector2(580,130),true,false);await process_frame
	check(game.weapon.reserves.pistol==0,"VR board ray activation drops finite pistol remainder")
	var equip_action:String=ui.entries[0].action
	ui._activate(0,false);await process_frame
	check(game.weapon.selected==int(equip_action.trim_prefix("weapon_")),"actual catalog equipment callback resumes input before selecting carried gun")
	check(game.player.input_enabled and not ui.active,"close restores input and hides both surfaces")
	check(service.activate({"kind":"utility","item":"revive"}) and game.revive_paddles.selected,"catalog utility equips actual revive paddles")
	game.weapon.shutdown();game.queue_free();await process_frame;await process_frame
	print("ITEM_CATALOG_088 checks=",checks," failures=",failures," five_ammo_types=true inventory_slots=6 fixed_top_cells=12 xr_off=true");quit(failures)
