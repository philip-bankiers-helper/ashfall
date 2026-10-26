extends Node3D
var network_bridge:Node
## Ownership refers to persistent rack instances. Moving a gun never creates ammo.
signal changed
const SLOT_LIMIT := 6
const HOVER_HEIGHT:=0.75-.3048 #0992 lower world loot by one physical foot
const AIM_REACH:=2.0
const AIM_DOT:=0.94
const WeaponPose=preload("res://scripts/weapon.gd")
var aim_rings:Dictionary={}
const INITIAL_OWNED := [0, 2, 9]
var player: Node3D
var rack: Node3D
var owned: Array[int] = []
var capacity:int=3:
	set(value):capacity=clampi(value,3,SLOT_LIMIT)
var pickups: Dictionary = {}
var review_owned_props:Dictionary={}
var review_positions:Dictionary={}
var expended:Dictionary={}
var _slot_groups:Array=[]

func setup(actor: Node3D, weapon_rack: Node3D) -> void:
	player = actor
	rack = weapon_rack
	rack.wheel.inventory_provider=self
	owned.assign(INITIAL_OWNED)
	for property in rack.get_property_list():
		if property.name == "inventory": rack.set("inventory", self)
	relocate_pickups(actor.global_position)
	_sync_selection()

func has_weapon(index: int) -> bool:
	return owned.has(index)

func owned_indices() -> Array[int]:
	var ordered:Array[int]=owned.duplicate()
	ordered.sort_custom(func(a:int,b:int)->bool:
		var ca:=category_rank(rack.catalog_index(a));var cb:=category_rank(rack.catalog_index(b))
		return catalog_before(a,b) if ca==cb else ca<cb)
	return ordered

static func category_rank(index:int)->int:
	if index in [14,15,16,29]:return 0 # swords/knife
	if index in [1,4,9,12]:return 1 # shotguns
	if index in [2,7,19,20]:return 2 # pistols
	if index in [6,10,11,17,18]:return 3 # SMGs
	if index in [0,3,8,21,23,24]:return 4 # automatic/battle rifles and machine guns
	if index in [5,13,25]:return 5 # snipers
	return 6 # grenades/launcher

func pickup_weapon(index: int) -> bool:
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:return network_bridge.gateway("weapon_pickup",index)
	if not _valid_index(index) or has_weapon(index) or (total_slots() >= capacity and not has_stack_room("weapon_%d"%index)): return false
	# Only a represented ground instance can enter the carried inventory.
	if not pickups.has(index): return false
	owned.append(index)
	var prop: Node3D = pickups[index]
	pickups.erase(index)
	prop.queue_free()
	_sync_selection()
	changed.emit()
	return true

func drop_weapon(index: int) -> bool:
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:return network_bridge.gateway("drop_weapon",index)
	if not has_weapon(index): return false
	# During a reload a magazine/shell may be held. Finish or cancel it before drop.
	if not _transfer_safe(index):return false
	var prop := _create_prop(index)
	if not _place_reachable_drop(prop):
		prop.free()
		return false
	# Commit ownership only after real floor, bounds and retrieval checks succeed.
	owned.erase(index)
	pickups[index] = prop
	_sync_selection()
	changed.emit()
	return true

func relocate_pickups(origin: Vector3) -> void:
	for prop in pickups.values():prop.queue_free()
	for prop in review_owned_props.values():prop.queue_free()
	pickups.clear();review_owned_props.clear();review_positions.clear()
	var offset:=0
	for index in range(30):
		if not _catalog_active(index):continue
		if expended.has(index) and rack.weapons[index].ammo>0:expended.erase(index)
		if expended.has(index):continue
		# Eight columns give long barrels their own aisle. The old62cm row gap
		# let adjacent rows overlap and obscured the Katana's pickup target.
		var point:=origin+Vector3(-4.3+(offset%8)*1.4,.3,.60-floori(float(offset)/8.0)*1.40) #086 uniform fit:60cm right/25cm inward clears generator and deck edge; rows stay1.4m apart
		review_positions[index]=point
		if not has_weapon(index):_spawn_pickup(index,point)
		else:_spawn_pickup(rack.create_instance(rack.catalog_index(index)),point)
		offset+=1
	# Ground copies are independent persistent instances.

