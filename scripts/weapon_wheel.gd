extends Node3D
## Six carried-item sectors plus two utilities; never additional inventory capacity.
const BASE_ACTIONS := ["empty","empty","empty","revive","backpack","empty","empty","empty"]
const SLOT_CLOCK_HOURS := [12.0,1.5,3.0,4.5,6.0,7.5,9.0,10.5] # equal clockwise eighths from top
const ITEM_SLOTS := [2,1,0,7,6,5] # sorted ordinary arc: right, upper-right, top, upper-left, left, lower-left
var consumable_provider:Node
var inventory_provider:Node
var SLOT_ACTIONS := BASE_ACTIONS.duplicate()
const OUTER_RADIUS := 0.34
const INNER_RADIUS := OUTER_RADIUS * 0.30
const DISPLAY_SCALE := 1.2
var highlighted := -1
var point_valid := false
var _player_anchor:=Vector3.ZERO
var pointer: MeshInstance3D
var status_label: Label3D
var _materials: Array[StandardMaterial3D] = []
var _weapons: Array = []
var _drop_ring: MeshInstance3D
var _drop_mesh: ImmediateMesh
var _drop_material: StandardMaterial3D

func set_owned_indices(indices:Array) -> void:
	SLOT_ACTIONS=BASE_ACTIONS.duplicate()
	var actions:Array=[]
	var inventory:Node=inventory_provider
	if is_instance_valid(inventory):actions=inventory.slot_actions()
	else:
		for index in indices:actions.append("weapon_%d"%int(index))
	for i in ITEM_SLOTS.size():
		SLOT_ACTIONS[ITEM_SLOTS[i]]=actions[i] if i<actions.size() else ("locked" if is_instance_valid(inventory) and i>=inventory.capacity else "empty")
	set_weapon_icons(_weapons)
	_set_highlight(highlighted)

func set_drop_progress(slot:int, fraction:float) -> void:
	if _drop_ring==null:
		_drop_ring=MeshInstance3D.new()
		_drop_ring.name="DropProgressRing"
		_drop_mesh=ImmediateMesh.new()
		_drop_ring.mesh=_drop_mesh
		_drop_material=_ui_material(Color("ffbd58"),126)
		_drop_ring.material_override=_drop_material
		_drop_ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_drop_ring)
	_drop_ring.visible=slot>=0 and slot<SLOT_ACTIONS.size() and fraction>0
	_drop_mesh.clear_surfaces()
	if not _drop_ring.visible:return
	_drop_ring.position=slot_position(slot,.215)+Vector3(0,0,.029)
	_drop_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=maxi(1,ceili(clampf(fraction,0,1)*32))
	for step in range(count):
		var a:=PI/2-float(step)*TAU/32
		var b:=PI/2-minf(float(step+1)/32,clampf(fraction,0,1))*TAU
		var points:=[Vector3(cos(a),sin(a),0)*.067,Vector3(cos(a),sin(a),0)*.074,Vector3(cos(b),sin(b),0)*.074,Vector3(cos(b),sin(b),0)*.067]
		for i in [0,1,2,0,2,3]:_drop_mesh.surface_add_vertex(points[i])
	_drop_mesh.surface_end()

func _ready() -> void:
	for slot in range(SLOT_ACTIONS.size()):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in range(8):
			var bounds := slot_bounds(slot)
			var start := lerpf(bounds.x,bounds.y,float(step)/8.0)
			var finish := lerpf(bounds.x,bounds.y,float(step+1)/8.0)
			var points := [Vector3(cos(start), sin(start), 0) * INNER_RADIUS, Vector3(cos(start), sin(start), 0) * OUTER_RADIUS, Vector3(cos(finish), sin(finish), 0) * OUTER_RADIUS, Vector3(cos(finish), sin(finish), 0) * INNER_RADIUS]
			for index in [0, 1, 2, 0, 2, 3]: surface.add_vertex(points[index])
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		mat.render_priority = 120
		_materials.append(mat)
		surface.set_material(mat)
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		add_child(mesh)
	_build_slot_graphics()
	_build_pointer()
	status_label=Label3D.new();status_label.name="PointedWeaponName";status_label.position=Vector3(0,.39,.02);status_label.font_size=30;status_label.pixel_size=.001;status_label.no_depth_test=true;status_label.billboard=BaseMaterial3D.BILLBOARD_DISABLED;add_child(status_label)
	_set_highlight(-1)
	hide()

