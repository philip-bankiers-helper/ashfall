extends Node3D
var network_bridge:Node
## Original field construction. No multiplayer or reference-game assets.
signal placed(kind: String, remaining: int)
signal preview_changed(valid: bool)
signal supply_received(amount: int, remaining: int)
const ConstructionPiece = preload("res://scripts/construction_piece.gd")
const Support = preload("res://scripts/construction_support.gd")
const BuildAudio = preload("res://scripts/construction_audio.gd")
# Al clarified on 2026-10-20: each filmed "metre" unit was two feet.
# Four reference units are eight feet, converted once to SI metres.
const REFERENCE_UNIT_METRES := 0.6096 * preload("res://scripts/measurement_calibration.gd").FACTOR
const PANEL_SIDE := 4.0 * REFERENCE_UNIT_METRES
signal collapse_scheduled(piece:StaticBody3D,delay:float)
@export var initial_charges := 999
@export var max_charges := 0 #089 unlimited; retained property for compatibility
@export var wall_health := 180.0
@export var ramp_health := 160.0
@export var floor_health := 140.0
@export var max_debris := 24
@export var debris_lifetime := 0.65
@export var max_live_pieces := 256
@export var collapse_step_seconds := 0.30
@export var support_poll_seconds := 0.25
@export var placement_range := 6.0
@export var piece_cost := 1
@export var grid_spacing := PANEL_SIDE
@export var grid_height_step := 0.1
@export var minimum_wall_height := PANEL_SIDE
var wall_height := PANEL_SIDE
var placement_cost:=1
var _planned:Array[Dictionary]=[]
var _secondary_preview:MeshInstance3D
var charges := 999
var piece_index := 0
var kinds := ["wall", "floor"]
const Grid = preload("res://scripts/build_grid.gd")
@export var grid_origin := Vector3.ZERO
@export var minimum_placement_distance := 0.0
@export var minimum_vertical_placement_distance := .4572 #088 eighteen inches, walls only
@export var intersection_hysteresis := .08
var _preferred_slot := ""
var _preferred_candidate:Dictionary={}
var pieces: Array[StaticBody3D] = []
var preview: MeshInstance3D
var preview_valid := false
var invalid_reason := ""
var _lightning:MeshInstance3D
var _active := false
var _level_y := 0.0
var _floor_grid_origin:=Vector2.ZERO
var _trigger := true
var _cycle := true
var _rearm := true
var _actor: Node
var _rack: Node
var _game: Node
var input_eligible: Callable
func reserves_shape_button()->bool:
	return false # B belongs exclusively to marking.
var _shape: Shape3D
var _placement := Transform3D.IDENTITY
var _preview_material: StandardMaterial3D
var _supply_events: Dictionary = {}
var _debris: Array[Node3D] = []
var _support_edges:Dictionary={}
var _support_entries:Dictionary={}
var _world_roots:Dictionary={}
var _supported:Dictionary={}
var _collapse_pending:Dictionary={}
var _support_dirty:=true
var _support_clock:=0.0
var _collapse_time:=0.0
var _last_state:Dictionary={}
var _audio_voices:Array[AudioStreamPlayer3D]=[]
var _audio_cursor:=0
var _lightning_audio:AudioStreamPlayer3D
var _lightning_was_active:=false
func _panel_entry(body:StaticBody3D)->Dictionary:
	var kind:String=body.get_meta("construction_kind","wall")
	var shape:Shape3D=body.get_meta("construction_shape",null)
	if shape==null:shape=_geometry(kind).shape
	return {"kind":kind,"at":body.global_transform,"shape":shape}

func _world_contact(entry:Dictionary)->bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=entry.shape;query.transform=entry.at;query.collision_mask=1;query.margin=Support.CONTACT_TOLERANCE
	var excluded:Array[RID]=[]
	for body in pieces:
		if is_instance_valid(body):excluded.append(body.get_rid())
	if _actor is CollisionObject3D:excluded.append(_actor.get_rid())
	query.exclude=excluded
	for hit in get_world_3d().direct_space_state.intersect_shape(query,64):
		var collider=hit.get("collider")
		# Moving actors/loot are not permanent map anchors. Compound world shapes
		# are tested locally by physics, rather than exempting an entire RID.
		if collider is StaticBody3D or collider is CSGShape3D or collider is GridMap:
			if not collider.is_in_group("field_construction"):return true
	return false

