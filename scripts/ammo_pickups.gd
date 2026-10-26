extends Node3D
var network_bridge:Node
## Explicit grip pickups share weapon reach/occlusion/hand arbitration. No proximity collection.
signal collected(family:String,amount:int)
const Supply=preload("res://scripts/supply_catalog_088.gd")
var boxes:Array[Node3D]=[]
var families:=["rifle","pistol","shells","smg","sniper","builds"]
var _actor:Node3D
var _rack:Node
var _builder:Node
var _next_id:=0
var aim_rings:Dictionary={}
var _audio:AudioStreamPlayer3D
func setup(actor:Node3D,rack:Node,positions:Array)->void:
	_actor=actor;_rack=rack
	for old in boxes:old.queue_free()
	boxes.clear()
	for i in families.size():
		var point:Vector3=positions[i] if i<positions.size() and positions[i] is Vector3 else (positions[0]+Vector3(i*.55,0,0) if not positions.is_empty() else Vector3(i*.55,.3,-2))
		spawn_box(families[i],point)
	_audio=AudioStreamPlayer3D.new();_audio.bus="SFX";_audio.volume_db=-14;_audio.max_distance=8;add_child(_audio)
func spawn_box(family:String,point:Vector3,amount:int=-1)->Node3D:
	if not Supply.AMOUNTS.has(family):return null
	var box:Node3D=Supply.model(family)
	box.set_meta("family",family);box.set_meta("amount",int(Supply.AMOUNTS[family]) if amount<0 else amount);box.set_meta("collected",false)
	box.set_meta("supply_event","pickup089:%d"%_next_id);_next_id+=1
	add_child(box);box.global_position=point;boxes.append(box)
	if is_instance_valid(_rack) and is_instance_valid(_rack.inventory):_rack.inventory._settle_pickup_id.call_deferred(box.get_instance_id())
	return box
func reset_pickups()->void:
	for box in boxes:box.set_meta("collected",false);box.show()
func collect_box(box:Node3D)->int:
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:
		network_bridge.gateway("ammo_pickup",box);return 1
	if not is_instance_valid(box) or box.get_meta("collected",false):return 0
	var family:=str(box.get_meta("family"));var amount:=int(box.get_meta("amount",0));var accepted:=0
	if family=="builds":
		if is_instance_valid(_builder):accepted=int(_builder.award_supply(str(box.get_meta("supply_event")),amount))
	elif is_instance_valid(_rack):accepted=int(_rack.add_reserve(family,amount))
	if accepted<=0:return 0
	box.set_meta("collected",true);box.hide()
	if is_instance_valid(_audio):_audio.global_position=box.global_position;_audio.stream=AshAudioBank.sample("build_pickup" if family=="builds" else "ammo_pickup");_audio.play()
	collected.emit(family,accepted);return accepted
func get_grip_targets()->Array:
	var result:Array=[]
	if not is_instance_valid(_rack) or not is_instance_valid(_rack.inventory) or not _actor.input_enabled or _actor.inventory_open:return result
	for hand in [_actor.left_hand,_actor.right_hand]:
		if not _rack.inventory._hand_eligible(hand):continue
		for i in boxes.size():
			var box:=boxes[i]
			if box.get_meta("collected",false) or not box.is_visible_in_tree():continue
			var offset:Vector3=box.global_position-hand.global_position;var distance:float=offset.length()
			if distance>_rack.inventory.AIM_REACH:continue
			var forward:Vector3=-preload("res://scripts/weapon.gd").corrected_grip_transform(hand.global_transform).basis.z.normalized()
			if distance>.35 and forward.dot(offset.normalized())<=_rack.inventory.AIM_DOT:continue
			if not _rack.inventory._line_clear(_actor.get_view_camera().global_position,hand.global_position) or not _rack.inventory._line_clear(hand.global_position,box.global_position):continue
			result.append({"id":"supply:%d"%i,"position":box.global_position,"hand":hand,"reach":_rack.inventory.AIM_REACH})
	return result
func is_valid_target(id:String,hand:Node3D)->bool:
	for target in get_grip_targets():
		if target.id==id and target.hand==hand:return true
	return false
func handle_grip(id:String,hand:Node3D)->bool:
	if not is_valid_target(id,hand):return false
	var index:=int(id.trim_prefix("supply:"))
	return index>=0 and index<boxes.size() and collect_box(boxes[index])>0
func _process(_delta:float)->void:
	if not is_instance_valid(_rack) or not is_instance_valid(_rack.inventory):return
	for hand in [_actor.left_hand,_actor.right_hand]:
		if not aim_rings.has(hand):
			var ring:Node3D=_rack.inventory._create_aim_ring(hand);ring.reparent(self);aim_rings[hand]=ring
		aim_rings[hand].hide()
	var targets:=get_grip_targets()
	for hand in aim_rings:
		var best:Dictionary={};var distance:=INF
		for target in targets:
			if target.hand!=hand:continue
			var d:float=hand.global_position.distance_to(target.position)
			if d<distance:best=target;distance=d
		if best.is_empty():continue
		var index:=int(str(best.id).trim_prefix("supply:"));var ring:Node3D=aim_rings[hand]
		ring.global_position=best.position;ring.global_basis=preload("res://scripts/upright_ui.gd").view_basis(_actor.get_view_camera().global_basis)
		ring.get_node("TargetName").text=Supply.TITLES[str(boxes[index].get_meta("family"))];ring.show()