func _refresh_review_copies()->void:
	for index in review_owned_props.keys():
		if not has_weapon(index) or not review_positions.has(index):
			review_owned_props[index].queue_free();review_owned_props.erase(index)
	for index in owned:
		if not review_positions.has(index) or review_owned_props.has(index):continue
		var prop:=_create_prop(index);prop.name="ReviewOwnedWeapon"+str(index);prop.set_meta("review_only",true)
		prop.global_position=review_positions[index];review_owned_props[index]=prop
		_settle_pickup_id.call_deferred(prop.get_instance_id())

func consume_disposable(index:int)->void:
	if not has_weapon(index) or rack.weapons[index].ammo>0:return
	var remaining:Array=stack_members("weapon_%d"%index)
	remaining.erase("weapon_%d"%index)
	owned.erase(index);expended[index]=true
	if rack.selected==index and not remaining.is_empty():rack.selected=int(str(remaining[0]).trim_prefix("weapon_"))
	if review_owned_props.has(index):review_owned_props[index].queue_free();review_owned_props.erase(index)
	_sync_selection();changed.emit()

func _process(_delta:float)->void:
	update_aim_rings()

func _pickup_center(index:int)->Vector3:
	var prop:Node3D=pickups[index]
	if not prop.has_meta("pickup_local_center"):
		var bounds:=_world_mesh_bounds(prop)
		prop.set_meta("pickup_local_center",prop.to_local(bounds.get_center()) if bounds.size!=Vector3.ZERO else Vector3.ZERO)
	return prop.to_global(prop.get_meta("pickup_local_center"))

func _hand_eligible(hand:Node3D)->bool:
	if not _can_interact() or not is_instance_valid(hand):return false
	if hand!=player.left_hand and hand!=player.right_hand:return false
	if not player.is_hand_input_ready(hand) or player._grabs.has(hand):return false
	var support_hand:Node3D=player.get_support_hand() if player.has_method("get_support_hand") else player.left_hand
	# A gun waiting for ammo/bolt input does not own the free offhand everywhere.
	# Only real reload contact/proximity blocks that hand; held parts are already
	# rejected by _transfer_safe. This matches wall-grab ownership arbitration.
	if hand==support_hand and rack.weapons[rack.selected].has_method("reload_claims_hand") and rack.weapons[rack.selected].reload_claims_hand(hand):return false
	return true