func _connected_to_supported(entries:Array)->bool:
	if _support_dirty:_refresh_support_graph()
	var accepted:Dictionary={}
	for i in entries.size():
		if _world_contact(entries[i]):accepted[i]=true
		else:
			for body in pieces:
				if is_instance_valid(body) and _supported.has(body.get_instance_id()) and Support.connected(entries[i],_panel_entry(body),grid_spacing):
					accepted[i]=true;break
	var changed:=true
	while changed:
		changed=false
		for i in entries.size():
			if accepted.has(i):continue
			for j in accepted.keys():
				if Support.connected(entries[i],entries[j],grid_spacing):accepted[i]=true;changed=true;break
	return accepted.size()==entries.size()

func _refresh_support_graph(severed_neighbors:Array=[])->void:
	var live:Dictionary={};var entries:Dictionary={}
	var changed:Array=[]
	for body in pieces:
		if is_instance_valid(body) and not body.broken:
			var id:=body.get_instance_id();live[id]=body
			var entry:=_panel_entry(body)
			if _support_entries.has(id) and _support_entries[id].at==entry.at:entries[id]=_support_entries[id]
			else:entries[id]=entry;changed.append(id)
	# Static panels keep their finite contact edges. A normal placement checks
	# just the new panel against its neighbors, rather than rebuilding N² edges.
	for id in _support_edges.keys():
		if not live.has(id):
			for neighbor in _support_edges[id]:
				if _support_edges.has(neighbor):_support_edges[neighbor].erase(id)
			_support_edges.erase(id)
	for id in changed:
		for neighbor in _support_edges.get(id,[]):
			if _support_edges.has(neighbor):_support_edges[neighbor].erase(id)
		_support_edges[id]=[]
	for id in changed:
		for other in live:
			if id==other or _support_edges[id].has(other):continue
			if Support.connected(entries[id],entries[other],grid_spacing):
				_support_edges[id].append(other);_support_edges[other].append(id)
	_support_entries=entries;_support_dirty=false
	var old_roots:=_world_roots.duplicate();_world_roots.clear();_supported.clear()
	var frontier:Array=[]
	for id in live:
		if _world_contact(entries[id]):_world_roots[id]=true;_supported[id]=true;frontier.append(id)
	var cursor:=0
	while cursor<frontier.size():
		var id:int=frontier[cursor];cursor+=1
		for neighbor in _support_edges.get(id,[]):
			if live.has(neighbor) and not _supported.has(neighbor):_supported[neighbor]=true;frontier.append(neighbor)
	# A second surviving world anchor prevents the whole component collapsing.
	for id in _collapse_pending.keys():
		if not live.has(id) or _supported.has(id):_collapse_pending.erase(id)
	var distance:Dictionary={};frontier.clear();cursor=0
	for id in severed_neighbors:
		if live.has(id) and not _supported.has(id):distance[id]=1;frontier.append(id)
	for id in old_roots:
		if live.has(id) and not _supported.has(id) and not distance.has(id):distance[id]=1;frontier.append(id)
	while cursor<frontier.size():
		var id:int=frontier[cursor];cursor+=1
		for neighbor in _support_edges.get(id,[]):
			if live.has(neighbor) and not _supported.has(neighbor) and not distance.has(neighbor):distance[neighbor]=int(distance[id])+1;frontier.append(neighbor)
	for id in live:
		if _supported.has(id) or _collapse_pending.has(id):continue
		var delay:=maxf(.01,collapse_step_seconds)*float(distance.get(id,1))
		_collapse_pending[id]=_collapse_time+delay
		collapse_scheduled.emit(live[id],delay)

func _physics_process(delta:float)->void:
	if _game!=null and _game.get("paused")==true:return
	_collapse_time+=delta;_support_clock+=delta
	if _support_dirty or _support_clock>=maxf(.05,support_poll_seconds):
		_support_clock=0.0;_refresh_support_graph()
	var due:Array=[]
	for id in _collapse_pending:
		if float(_collapse_pending[id])<=_collapse_time+.00001:due.append(id)
	# Refresh before breaking: a newly attached supported branch can rescue it.
	if not due.is_empty():
		_refresh_support_graph()
		for id in due:
			if not _collapse_pending.has(id):continue
			var body=instance_from_id(id)
			if is_instance_valid(body):body.collapse()