func slot_angle(slot:int)->float:
	return PI/2.0-float(slot)*TAU/8.0

func slot_bounds(slot:int)->Vector2:
	var center:=slot_angle(slot)
	var previous:=slot_angle((slot+7)%8)
	var next:=slot_angle((slot+1)%8)
	while previous<=center:previous+=TAU
	while next>=center:next-=TAU
	return Vector2((previous+center)*.5,(center+next)*.5)

func slot_position(slot: int, radius: float) -> Vector3:
	var angle := slot_angle(slot)
	return Vector3(cos(angle) * radius, sin(angle) * radius, 0)

func _ui_material(color: Color, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = priority
	mat.albedo_color = color
	return mat

func _flat_bar(name: String, center: Vector3, size: Vector2, mat: StandardMaterial3D, angle: float = 0.0) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	bar.name = name
	var shape := BoxMesh.new()
	shape.size = Vector3(size.x, size.y, 0.002)
	bar.mesh = shape
	bar.position = center
	bar.rotation.z = angle
	bar.material_override = mat
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	return bar

func _build_slot_graphics() -> void:
	var separator := _ui_material(Color("91a6b3"), 121)
	for slot in range(SLOT_ACTIONS.size()):
		var angle := slot_bounds(slot).x
		var middle := (INNER_RADIUS + OUTER_RADIUS) * 0.5
		_flat_bar("WheelDivider%d" % slot, Vector3(cos(angle) * middle, sin(angle) * middle, 0.009), Vector2(0.006, OUTER_RADIUS - INNER_RADIUS), separator, angle - PI / 2.0)
	var center_mat := _ui_material(Color("82aec7"), 122)
	var disc := SurfaceTool.new()
	disc.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(32):
		var a := float(step) * TAU / 32.0
		var b := float(step + 1) * TAU / 32.0
		disc.add_vertex(Vector3(0, 0, 0.011))
		disc.add_vertex(Vector3(cos(a) * INNER_RADIUS, sin(a) * INNER_RADIUS, 0.011))
		disc.add_vertex(Vector3(cos(b) * INNER_RADIUS, sin(b) * INNER_RADIUS, 0.011))
	disc.set_material(center_mat)
	var center_mesh := MeshInstance3D.new()
	center_mesh.name = "CancelDisc"
	center_mesh.mesh = disc.commit()
	center_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(center_mesh)
	var mark := _ui_material(Color("173443"), 123)
	_flat_bar("CancelMarkA", Vector3(0, 0, 0.016), Vector2(0.011, 0.074)*1.05, mark, PI / 4.0)
	_flat_bar("CancelMarkB", Vector3(0, 0, 0.016), Vector2(0.011, 0.074)*1.05, mark, -PI / 4.0)
	var unavailable := _ui_material(Color(0.65, 0.70, 0.73, 0.72), 123)
	var revive_slot := SLOT_ACTIONS.find("revive")
	if revive_slot >= 0:
		var revive := slot_position(revive_slot, 0.225) + Vector3(0, 0, 0.018)
		_flat_bar("ReviveCrossVertical", revive, Vector2(0.022, 0.09), unavailable)
		_flat_bar("ReviveCrossHorizontal", revive, Vector2(0.09, 0.022), unavailable)
	var utility := _ui_material(Color("d8e4e9"), 123)
	var bag_slot := SLOT_ACTIONS.find("backpack")
	if bag_slot >= 0:
		var bag := slot_position(bag_slot, 0.225) + Vector3(0, 0, 0.018)
		_flat_bar("BackpackBody", bag, Vector2(0.094, 0.09), utility)
		_flat_bar("BackpackFlap", bag + Vector3(0, 0.034, 0.003), Vector2(0.068, 0.018), _ui_material(Color("678b9c"), 124))
		_flat_bar("BackpackStrapLeft", bag + Vector3(-0.033, 0.060, 0), Vector2(0.014, 0.035), utility)
		_flat_bar("BackpackStrapRight", bag + Vector3(0.033, 0.060, 0), Vector2(0.014, 0.035), utility)

func set_weapon_icons(_weapons: Array) -> void:
	self._weapons=_weapons
	# Flat original silhouettes, with no duplicated weapon scenes.
	for child in get_children():
		if child.name.begins_with("WeaponIcon") or child.name.begins_with("SupplyIcon") or child.name.begins_with("StackCount"):
			remove_child(child)
			child.queue_free()
	for index in range(_weapons.size()):
		var slot := SLOT_ACTIONS.find("weapon_%d" % index)
		if slot < 0: continue
		var icon := Sprite3D.new()
		icon.name = "WeaponIcon%d" % index
		icon.texture = preload("res://scripts/weapon_icons_094.gd").icon(int(_weapons[index].get_meta("catalog_index",index)))
		icon.pixel_size = .18432 / float(icon.texture.get_width())
		icon.position = slot_position(slot, 0.215) + Vector3(0, 0, 0.022)
		icon.no_depth_test = true
		icon.shaded = false
		icon.render_priority = 124
		icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		add_child(icon)

	for slot in SLOT_ACTIONS.size():
		var action:String=SLOT_ACTIONS[slot]
		if is_instance_valid(inventory_provider) and not inventory_provider.stack_key(action).is_empty() and inventory_provider.stack_count(action)>0:
			var count:=Label3D.new();count.name="StackCount%d"%slot;count.text=str(inventory_provider.stack_count(action));count.font_size=30;count.pixel_size=.001;count.no_depth_test=true;count.position=slot_position(slot,.215)+Vector3(.04,-.04,.025);add_child(count)
		if action=="locked":
			var lock:=Label3D.new();lock.name="SupplyIconLocked%d"%slot;lock.text="X\nLOCKED";lock.font_size=36;lock.pixel_size=.001;lock.no_depth_test=true;lock.position=slot_position(slot,.215);add_child(lock)
		if not action.begins_with("consumable:"):continue
		var id:=action.trim_prefix("consumable:")
		var icon:=Sprite3D.new();icon.name="SupplyIcon"+id
		icon.texture=load("res://assets/ui/item_%s.svg"%consumable_provider.items[id].kind)
		icon.pixel_size=.00072;icon.no_depth_test=true;icon.shaded=false;icon.render_priority=124
		icon.position=slot_position(slot,.215)+Vector3(0,0,.022);add_child(icon)

func follow_player_translation(player_position:Vector3)->void:
	if not visible:return
	global_position+=player_position-_player_anchor
	_player_anchor=player_position

func open_at(view: Transform3D, aim: Transform3D = Transform3D.IDENTITY, player_position:Vector3=Vector3.ZERO) -> void:
	top_level=true
	_player_anchor=player_position
	var facing := preload("res://scripts/upright_ui.gd").view_basis(view.basis)
	# Capture the current weapon ray; preserve view-facing geometry for readability.
	var center := aim.origin - aim.basis.z.normalized() * 0.85 if aim != Transform3D.IDENTITY else view.origin - facing.z * 0.85
	var toward_center := center - view.origin
	if toward_center.length() > 0.01:
		var up := Vector3.UP
		if absf(toward_center.normalized().dot(up)) > 0.95: up = facing.z
		facing = Basis.looking_at(toward_center, up)
	global_transform = Transform3D(facing.scaled(Vector3.ONE * DISPLAY_SCALE), center)
	_set_highlight(-1)
	show()

func point(ray: Transform3D) -> int:
	point_valid = false
	if not ray.origin.is_finite() or not ray.basis.is_finite():
		_set_highlight(-1)
		pointer.hide()
		return -1
	var origin := to_local(ray.origin)
	var direction := global_basis.inverse() * -ray.basis.z
	var slot := -1
	pointer.visible = false
	if absf(direction.z) > 0.0001:
		var distance := -origin.z / direction.z
		if is_finite(distance) and distance > 0:
			var hit := origin + direction * distance
			var radius := Vector2(hit.x, hit.y).length()
			point_valid = hit.is_finite() and is_finite(radius)
			if point_valid:
				var display_hit := Vector2(hit.x,hit.y).limit_length(OUTER_RADIUS)
				pointer.position = Vector3(display_hit.x,display_hit.y,0.012)
				pointer.visible = true
			if point_valid and radius >= INNER_RADIUS:
				var nearest:=INF
				for candidate in SLOT_CLOCK_HOURS.size():
					var difference:=absf(wrapf(atan2(hit.y,hit.x)-slot_angle(candidate),-PI,PI))
					if difference<nearest:nearest=difference;slot=candidate
	_set_highlight(slot)
	return weapon_index_at_slot(SLOT_ACTIONS, slot)

static func weapon_index_at_slot(actions: Array, slot: int) -> int:
	if slot < 0 or slot >= actions.size(): return -1
	var action := str(actions[slot])
	if not action.begins_with("weapon_"): return -1
	var number := action.trim_prefix("weapon_")
	return int(number) if number.is_valid_int() else -1

func point_action() -> String:
	return SLOT_ACTIONS[highlighted] if highlighted >= 0 else "cancel"

func _set_highlight(index: int) -> void:
	highlighted = index
	if status_label!=null:
		var weapon_index:=weapon_index_at_slot(SLOT_ACTIONS,index)
		var names:Array=get_meta("weapon_names",[])
		status_label.text=names[weapon_index] if weapon_index>=0 and weapon_index<names.size() else (consumable_provider.TITLES[consumable_provider.items[str(SLOT_ACTIONS[index]).trim_prefix("consumable:")].kind] if index>=0 and str(SLOT_ACTIONS[index]).begins_with("consumable:") else "")
	if status_label!=null and is_instance_valid(inventory_provider) and index>=0 and (str(SLOT_ACTIONS[index]).begins_with("weapon_") or str(SLOT_ACTIONS[index]).begins_with("consumable:")):
		status_label.text=inventory_provider.action_label(str(SLOT_ACTIONS[index]))
	for i in range(_materials.size()):
		if i == index and (str(SLOT_ACTIONS[i]).begins_with("weapon_") or str(SLOT_ACTIONS[i]).begins_with("consumable:") or SLOT_ACTIONS[i] in ["backpack","revive"]):
			_materials[i].albedo_color = Color("b16a20")
		elif SLOT_ACTIONS[i] == "locked":
			_materials[i].albedo_color=Color("747b84")
		elif SLOT_ACTIONS[i] == "empty":
			_materials[i].albedo_color = Color("26323a") if i == index else Color("10232d")
		elif SLOT_ACTIONS[i] == "revive":
			_materials[i].albedo_color = Color("35414a") if i == index else Color("202d37")
		else:
			_materials[i].albedo_color = Color("16313a")

func _build_pointer() -> void:
	pointer = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.009
	dot.height = 0.018
	dot.radial_segments = 8
	dot.rings = 4
	pointer.mesh = dot
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.85, 0.2)
	mat.no_depth_test = true
	mat.render_priority = 125
	pointer.material_override = mat
	pointer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pointer)
	pointer.hide()

func set_status(message: String) -> void:
	if status_label!=null and point_action() in ["backpack","revive","empty","locked"]:
		status_label.text="BACKPACK" if point_action()=="backpack" else ("REVIVE PADDLES" if point_action()=="revive" else message)