func _line_clear(start:Vector3,finish:Vector3)->bool:
	if start.distance_squared_to(finish)<0.000001:return true
	var excluded:Array[RID]=[]
	if player is CollisionObject3D:excluded.append(player.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(start,finish,1|8,excluded)
	query.hit_from_inside=true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func get_aimed_pickup(hand:Node3D)->int:
	if not _hand_eligible(hand):return -1
	var head:Vector3=player.get_view_camera().global_position
	if not _line_clear(head,hand.global_position):return -1
	var forward:Vector3=-WeaponPose.corrected_grip_transform(hand.global_transform).basis.z.normalized()
	var best:=-1
	var best_score:=-INF
	for index in pickups:
		var prop:Node3D=pickups[index]
		if not is_instance_valid(prop) or prop.is_queued_for_deletion() or not prop.is_visible_in_tree():continue
		var point:=_pickup_center(index)
		var offset:=point-hand.global_position
		var distance:=offset.length()
		if distance>AIM_REACH:continue
		var alignment:=forward.dot(offset/distance) if distance>0.0001 else 1.0
		if distance>.35 and alignment<=AIM_DOT:continue
		if not _line_clear(hand.global_position,point):continue
		var score:=2.0+(.35-distance) if distance<=.35 else alignment-distance*.025
		if score>best_score or (is_equal_approx(score,best_score) and int(index)<best):
			best=int(index)
			best_score=score
	return best

func get_grip_targets()->Array:
	var result:Array=[]
	if not _can_interact():return result
	for hand in [player.left_hand,player.right_hand]:
		var index:=get_aimed_pickup(hand)
		if index>=0:result.append({"id":"inventory_pickup:"+str(index),"position":_pickup_center(index),"hand":hand,"reach":AIM_REACH,"eligible":true})
	return result

func handle_grip(target_id:String,hand:Node3D)->bool:
	if not target_id.begins_with("inventory_pickup:") or not _hand_eligible(hand):return false
	var suffix:=target_id.trim_prefix("inventory_pickup:")
	if not suffix.is_valid_int():return false
	var index:=int(suffix)
	if index!=get_aimed_pickup(hand):return false
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:return network_bridge.gateway("weapon_pickup",index)
	var swapped:=-1
	if not make_room("weapon_%d"%index):return false
	if false:
		swapped=int(rack.selected)
		if not has_weapon(swapped) or not drop_weapon(swapped):return false
	if not pickup_weapon(index):
		# A synchronous signal consumer may invalidate a target; preserve the carried instance.
		if swapped>=0 and pickups.has(swapped):
			var dropped:Node3D=pickups[swapped]
			pickups.erase(swapped)
			dropped.queue_free()
			owned.append(swapped)
			rack.selected=swapped
			_sync_selection()
			changed.emit()
		return false
	rack._clear_consumable_selection()
	rack.selected=index
	rack.is_holstered=false
	_sync_selection()
	changed.emit()
	return true

func _can_interact()->bool:
	if is_instance_valid(player) and player.get_meta("tactical_map1000",false):return false
	return is_instance_valid(player) and is_instance_valid(rack) and player.input_enabled and player.get("inventory_open")!=true and not player.mantling and not player.head_obstructed and not rack.is_selecting and _transfer_safe(rack.selected)

func update_aim_rings()->void:
	if not is_instance_valid(player):return
	for hand in [player.left_hand,player.right_hand]:
		if not is_instance_valid(hand):continue
		if not aim_rings.has(hand):aim_rings[hand]=_create_aim_ring(hand)
		var ring:Node3D=aim_rings[hand]
		var index:=get_aimed_pickup(hand)
		ring.visible=index>=0
		ring.set_meta("pickup_index",index)
		if index<0:continue
		ring.global_position=_pickup_center(index)
		ring.global_basis=preload("res://scripts/upright_ui.gd").view_basis(player.get_view_camera().global_basis)
		ring.get_node("TargetName").text=rack.get_weapon_label(index)

func _create_aim_ring(hand:Node3D)->Node3D:
	var ring:=Node3D.new()
	ring.name="PickupAimRingLeft" if hand==player.left_hand else "PickupAimRingRight"
	add_child(ring)
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(0.25,0.85,1.0) if hand==player.left_hand else Color(1.0,0.8,0.2)
	material.no_depth_test=false
	for i in range(24):
		var segment:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(.041,.007,.007)
		segment.mesh=mesh
		segment.material_override=material
		segment.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle:=TAU*float(i)/24.0
		segment.position=Vector3(cos(angle)*.17,sin(angle)*.17,0)
		segment.rotation.z=angle+PI*.5
		ring.add_child(segment)
	var label:=Label3D.new();label.name="TargetName";label.position.y=.24;label.font_size=30;label.pixel_size=.0015;ring.add_child(label)
	ring.hide()
	return ring
func _valid_index(index: int) -> bool:
	return is_instance_valid(rack) and _catalog_active(index) and index >= 0 and index < rack.weapons.size()

func _catalog_active(index:int)->bool:
	return rack.is_catalog_active(index) if rack.has_method("is_catalog_active") else true

func _sync_selection() -> void:
	# Ground instances already represent every catalog item.
	if not has_weapon(rack.selected):
		if not owned.is_empty(): rack.selected = owned[0]
		else: rack.is_holstered = true
	if rack.has_method("_apply_selection"): rack._apply_selection()
	if rack.wheel and rack.wheel.has_method("set_owned_indices"): rack.wheel.set_owned_indices(owned_indices())

func _spawn_pickup(index: int, point: Vector3) -> void:
	if pickups.has(index): return
	var prop := _create_prop(index)
	prop.global_position = point
	pickups[index] = prop
	_settle_pickup_id.call_deferred(prop.get_instance_id())

func _create_prop(index: int) -> Node3D:
	var prop := Node3D.new()
	prop.name = "GroundWeapon" + str(index)
	prop.set_meta("catalog_index",rack.catalog_index(index))
	add_child(prop)
	var copy: Node3D = rack.weapons[index].model.duplicate(0)
	copy.transform = Transform3D(Basis.IDENTITY.scaled(rack.weapons[index].model.scale),Vector3.ZERO) #085 preserve final held size on ground
	copy.visible = true
	preload("res://scripts/ground_art0992.gd").prepare(rack.weapons[index],copy)
	_strip(copy)
	prop.add_child(copy)
	# Ordinary upright orientation: +Y is up and muzzle/local-Z faces forward.
	# Swords are acquired at their hilt, not halfway up a2m blade.
	if rack.weapons[index].has_method("sample_motion"):
		prop.set_meta("pickup_local_center",rack.weapons[index].hand_grip_center)
	return prop

func _place_reachable_drop(prop: Node3D) -> bool:
	var camera: Camera3D = player.get_view_camera()
	var head := camera.global_position
	var forward := -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < .001: forward = Vector3.FORWARD
	forward = forward.normalized()
	var excluded: Array[RID] = []
	if player is CollisionObject3D: excluded.append(player.get_rid())
	var space := get_world_3d().direct_space_state
	# Prefer1m in front of the tracked head. Heading comes from the user, not
	# world/grid axes. Nearby forward alternatives handle walls and ledges.
	var angles:=[0.0,.25,-.25,.50,-.50,.80,-.80,0.0]
	for i in range(8):
		var direction := forward.rotated(Vector3.UP,angles[i])
		var radius := .85 if i==7 else 1.0
		var origin := head + direction * radius
		var floor_query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * 20.0, 1, excluded)
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty() or floor_hit.normal.y < .65: continue
		prop.global_basis=Basis.looking_at(forward,Vector3.UP)
		prop.global_position = floor_hit.position
		prop.global_position.y += HOVER_HEIGHT - (_lowest_mesh_point(prop) - prop.global_position.y)
		if head.distance_to(prop.global_position) > 2.2: continue
		var los := PhysicsRayQueryParameters3D.create(head, prop.global_position, 1, excluded)
		los.hit_from_inside = true
		if not space.intersect_ray(los).is_empty(): continue
		var bounds := _world_mesh_bounds(prop)
		if bounds.size == Vector3.ZERO: continue
		var shape := BoxShape3D.new(); shape.size = bounds.size
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape; query.transform.origin = bounds.get_center()
		query.collision_mask = 1; query.exclude = excluded; query.margin = .001
		# Do not exclude the floor RID: it may also contain walls or other geometry.
		if not space.intersect_shape(query, 1).is_empty(): continue
		return true
	return false