func _play_build_sound(point:Vector3,breaking:bool=false)->void:
	if _audio_voices.is_empty():
		for i in 8:
			var voice:=AudioStreamPlayer3D.new();voice.name="BuildSound"+str(i);voice.max_distance=48;voice.unit_size=8;voice.volume_db=2;add_child(voice);_audio_voices.append(voice)
	var voice:AudioStreamPlayer3D=_audio_voices[_audio_cursor];_audio_cursor=(_audio_cursor+1)%_audio_voices.size()
	voice.stop();voice.global_position=point;voice.bus="SFX";voice.volume_db=-10;voice.stream=AshAudioBank.sample("build_break" if breaking else "build_place",_audio_cursor);voice.play()

func award_supply(event_id: String, amount: int = 3) -> int:
	if event_id.is_empty() or amount <= 0 or _supply_events.has(event_id):
		return 0
	_supply_events[event_id] = true
	var granted := amount
	charges += granted
	if granted > 0:
		supply_received.emit(granted, charges)
	return granted

func _piece_destroyed(body: StaticBody3D) -> void:
	var neighbors:Array=_support_edges.get(body.get_instance_id(),[]).duplicate()
	pieces.erase(body)
	_collapse_pending.erase(body.get_instance_id());_support_dirty=true
	_play_build_sound(body.global_position,true)
	_refresh_support_graph(neighbors)
	for index in range(6):
		while _debris.size() >= maxi(1, max_debris):
			var oldest: Node3D = _debris.pop_front()
			if is_instance_valid(oldest):
				oldest.queue_free()
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12,0.16,0.035)
		shard.mesh = mesh
		shard.material_override = body.visual.material_override
		add_child(shard)
		shard.global_position = body.global_position + Vector3((index % 3 - 1) * 0.35, (index / 3) * 0.3,0)
		_debris.append(shard)
		var tween := create_tween().bind_node(shard).set_parallel(true)
		tween.tween_property(shard,"position",shard.position + Vector3((index % 3 - 1) * 0.5,-0.6,0.3),debris_lifetime)
		tween.tween_property(shard,"scale",Vector3.ZERO,debris_lifetime)
		tween.chain().tween_callback(_remove_debris.bind(shard.get_instance_id()))

func _remove_debris(instance_id: int) -> void:
	var shard := instance_from_id(instance_id) as Node3D
	_debris.erase(shard)
	if is_instance_valid(shard):
		shard.queue_free()

func setup(actor: Node, rack: Node, game: Node) -> void:
	_actor = actor
	_rack = rack
	_game = game
	wall_height=PANEL_SIDE;grid_spacing=PANEL_SIDE
	charges = initial_charges
	preview = MeshInstance3D.new()
	preview.name = "ConstructionPreview"
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_material = StandardMaterial3D.new()
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	preview.material_override = _preview_material
	add_child(preview)
	preview.visible = false
	_lightning=preload("res://scripts/build_lightning_085.gd").new();add_child(_lightning);_lightning.hide()
	_secondary_preview=MeshInstance3D.new();_secondary_preview.name="LowerSupportPreview";_secondary_preview.material_override=_preview_material;_secondary_preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(_secondary_preview);_secondary_preview.hide()
	_set_piece()

func is_active() -> bool:
	return _active

func reset_builds() -> void:
	for body in pieces:
		if is_instance_valid(body):
			body.queue_free()
	pieces.clear()
	_support_edges.clear();_support_entries.clear();_world_roots.clear();_supported.clear();_collapse_pending.clear();_support_dirty=true;_support_clock=0.0;_collapse_time=0.0
	for voice in _audio_voices:voice.stop()
	charges = initial_charges
	_supply_events.clear()
	for shard in _debris:
		if is_instance_valid(shard):
			shard.queue_free()
	_debris.clear()
	_cancel()

func _cancel() -> void:
	if _lightning!=null:_lightning.update_bolt(Vector3.ZERO,Vector3.ZERO,false)
	if _lightning_audio!=null:_lightning_audio.stop()
	_lightning_was_active=false
	_active = false
	_preferred_slot = ""
	_preferred_candidate.clear()
	preview_valid = false
	_rearm = true
	if preview != null:
		preview.visible = false
	if _secondary_preview!=null:_secondary_preview.hide()
	_planned.clear()

