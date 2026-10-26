extends Node
signal changed
const Supply=preload("res://scripts/supply_catalog_088.gd")
const PINNED_INVENTORY=[0,1,4,5,8,9]
const PINNED_RESOURCES={2:"pistol",3:"rifle",6:"shells",7:"sniper",10:"smg",11:"builds"}
var game:Node
var testing:=false
func setup(value:Node,allow_catalog:bool)->void:game=value;testing=allow_catalog
func cards()->Array[Dictionary]:
	var result:Array[Dictionary]=[];var slots:Array=game.weapon_inventory.slot_actions()
	for cell in 12:
		if PINNED_RESOURCES.has(cell):
			var family:String=PINNED_RESOURCES[cell];var count:int=game.field_builder.charges if family=="builds" else int(game.weapon.reserves.get(family,0))
			result.append({"kind":"reserve","family":family,"title":Supply.TITLES[family],"count":count,"icon":Supply.icon(family),"active":count>0})
		else:
			var index:=PINNED_INVENTORY.find(cell);var action:String=slots[index] if index<slots.size() else ""
			var title:String=game.weapon_inventory.action_label(action) if not action.is_empty() else ("LOCKED" if index>=game.weapon_inventory.capacity else "EMPTY")
			var icon:Texture2D=game.weapon_inventory.action_icon(action) if not action.is_empty() else null
			result.append({"kind":"slot","slot":index,"action":action,"title":title,"icon":icon,"count":game.weapon_inventory.stack_count(action),"active":not action.is_empty()})
	if not testing:return result
	var ordered:Array=game.weapon.ACTIVE_WEAPON_INDICES.duplicate();ordered.sort_custom(game.weapon_inventory.catalog_before)
	for index in ordered:
		result.append({"kind":"weapon","catalog":index,"title":game.weapon.weapon_names[index],"icon":preload("res://scripts/weapon_icons_094.gd").icon(index),"active":true})
	for family in ["pistol","rifle","shells","sniper","smg","builds"]:
		result.append({"kind":"supply","family":family,"title":Supply.TITLES[family]+" +%d"%Supply.AMOUNTS[family],"icon":Supply.icon(family),"active":true})
	for kind in ["banana","soda","shaker","backpack"]:
		var icon:Texture2D=load("res://assets/ui/item_%s.svg"%kind) if kind!="backpack" else load("res://assets/ui/item_088_backpack.svg")
		result.append({"kind":"consumable","item":kind,"title":"BACKPACK +1 SLOT" if kind=="backpack" else game.field_consumables.TITLES[kind],"icon":icon,"active":true})
	result.append({"kind":"utility","item":"revive","title":"REVIVE PADDLES","icon":load("res://assets/ui/item_088_revive.svg"),"active":true})
	return result
func drop_point()->Vector3:
	var camera:Camera3D=game.player.get_view_camera();var forward:Vector3=-camera.global_basis.z;forward.y=0
	if forward.length_squared()<.001:forward=Vector3.FORWARD
	var desired:Vector3=game.player.global_position+forward.normalized()*1.65+Vector3.UP*.75
	var excluded:Array[RID]=[]
	if game.player is CollisionObject3D:excluded.append(game.player.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,desired,1|8,excluded)
	var hit:Dictionary=game.player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position+hit.normal*.2 if not hit.is_empty() else desired
func activate(card:Dictionary,drop:bool=false)->bool:
	var kind:=str(card.get("kind",""))
	if kind=="slot":
		var action:=str(card.get("action",""))
		if action.is_empty():return false
		var ok:bool=game.weapon_inventory.drop_action(action) if drop else game.weapon_inventory.select_action(action)
		changed.emit();return ok
	if kind=="reserve":return _drop_reserve(str(card.family))
	if not testing:return false
	if game.get("network_bridge")!=null and game.network_bridge.live():
		if kind=="utility":return game.revive_paddles.equip()
		var request:Dictionary={"kind":kind,"position":drop_point(),"catalog":card.get("catalog",-1),"family":card.get("family",""),"item":card.get("item","")}
		return game.network_bridge.gateway("catalog",request)
	if kind=="weapon":
		var instance:int=game.weapon.create_instance(int(card.catalog))
		if instance<0:return false
		game.weapon_inventory._spawn_pickup(instance,drop_point())
	elif kind=="supply":game.ammo_pickups.spawn_box(str(card.family),drop_point())
	elif kind=="utility":
		if not is_instance_valid(game.revive_paddles) or not game.revive_paddles.equip():return false
	elif kind=="consumable":
		var prop:Node3D=game.field_consumables.make_prop(str(card.item));prop.set_meta("kind",str(card.item));prop.set_meta("taken",false)
		game.field_consumables.add_child(prop);prop.global_position=drop_point();game.field_consumables.pickups.append(prop);game.weapon_inventory._settle_pickup_id.call_deferred(prop.get_instance_id())
	else:return false
	changed.emit();return true
func _drop_reserve(family:String)->bool:
	if game.get("network_bridge")!=null and game.network_bridge.live():return game.network_bridge.gateway("drop_reserve",{"family":family,"position":drop_point()})
	var available:int=game.field_builder.charges if family=="builds" else int(game.weapon.reserves.get(family,0))
	var amount:=mini(available,int(Supply.AMOUNTS.get(family,0)))
	if amount<=0:return false
	var box:Node3D=game.ammo_pickups.spawn_box(family,drop_point(),amount)
	if box==null:return false
	if family=="builds":game.field_builder.charges-=amount
	else:game.weapon.consume_reserve(family,amount)
	changed.emit();return true