func _world_mesh_bounds(node: Node) -> AABB:
	var points: Array[Vector3] = []
	_collect_mesh_points(node, points)
	if points.is_empty(): return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point in points: result = result.expand(point)
	return result

func _collect_mesh_points(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.visible and node.mesh != null:
		var bounds: AABB = node.get_aabb()
		for x in [0, 1]:
			for y in [0, 1]:
				for z in [0, 1]: points.append(node.to_global(bounds.position + bounds.size * Vector3(x,y,z)))
	for child in node.get_children():
		if child is Node3D and not child.visible: continue
		_collect_mesh_points(child, points)

func _settle_pickup_id(instance_id: int) -> void:
	# A checkpoint can free this prop before the deferred method is dispatched.
	# IDs are safe deferred arguments; resolve only after the physics boundary.
	await get_tree().physics_frame
	if not is_instance_id_valid(instance_id): return
	var prop = instance_from_id(instance_id)
	if prop is Node3D: _settle_on_surface(prop)

func _settle_pickup(prop: Node3D) -> void:
	# Physics servers must have received newly loaded checkpoint floors first.
	var instance_id := prop.get_instance_id()
	await get_tree().physics_frame
	if not is_instance_id_valid(instance_id): return
	var current = instance_from_id(instance_id)
	if current is Node3D: _settle_on_surface(current)

func _settle_on_surface(prop: Node3D) -> void:
	if not prop.is_inside_tree() or prop.is_queued_for_deletion(): return
	var excluded: Array[RID] = []
	if player is CollisionObject3D: excluded.append(player.get_rid())
	var origin := prop.global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * 20.0, 1, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# No floor within the bounded cast: preserve the original placement.
	if hit.is_empty(): return
	var lowest := _lowest_mesh_point(prop)
	if is_finite(lowest): prop.global_position.y += float(hit.position.y) + HOVER_HEIGHT - lowest

func _lowest_mesh_point(node: Node) -> float:
	var lowest := INF
	if node is MeshInstance3D and node.visible and node.mesh != null:
		var bounds: AABB = node.get_aabb()
		for x in [0, 1]:
			for y in [0, 1]:
				for z in [0, 1]:
					var corner := bounds.position + bounds.size * Vector3(x, y, z)
					lowest = minf(lowest, node.to_global(corner).y)
	for child in node.get_children():
		if child is Node3D and not child.visible: continue
		lowest = minf(lowest, _lowest_mesh_point(child))
	return lowest

func _strip(node: Node) -> void:
	node.set_script(null)
	if node is Node3D and node.name=="RearOcularGlass":node.show()
	node.set_process(false)
	node.set_physics_process(false)
	# Live optics reserve visual layers to prevent their view feeding itself.
	# Inert ground copies must be ordinary visible world geometry.
	if node is VisualInstance3D: node.layers = 1
	for child in node.get_children():
		if child is Label3D or child is AudioStreamPlayer3D or child is CollisionObject3D or child is SubViewport or child is Camera3D or child.name in ["AmmoReadoutPanel","DynamicScopeLens","DynamicReflexReticle","DirectionalBulletShield","SwordSupportGripCue"]:
			node.remove_child(child)
			child.free()
		else: _strip(child)







func _idle_sniper_cycle()->bool:
	if rack.weapons.is_empty():return false
	var active:Node3D=rack.weapons[rack.selected]
	return active.reload_state=="needs_bolt" and active.get("_bolt_contact")==false
func _transfer_safe(index:int)->bool:
	if index<0 or index>=rack.weapons.size():return false
	var active:Node3D=rack.weapons[index]
	return not active.reload_grip_in_progress()

func _raw_actions()->Array[String]:
	var result:Array[String]=[]
	for id in owned_indices():result.append("weapon_%d"%id)
	if is_instance_valid(rack.consumable_provider):
		for id in rack.consumable_provider.items:result.append("consumable:"+str(id))
	return result
func stack_key(action:String)->String:
	if action.begins_with("weapon_"):
		return "frag" if rack.catalog_index(int(action.trim_prefix("weapon_")))==26 else ""
	var kind:=""
	if action.begins_with("kind:"):kind=action.trim_prefix("kind:")
	elif action.begins_with("consumable:") and is_instance_valid(rack.consumable_provider):
		var id:=action.trim_prefix("consumable:")
		if rack.consumable_provider.items.has(id):kind=str(rack.consumable_provider.items[id].kind)
	return kind if kind in ["shaker","soda"] else ""
func _sync_slot_groups()->void:
	var raw:=_raw_actions();var seen:Dictionary={};var kept:Array=[]
	for group in _slot_groups:
		var live:Array=[]
		for action in group:
			if raw.has(action) and not seen.has(action):live.append(action);seen[action]=true
		if not live.is_empty():kept.append(live)
	_slot_groups=kept
	for action in raw:
		if seen.has(action):continue
		var key:=stack_key(action);var added:=false
		if not key.is_empty():
			for group in _slot_groups:
				if group.size()<2 and stack_key(str(group[0]))==key:group.append(action);added=true;break
		if not added:_slot_groups.append([action])
		seen[action]=true
	# Retain original category order and instance order; grouping does not alter ownership.
	_slot_groups.sort_custom(func(a:Array,b:Array)->bool:return raw.find(a[0])<raw.find(b[0]))
func stack_members(action:String)->Array:
	_sync_slot_groups()
	for group in _slot_groups:
		if group.has(action):return group.duplicate()
	return []
func stack_count(action:String)->int:return stack_members(action).size()
func has_stack_room(incoming:String)->bool:
	_sync_slot_groups();var key:=stack_key(incoming)
	if key.is_empty():return false
	for group in _slot_groups:
		if group.size()<2 and stack_key(str(group[0]))==key:return true
	return false
func total_slots()->int:
	_sync_slot_groups();return _slot_groups.size()
func selected_action()->String:
	if is_instance_valid(rack.consumable_provider) and not rack.consumable_provider.selected_instance.is_empty():return "consumable:"+rack.consumable_provider.selected_instance
	return "weapon_%d"%rack.selected
func make_room(incoming:String="")->bool:
	if has_stack_room(incoming) or total_slots()<capacity:return true
	return drop_slot(selected_action())
func drop_slot(action:String)->bool:
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:return network_bridge.gateway("drop_slot",action)
	# Full replacement drops the entire selected slot. Stage every placement first:
	# failure cannot remove half a stack, lose an instance, or exceed capacity.
	var members:=stack_members(action)
	if members.is_empty():return false
	var staged:Array=[];var supply:Node=rack.consumable_provider
	for member in members:
		var prop:Node3D
		if str(member).begins_with("weapon_"):
			var id:=int(str(member).trim_prefix("weapon_"))
			if not _transfer_safe(id):
				for prior in staged:prior.prop.free()
				return false
			prop=_create_prop(id)
		else:
			var id:=str(member).trim_prefix("consumable:")
			prop=supply.make_prop(str(supply.items[id].kind));supply.add_child(prop)
		if not _place_reachable_drop(prop):
			prop.free()
			for prior in staged:prior.prop.free()
			return false
		staged.append({"action":str(member),"prop":prop})
	for entry in staged:
		if entry.action.begins_with("weapon_"):
			var id:=int(str(entry.action).trim_prefix("weapon_"));owned.erase(id);pickups[id]=entry.prop
		else:
			var id:=str(entry.action).trim_prefix("consumable:");var kind:String=supply.items[id].kind
			if supply.selected_instance==id:supply.stow();supply.selected_kind="";supply.selected_instance=""
			entry.prop.set_meta("kind",kind);entry.prop.set_meta("taken",false);entry.prop.set_meta("item_id",id)
			supply.pickups.append(entry.prop);supply.items.erase(id);supply.stock[kind]-=1
	_sync_selection();changed.emit()
	if is_instance_valid(supply):supply._refresh_pouch();supply.changed.emit()
	return true
func slot_actions()->Array[String]:
	_sync_slot_groups();var result:Array[String]=[];var selected:=selected_action()
	for group in _slot_groups:result.append(str(selected if group.has(selected) else group[0]))
	return result
func action_label(action:String)->String:
	if action.begins_with("weapon_"):return rack.get_weapon_label(int(action.trim_prefix("weapon_")))+_count_suffix(action)
	if action.begins_with("consumable:"):
		var id:=action.trim_prefix("consumable:");return rack.consumable_provider.TITLES[rack.consumable_provider.items[id].kind]
	return "EMPTY"
func action_icon(action:String)->Texture2D:
	if action.begins_with("weapon_"):return preload("res://scripts/weapon_icons_094.gd").icon(rack.catalog_index(int(action.trim_prefix("weapon_"))))
	if action.begins_with("consumable:"):return load("res://assets/ui/item_%s.svg"%rack.consumable_provider.items[action.trim_prefix("consumable:")].kind)
	return null
func select_action(action:String)->bool:
	if action.begins_with("weapon_"):return rack.select_inventory_weapon(int(action.trim_prefix("weapon_")))
	if action.begins_with("consumable:" ):return rack.consumable_provider.equip_instance(action.trim_prefix("consumable:"))
	return false
func drop_action(action:String)->bool:
	if action.begins_with("weapon_" ):return drop_weapon(int(action.trim_prefix("weapon_")))
	if action.begins_with("consumable:" ):return rack.consumable_provider.drop_instance(action.trim_prefix("consumable:"))
	return false

func _count_suffix(action:String)->String:
	return " x%d"%stack_count(action) if not stack_key(action).is_empty() else ""

func catalog_before(a:int,b:int)->bool:
	var ca:=category_rank(rack.catalog_index(a));var cb:=category_rank(rack.catalog_index(b))
	if ca!=cb:return ca<cb
	var da:float=rack.weapons[a].damage;var db:float=rack.weapons[b].damage
	return rack.catalog_index(a)<rack.catalog_index(b) if is_equal_approx(da,db) else da>db