func _capture_floor_grid(_state:Dictionary)->void:
	# Compatibility entry: never reanchor to the player, roof, hand or session.
	_level_y=grid_origin.y
	_floor_grid_origin=Vector2(grid_origin.x,grid_origin.z)
func tick_input(state: Dictionary) -> bool:
	# Physical eye-height changes never resize the corrected eight-foot grid.
	var pressed: bool = state.get("trigger", false)
	var cycling: bool = state.get("cycle", false)
	var conflict: bool = not state.get("eligible", false) or not state.get("tracking", false) or state.get("cancel", false)
	var consumed := _active
	if conflict:
		_cancel()
		_trigger = pressed
		_cycle = cycling
		return consumed
	if _rearm:
		if pressed:
			_trigger = pressed
			_cycle = cycling
			return consumed
		_rearm = false
	var fresh := pressed and not _trigger
	if not _active and fresh:
		_active = true
		_level_y = grid_origin.y
		_capture_floor_grid(state)
		consumed = true
	if _active:
		consumed = true

	if _active:
		_update_placement(state)
		if not pressed and _trigger:
			_commit()
			_cancel()
	preview.visible = _active
	var beam_start:Vector3=state.get("origin",Vector3.ZERO)
	var beam_direction:Vector3=state.get("direction",Vector3.FORWARD)
	var beam_distance:float=float(_preferred_candidate.get("distance",placement_range))
	var beam_end:=beam_start+beam_direction.normalized()*beam_distance
	_lightning.update_bolt(beam_start,beam_end,_active and preview_valid)
	_update_lightning_audio(beam_start,_active and preview_valid)
	_trigger = pressed
	_cycle = cycling
	return consumed

func _geometry(kind:String)->Dictionary:
	if kind=="ramp":
		var half:=grid_spacing*.5
		var points:=PackedVector3Array([Vector3(-half,0,half),Vector3(half,0,half),Vector3(-half,0,-half),Vector3(half,0,-half),Vector3(-half,wall_height,-half),Vector3(half,wall_height,-half)])
		var convex:=ConvexPolygonShape3D.new();convex.points=points
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0,1,3,0,3,2,0,4,5,0,5,1,2,3,5,2,5,4,0,2,4,1,5,3]:surface.add_vertex(points[i])
		surface.generate_normals();return {"shape":convex,"mesh":surface.commit()}
	var size:=Vector3(grid_spacing,wall_height,.08) if kind=="wall" else Vector3(grid_spacing,.08,grid_spacing)
	var shape:=BoxShape3D.new();shape.size=size
	var mesh:=BoxMesh.new();mesh.size=size
	return {"shape":shape,"mesh":mesh}

func _set_piece()->void:
	var geometry:=_geometry(kinds[piece_index]);_shape=geometry.shape;preview.mesh=geometry.mesh
	_planned.clear()
	if _secondary_preview!=null:_secondary_preview.hide()

func _slot_for(at:Transform3D,kind:String)->String:
	var orientation:=0
	if kind=="wall":orientation=1 if absf(at.basis.z.x)>.5 else 0
	elif kind=="ramp":orientation=posmod(roundi(at.basis.get_euler().y/(PI*.5)),4)
	return "%s:%d:%d:%d:%d"%[kind,roundi(at.origin.x*2/grid_spacing),roundi(at.origin.y*2/grid_spacing),roundi(at.origin.z*2/grid_spacing),orientation]
func _slot_key()->String:return _slot_for(_placement,kinds[piece_index])
func _has_slot(key:String)->bool:
	for body in pieces:
		if is_instance_valid(body) and body.get_meta("grid_slot","")==key:return true
	return false
func _slot_occupied()->bool:return _has_slot(_slot_key())

func _ground_samples(at:Transform3D,base_y:float,kind:String,exclusions:Array[RID])->Dictionary:
	var result:={"found":false,"max_y":-INF,"min_y":INF,"rids":[],"contacts":[],"count":0,"total":0}
	var points:Array[Vector3]=[Vector3.ZERO]
	if kind=="wall":
		for offset in [-.501,-.22,.22,.501]:
			for depth in [-.041,.041]:points.append(at.basis.x*grid_spacing*offset+at.basis.z*depth)
	else:
		# Include a 0.1%-of-panel seam at the finite tile boundary. Sampling 1%
		# inside missed a roof whose edge exactly met the next floor's edge.
		for x in [-.501,.501]:
			for z in [-.501,.501]:points.append(Vector3(x*grid_spacing,0,z*grid_spacing))
		for edge in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:points.append(edge*grid_spacing*.501)
	var space:=get_world_3d().direct_space_state
	result.total=points.size()
	for offset in points:
		var spot:=at.origin+offset
		var query:=PhysicsRayQueryParameters3D.create(Vector3(spot.x,base_y+wall_height+.25,spot.z),Vector3(spot.x,base_y-wall_height*3,spot.z),1,exclusions)
		var hit:=space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<.25:continue
		result.found=true;result.count+=1;result.max_y=maxf(result.max_y,hit.position.y);result.min_y=minf(result.min_y,hit.position.y)
		if not result.rids.has(hit.rid):result.rids.append(hit.rid)
		result.contacts.append({"rid":hit.rid,"shape":hit.shape})
	return result

func _plan_entry(kind:String,at:Transform3D,ground:Dictionary,support:bool=false)->Dictionary:
	var geometry:=_geometry(kind)
	return {"kind":kind,"at":at,"shape":geometry.shape,"mesh":geometry.mesh,"key":_slot_for(at,kind),"ground":ground,"support":support}

func _entry_clear(entry:Dictionary,exclusions:Array[RID],state:Dictionary)->String:
	var at:Transform3D=entry.at
	var mesh:Mesh=entry.mesh
	if entry.kind=="wall" and not entry.get("support",false) and state.has("origin") and state.has("direction"):
		var direction:Vector3=state.direction.normalized()
		var denominator:=direction.dot(at.basis.z)
		if absf(denominator)>.000001:
			var depth:float=(at.origin-state.origin).dot(at.basis.z)/denominator
			if depth<minimum_vertical_placement_distance-.00001:return "vertical_minimum_distance"
	var head:Vector3=state.get("head",state.get("origin",Vector3.ZERO))
	if mesh.get_aabb().grow(.20).has_point(at.affine_inverse()*head):return "head_clearance"
	var target_method:="_construction_protected_targets" if _game!=null and _game.has_method("_construction_protected_targets") else "_objective_grip_targets"
	if _game!=null and _game.has_method(target_method):
		for target in _game.call(target_method):
			var point:Vector3=target.global_position if target is Node3D else target.get("position",Vector3.ZERO)
			if mesh.get_aabb().grow(.4).has_point(at.affine_inverse()*point):return "objective_clearance"
	if _actor is CollisionObject3D:
		var safety:=PhysicsShapeQueryParameters3D.new();safety.shape=entry.shape;safety.transform=at;safety.collision_mask=2
		for contact in get_world_3d().direct_space_state.intersect_shape(safety,32):
			if contact.collider==_actor:return "player_clearance"
	# World geometry may overlap panels; head/objective safety above still applies.
	# Support graph and duplicate-slot checks remain authoritative.
	return ""

func _ramp_ray_distance(_at:Transform3D,_origin:Vector3,_direction:Vector3)->float:
	return INF # Ramps are no longer placeable.
func _next_ray_cell(origin:Vector3,direction:Vector3,distance:float,anchor:float)->float:
	var point:=origin+direction*distance
	var next:=INF
	for axis in 3:
		if absf(direction[axis])<.00001:continue
		var offset:=anchor if axis==1 else 0.0
		var cell:=floorf((point[axis]-offset)/grid_spacing)
		var boundary:float=(cell+(1.0 if direction[axis]>0 else 0.0))*grid_spacing+offset
		var crossing:float=(boundary-origin[axis])/direction[axis]
		if crossing>distance+.00001:next=minf(next,crossing)
	return next+.0001

func _placement_candidates(origin:Vector3,direction:Vector3,maximum:float)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for candidate in Grid.intersections(origin,direction,grid_origin,grid_spacing,minimum_placement_distance,maximum):
		if candidate.kind=="wall" and float(candidate.distance)<minimum_vertical_placement_distance-.00001:continue
		result.append(candidate)
	return result
func _aimed_panel(origin:Vector3,direction:Vector3,_point:Vector3,_kind:String,_anchor:float)->Dictionary:
	for candidate in _placement_candidates(origin,direction,placement_range):
		if not _has_slot(_slot_for(candidate.at,candidate.kind)):return candidate
	return {"reason":"reach"}
func _update_placement(state:Dictionary)->void:
	_last_state=state.duplicate();preview_valid=false;invalid_reason="reach";_planned.clear();_secondary_preview.hide()
	var origin:Vector3=state.get("origin",Vector3.ZERO)
	var direction:Vector3=state.get("direction",Vector3.FORWARD)
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared()<.001:return
	direction=direction.normalized()
	var exclusions:Array[RID]=[]
	for rid in state.get("exclusions",[]):exclusions.append(rid)
	if _actor is CollisionObject3D:exclusions.append(_actor.get_rid())
	var limit:float=placement_range # World overlap is explicitly allowed.
	var candidates:=_placement_candidates(origin,direction,minf(placement_range,limit))
	# Retain the same finite lattice face across tiny edge/corner aim changes.
	# It still must satisfy ray depth, reach and normal support checks.
	if not candidates.is_empty() and not _preferred_candidate.is_empty():
		var axis:int=_preferred_candidate.axis
		var at:Transform3D=_preferred_candidate.at
		if absf(direction[axis])>.000001:
			var distance:float=(at.origin[axis]-origin[axis])/direction[axis]
			var offset:Vector3=origin+direction*distance-at.origin
			var within_face:=true
			for component in 3:
				if component!=axis and absf(offset[component])>grid_spacing*.5+intersection_hysteresis:within_face=false
			var minimum:=maxf(minimum_placement_distance,minimum_vertical_placement_distance if _preferred_candidate.kind=="wall" else 0.0)
			if within_face and distance>=minimum and distance<=minf(placement_range,limit) and absf(distance-float(candidates[0].distance))<=intersection_hysteresis:
				var preferred:Dictionary=_preferred_candidate.duplicate();preferred.distance=distance;candidates.push_front(preferred)
	var first_failure:="reach";var tried:=false
	for candidate in candidates:
		if _has_slot(_slot_for(candidate.at,candidate.kind)):continue
		if _evaluate_grid_candidate(candidate,state,exclusions):
			_preferred_slot=_slot_for(candidate.at,candidate.kind);_preferred_candidate=candidate.duplicate();_finish_preview(true);return
		if not tried:first_failure=invalid_reason;tried=true
	invalid_reason=first_failure if tried else "reach"
	_planned.clear();_finish_preview(false)

func _evaluate_grid_candidate(selected:Dictionary,state:Dictionary,exclusions:Array[RID])->bool:
	var kind:String=selected.kind
	piece_index=kinds.find(kind);_set_piece()
	var at:Transform3D=selected.at;var base_y:float=selected.base_y
	var ground:=_ground_samples(at,base_y,kind,exclusions)
	_placement=at;preview.global_transform=at
	var primary:=_plan_entry(kind,at,ground);_planned.append(primary)
	if kind=="floor" and ground.found and ground.count==ground.total and ground.min_y>=at.origin.y-.025:
		invalid_reason="buried_floor";return false
	if kind=="wall" and _wall_fully_buried_091(at,exclusions):invalid_reason="buried_wall";return false
	if not _connected_to_supported(_planned):
		var below:=at
		if kind=="wall":below.origin.y-=grid_spacing
		else:below=Transform3D(Basis.IDENTITY,Vector3(at.origin.x,base_y-grid_spacing*.5,at.origin.z-grid_spacing*.5))
		var lower:=_plan_entry("wall",below,ground,true)
		if not _has_slot(lower.key):_planned.push_front(lower)
	placement_cost=_planned.size()*piece_cost
	if charges<placement_cost or pieces.size()+_planned.size()>max_live_pieces:invalid_reason="capacity";return false
	for entry in _planned:
		var reason:=_entry_clear(entry,exclusions,state)
		if not reason.is_empty():invalid_reason=reason;return false
	if not _connected_to_supported(_planned):invalid_reason="unsupported";return false
	invalid_reason="";return true
func _finish_preview(valid:bool)->void:
	preview_valid=valid
	_preview_material.albedo_color=Color(.8,.8,.8,.35) if valid else Color(1,.12,.1,.3)
	if _planned.size()>1:
		_secondary_preview.mesh=_planned[0].mesh;_secondary_preview.global_transform=_planned[0].at;_secondary_preview.visible=_active
	preview_changed.emit(valid)

func _wall_fully_buried_091(at:Transform3D,exclusions:Array[RID])->bool:
	# Probe above the entire reachable depth, independently of local support rays.
	# Skip roofs / catwalks / loot: only actual terrain defines underground.
	if get_tree().get_nodes_in_group("terrain_surface").is_empty() and get_tree().get_nodes_in_group("construction_terrain").is_empty():return false
	var space:=get_world_3d().direct_space_state
	for x in [-.501,.501]:
		for z in [-.041,.041]:
			var corner:Vector3=at*Vector3(x*grid_spacing,wall_height*.5,z)
			var start:=corner+Vector3.UP*(placement_range+wall_height+1.0)
			var skipped:Array[RID]=exclusions.duplicate();var buried:=false
			for pass_index in 32:
				var query:=PhysicsRayQueryParameters3D.create(start,corner-Vector3.UP*.001,1,skipped)
				var hit:=space.intersect_ray(query)
				if hit.is_empty():break
				if (hit.collider.is_in_group("terrain_surface") or hit.collider.is_in_group("construction_terrain")) and hit.normal.y>.01:buried=true;break
				skipped.append(hit.rid)
			if not buried:return false # Any exposed top corner keeps a partial panel eligible.
	return true

func _spawn_entry(entry:Dictionary)->void:
	if entry.kind not in kinds:return
	var body:=ConstructionPiece.new();body.name="Field_"+str(entry.kind);body.collision_layer=1;body.collision_mask=1
	body.add_to_group("climbable");body.add_to_group("field_construction");body.set_meta("construction_kind",entry.kind);body.set_meta("grid_slot",entry.key)
	body.set_meta("lower_support",entry.support)
	body.set_meta("construction_shape",entry.shape)
	var mesh:=MeshInstance3D.new();mesh.mesh=entry.mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.9,.9,.9);material.metallic=.6;material.roughness=.7;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	body.apply_panel_material(material);mesh.material_override=material;body.add_child(mesh)
	var collider:=CollisionShape3D.new();collider.shape=entry.shape;body.add_child(collider)
	body.configure({"wall":wall_health,"ramp":ramp_health,"floor":floor_health}[entry.kind],mesh)
	body.destroyed.connect(_piece_destroyed);add_child(body);body.global_transform=entry.at;pieces.append(body)
	_support_dirty=true

func _commit()->void:
	if not preview_valid or _slot_occupied():return
	var entries:Array[Dictionary]=_planned.duplicate()
	# Direct fixture/legacy API calls can supply a previously validated transform.
	if entries.is_empty():entries.append(_plan_entry(kinds[piece_index],_placement,{"found":false,"max_y":-INF,"min_y":INF,"rids":[]}))
	var unique:Array[Dictionary]=[]
	for entry in entries:
		if not _has_slot(entry.key):unique.append(entry)
	var cost:=unique.size()*piece_cost
	if unique.is_empty() or charges<cost or pieces.size()+unique.size()>max_live_pieces:return
	if _last_state.has("head"):
		var exclusions:Array[RID]=[]
		for rid in _last_state.get("exclusions",[]):exclusions.append(rid)
		if _actor is CollisionObject3D:exclusions.append(_actor.get_rid())
		for entry in unique:
			var reason:=_entry_clear(entry,exclusions,_last_state)
			if not reason.is_empty():invalid_reason=reason;_finish_preview(false);return
	# Recheck connectivity at commit, including when a support broke after the
	# preview or a caller supplied a legacy validated transform.
	_refresh_support_graph()
	if not _connected_to_supported(unique):
		invalid_reason="unsupported";_finish_preview(false);return
	# Validate total cost/capacity before creating either member: never half-build.
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:
		network_bridge.gateway("build",unique);_rearm=true;return
	for entry in unique:_spawn_entry(entry)
	_refresh_support_graph()
	_play_build_sound(_placement.origin)
	charges-=cost;placed.emit(kinds[piece_index],charges)



func _update_lightning_audio(point:Vector3,on:bool)->void:
	if _lightning_audio==null:
		_lightning_audio=AudioStreamPlayer3D.new();_lightning_audio.name="ConstructionLightning";_lightning_audio.bus="SFX";_lightning_audio.volume_db=-22;_lightning_audio.max_distance=12;_lightning_audio.stream=AshAudioBank.sample("build_lightning");add_child(_lightning_audio)
	_lightning_audio.global_position=point
	if on and not _lightning_was_active:_lightning_audio.play()
	elif not on and _lightning_was_active:_lightning_audio.stop()
	_lightning_was_active=on
